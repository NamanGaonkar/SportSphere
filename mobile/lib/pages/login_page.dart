import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_shell.dart';

/// Roles available at public signup. Admin is NOT selectable — the single
/// admin account is provisioned out-of-band (supabase/branding.sql).
const kSignupRoles = <String>['Athlete', 'Coach', 'HR', 'Finance', 'VenueManager'];

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  String _role = 'Athlete';
  bool _busy = false;
  bool _obscure = true;
  bool _isSignUp = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      final client = Supabase.instance.client;
      if (_isSignUp) {
        final response = await client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {'full_name': _name.text.trim(), 'role': _role},
        );
        // mailer_autoconfirm = true -> session is returned straight away
        if (response.session == null) {
          if (!mounted) return;
          setState(() {
            _error = 'Check your email to confirm, then sign in.';
            _busy = false;
          });
          return;
        }
      } else {
        await client.auth.signInWithPassword(
            email: _email.text.trim(), password: _password.text);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Network error. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6A13),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.sports_score, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'SportSphere',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sports organization management platform',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13.5),
                  ),
                  const SizedBox(height: 28),
                  if (_isSignUp) ...[
                    TextField(
                      controller: _name,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Full name'),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      style: const TextStyle(color: Colors.white),
                      dropdownColor: const Color(0xFF1A1A1A),
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        helperText: 'Determines what you can access after signing in.',
                        helperStyle: TextStyle(color: Colors.white38, fontSize: 11.5),
                      ),
                      items: kSignupRoles
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) => setState(() => _role = v ?? 'Athlete'),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.white54,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isSignUp ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _isSignUp = !_isSignUp;
                              _error = null;
                            }),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign in'
                          : "Don't have an account? Sign up",
                      style: const TextStyle(color: Color(0xFFFF8A42)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Admin accounts are provisioned by the organization.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
