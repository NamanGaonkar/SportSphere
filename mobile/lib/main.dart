import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/splash_page.dart';

/// Supabase credentials are injected at build time, e.g.:
/// flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// Values are sanitized: shell pipelines on Windows (CRLF .env) can leave a
/// trailing \r or quotes in the dart-define, which breaks Uri parsing with
/// "Invalid argument(s): no host specified in URL" at sign-in time.
String _sanitize(String raw) {
  var v = raw.trim();
  while (v.isNotEmpty && (v.codeUnitAt(0) == 0x0D || v.codeUnitAt(0) == 0x0A)) {
    v = v.substring(1);
  }
  while (v.isNotEmpty &&
      (v.codeUnitAt(v.length - 1) == 0x0D || v.codeUnitAt(v.length - 1) == 0x0A)) {
    v = v.substring(0, v.length - 1);
  }
  if (v.length >= 2 &&
      ((v.startsWith('"') && v.endsWith('"')) ||
          (v.startsWith("'") && v.endsWith("'")))) {
    v = v.substring(1, v.length - 1).trim();
  }
  return v;
}

const _rawSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _rawSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
final kSupabaseUrl = _sanitize(_rawSupabaseUrl);
final kSupabaseAnonKey = _sanitize(_rawSupabaseAnonKey);

bool get _envValid =>
    kSupabaseUrl.startsWith('https://') &&
    Uri.tryParse(kSupabaseUrl)?.host.isNotEmpty == true &&
    kSupabaseAnonKey.length > 40;

/// Shown when build-time credentials are missing/corrupted, instead of a
/// cryptic runtime failure at sign-in.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Brand.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/logo.png', height: 84),
                const SizedBox(height: 24),
                const Text('Configuration error',
                    style: TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(
                  'Supabase credentials were not injected correctly at build time.'
                  ' Rebuild the APK with --dart-define=SUPABASE_URL and'
                  ' --dart-define=SUPABASE_ANON_KEY.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13.5, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// SportSphere brand — mirrors web/src/theme.ts (single source of truth on web).
class Brand {
  static const primary = Color(0xFFFF6A13); // brand orange
  static const primaryHover = Color(0xFFFF8A42); // accent / hover orange
  static const black = Color(0xFF0D0D0D);
  static const background = Color(0xFFFAFAF8);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Edge-to-edge: draw behind the status bar so dark screens control the
  // status bar icon color themselves (fixes invisible battery/clock icons).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  if (!_envValid) {
    runApp(const ConfigErrorApp());
    return;
  }
  await Supabase.initialize(url: kSupabaseUrl, publishableKey: kSupabaseAnonKey);
  runApp(const SportSphereApp());
}

class SportSphereApp extends StatelessWidget {
  const SportSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: MaterialApp(
      title: 'SportSphere',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const SplashPage(),
      ),
    );
  }

  ThemeData _buildTheme() {
    const scheme = ColorScheme.light(
      primary: Brand.primary,
      onPrimary: Colors.white,
      secondary: Brand.primaryHover,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: Brand.black,
      error: Color(0xFFC62828),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Lato everywhere: applied globally via the root font family.
      fontFamily: 'Lato',
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: Brand.black,
        displayColor: Brand.black,
      ),
      scaffoldBackgroundColor: Brand.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Brand.background,
        foregroundColor: Brand.black,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Brand.black),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(color: Brand.black, fontSize: 15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E5E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E5E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Brand.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Brand.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Brand.primary,
          side: const BorderSide(color: Brand.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Brand.primary.withValues(alpha: 0.12),
        iconTheme: const WidgetStatePropertyAll(IconThemeData(color: Brand.black)),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Brand.black),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5E5E0)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE5E5E0), thickness: 1),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Brand.black,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: Brand.primary),
    );
  }
}
