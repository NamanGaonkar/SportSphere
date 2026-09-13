import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_shell.dart';
import 'onboarding_page.dart';

/// SportSphere splash — logo centered on the black brand background while the
/// Supabase session is restored, then routes to onboarding or home.
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
    // Brief brand moment, then route on the restored Supabase session.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => session == null ? const OnboardingPage() : const HomeShell(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 160),
            const SizedBox(height: 28),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFFFF5500)),
            ),
          ],
        ),
      ),
    );
  }
}
