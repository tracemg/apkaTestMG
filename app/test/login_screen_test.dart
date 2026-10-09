import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:judo_masters/main.dart';
import 'package:judo_masters/repository.dart';
import 'package:judo_masters/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Udaje Supabase: rejestracja bez sesji (wymaga potwierdzenia kodem).
class _FakeRepository extends Repository {
  _FakeRepository()
    : super(
        SupabaseClient(
          'http://localhost',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final verified = <(String, String)>[];

  @override
  bool get hasSession => false;

  @override
  Future<void> signUp(String email, String password, String fullName) async {}

  @override
  Future<void> verifySignUpCode(String email, String code) async =>
      verified.add((email, code));
}

void main() {
  testWidgets('Po rejestracji pokazuje pole na kod i go weryfikuje', (
    tester,
  ) async {
    final repo = _FakeRepository();
    await tester.pumpWidget(clubMaterialApp(home: LoginScreen(repo: repo)));

    await tester.tap(find.text('Nie masz konta? Zarejestruj się'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Imię i nazwisko'),
      'Jan Kowalski',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'jan@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Hasło'),
      'sekret123',
    );
    await tester.tap(find.text('Załóż konto'));
    await tester.pumpAndSettle();

    expect(find.text('Potwierdź e-mail'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kod z maila'),
      '123456',
    );
    await tester.tap(find.text('Potwierdź'));
    await tester.pumpAndSettle();

    expect(repo.verified, [('jan@example.com', '123456')]);
  });
}
