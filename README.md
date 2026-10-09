# KS Judo Team Masters Gliwice — aplikacja klubowa

Aplikacja mobilna (Flutter) z backendem Supabase.

- **Treningi** — cotygodniowy rozkład zajęć dla grup
- **Zawody** — kalendarz nadchodzących i minionych zawodów, zapisy zawodników
- **Zawodnicy** — lista członków klubu (pas, kategoria wagowa)
- **Notatki** — prywatne notatki każdego użytkownika (widzi je tylko autor)

Role: **trener** edytuje rozkład, zawody, zawodników i potwierdza zapisy;
**zawodnik** przegląda, zapisuje się/wypisuje z zawodów i edytuje swój profil.

## Struktura

```
supabase/migrations/   schemat bazy + uprawnienia (RLS)
app/                   aplikacja Flutter
```

## Uruchomienie

### 1. Supabase

1. Załóż darmowy projekt na <https://supabase.com>.
2. **SQL Editor** → wklej `supabase/migrations/0001_init.sql` → **Run**.
3. **Project Settings → API Keys** → skopiuj *Project URL* i *Publishable key*.
4. (Opcjonalnie, na czas testów) **Authentication → Sign In / Providers → Email** —
   wyłącz *Confirm email*, żeby nie trzeba było potwierdzać maili.

### 2. Aplikacja

```bash
cd app
cp env.example.json env.json   # wpisz URL i klucz z kroku 1.3
flutter pub get
flutter run --dart-define-from-file=env.json
```

### 3. Pierwszy trener

Zarejestruj się w aplikacji, potem w Supabase **SQL Editor**:

```sql
update public.profiles set role = 'coach'
where id = (select id from auth.users where email = 'twoj@email.pl');
```

Kolejnych trenerów można już ustawiać w aplikacji (Zawodnicy → profil → Trener).

## Testy

```bash
cd app && flutter test
```
