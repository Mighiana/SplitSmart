import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';


import 'package:flutter/foundation.dart' show kIsWeb;
import 'l10n/app_localizations.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'providers/app_state.dart';
import 'services/notification_service.dart';
import 'services/backup_service.dart';

import 'services/security_service.dart';
import 'services/analytics_service.dart';
import 'utils/theme_utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow runtime font fetching — fonts are loaded from Google's CDN on
  // first launch, then cached locally for subsequent offline use.
  // If fetch fails (no network), the app gracefully falls back to system fonts.
  GoogleFonts.config.allowRuntimeFetching = true;

  // 1. Initialize Firebase — wrap in try/catch so a config error never
  //    prevents the app from rendering its first frame.
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyBdqQTvTrtlsRaSbQ7wkFcsw7KwvKm060U",
          appId: "1:698180984926:web:dummy_app_id_to_prevent_crash",
          messagingSenderId: "698180984926",
          projectId: "splitsmart-3898",
          storageBucket: "splitsmart-3898.firebasestorage.app",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('[main] Firebase init failed: $e');
  }

  // 2. Layer 1: Catch Flutter framework errors (Widget build, synchronous, etc.)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (_) {}
    _logError(details.exceptionAsString(), details.stack.toString());
  };

  // 3. Layer 2: Catch ALL other errors (Async, Futures, Platform-level)
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {}
    _logError(error.toString(), stack.toString());
    return true; // Error was handled
  };

  // 4. Orientation & status bar — lightweight, safe to do before runApp
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 5. Read only the two prefs needed to construct AppState — fast
  final prefs = await SharedPreferences.getInstance();
  final savedDarkMode = prefs.getBool('dark_mode') ?? false; // Default: light theme for new users

  // Auto-detect device language on first launch, fall back to 'en'
  final supportedCodes = {'en', 'ur', 'ar', 'fr', 'es', 'de', 'tr', 'hi'};
  final savedLocale = prefs.getString('locale');
  String initialLocaleCode;
  if (savedLocale != null) {
    // User explicitly chose a language before
    initialLocaleCode = savedLocale;
  } else {
    // First launch — use device system locale if we support it
    final systemCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    initialLocaleCode = supportedCodes.contains(systemCode) ? systemCode : 'en';
  }

  final appState = AppState(
    initialLocale: Locale(initialLocaleCode),
    initialDarkMode: savedDarkMode,
  );

  // 6. *** Call runApp IMMEDIATELY — the splash screen will show while
  //    heavy initialization (DB, notifications, Firestore, backup) runs
  //    in the background via _AppGate. ***
  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const SplitSmartApp(),
    ),
  );
}

/// The global "Safety Net" logger.
/// Persists both framework and async errors to the local log file.
/// Rotates the log file when it exceeds 1 MB to prevent unbounded growth.
Future<void> _logError(String error, String stack) async {
  if (kIsWeb) {
    debugPrint('Web Error Log: $error\n$stack');
    return;
  }
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/app_errors.log');
    final timestamp = DateTime.now();

    // Rotate if over 1 MB
    if (await file.exists() && (await file.length()) > 1024 * 1024) {
      final old = File('${dir.path}/app_errors.old.log');
      if (await old.exists()) await old.delete();
      await file.rename(old.path);
    }

    await file.writeAsString(
      '$timestamp:\n$error\n$stack\n-----------------------------------\n',
      mode: FileMode.append,
      flush: true, // Ensure it's written immediately
    );
  } catch (e) {
    debugPrint('Critical Failure: Could not write to app_errors.log $e');
  }
}

