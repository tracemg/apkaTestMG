import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../models.dart';

final _updatedFmt = DateFormat('d MMM yyyy, HH:mm', 'pl');

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _listKey = GlobalKey<AsyncListState<Note>>();

  Future<void> _open([Note? n]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NoteEditor(note: n)),
    );
    if (changed == true) _listKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repo;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _open,
        tooltip: 'Nowa notatka',
        child: const Icon(Icons.edit_note),
      ),
      body: AsyncList<Note>(
        key: _listKey,
        load: repo.notes,
        emptyText:
            'Twoje prywatne notatki z treningów i zawodów.\n'
            'Widzisz je tylko Ty. Dodaj pierwszą przyciskiem na dole.',
        itemBuilder: (context, n, _) => ListTile(
          title: Text(n.title.isEmpty ? '(bez tytułu)' : n.title),
          subtitle: Text(
            '${_updatedFmt.format(n.updatedAt!)}\n${n.body}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: true,
          onTap: () => _open(n),
        ),
      ),
    );
  }
}

class NoteEditor extends StatefulWidget {
  const NoteEditor({super.key, this.note});

  final Note? note;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final _title = TextEditingController(text: widget.note?.title);
  late final _body = TextEditingController(text: widget.note?.body);
  bool _busy = false;

  Future<void> _save() async {
    if (_title.text.trim().isEmpty && _body.text.trim().isEmpty) {
      Navigator.pop(context, false);
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).repo.saveNote(
        Note(id: widget.note?.id, title: _title.text.trim(), body: _body.text),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Usunąć notatkę?')) return;
    if (!mounted) return;
    try {
      await AppScope.of(context).repo.deleteNote(widget.note!.id!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Nowa notatka' : 'Notatka'),
        actions: [
          if (widget.note != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Zapisz',
            onPressed: _busy ? null : _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                hintText: 'Tytuł',
                border: InputBorder.none,
              ),
              style: Theme.of(context).textTheme.titleLarge,
              textCapitalization: TextCapitalization.sentences,
            ),
            Expanded(
              child: TextField(
                controller: _body,
                decoration: const InputDecoration(
                  hintText:
                      'Np. technika z treningu, uwagi trenera, plan na zawody…',
                  border: InputBorder.none,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
