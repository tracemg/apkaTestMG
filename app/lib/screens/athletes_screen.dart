import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models.dart';
import 'profile_screen.dart';

class AthletesScreen extends StatefulWidget {
  const AthletesScreen({super.key});

  @override
  State<AthletesScreen> createState() => _AthletesScreenState();
}

class _AthletesScreenState extends State<AthletesScreen> {
  final _listKey = GlobalKey<AsyncListState<Profile>>();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: SearchBar(
            hintText: 'Szukaj zawodnika',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (q) {
              _query = q.trim().toLowerCase();
              _listKey.currentState?.reload();
            },
          ),
        ),
        Expanded(
          child: AsyncList<Profile>(
            key: _listKey,
            load: () async {
              final all = await scope.repo.profiles();
              return all
                  .where((p) => p.fullName.toLowerCase().contains(_query))
                  .toList();
            },
            emptyText: 'Brak zawodników.',
            itemBuilder: (context, p, reload) => ListTile(
              leading: CircleAvatar(
                child: Text(
                  p.fullName.isEmpty ? '?' : p.fullName[0].toUpperCase(),
                ),
              ),
              title: Text(p.displayName),
              subtitle: Text(
                [p.belt, p.weightCategory].whereType<String>().join(' · '),
              ),
              trailing: p.isCoach ? const Chip(label: Text('trener')) : null,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(profile: p)),
                );
                reload();
              },
            ),
          ),
        ),
      ],
    );
  }
}
