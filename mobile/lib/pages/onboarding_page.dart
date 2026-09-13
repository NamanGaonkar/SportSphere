import 'dart:async';

import 'package:flutter/material.dart';

import 'login_page.dart';

/// First-launch experience: full-bleed feature image at ~50% opacity behind
/// bold aggressive lettering. Users can swipe between slides by hand; it also
/// auto-rotates (pausing briefly after a manual swipe).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _slides = <(String, String, String)>[
    ('assets/images/feature1.png', 'EVERY GAME. ONE PLATFORM.',
        'Athletes, coaches, teams, tournaments, venues and operations - managed end to end.'),
    ('assets/images/feature2.png', 'BUILT FOR SPEED.',
        'Mark attendance, schedule fixtures and push results in seconds, not spreadsheets.'),
    ('assets/images/feature3.png', 'NEVER MISS A BEAT.',
        'Live scores, alerts and schedules the moment they happen.'),
  ];

  final _controller = PageController();
  Timer? _timer;
  bool _hold = false; // suppress auto-advance briefly after manual swipe

  int get _page => _controller.hasClients
      ? _controller.page?.round() ?? 0
      : 0;

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _hold) return;
      final current = _controller.hasClients ? (_controller.page ?? 0) : 0;
      final next = current >= _slides.length - 1 ? 0 : current + 1;
      _controller.animateToPage(
        next.toInt(),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onUserPageChanged(int page) {
    setState(() {}); // refresh dots/headline
    // Pause auto-rotation for one cycle after the user interacts.
    _hold = true;
    Timer(const Duration(seconds: 7), () {
      if (mounted) _hold = false;
    });
  }

  void _goTo(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _go(bool signup) {
    _timer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => signup ? const LoginPage(initialSignUp: true) : const LoginPage(),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page.clamp(0, _slides.length - 1);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Swipeable full-bleed feature image, one per slide.
          PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: _onUserPageChanged,
            itemBuilder: (context, i) {
              return Image.asset(
                _slides[i].$1,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              );
            },
          ),
          // Dark gradient veil so the lettering stays readable over the image.
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
                // IgnorePointer: the headline sits over the PageView; without
                // this the text swallows horizontal drags and swipes "do nothing".
                IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        _slides[page].$2,
                        textAlign: TextAlign.center,
                        key: ValueKey('title$page'),
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
                        _slides[page].$3,
                        textAlign: TextAlign.center,
                        key: ValueKey('body$page'),
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
                ),
                const Spacer(flex: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var j = 0; j < _slides.length; j++)
                      GestureDetector(
                        onTap: () => _goTo(j),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: j == page ? 26 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: j == page
                                  ? const Color(0xFFFF5500)
                                  : Colors.white30,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
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