class SplitSmartApp extends StatelessWidget {
  const SplitSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return MaterialApp(
      title: 'SplitSmart',
      debugShowCheckedModeBanner: false,
      themeMode: state.themeMode,
      darkTheme: _buildTheme(Brightness.dark),
      theme: _buildTheme(Brightness.light),
      locale: state.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _AppGate(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? AppColors.bg : const Color(0xFFF4F6FA);
    final surface = isDark ? AppColors.surface : const Color(0xFFFFFFFF);
    final card = isDark ? AppColors.card : const Color(0xFFFFFFFF);
    final border = isDark ? AppColors.border : const Color(0xFFE0E4EE);
    final text = isDark ? AppColors.text : const Color(0xFF1A1A2E);
    final text2 = isDark ? AppColors.text2 : const Color(0xFF6B7280);
    final text3 = isDark ? AppColors.text3 : const Color(0xFFADB5BD);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.green,
        secondary: AppColors.blue,
        surface: surface,
        error: AppColors.red,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: text,
        onError: Colors.white,
      ),
      textTheme: _safeTextTheme(isDark),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border, width: 1.5),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _SpringSlideTransitionBuilder(),
          TargetPlatform.iOS: _SpringSlideTransitionBuilder(),
          TargetPlatform.windows: _SpringSlideTransitionBuilder(),
          TargetPlatform.macOS: _SpringSlideTransitionBuilder(),
        },
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.green, width: 1.5),
        ),
        hintStyle: TextStyle(color: text3),
        labelStyle: TextStyle(color: text2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _safeTitleStyle(text),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
    );
  }

  /// Build text theme with PlusJakartaSans, falling back to system font
  /// if the Google Font isn't available (e.g. first launch without network).
  static TextTheme _safeTextTheme(bool isDark) {
    final base = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final Color textColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    try {
      return GoogleFonts.plusJakartaSansTextTheme(base).apply(
        bodyColor: textColor,
        displayColor: textColor,
      );
    } catch (_) {
      return base.apply(
        bodyColor: textColor,
        displayColor: textColor,
      );
    }
  }

  /// AppBar title style with safe GoogleFonts fallback.
  static TextStyle _safeTitleStyle(Color color) {
    try {
      return GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
      );
    } catch (_) {
      return TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
      );
    }
  }
}

