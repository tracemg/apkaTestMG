import 'package:flutter/material.dart';

import '../app_scope.dart';
import 'athletes_screen.dart';
import 'competitions_screen.dart';
import 'notes_screen.dart';
import 'profile_screen.dart';
import 'schedule_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _titles = ['Treningi', 'Zawody', 'Zawodnicy', 'Notatki'];

  @override
  Widget build(BuildContext context) {
    final me = AppScope.of(context).me;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          IconButton(
            tooltip: 'Mój profil',
            icon: CircleAvatar(
              radius: 16,
              child: Text(
                me.fullName.isEmpty ? '?' : me.fullName[0].toUpperCase(),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          ScheduleScreen(),
          CompetitionsScreen(),
          AthletesScreen(),
          NotesScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.schedule), label: 'Treningi'),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'Zawody',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: 'Zawodnicy',
          ),
          NavigationDestination(
            icon: Icon(Icons.sticky_note_2_outlined),
            label: 'Notatki',
          ),
        ],
      ),
    );
  }
}
