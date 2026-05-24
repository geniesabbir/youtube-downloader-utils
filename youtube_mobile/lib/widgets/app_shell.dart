import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'branded_splash_screen.dart';
import 'dashboard.dart';
import 'onboarding_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const String _onboardingKey = 'app_onboarding_complete_v1';

  bool _booted = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final completedOnboarding = prefs.getBool(_onboardingKey) ?? false;

    await Future<void>.delayed(const Duration(milliseconds: 1600));

    if (!mounted) return;
    setState(() {
      _booted = true;
      _showOnboarding = !completedOnboarding;
    });
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    if (!mounted) return;
    setState(() {
      _showOnboarding = false;
      _booted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget screen;
    if (!_booted) {
      screen = const BrandedSplashScreen();
    } else if (_showOnboarding) {
      screen = OnboardingScreen(onComplete: _finishOnboarding);
    } else {
      screen = const Dashboard();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey(screen.runtimeType),
        child: screen,
      ),
    );
  }
}
