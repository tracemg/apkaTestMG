import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models.dart';

/// Bez [profile] — mój profil. Z [profile] — profil innego zawodnika
/// (edytowalny tylko dla trenera).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.profile});

  final Profile? profile;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late Profile _p;
  late final TextEditingController _name, _belt, _weight, _birthYear, _phone;
  late UserRole _role;
  bool _initialized = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _p = widget.profile ?? AppScope.of(context).me;
    _name = TextEditingController(text: _p.fullName);
    _belt = TextEditingController(text: _p.belt);
    _weight = TextEditingController(text: _p.weightCategory);
    _birthYear = TextEditingController(text: _p.birthYear?.toString());
    _phone = TextEditingController(text: _p.phone);
    _role = _p.role;
  }

  @override
  void dispose() {
    for (final c in [_name, _belt, _weight, _birthYear, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final scope = AppScope.of(context);
    setState(() => _busy = true);
    try {
      final fields = Profile(
        id: _p.id,
        fullName: _name.text.trim(),
        role: _role,
        belt: emptyToNull(_belt.text),
        weightCategory: emptyToNull(_weight.text),
        birthYear: int.tryParse(_birthYear.text.trim()),
        phone: emptyToNull(_phone.text),
      ).toEditableJson();
      if (scope.me.isCoach && _role != _p.role) fields['role'] = _role.name;
      await scope.repo.updateProfile(_p.id, fields);
      if (_p.id == scope.me.id) await scope.reloadMe();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Zapisano')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final isMe = _p.id == scope.me.id;
    final canEdit = isMe || scope.me.isCoach;

    return Scaffold(
      appBar: AppBar(title: Text(isMe ? 'Mój profil' : _p.displayName)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              enabled: canEdit,
              decoration: const InputDecoration(labelText: 'Imię i nazwisko'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Podaj imię i nazwisko' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _belt,
              enabled: canEdit,
              decoration: const InputDecoration(
                labelText: 'Pas (np. 5 kyu – pomarańczowy)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weight,
              enabled: canEdit,
              decoration: const InputDecoration(
                labelText: 'Kategoria wagowa (np. -73 kg)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _birthYear,
              enabled: canEdit,
              decoration: const InputDecoration(labelText: 'Rok urodzenia'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                final y = int.tryParse(s);
                return y == null || y < 1920 || y > DateTime.now().year
                    ? 'Niepoprawny rok'
                    : null;
              },
            ),
            if (canEdit) ...[
              // Telefon ukryty w UI dla innych zawodników (uwaga: RLS jeszcze go nie chroni).
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Telefon'),
                keyboardType: TextInputType.phone,
              ),
            ],
            if (scope.me.isCoach) ...[
              const SizedBox(height: 16),
              SegmentedButton<UserRole>(
                segments: const [
                  ButtonSegment(
                    value: UserRole.athlete,
                    label: Text('Zawodnik'),
                  ),
                  ButtonSegment(value: UserRole.coach, label: Text('Trener')),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
            ],
            if (canEdit) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Zapisz'),
              ),
            ],
            if (isMe) ...[
              const SizedBox(height: 32),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Wyloguj się'),
                onPressed: () async {
                  Navigator.popUntil(context, (r) => r.isFirst);
                  await scope.repo.signOut();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
