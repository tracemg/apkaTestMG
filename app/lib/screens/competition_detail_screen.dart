import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models.dart';
import 'competitions_screen.dart';

class CompetitionDetailScreen extends StatefulWidget {
  const CompetitionDetailScreen({super.key, required this.competition});

  final Competition competition;

  @override
  State<CompetitionDetailScreen> createState() =>
      _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends State<CompetitionDetailScreen> {
  late Competition _c = widget.competition;
  Future<List<CompetitionEntry>>? _entries;
  bool _changed = false;
  bool _busy = false;

  void _reload() =>
      setState(() => _entries = AppScope.of(context).repo.entries(_c.id!));

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      _changed = true;
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    final me = AppScope.of(context).me;
    final ctrl = TextEditingController(text: me.weightCategory);
    final category = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Zapis na zawody'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Kategoria wagowa (np. -73 kg)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text),
            child: const Text('Zapisz mnie'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (category == null || !mounted) return;
    final repo = AppScope.of(context).repo;
    await _run(() => repo.register(_c.id!, emptyToNull(category)));
  }

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CompetitionEditor(competition: _c)),
    );
    if (saved != true || !mounted) return;
    try {
      final fresh = await AppScope.of(context).repo.competition(_c.id!);
      if (mounted) setState(() => _c = fresh);
    } catch (e) {
      if (mounted) showError(context, e);
    }
    _changed = true;
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      'Usunąć zawody „${_c.name}” razem z zapisami?',
    );
    if (!ok) return;
    if (!mounted) return;
    try {
      await AppScope.of(context).repo.deleteCompetition(_c.id!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final me = scope.me;
    _entries ??= scope.repo.entries(_c.id!);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_c.name),
          actions: [
            if (me.isCoach) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: _edit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
            ],
          ],
        ),
        body: FutureBuilder<List<CompetitionEntry>>(
          future: _entries,
          builder: (context, snap) {
            final entries = snap.data ?? const <CompetitionEntry>[];
            final mine = entries
                .where((e) => e.athlete.id == me.id)
                .firstOrNull;
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _InfoRow(Icons.event, competitionDates(_c)),
                  if (_c.location != null)
                    _InfoRow(Icons.place_outlined, _c.location!),
                  if (_c.registrationDeadline != null)
                    _InfoRow(
                      Icons.timer_outlined,
                      'Zgłoszenia do ${dateFmt.format(_c.registrationDeadline!)}',
                    ),
                  if (_c.url != null)
                    _InfoRow(Icons.link, _c.url!, selectable: true),
                  if (_c.description != null) ...[
                    const SizedBox(height: 12),
                    Text(_c.description!),
                  ],
                  const SizedBox(height: 16),
                  if (snap.connectionState == ConnectionState.done &&
                      !snap.hasError)
                    if (mine == null)
                      FilledButton.icon(
                        icon: const Icon(Icons.how_to_reg),
                        label: Text(
                          _c.registrationOpen
                              ? 'Zapisz się'
                              : 'Zapisy zamknięte',
                        ),
                        onPressed: _busy || !_c.registrationOpen
                            ? null
                            : _register,
                      )
                    else
                      OutlinedButton.icon(
                        icon: const Icon(Icons.person_remove_outlined),
                        label: Text(
                          'Jesteś zapisany (${mine.status.label}) — wypisz się',
                        ),
                        onPressed: _busy
                            ? null
                            : () async {
                                if (await confirm(
                                  context,
                                  'Wypisać się z zawodów?',
                                )) {
                                  await _run(
                                    () => scope.repo.unregister(_c.id!, me.id),
                                  );
                                }
                              },
                      ),
                  const Divider(height: 32),
                  Text(
                    'Zapisani (${entries.length})',
                    style: theme.textTheme.titleMedium,
                  ),
                  if (snap.connectionState != ConnectionState.done)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snap.hasError)
                    Text('Błąd: ${snap.error}')
                  else if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Nikt jeszcze się nie zapisał.'),
                    ),
                  for (final e in entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.athlete.displayName),
                      subtitle: Text(
                        [
                          e.weightCategory,
                          e.status.label,
                        ].whereType<String>().join(' · '),
                      ),
                      trailing: me.isCoach
                          ? PopupMenuButton<String>(
                              onSelected: (v) => _run(
                                () => v == 'remove'
                                    ? scope.repo.unregister(
                                        _c.id!,
                                        e.athlete.id,
                                      )
                                    : scope.repo.setEntryStatus(
                                        _c.id!,
                                        e.athlete.id,
                                        EntryStatus.values.byName(v),
                                      ),
                              ),
                              itemBuilder: (_) => [
                                for (final s in EntryStatus.values)
                                  if (s != e.status)
                                    PopupMenuItem(
                                      value: s.name,
                                      child: Text('Oznacz: ${s.label}'),
                                    ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Usuń z listy'),
                                ),
                              ],
                            )
                          : null,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text, {this.selectable = false});

  final IconData icon;
  final String text;
  final bool selectable;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: selectable ? SelectableText(text) : Text(text)),
      ],
    ),
  );
}
