-- KS Judo Team Masters Gliwice — schemat bazy
-- Uruchom w Supabase: SQL Editor -> wklej całość -> Run.

-- ============================================================
-- Profile użytkowników (zawodnicy i trenerzy)
-- ============================================================
create type public.user_role as enum ('athlete', 'coach');

create table public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  full_name       text not null default '',
  role            public.user_role not null default 'athlete',
  belt            text,               -- np. '6 kyu (żółty)'
  weight_category text,               -- np. '-73 kg'
  birth_year      int,
  phone           text,
  created_at      timestamptz not null default now()
);

-- Czy zalogowany użytkownik jest trenerem? (security definer omija RLS,
-- żeby polityki na profiles nie wywoływały się rekurencyjnie)
create or replace function public.is_coach()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and role = 'coach'
  );
$$;

-- Nowy użytkownik w auth.users -> automatycznie profil zawodnika
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Zawodnik nie może sam nadać sobie roli trenera.
-- auth.uid() is null = zmiana z SQL Editora / service role (tak nadajesz pierwszego trenera).
create or replace function public.protect_role()
returns trigger
language plpgsql
as $$
begin
  if new.role is distinct from old.role
     and auth.uid() is not null
     and not public.is_coach() then
    raise exception 'Tylko trener może zmieniać role';
  end if;
  return new;
end;
$$;

create trigger profiles_protect_role
  before update on public.profiles
  for each row execute function public.protect_role();

-- ============================================================
-- Rozkład treningów (cotygodniowy)
-- ============================================================
create table public.trainings (
  id          bigint generated always as identity primary key,
  weekday     smallint not null check (weekday between 1 and 7), -- 1 = poniedziałek
  start_time  time not null,
  end_time    time not null check (end_time > start_time),
  group_name  text not null,          -- np. 'Dzieci 6-9', 'Seniorzy'
  location    text,
  notes       text,
  created_at  timestamptz not null default now()
);

-- ============================================================
-- Zawody i zapisy
-- ============================================================
create table public.competitions (
  id                    bigint generated always as identity primary key,
  name                  text not null,
  date_start            date not null,
  date_end              date check (date_end is null or date_end >= date_start),
  location              text,
  registration_deadline date,
  url                   text,
  description           text,
  created_at            timestamptz not null default now()
);

create type public.entry_status as enum ('registered', 'confirmed', 'withdrawn');

create table public.competition_entries (
  competition_id  bigint not null references public.competitions (id) on delete cascade,
  athlete_id      uuid not null references public.profiles (id) on delete cascade,
  weight_category text,
  status          public.entry_status not null default 'registered',
  created_at      timestamptz not null default now(),
  primary key (competition_id, athlete_id)
);

-- ============================================================
-- Prywatne notatki (każdy widzi tylko swoje)
-- ============================================================
create table public.notes (
  id          bigint generated always as identity primary key,
  owner_id    uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  title       text not null default '',
  body        text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index notes_owner_idx on public.notes (owner_id, updated_at desc);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger notes_touch
  before update on public.notes
  for each row execute function public.touch_updated_at();

-- ============================================================
-- Row Level Security
-- ============================================================
alter table public.profiles            enable row level security;
alter table public.trainings           enable row level security;
alter table public.competitions        enable row level security;
alter table public.competition_entries enable row level security;
alter table public.notes               enable row level security;

-- profiles: wszyscy zalogowani widzą listę; edycja własnego profilu albo trener
create policy "profiles read"   on public.profiles for select to authenticated using (true);
create policy "profiles update" on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_coach())
  with check (id = auth.uid() or public.is_coach());

-- trainings / competitions: czytają wszyscy zalogowani, edytuje trener
create policy "trainings read"  on public.trainings for select to authenticated using (true);
create policy "trainings write" on public.trainings for all    to authenticated
  using (public.is_coach()) with check (public.is_coach());

create policy "competitions read"  on public.competitions for select to authenticated using (true);
create policy "competitions write" on public.competitions for all    to authenticated
  using (public.is_coach()) with check (public.is_coach());

-- competition_entries: wszyscy widzą kto jedzie; zawodnik zapisuje/wypisuje siebie,
-- trener zarządza wszystkimi (w tym statusem 'confirmed')
create policy "entries read" on public.competition_entries for select to authenticated using (true);
create policy "entries insert" on public.competition_entries for insert to authenticated
  with check (public.is_coach() or (athlete_id = auth.uid() and status = 'registered'));
create policy "entries update" on public.competition_entries for update to authenticated
  using (public.is_coach()) with check (public.is_coach());
create policy "entries delete" on public.competition_entries for delete to authenticated
  using (public.is_coach() or athlete_id = auth.uid());

-- notes: tylko właściciel
create policy "notes owner" on public.notes for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
