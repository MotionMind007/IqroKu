import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/audio_playback_service.dart';
import '../data/auth_api_service.dart';
import '../data/daily_prayer_api_service.dart';
import '../data/dummy_iqroku_repository.dart';
import '../data/islamic_activity_service.dart';
import '../data/prayer_reminder_service.dart';
import '../data/push_notification_service.dart';
import '../data/quran_api_service.dart';
import '../data/voice_recording_service.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/password_reset_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/email_verification_screen.dart';
import '../features/auth/setup_child_screen.dart';
import '../features/auth/setup_parent_pin_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/mode/mode_selection_screen.dart';
import '../features/mode/parent_dashboard_screen.dart';
import '../features/mode/pin_entry_screen.dart';
import 'app_shell.dart';
import 'app_state.dart';

class IqrokuApp extends StatefulWidget {
  IqrokuApp({
    super.key,
    this.repository = const DummyIqrokuRepository(),
    AuthApiService? authService,
    this.dailyPrayerApiService = const DailyPrayerApiService(),
    this.quranApiService = const QuranApiService(),
    this.islamicActivityService = const IslamicActivityService(),
    this.prayerReminderService,
    this.pushNotificationService,
    this.voiceRecordingService,
    this.audioPlaybackService,
  }) : authService = authService ?? AuthApiService();

  final DummyIqrokuRepository repository;
  final AuthApiService authService;
  final DailyPrayerApiService dailyPrayerApiService;
  final QuranApiService quranApiService;
  final IslamicActivityService islamicActivityService;
  final PrayerReminderService? prayerReminderService;
  final PushNotificationService? pushNotificationService;
  final VoiceRecordingService? voiceRecordingService;
  final AudioPlaybackService? audioPlaybackService;

  @override
  State<IqrokuApp> createState() => _IqrokuAppState();
}

class _IqrokuAppState extends State<IqrokuApp> {
  late final IqrokuState state;

  @override
  void initState() {
    super.initState();
    state = IqrokuState(
      repository: widget.repository,
      authService: widget.authService,
      dailyPrayerApiService: widget.dailyPrayerApiService,
      quranApiService: widget.quranApiService,
      islamicActivityService: widget.islamicActivityService,
      prayerReminderService: widget.prayerReminderService,
      pushNotificationService: widget.pushNotificationService,
      voiceRecordingService: widget.voiceRecordingService,
      audioPlaybackService: widget.audioPlaybackService,
    );
    state.restoreFromDisk();
    state.loadIqroContent();
    state.loadQuranContent();
    state.loadIslamicActivity();
    state.loadDailyPrayers();
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
            AppLaunchStage.emailVerification => EmailVerificationScreen(
              state: state,
            ),
            AppLaunchStage.passwordReset => PasswordResetScreen(state: state),
            AppLaunchStage.setupParentPin => SetupParentPinScreen(state: state),
            AppLaunchStage.setupChild => SetupChildScreen(state: state),
            AppLaunchStage.authenticated => _buildAuthenticatedView(),
          };
        },
      ),
    );
  }

  Widget _buildAuthenticatedView() {
    // If no mode selected, show mode selection
    if (state.currentMode == AppMode.none) {
      return ModeSelectionScreen(state: state);
    }

    // Parent mode
    if (state.currentMode == AppMode.parent) {
      // If PIN verified, show dashboard
      if (state.parentPinVerified) {
        return ParentDashboardScreen(state: state);
      }
      // Show PIN entry (PIN should already be set during registration)
      return PinEntryScreen(state: state, isParentMode: true);
    }

    // Child mode - show child selection
    if (state.currentMode == AppMode.child &&
        state.currentChildAccount == null) {
      return _buildChildSelection();
    }

    // Child mode with child selected - verify the existing child PIN.
    if (state.currentMode == AppMode.child &&
        state.currentChildAccount != null &&
        !state.childPinVerified) {
      return PinEntryScreen(
        state: state,
        isParentMode: false,
        childName: state.currentChildAccount?.name,
      );
    }

    // Default - show main app shell
    return AppShell(state: state);
  }

  Widget _buildChildSelection() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.child_care,
                    size: 64,
                    color: Color(0xFF23864B),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Pilih Profil Anak',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  if (state.childProfiles.isEmpty)
                    const Text(
                      'Belum ada profil anak. Silakan tambah profil anak terlebih dahulu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6D756F)),
                    )
                  else
                    ...state.childProfiles.map(
                      (child) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              state.selectChildForMode(child.id);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              child.name,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => state.exitToModeSelection(),
                    child: const Text('Kembali'),
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
