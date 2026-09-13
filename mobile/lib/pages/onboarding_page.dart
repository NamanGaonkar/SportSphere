import 'package:flutter/material.dart';

import 'login_page.dart';

/// First-launch experience: full-bleed feature image at ~50% opacity behind
/// bold aggressive lettering, one image per slide, auto-rotating.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _page = 0;
  bool _advancing = true;

  static const _slides = <(String, String, String)>[
    ('assets/images/feature1.png', 'EVERY GAME. ONE PLATFORM.',
        'Athletes, coaches, teams, tournaments, venues and operations - managed end to end.'),
    ('assets/images/feature2.png', 'BUILT FOR SPEED.',
        'Mark attendance, schedule fixtures and push results in seconds, not spreadsheets.'),
    ('assets/images/feature3.png', 'NEVER MISS A BEAT.',
        'Live scores, alerts and schedules the moment they happen.'),
  ];

  @override
  void initState() {
    super.initState();
    _autoAdvance();
  }

  @override
  void dispose() {
    _advancing = false;
    super.dispose();
  }

  Future<void> _autoAdvance() async {
    await Future<void>.delayed(const Duration(seconds: 4));
    if (!mounted || !_advancing) return;
    setState(() => _page = _page < _slides.length - 1 ? _page + 1 : 0);
    _autoAdvance();
  }

  void _go(bool signup) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => signup ? const LoginPage(initialSignUp: true) : const LoginPage(),
      ),
    );
  }

  /// Animated cross-fade between the three feature images. ONLY the image
  /// swaps — the text, dots and buttons are fixed UI and never slide.
  Widget _imageStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < _slides.length; i++)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 450),
            opacity: _page == i ? 0.5 : 0.0,
            child: Image.asset(_slides[i].$1, fit: BoxFit.cover),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _imageStack(),
          // Dark gradient veil so the lettering stays readable
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xAA0A0A0A),
                  Color(0x660A0A0A),
                  Color(0xF20A0A0A),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        _slides[_page].$2,
                        textAlign: TextAlign.center,
                        key: ValueKey(_page),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                          letterSpacing: 1,
                          shadows: [Shadow(blurRadius: 14, color: Color(0xB3000000))],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _slides[_page].$3,
                        textAlign: TextAlign.center,
                        key: ValueKey('body$_page'),
                        style: const TextStyle(
                          color: Color(0xE6FFFFFF),
                          fontSize: 15.5,
                          height: 1.55,
                          shadows: [Shadow(blurRadius: 10, color: Color(0x99000000))],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var j = 0; j < _slides.length; j++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: j == _page ? 26 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: j == _page ? const Color(0xFFFF5500) : Colors.white30,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: () => _go(false),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5500),
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: const Text('Sign in'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _go(true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: const Text('Create account'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
