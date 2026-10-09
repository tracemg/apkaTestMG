import 'package:flutter_test/flutter_test.dart';
import 'package:judo_masters/models.dart';

void main() {
  test('Training parsuje czas z Postgresa do HH:mm', () {
    final t = Training.fromJson({
      'id': 1,
      'weekday': 2,
      'start_time': '17:30:00',
      'end_time': '19:00:00',
      'group_name': 'Seniorzy',
      'location': null,
      'notes': null,
    });
    expect(t.startTime, '17:30');
    expect(t.endTime, '19:00');
    expect(t.toJson()['start_time'], '17:30');
  });

  test('Competition: daty w formacie YYYY-MM-DD w obie strony', () {
    final c = Competition.fromJson({
      'id': 5,
      'name': 'Puchar Śląska',
      'date_start': '2026-11-14',
      'date_end': '2026-11-15',
      'location': 'Gliwice',
      'registration_deadline': '2026-11-07',
      'url': null,
      'description': null,
    });
    expect(c.toJson()['date_start'], '2026-11-14');
    expect(c.toJson()['date_end'], '2026-11-15');
    expect(c.toJson()['registration_deadline'], '2026-11-07');
  });

  test('Rejestracja zamknięta po terminie zgłoszeń', () {
    final past = Competition(
      name: 'x',
      dateStart: DateTime(2020, 1, 10),
      registrationDeadline: DateTime(2020, 1, 1),
    );
    expect(past.registrationOpen, isFalse);
    final future = Competition(
      name: 'y',
      dateStart: DateTime.now().add(const Duration(days: 30)),
    );
    expect(future.registrationOpen, isTrue);
  });

  test('Profile i wpis na zawody z zagnieżdżonym profilem', () {
    final e = CompetitionEntry.fromJson({
      'competition_id': 5,
      'weight_category': '-73 kg',
      'status': 'confirmed',
      'profiles': {'id': 'abc', 'full_name': 'Jan Kowalski', 'role': 'athlete'},
    });
    expect(e.athlete.displayName, 'Jan Kowalski');
    expect(e.status, EntryStatus.confirmed);
    expect(e.status.label, 'potwierdzony');
    expect(e.athlete.isCoach, isFalse);
  });
}
