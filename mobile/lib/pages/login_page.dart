import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_shell.dart';

/// Roles available at public signup. Admin is NOT selectable — the single
/// admin account is provisioned out-of-band (supabase/branding.sql).
const kSignupRoles = <String>['Athlete', 'Coach', 'HR', 'Finance', 'VenueManager'];

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialSignUp = false});

  final bool initialSignUp;

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
  void initState() {
    super.initState();
    _isSignUp = widget.initialSignUp;
  }

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
          password: _text(_password),
          data: {'full_name': _text(_name), 'role': _role},
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
            email: _email.text.trim(), password: _text(_password));
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

  String _text(TextEditingController c) => c.text.trim();

  @override
  Widget build(BuildContext context) {
    // Dark inputs on the black brand background: filled dark, white text.
    // floatingLabelBehavior + a shrunk start label keep the field label
    // permanently visible and prevent overlap with the entered text.
    const darkFill = Color(0xFF1A1A1A);
    const fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: Color(0xFF2E2E2E)),
    );

    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          filled: true,
          fillColor: darkFill,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: fieldBorder,
          enabledBorder: fieldBorder,
          focusedBorder: fieldBorder.copyWith(
            borderSide: const BorderSide(color: Color(0xFFFF6A13), width: 1.4),
          ),
        );

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/images/logo.png', height: 96),
                    const SizedBox(height: 20),
                    const Text(
                      'SPORTSPHERE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Elevate every game',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                    ),
                    const SizedBox(height: 28),
                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _name,
                        style: const TextStyle(color: Colors.white),
                        decoration: deco('Full name'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Enter the full name' : null,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        dropdownColor: darkFill,
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                        decoration: deco('Role').copyWith(
                          helperText: 'Determines what you can access after signing in.',
                          helperStyle: const TextStyle(color: Colors.white38, fontSize: 11.5),
                        ),
                        items: kSignupRoles
                            .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r, style: const TextStyle(color: Colors.white)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _role = v ?? 'Athlete'),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: deco('Email'),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      style: const TextStyle(color: Colors.white),
                      decoration: deco('Password').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.white70,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Password must be at least 6 characters'
                          : null,
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
