import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_scope.dart';
import 'models.dart';
import 'repository.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';

// Uruchamianie: flutter run --dart-define-from-file=env.json
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pl');
  if (_supabaseUrl.isEmpty || _supabaseKey.isEmpty) {
    runApp(const _MissingConfigApp());
    return;
  }
  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
  runApp(const JudoApp());
}

class JudoApp extends StatelessWidget {
  const JudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Judo Team Masters',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pl'),
      supportedLocales: const [Locale('pl')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F3A93)),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F3A93),
          brightness: Brightness.dark,
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

/// Pokazuje logowanie albo aplikację, zależnie od sesji.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _repo = Repository(Supabase.instance.client);
  Profile? _me;
  Object? _error;
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.session == null) {
        setState(() => _me = null);
      } else if (_me == null || _me!.id != state.session!.user.id) {
        _loadMe();
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  Future<void> _loadMe() async {
    try {
      final me = await _repo.myProfile();
      if (!mounted) return;
      setState(() {
        _me = me;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return LoginScreen(repo: _repo);
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nie udało się wczytać profilu:\n$_error',
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: _repo.signOut,
                child: const Text('Wyloguj'),
              ),
            ],
          ),
        ),
      );
    }
    if (_me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return AppScope(
      repo: _repo,
      me: _me!,
      reloadMe: _loadMe,
      child: const HomeShell(),
    );
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Brak konfiguracji Supabase.\n\n'
            'Uruchom: flutter run --dart-define-from-file=env.json',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
