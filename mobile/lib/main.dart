import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/splash_page.dart';

/// Supabase credentials are injected at build time, e.g.:
/// flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

// SportSphere brand — mirrors web/src/theme.ts (single source of truth on web).
class Brand {
  static const primary = Color(0xFFFF6A13); // brand orange
  static const primaryHover = Color(0xFFFF8A42); // accent / hover orange
  static const black = Color(0xFF0D0D0D);
  static const background = Color(0xFFFAFAF8);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: kSupabaseUrl, publishableKey: kSupabaseAnonKey);
  runApp(const SportSphereApp());
}

class SportSphereApp extends StatelessWidget {
  const SportSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SportSphere',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const SplashPage(),
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