class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate>
    with SingleTickerProviderStateMixin {
  bool? _onboardingDone;
  bool? _nameRecorded;
  bool? _isAuthenticated;
  bool _splashFinished = false;
  late final StreamSubscription<dynamic> _authSub;
  late AnimationController _splashCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _subtitleFade;

  static const _word = 'SplitSmart';
  static const _totalChars = 10;
  static const _typeStart = 0.32;
  static const _typeEnd = 0.95;
  static const _typeRange = _typeEnd - _typeStart;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();

    // Listen for auth state changes (sign-out triggers redirect)
    _authSub = AuthService.instance.authStateChanges.listen((user) async {
      if (!mounted) return;
      
      final wasAuthenticated = _isAuthenticated;
      final isNowAuthenticated = user != null;
      
      // If user just logged in during this session, initialize cloud data
      if (wasAuthenticated == false && isNowAuthenticated == true) {
        try {
          await FirestoreService.instance.ensureUserDocument();
        } catch (e) {
          debugPrint('[AppGate] Firestore init error: $e');
        }
        if (mounted) {
          final state = context.read<AppState>();
          await state.reloadFromDatabase();
        }
      }

      if (mounted) {
        setState(() => _isAuthenticated = isNowAuthenticated);
      }
    });

    _splashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _logoScale = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashCtrl,
        curve: const Interval(0.0, 0.42, curve: Curves.elasticOut),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashCtrl,
        curve: const Interval(0.0, 0.22, curve: Curves.easeOut),
      ),
    );

    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashCtrl,
        curve: const Interval(0.90, 1.0, curve: Curves.easeOut),
      ),
    );

    _splashCtrl.forward().then((_) {
      if (mounted) setState(() => _splashFinished = true);
    });

    // Heavy init runs in background AFTER the first frame is painted
    // (avoids notifyListeners() during the build phase)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  /// Runs all heavy async initialization (DB, notifications, backup,
  /// analytics) in the background while the splash animation plays.
  /// Every step is wrapped in try/catch so a single failure can never
  /// prevent the app from opening.
  Future<void> _initializeApp() async {
    final appState = context.read<AppState>();

    // 1. Load data from SQLite / Firestore
    try {
      await appState.loadInitialData();
    } catch (e) {
      debugPrint('[AppGate] loadInitialData failed: $e');
    }

    // 2. Notification service (timezone init + plugin init)
    try {
      await NotificationService.init();
    } catch (e) {
      debugPrint('[AppGate] NotificationService.init failed: $e');
    }

    // 3. Reschedule subscription & reminder notifications
    try {
      await NotificationService.rescheduleAll(appState.subscriptions);
      await NotificationService.rescheduleAllReminders(appState.reminders);
    } catch (e) {
      debugPrint('[AppGate] Notification reschedule failed: $e');
    }

    // 4. Auto-backup check
    try {
      await BackupService.checkAutoBackup();
    } catch (e) {
      debugPrint('[AppGate] Auto-backup check failed: $e');
    }

    // 5. Analytics user properties (fire-and-forget)
    try {
      AnalyticsService.setUserProperties({
        'total_groups': appState.groups.length.toString(),
        'total_wallets': appState.wallets.length.toString(),
        'locale': appState.locale.languageCode,
        'theme': appState.isDark ? 'dark' : 'light',
      });
    } catch (e) {
      debugPrint('[AppGate] Analytics properties failed: $e');
    }

    // 6. Clear stale error logs from previous versions (one-time)
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logFile = File('${dir.path}/app_errors.log');
      if (await logFile.exists()) {
        final content = await logFile.readAsString();
        // If the log only contains pre-fix errors (before today), clear it
        if (!content.contains(DateTime.now().toIso8601String().substring(0, 10))) {
          await logFile.delete();
          debugPrint('[AppGate] Cleared stale error logs');
        }
      }
    } catch (e) {
      debugPrint('[AppGate] Log cleanup failed: $e');
    }
  }


  @override
  void dispose() {
    _authSub.cancel();
    _splashCtrl.dispose();
    super.dispose();
  }


  double _charOpacity(int index, double ctrlValue) {
    final sliceWidth = _typeRange / _totalChars;
    final charStart = _typeStart + index * sliceWidth;
    final charEnd = charStart + sliceWidth;

    if (ctrlValue <= charStart) return 0.0;
    if (ctrlValue >= charEnd) return 1.0;
    return (ctrlValue - charStart) / sliceWidth;
  }

  Future<void> _checkOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('onboarding_done') ?? false;
      final hasNameKey = prefs.containsKey('user_first_name');
      final isAuth = AuthService.instance.isSignedIn;
      if (mounted) {
        setState(() {
           _onboardingDone = done;
           _nameRecorded = hasNameKey;
           _isAuthenticated = isAuth;
        });
      }
    } catch (e) {
      debugPrint('[AppGate] _checkOnboarding failed: $e');
      // Set safe defaults so the app doesn't stay stuck on splash
      if (mounted) {
        setState(() {
          _onboardingDone = false;
          _nameRecorded = false;
          _isAuthenticated = false;
        });
      }
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      setState(() => _onboardingDone = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.select<AppState, bool>((s) => s.isLoading);

    if (loading || _onboardingDone == null || _nameRecorded == null || _isAuthenticated == null || !_splashFinished) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: AnimatedBuilder(
            animation: _splashCtrl,
            builder: (_, __) {
              final v = _splashCtrl.value;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: _logoFade.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        width: 88,
                        height: 88,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.green.withValues(alpha: 0.45),
                              blurRadius: 36,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Text(
                          '💚',
                          style: TextStyle(fontSize: 44),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_totalChars, (i) {
                      final opacity = _charOpacity(i, v);
                      final isGreen = i >= 5;
                      final charColor =
                          isGreen ? AppColors.green : AppColors.text;

                      return Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(0, (1 - opacity) * -14),
                          child: Text(
                            _word[i],
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: charColor,
                              letterSpacing: -0.5,
                              height: 1.0,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: _subtitleFade.value.clamp(0.0, 1.0),
                    child: const Text(
                      'Bill Splitter · Money Manager',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.text2,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 56),
                  Opacity(
                    opacity: _subtitleFade.value.clamp(0.0, 1.0),
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        color: AppColors.green.withValues(alpha: 0.65),
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    if (!_onboardingDone!) {
      return OnboardingScreen(onDone: _completeOnboarding);
    }

    if (!_nameRecorded!) {
      return _WelcomeNameScreen(onDone: () {
        if (mounted) setState(() => _nameRecorded = true);
      });
    }

    // Auth gate — require sign-in before entering the app
    if (!_isAuthenticated!) {
      return AuthScreen(
        onAuthenticated: () {
          // Handled by authStateChanges listener above
        },
      );
    }

    return _AppLockGate(child: const HomeScreen());
  }
}

class AppColors {
  // --- Dark Theme (Luxury) ---
  static const bg = Color(0xFF060608); // Deep black-blue
  static const surface = Color(0xFF0E0E12); // Slightly lighter black
  static const card = Color(0xFF16161C); // Elevated surface
  static const card2 = Color(0xFF1E1E26); // Nested elevation
  static const border = Color(0xFF23232D); // Subtle separators

  // --- Brand Accents (Emerald & Mint) ---
  static const green = Color(0xFF00E69B); // High-vibrancy Emerald
  static const greenGradient = LinearGradient(
    colors: [Color(0xFF00E69B), Color(0xFF00BFA5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const greenDim = Color(0x1A00E69B);
  static const greenDim2 = Color(0x0D00E69B);

  // --- Secondary Accents ---
  static const red = Color(0xFFFF4B6E); // Vibrant Pinkish Red
  static const redDim = Color(0x1AFF4B6E);
  
  static const blue = Color(0xFF00A3FF); // Bright Electric Blue
  static const blueDim = Color(0x1A00A3FF);

  static const yellow = Color(0xFFFFD600);
  static const yellowDim = Color(0x1AFFD600);

  static const purple = Color(0xFF7C4DFF);
  static const purpleDim = Color(0x1A7C4DFF);

  static const amber = Color(0xFFFFAB00);

  // --- Text & Greys ---
  static const text = Color(0xFFFDFDFD); // Clean white
  static const text2 = Color(0xFFA1A1B2); // Muted secondary
  static const text3 = Color(0xFF626274); // Hint/Disabled
}

class _SpringSlideTransitionBuilder extends PageTransitionsBuilder {
  const _SpringSlideTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slideTween = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).chain(
      CurveTween(curve: Curves.easeOutBack),
    );

    final fadeTween = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).chain(
      CurveTween(curve: Curves.easeOut),
    );

    return SlideTransition(
      position: animation.drive(slideTween),
      child: FadeTransition(
        opacity: animation.drive(fadeTween),
        child: child,
      ),
    );
  }
}

class _AppLockGate extends StatefulWidget {
  final Widget child;
  const _AppLockGate({required this.child});

  @override
  State<_AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<_AppLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _lockChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkLock() async {
    final enabled = await SecurityService.isAppLockEnabled();
    if (!mounted) return;
    setState(() {
      _locked = enabled;
      _lockChecked = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      SecurityService.isAppLockEnabled().then((enabled) {
        if (enabled && mounted) {
          setState(() => _locked = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_lockChecked) return const SizedBox.shrink();

    if (_locked) {
      return LockScreen(
        onUnlocked: () {
          if (mounted) setState(() => _locked = false);
        },
      );
    }

    return widget.child;
  }
}

class _WelcomeNameScreen extends StatefulWidget {
  final VoidCallback onDone;
  const _WelcomeNameScreen({required this.onDone});
  
  @override
  State<_WelcomeNameScreen> createState() => _WelcomeNameScreenState();
}

class _WelcomeNameScreenState extends State<_WelcomeNameScreen> {
  final _ctrl = TextEditingController();
  
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('👋', style: TextStyle(fontSize: 72), textAlign: TextAlign.center)
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .scale(duration: 1.seconds, begin: const Offset(1, 1), end: const Offset(1.15, 1.15)),
                  const SizedBox(height: 48),
                  Text('What should we call you?', 
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: TC.text(context), letterSpacing: -0.5), 
                    textAlign: TextAlign.center
                  ),
                  const SizedBox(height: 12),
                  Text('This is how you\'ll appear in the app.', style: TextStyle(fontSize: 16, color: TC.text2(context)), textAlign: TextAlign.center),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _ctrl,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: TC.text(context)),
                    textAlign: TextAlign.center,
                    autofocus: true,
                    maxLength: 50,
                    decoration: InputDecoration(hintText: 'Your name', hintStyle: TextStyle(color: TC.text3(context), fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 64),
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      String name = _ctrl.text.trim();
                      if (name.isEmpty) return;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('user_first_name', name);
                      widget.onDone();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(16)),
                      alignment: Alignment.center,
                      child: const Text('Continue  →', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
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
