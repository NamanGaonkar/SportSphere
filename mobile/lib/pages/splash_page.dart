import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_shell.dart';
import 'login_page.dart';

/// SportSphere splash — logo centered on the brand background while the
/// Supabase session is restored, then routes to login or home automatically.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    // Brief brand moment, then route based on the restored Supabase session.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => session == null ? const LoginPage() : const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6A13),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.sports_score, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'SportSphere',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFFFF6A13)),
            ),
          ],
        ),
      ),
    );
  }
}
