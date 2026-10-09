enum UserRole { athlete, coach }

class Profile {
  Profile({
    required this.id,
    required this.fullName,
    required this.role,
    this.belt,
    this.weightCategory,
    this.birthYear,
    this.phone,
  });

  final String id;
  final String fullName;
  final UserRole role;
  final String? belt;
  final String? weightCategory;
  final int? birthYear;
  final String? phone;

  bool get isCoach => role == UserRole.coach;
  String get displayName => fullName.isEmpty ? '(bez nazwy)' : fullName;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'] as String,
    fullName: (j['full_name'] as String?) ?? '',
    role: UserRole.values.byName(j['role'] as String),
    belt: j['belt'] as String?,
    weightCategory: j['weight_category'] as String?,
    birthYear: j['birth_year'] as int?,
    phone: j['phone'] as String?,
  );

  Map<String, dynamic> toEditableJson() => {
    'full_name': fullName,
    'belt': belt,
    'weight_category': weightCategory,
    'birth_year': birthYear,
    'phone': phone,
  };
}

class Training {
  Training({
    this.id,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.groupName,
    this.location,
    this.notes,
  });

  final int? id;
  final int weekday; // 1 = poniedziałek
  final String startTime; // 'HH:mm'
  final String endTime;
  final String groupName;
  final String? location;
  final String? notes;

  factory Training.fromJson(Map<String, dynamic> j) => Training(
    id: j['id'] as int,
    weekday: j['weekday'] as int,
    startTime: _hhmm(j['start_time'] as String),
    endTime: _hhmm(j['end_time'] as String),
    groupName: j['group_name'] as String,
    location: j['location'] as String?,
    notes: j['notes'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'weekday': weekday,
    'start_time': startTime,
    'end_time': endTime,
    'group_name': groupName,
    'location': location,
    'notes': notes,
  };
}

class Competition {
  Competition({
    this.id,
    required this.name,
    required this.dateStart,
    this.dateEnd,
    this.location,
    this.registrationDeadline,
    this.url,
    this.description,
  });

  final int? id;
  final String name;
  final DateTime dateStart;
  final DateTime? dateEnd;
  final String? location;
  final DateTime? registrationDeadline;
  final String? url;
  final String? description;

  bool get registrationOpen {
    final deadline = registrationDeadline ?? dateStart;
    final today = DateTime.now();
    return !DateTime(today.year, today.month, today.day).isAfter(deadline);
  }

  factory Competition.fromJson(Map<String, dynamic> j) => Competition(
    id: j['id'] as int,
    name: j['name'] as String,
    dateStart: DateTime.parse(j['date_start'] as String),
    dateEnd: _date(j['date_end']),
    location: j['location'] as String?,
    registrationDeadline: _date(j['registration_deadline']),
    url: j['url'] as String?,
    description: j['description'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'date_start': _iso(dateStart),
    'date_end': dateEnd == null ? null : _iso(dateEnd!),
    'location': location,
    'registration_deadline': registrationDeadline == null
        ? null
        : _iso(registrationDeadline!),
    'url': url,
    'description': description,
  };
}

enum EntryStatus { registered, confirmed, withdrawn }

extension EntryStatusLabel on EntryStatus {
  String get label => switch (this) {
    EntryStatus.registered => 'zgłoszony',
    EntryStatus.confirmed => 'potwierdzony',
    EntryStatus.withdrawn => 'wycofany',
  };
}

class CompetitionEntry {
  CompetitionEntry({
    required this.competitionId,
    required this.athlete,
    required this.status,
    this.weightCategory,
  });

  final int competitionId;
  final Profile athlete;
  final EntryStatus status;
  final String? weightCategory;

  factory CompetitionEntry.fromJson(Map<String, dynamic> j) => CompetitionEntry(
    competitionId: j['competition_id'] as int,
    athlete: Profile.fromJson(j['profiles'] as Map<String, dynamic>),
    status: EntryStatus.values.byName(j['status'] as String),
    weightCategory: j['weight_category'] as String?,
  );
}

class Note {
  Note({this.id, required this.title, required this.body, this.updatedAt});

  final int? id;
  final String title;
  final String body;
  final DateTime? updatedAt;

  factory Note.fromJson(Map<String, dynamic> j) => Note(
    id: j['id'] as int,
    title: j['title'] as String,
    body: j['body'] as String,
    updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
  );

  Map<String, dynamic> toJson() => {'title': title, 'body': body};
}

String _hhmm(String t) => t.substring(0, 5);
DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);
String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
