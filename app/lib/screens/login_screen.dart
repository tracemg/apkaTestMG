import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repository.dart';

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
  bool _signUp = false;
  bool _busy = false;
  String? _message;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_signUp) {
        await widget.repo.signUp(
          _email.text.trim(),
          _password.text,
          _name.text.trim(),
        );
        if (Supabase.instance.client.auth.currentSession == null) {
          _message = 'Sprawdź skrzynkę e-mail i potwierdź rejestrację, potem się zaloguj.';
          _signUp = false;
        }
      } else {
        await widget.repo.signIn(_email.text.trim(), _password.text);
      }
    } on AuthException catch (e) {
      _message = e.message;
    } catch (e) {
      _message = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    if (_signUp) ...[
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
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_signUp ? 'Załóż konto' : 'Zaloguj się'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _signUp = !_signUp),
                      child: Text(
                        _signUp
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
