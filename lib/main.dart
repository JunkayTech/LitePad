import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/note_service.dart';
import 'screens/home_screen.dart';
import 'screens/summarizer_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/glow_nav_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final noteService = NoteService();
  try {
    await noteService.init();
  } catch (e, st) {
    debugPrint("NoteService init failed: $e\n$st");
  }
  runApp(LitePadApp(noteService: noteService));
}

class LitePadApp extends StatefulWidget {
  final NoteService noteService;
  const LitePadApp({super.key, required this.noteService});

  @override
  State<LitePadApp> createState() => _LitePadAppState();
}

class _LitePadAppState extends State<LitePadApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _updateTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.noteService,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'LitePad',
        themeMode: _themeMode,
        theme: _lightTheme,
        darkTheme: _darkTheme,
        home: RootScaffold(
          themeMode: _themeMode,
          onThemeChange: _updateTheme,
        ),
      ),
    );
  }
}

class RootScaffold extends StatefulWidget {
  final ThemeMode themeMode;
  final void Function(ThemeMode mode) onThemeChange;
  const RootScaffold(
      {super.key, required this.themeMode, required this.onThemeChange});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(key: ValueKey('home')),
      const SummarizerScreen(key: ValueKey('summarizer')),
      SettingsScreen(
        key: const ValueKey('settings'),
        mode: widget.themeMode,
        onThemeChange: widget.onThemeChange,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: pages[_index],
      ),
      bottomNavigationBar: GlowNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          GlowNavItem(icon: Icons.dashboard_rounded, label: 'Home'),
          GlowNavItem(icon: Icons.auto_awesome, label: 'Summarizer'),
          GlowNavItem(icon: Icons.settings_rounded, label: 'Settings'),
        ],
      ),
    );
  }
}

/// New color palette
const Color _deepTeal = Color(0xFF0F766E); // primary accent (deep teal)
const Color _warmAmber = Color(0xFFFFB020); // secondary accent (warm amber)
const Color _charcoal = Color(0xFF111827); // dark neutral
const Color _ivory = Color(0xFFF8F6F2); // light neutral

final ThemeData _lightTheme = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  colorScheme: ColorScheme(
    brightness: Brightness.light,
    primary: _deepTeal,
    onPrimary: _ivory,
    secondary: _warmAmber,
    onSecondary: _charcoal,
    error: const Color(0xFFB00020),
    onError: _ivory,
    background: _ivory,
    onBackground: _charcoal,
    surface: Colors.white,
    onSurface: _charcoal,
  ),
  scaffoldBackgroundColor: const Color(0xFFFAFBFA),
  cardTheme: CardTheme(
    elevation: 2,
    margin: EdgeInsets.zero,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18))),
    color: Colors.white,
  ),
  appBarTheme: AppBarTheme(
    elevation: 0,
    centerTitle: true,
    backgroundColor: _deepTeal,
    foregroundColor: _ivory,
    titleTextStyle: const TextStyle(
        color: _ivory, fontSize: 20, fontWeight: FontWeight.w700),
    iconTheme: const IconThemeData(color: _ivory),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: _warmAmber,
    foregroundColor: _charcoal,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: _deepTeal,
    unselectedItemColor: _charcoal.withOpacity(0.6),
    showUnselectedLabels: true,
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(
        fontWeight: FontWeight.w700, letterSpacing: -0.5, color: _charcoal),
    bodyMedium: TextStyle(height: 1.35, color: _charcoal),
  ),
  inputDecorationTheme: InputDecorationTheme(
    hintStyle: TextStyle(color: _charcoal.withOpacity(0.6)),
    border: InputBorder.none,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _deepTeal,
      foregroundColor: _ivory,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _deepTeal,
      side: BorderSide(color: _deepTeal.withOpacity(0.12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
);

final ThemeData _darkTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  colorScheme: ColorScheme(
    brightness: Brightness.dark,
    primary: _deepTeal,
    onPrimary: _ivory,
    secondary: _warmAmber,
    onSecondary: _charcoal,
    error: const Color(0xFFCF6679),
    onError: _charcoal,
    background: const Color(0xFF0B0D0E),
    onBackground: _ivory,
    surface: const Color(0xFF0F1720),
    onSurface: _ivory,
  ),
  scaffoldBackgroundColor: const Color(0xFF07090A),
  cardTheme: const CardTheme(
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18))),
    color: Color(0xFF0F1720),
  ),
  appBarTheme: AppBarTheme(
    elevation: 0,
    centerTitle: true,
    backgroundColor: _deepTeal.withOpacity(0.14),
    foregroundColor: _ivory,
    titleTextStyle: const TextStyle(
        color: _ivory, fontSize: 20, fontWeight: FontWeight.w700),
    iconTheme: const IconThemeData(color: _ivory),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: _warmAmber,
    foregroundColor: _charcoal,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: const Color(0xFF0B0D0E),
    selectedItemColor: _warmAmber,
    unselectedItemColor: _ivory.withOpacity(0.7),
    showUnselectedLabels: true,
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(
        fontWeight: FontWeight.w700, letterSpacing: -0.5, color: _ivory),
    bodyMedium: TextStyle(height: 1.35, color: _ivory),
  ),
  inputDecorationTheme: InputDecorationTheme(
    hintStyle: TextStyle(color: _ivory.withOpacity(0.6)),
    border: InputBorder.none,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _deepTeal,
      foregroundColor: _ivory,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
);
