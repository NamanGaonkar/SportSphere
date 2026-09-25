import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/sports.dart';
import 'pages/home_shell.dart' show initShellPrefs;
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

  // Dark-mode app palette (app only — the web app stays light).
  static const darkBg = Color(0xFF0D0D0D); // scaffold background
  static const darkSurface = Color(0xFF161616); // cards / tables
  static const darkSurfaceAlt = Color(0xFF1F1F1F); // table header, wells
  static const darkBorder = Color(0xFF2A2A2A); // hairlines / input borders
}

/// App-only theme mode (web app is untouched). Persisted so the choice
/// survives restarts. Listened to by the root MaterialApp.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _kPrefKey = 'sportsphere.dark';
  bool _dark = false;
  bool get isDark => _dark;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dark = prefs.getBool(_kPrefKey) ?? false;
    } catch (_) {
      _dark = false;
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    _dark = !_dark;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefKey, _dark);
    } catch (_) {}
  }
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
  await initShellPrefs();
  await ThemeController.instance.load();
  // Start the sports lookup early so dashboard charts have names on first paint.
  SportsCache.warm();
  runApp(const SportSphereApp());
}

class SportSphereApp extends StatefulWidget {
  const SportSphereApp({super.key});

  @override
  State<SportSphereApp> createState() => _SportSphereAppState();
}

class _SportSphereAppState extends State<SportSphereApp> {
  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dark = ThemeController.instance.isDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark status-bar icons on the light theme, white icons on dark.
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: MaterialApp(
        title: 'SportSphere',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: const SplashPage(),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = dark
        ? const ColorScheme.dark(
            primary: Brand.primary,
            onPrimary: Colors.white,
            secondary: Brand.primaryHover,
            onSecondary: Colors.white,
            surface: Brand.darkSurface,
            onSurface: Colors.white,
            error: Color(0xFFEF5350),
          )
        : const ColorScheme.light(
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

    final fg = scheme.onSurface;
    final sub = dark ? Colors.white60 : Colors.black54;
    final borderColor = dark ? Brand.darkBorder : const Color(0xFFE5E5E0);
    final fillColor = dark ? Brand.darkSurfaceAlt : Colors.white;

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: fg,
        displayColor: fg,
      ),
      // FilterChip labels must stay readable in BOTH states: dark ink on
      // light backgrounds when unselected, dark ink on the orange tint when
      // selected (white labels were invisible on the pale chip fill).
      chipTheme: base.chipTheme.copyWith(
        labelStyle: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600),
        selectedColor: const Color(0x33FF6A13),
        backgroundColor: dark ? Brand.darkSurfaceAlt : const Color(0xFFF3F3EE),
        checkmarkColor: const Color(0xFFB24A00),
        side: BorderSide(color: dark ? Brand.darkBorder : const Color(0xFFDDDDD2)),
        showCheckmark: true,
      ),
      scaffoldBackgroundColor: dark ? Brand.darkBg : Brand.background,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? Brand.darkBg : Brand.background,
        foregroundColor: fg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: fg),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: fg, fontSize: 15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fillColor,
        hintStyle: TextStyle(color: sub),
        labelStyle: TextStyle(color: sub),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
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
        backgroundColor: dark ? Brand.darkSurface : Colors.white,
        indicatorColor: Brand.primary.withValues(alpha: 0.12),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: fg)),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
        ),
      ),
      cardTheme: CardThemeData(
        color: dark ? Brand.darkSurface : Colors.white,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: dark ? Brand.darkBorder : const Color(0xFFE5E5E0)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? Brand.darkSurface : Colors.white,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg),
        contentTextStyle: TextStyle(fontSize: 14, color: fg),
      ),
      dividerTheme: DividerThemeData(color: dark ? Brand.darkBorder : const Color(0xFFE5E5E0), thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? Brand.darkSurfaceAlt : Brand.black,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: Brand.primary),
    );
  }
}
