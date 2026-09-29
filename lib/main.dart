import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/app_services.dart';
import 'services/blocker_service.dart';
import 'services/companion_service.dart';
import 'services/health_service.dart';
import 'services/time_bank.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://ef3725e92e7ecf4e90066034930f710e@o4511955548372992.ingest.de.sentry.io/4511955554009168';
      // Traces and profiles sample rate: 1.0 in debug, 0.1 in production to conserve battery, CPU, and quota.
      options.tracesSampleRate = kDebugMode ? 1.0 : 0.1;
      options.profilesSampleRate = kDebugMode ? 1.0 : 0.1;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Tag current Shorebird patch number in Sentry for instant visibility
      try {
        final shorebirdUpdater = ShorebirdUpdater();
        final patch = await shorebirdUpdater.readCurrentPatch();
        if (patch != null) {
          Sentry.configureScope((scope) {
            scope.setTag('shorebird_patch', patch.number.toString());
          });
        }
      } catch (_) {}

      await TimeBankService.instance.init();
      await CompanionService.instance.init();
      await AppServices.instance.initialize();
      await BlockerService.instance.initialize();
      await HealthService.instance.initPedometerListener();
      if (await HealthService.instance.checkHealthConnectPermission()) {
        HealthService.instance.startAutoHealthSync();
      }
      await BlockerService.instance.evaluateBlockState();

      runApp(const FravoApp());
    },
  );
}

class FravoApp extends StatefulWidget {
  const FravoApp({super.key});

  @override
  State<FravoApp> createState() => _FravoAppState();
}

class _FravoAppState extends State<FravoApp> {
  bool _completedOnboarding = false;

  @override
  void initState() {
    super.initState();
    final box = Hive.box('time_bank');
    _completedOnboarding =
        box.get('completedOnboarding', defaultValue: false) as bool;
  }

  void _onOnboardingComplete() {
    if (mounted) {
      setState(() {
        _completedOnboarding = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fravo',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [
        SentryNavigatorObserver(),
      ],
      themeMode: ThemeMode.system,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFB),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4A90E2),
          secondary: Color(0xFF10B981),
          surface: Color(0xFFF8FAFB),
          error: Color(0xFFEF4444),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF1A202C)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1A202C),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        useMaterial3: true,
        fontFamily: 'System',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4A90E2),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
          error: Color(0xFFEF4444),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
          titleTextStyle: TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        useMaterial3: true,
        fontFamily: 'System',
      ),
      home: FravoAnimatedLaunchScreen(
        nextScreen: _completedOnboarding
            ? const MainNavigationScreen()
            : OnboardingScreen(onOnboardingComplete: _onOnboardingComplete),
      ),
    );
  }
}
