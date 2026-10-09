import 'package:flutter/material.dart';

import 'models.dart';
import 'repository.dart';

/// Udostępnia repozytorium i profil zalogowanego użytkownika całemu drzewu widgetów.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.repo,
    required this.me,
    required this.reloadMe,
    required super.child,
  });

  final Repository repo;
  final Profile me;
  final Future<void> Function() reloadMe;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) => me != old.me || repo != old.repo;
}

void showError(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Błąd: $error')));
}

Future<bool> confirm(BuildContext context, String question) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(question),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Tak'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Ładuje listę i pokazuje ją z pull-to-refresh, spinnerem i obsługą błędów.
class AsyncList<T> extends StatefulWidget {
  const AsyncList({
    super.key,
    required this.load,
    required this.itemBuilder,
    required this.emptyText,
  });

  final Future<List<T>> Function() load;
  final Widget Function(BuildContext, T, VoidCallback reload) itemBuilder;
  final String emptyText;

  @override
  State<AsyncList<T>> createState() => AsyncListState<T>();
}

class AsyncListState<T> extends State<AsyncList<T>> {
  late Future<List<T>> _future = widget.load();

  void reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Nie udało się wczytać danych:\n${snap.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: reload,
                    child: const Text('Spróbuj ponownie'),
                  ),
                ],
              ),
            ),
          );
        }
        final items = snap.data!;
        return RefreshIndicator(
          onRefresh: () async => reload(),
          child: items.isEmpty
              ? ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        widget.emptyText,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: items.length,
                  itemBuilder: (c, i) =>
                      widget.itemBuilder(c, items[i], reload),
                ),
        );
      },
    );
  }
}

String? emptyToNull(String s) => s.trim().isEmpty ? null : s.trim();
