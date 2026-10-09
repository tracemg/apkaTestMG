import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Jedno miejsce z wszystkimi zapytaniami do Supabase.
class Repository {
  Repository(this._db);

  final SupabaseClient _db;

  String get uid => _db.auth.currentUser!.id;

  // ---------- Auth ----------

  Future<void> signIn(String email, String password) =>
      _db.auth.signInWithPassword(email: email, password: password);

  Future<void> signUp(String email, String password, String fullName) => _db
      .auth
      .signUp(email: email, password: password, data: {'full_name': fullName});

  Future<void> signOut() => _db.auth.signOut();

  // ---------- Profile ----------

  Future<Profile> myProfile() async => Profile.fromJson(
    await _db.from('profiles').select().eq('id', uid).single(),
  );

  Future<List<Profile>> profiles() async {
    final rows = await _db.from('profiles').select().order('full_name');
    return rows.map(Profile.fromJson).toList();
  }

  Future<void> updateProfile(String id, Map<String, dynamic> fields) =>
      _db.from('profiles').update(fields).eq('id', id);

  // ---------- Treningi ----------

  Future<List<Training>> trainings() async {
    final rows = await _db
        .from('trainings')
        .select()
        .order('weekday')
        .order('start_time');
    return rows.map(Training.fromJson).toList();
  }

  Future<void> saveTraining(Training t) => t.id == null
      ? _db.from('trainings').insert(t.toJson())
      : _db.from('trainings').update(t.toJson()).eq('id', t.id!);

  Future<void> deleteTraining(int id) =>
      _db.from('trainings').delete().eq('id', id);

  // ---------- Zawody ----------

  Future<List<Competition>> competitions({required bool past}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final query = _db.from('competitions').select();
    final rows = past
        ? await query
              .lt('date_start', today)
              .order('date_start', ascending: false)
        : await query.gte('date_start', today).order('date_start');
    return rows.map(Competition.fromJson).toList();
  }

  Future<Competition> competition(int id) async => Competition.fromJson(
    await _db.from('competitions').select().eq('id', id).single(),
  );

  Future<void> saveCompetition(Competition c) => c.id == null
      ? _db.from('competitions').insert(c.toJson())
      : _db.from('competitions').update(c.toJson()).eq('id', c.id!);

  Future<void> deleteCompetition(int id) =>
      _db.from('competitions').delete().eq('id', id);

  Future<List<CompetitionEntry>> entries(int competitionId) async {
    final rows = await _db
        .from('competition_entries')
        .select('*, profiles(*)')
        .eq('competition_id', competitionId)
        .order('created_at');
    return rows.map(CompetitionEntry.fromJson).toList();
  }

  Future<void> register(int competitionId, String? weightCategory) =>
      _db.from('competition_entries').insert({
        'competition_id': competitionId,
        'athlete_id': uid,
        'weight_category': weightCategory,
      });

  Future<void> unregister(int competitionId, String athleteId) => _db
      .from('competition_entries')
      .delete()
      .eq('competition_id', competitionId)
      .eq('athlete_id', athleteId);

  Future<void> setEntryStatus(
    int competitionId,
    String athleteId,
    EntryStatus status,
  ) => _db
      .from('competition_entries')
      .update({'status': status.name})
      .eq('competition_id', competitionId)
      .eq('athlete_id', athleteId);

  // ---------- Notatki ----------

  Future<List<Note>> notes() async {
    final rows = await _db
        .from('notes')
        .select()
        .order('updated_at', ascending: false);
    return rows.map(Note.fromJson).toList();
  }

  Future<void> saveNote(Note n) => n.id == null
      ? _db.from('notes').insert(n.toJson())
      : _db.from('notes').update(n.toJson()).eq('id', n.id!);

  Future<void> deleteNote(int id) => _db.from('notes').delete().eq('id', id);
}
