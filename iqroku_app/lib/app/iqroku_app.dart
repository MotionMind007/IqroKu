import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/dummy_iqroku_repository.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/setup_child_screen.dart';
import '../features/auth/welcome_screen.dart';
import 'app_shell.dart';
import 'app_state.dart';

class IqrokuApp extends StatefulWidget {
  const IqrokuApp({super.key, this.repository = const DummyIqrokuRepository()});

  final DummyIqrokuRepository repository;

  @override
  State<IqrokuApp> createState() => _IqrokuAppState();
}

class _IqrokuAppState extends State<IqrokuApp> {
  late final IqrokuState state;

  @override
  void initState() {
    super.initState();
    state = IqrokuState(repository: widget.repository);
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IqroKu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          return switch (state.launchStage) {
            AppLaunchStage.onboarding => OnboardingScreen(state: state),
            AppLaunchStage.welcome => WelcomeScreen(state: state),
            AppLaunchStage.login => LoginScreen(state: state),
            AppLaunchStage.register => RegisterScreen(state: state),
            AppLaunchStage.setupChild => SetupChildScreen(state: state),
            AppLaunchStage.authenticated => AppShell(state: state),
          };
        },
      ),
    );
  }
}
