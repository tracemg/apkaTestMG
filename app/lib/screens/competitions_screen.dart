import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../models.dart';
import 'competition_detail_screen.dart';

final _monthFmt = DateFormat('LLLL yyyy', 'pl');
final dateFmt = DateFormat('d MMM yyyy', 'pl');

String competitionDates(Competition c) {
  if (c.dateEnd == null || c.dateEnd == c.dateStart) {
    return dateFmt.format(c.dateStart);
  }
  return '${DateFormat('d', 'pl').format(c.dateStart)}–${dateFmt.format(c.dateEnd!)}';
}

class CompetitionsScreen extends StatefulWidget {
  const CompetitionsScreen({super.key});

  @override
  State<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen> {
  bool _past = false;
  final _listKey = GlobalKey<AsyncListState<Object>>();

  Future<void> _open({Competition? c, bool edit = false}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => edit || c == null
            ? CompetitionEditor(competition: c)
            : CompetitionDetailScreen(competition: c),
      ),
    );
    if (changed == true) _listKey.currentState?.reload();
  }

  /// Zawody przeplatane nagłówkami miesięcy.
  Future<List<Object>> _load() async {
    final list = await AppScope.of(context).repo.competitions(past: _past);
    final out = <Object>[];
    String? month;
    for (final c in list) {
      final m = _monthFmt.format(c.dateStart);
      if (m != month) out.add(month = m);
      out.add(c);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final isCoach = AppScope.of(context).me.isCoach;
    return Scaffold(
      floatingActionButton: isCoach
          ? FloatingActionButton(
              onPressed: () => _open(),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Nadchodzące')),
                ButtonSegment(value: true, label: Text('Minione')),
              ],
              selected: {_past},
              onSelectionChanged: (s) {
                setState(() => _past = s.first);
                _listKey.currentState?.reload();
              },
            ),
          ),
          Expanded(
            child: AsyncList<Object>(
              key: _listKey,
              load: _load,
              emptyText: _past
                  ? 'Brak minionych zawodów.'
                  : 'Brak zaplanowanych zawodów.',
              itemBuilder: (context, item, _) {
                if (item is String) {
                  final theme = Theme.of(context);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      toBeginningOfSentenceCase(item),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                final c = item as Competition;
                return ListTile(
                  leading: const Icon(Icons.emoji_events_outlined),
                  title: Text(c.name),
                  subtitle: Text(
                    [
                      competitionDates(c),
                      c.location,
                    ].whereType<String>().join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(c: c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CompetitionEditor extends StatefulWidget {
  const CompetitionEditor({super.key, this.competition});

  final Competition? competition;

  @override
  State<CompetitionEditor> createState() => _CompetitionEditorState();
}

class _CompetitionEditorState extends State<CompetitionEditor> {
  final _form = GlobalKey<FormState>();
  late final c = widget.competition;
  late final _name = TextEditingController(text: c?.name);
  late final _location = TextEditingController(text: c?.location);
  late final _url = TextEditingController(text: c?.url);
  late final _description = TextEditingController(text: c?.description);
  late DateTime? _start = c?.dateStart;
  late DateTime? _end = c?.dateEnd;
  late DateTime? _deadline = c?.registrationDeadline;
  bool _busy = false;

  Future<DateTime?> _pickDate(DateTime? initial) => showDatePicker(
    context: context,
    initialDate: initial ?? _start ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_start == null) {
      showError(context, 'Wybierz datę rozpoczęcia');
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).repo.saveCompetition(
        Competition(
          id: c?.id,
          name: _name.text.trim(),
          dateStart: _start!,
          dateEnd: _end,
          location: emptyToNull(_location.text),
          registrationDeadline: _deadline,
          url: emptyToNull(_url.text),
          description: emptyToNull(_description.text),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _url.dispose();
    _description.dispose();
    super.dispose();
  }

  Widget _dateTile(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged, {
    bool clearable = true,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event),
      title: Text(label),
      subtitle: Text(value == null ? '—' : dateFmt.format(value)),
      trailing: clearable && value != null
          ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => onChanged(null),
            )
          : null,
      onTap: () async {
        final d = await _pickDate(value);
        if (d != null) onChanged(d);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(c == null ? 'Nowe zawody' : 'Edytuj zawody')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nazwa'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Podaj nazwę' : null,
            ),
            _dateTile(
              'Początek',
              _start,
              (d) => setState(() => _start = d),
              clearable: false,
            ),
            _dateTile(
              'Koniec (opcjonalnie)',
              _end,
              (d) => setState(() => _end = d),
            ),
            _dateTile(
              'Termin zgłoszeń',
              _deadline,
              (d) => setState(() => _deadline = d),
            ),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Miejsce'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'Link (komunikat, strona)',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Opis'),
              maxLines: 5,
              minLines: 2,
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
