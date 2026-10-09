import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repository.dart';

enum _Mode { signIn, signUp, verify }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.repo});

  final Repository repo;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  String? _message;

  /// Przejście do ekranu wpisywania kodu z maila.
  void _goToVerify(String message) {
    _mode = _Mode.verify;
    _code.clear();
    _message = message;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on AuthException catch (e) {
      _message = e.message;
    } catch (e) {
      _message = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final email = _email.text.trim();
    await _run(() async {
      switch (_mode) {
        case _Mode.signUp:
          await widget.repo.signUp(email, _password.text, _name.text.trim());
          if (!widget.repo.hasSession) {
            _goToVerify('Wysłaliśmy kod na $email. Wpisz go poniżej.');
          }
        case _Mode.signIn:
          try {
            await widget.repo.signIn(email, _password.text);
          } on AuthException catch (e) {
            if (e.code != 'email_not_confirmed') rethrow;
            await widget.repo.resendSignUpCode(email);
            _goToVerify(
              'Konto nie jest jeszcze potwierdzone. '
              'Wysłaliśmy nowy kod na $email.',
            );
          }
        case _Mode.verify:
          // Po sukcesie Supabase ustawia sesję, a JudoApp przełącza ekran.
          await widget.repo.verifySignUpCode(email, _code.text.trim());
      }
    });
  }

  Future<void> _resend() => _run(() async {
    await widget.repo.resendSignUpCode(_email.text.trim());
    _message = 'Wysłaliśmy nowy kod.';
  });

  void _switchMode(_Mode mode) => setState(() {
    _mode = mode;
    _message = null;
  });

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verify = _mode == _Mode.verify;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.sports_martial_arts,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'KS Judo Team Masters',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    Text(
                      'Gliwice',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 32),
                    if (verify) ...[
                      Text(
                        'Potwierdź e-mail',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _code,
                        decoration: const InputDecoration(
                          labelText: 'Kod z maila',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        autofillHints: const [AutofillHints.oneTimeCode],
                        autofocus: true,
                        validator: (v) => (v ?? '').trim().length < 6
                            ? 'Wpisz kod z maila'
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ] else ...[
                      if (_mode == _Mode.signUp) ...[
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Imię i nazwisko',
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Podaj imię i nazwisko'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'E-mail'),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) => (v ?? '').contains('@')
                            ? null
                            : 'Podaj poprawny e-mail',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        decoration: const InputDecoration(labelText: 'Hasło'),
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        validator: (v) =>
                            (v ?? '').length < 6 ? 'Min. 6 znaków' : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(switch (_mode) {
                        _Mode.signIn => 'Zaloguj się',
                        _Mode.signUp => 'Załóż konto',
                        _Mode.verify => 'Potwierdź',
                      }),
                    ),
                    if (verify) ...[
                      TextButton(
                        onPressed: _busy ? null : _resend,
                        child: const Text('Wyślij kod ponownie'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _switchMode(_Mode.signIn),
                        child: const Text('Wróć do logowania'),
                      ),
                    ] else
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _switchMode(
                                _mode == _Mode.signUp
                                    ? _Mode.signIn
                                    : _Mode.signUp,
                              ),
                        child: Text(
                          _mode == _Mode.signUp
                              ? 'Mam już konto'
                              : 'Nie masz konta? Zarejestruj się',
                        ),
                      ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_message!, textAlign: TextAlign.center),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
