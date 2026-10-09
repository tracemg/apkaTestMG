import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:judo_masters/app_scope.dart';
import 'package:judo_masters/main.dart';
import 'package:judo_masters/models.dart';
import 'package:judo_masters/repository.dart';
import 'package:judo_masters/screens/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pl'));

  // Regresja: ekrany otwierane przez Navigator.push muszą widzieć AppScope.
  testWidgets('Profil otwarty przez Navigator.push widzi AppScope', (
    tester,
  ) async {
    final repo = Repository(
      SupabaseClient(
        'http://localhost',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );
    final me = Profile(
      id: 'u1',
      fullName: 'Jan Kowalski',
      role: UserRole.athlete,
      belt: '4 kyu',
    );

    await tester.pumpWidget(
      AppScope(
        repo: repo,
        me: me,
        reloadMe: () async {},
        child: clubMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                child: const Text('profil'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('profil'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Mój profil'), findsOneWidget);
    expect(find.text('Jan Kowalski'), findsOneWidget);
  });
}
