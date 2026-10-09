import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models.dart';

const weekdayNames = [
  'Poniedziałek',
  'Wtorek',
  'Środa',
  'Czwartek',
  'Piątek',
  'Sobota',
  'Niedziela',
];

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  Future<List<Training>>? _future;

  void _reload() =>
      setState(() => _future = AppScope.of(context).repo.trainings());

  Future<void> _edit([Training? t]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TrainingEditor(training: t)),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    _future ??= scope.repo.trainings();
    final today = DateTime.now().weekday;

    return Scaffold(
      floatingActionButton: scope.me.isCoach
          ? FloatingActionButton(onPressed: _edit, child: const Icon(Icons.add))
          : null,
      body: FutureBuilder<List<Training>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Błąd: ${snap.error}'));
          }
          final trainings = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                if (trainings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Brak treningów w rozkładzie.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (var day = 1; day <= 7; day++)
                  if (trainings.any((t) => t.weekday == day)) ...[
                    _DayHeader(
                      name: weekdayNames[day - 1],
                      isToday: day == today,
                    ),
                    for (final t in trainings.where((t) => t.weekday == day))
                      ListTile(
                        leading: Text(
                          '${t.startTime}\n${t.endTime}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        title: Text(t.groupName),
                        subtitle: Text(
                          [t.location, t.notes]
                              .whereType<String>()
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                        ),
                        onTap: scope.me.isCoach ? () => _edit(t) : null,
                      ),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.name, required this.isToday});

  final String name;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            name,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: 8),
            Chip(
              label: const Text('dziś'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }
}

class TrainingEditor extends StatefulWidget {
  const TrainingEditor({super.key, this.training});

  final Training? training;

  @override
  State<TrainingEditor> createState() => _TrainingEditorState();
}

class _TrainingEditorState extends State<TrainingEditor> {
  final _form = GlobalKey<FormState>();
  late int _weekday = widget.training?.weekday ?? 1;
  late TimeOfDay _start = _parse(widget.training?.startTime ?? '17:00');
  late TimeOfDay _end = _parse(widget.training?.endTime ?? '18:30');
  late final _group = TextEditingController(text: widget.training?.groupName);
  late final _location = TextEditingController(text: widget.training?.location);
  late final _notes = TextEditingController(text: widget.training?.notes);
  bool _busy = false;

  static TimeOfDay _parse(String s) => TimeOfDay(
    hour: int.parse(s.substring(0, 2)),
    minute: int.parse(s.substring(3, 5)),
  );
  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (picked != null) setState(() => start ? _start = picked : _end = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_fmt(_end).compareTo(_fmt(_start)) <= 0) {
      showError(context, 'Koniec musi być po początku');
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).repo.saveTraining(
        Training(
          id: widget.training?.id,
          weekday: _weekday,
          startTime: _fmt(_start),
          endTime: _fmt(_end),
          groupName: _group.text.trim(),
          location: emptyToNull(_location.text),
          notes: emptyToNull(_notes.text),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Usunąć ten trening z rozkładu?')) return;
    if (!mounted) return;
    try {
      await AppScope.of(context).repo.deleteTraining(widget.training!.id!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  void dispose() {
    _group.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.training == null ? 'Nowy trening' : 'Edytuj trening',
        ),
        actions: [
          if (widget.training != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<int>(
              initialValue: _weekday,
              decoration: const InputDecoration(labelText: 'Dzień tygodnia'),
              items: [
                for (var d = 1; d <= 7; d++)
                  DropdownMenuItem(value: d, child: Text(weekdayNames[d - 1])),
              ],
              onChanged: (v) => setState(() => _weekday = v!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text('Od ${_fmt(_start)}'),
                    onPressed: () => _pick(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text('Do ${_fmt(_end)}'),
                    onPressed: () => _pick(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _group,
              decoration: const InputDecoration(
                labelText: 'Grupa (np. Dzieci 6-9, Seniorzy)',
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Podaj grupę' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Miejsce'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Uwagi'),
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
  }
}
