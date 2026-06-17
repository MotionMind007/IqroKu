import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/assessment_service.dart';
import '../data/audio_playback_service.dart';
import '../data/auth_api_service.dart';
import '../data/daily_prayer_api_service.dart';
import '../data/dummy_iqroku_repository.dart';
import '../data/islamic_activity_service.dart';
import '../data/quran_api_service.dart';
import '../data/voice_recording_service.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/setup_child_screen.dart';
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
    this.assessmentService = const MockAssessmentService(),
    AuthApiService? authService,
    this.dailyPrayerApiService = const DailyPrayerApiService(),
    this.quranApiService = const QuranApiService(),
    this.islamicActivityService = const IslamicActivityService(),
    this.voiceRecordingService,
    this.audioPlaybackService,
  }) : authService = authService ?? AuthApiService();

  final DummyIqrokuRepository repository;
  final AssessmentService assessmentService;
  final AuthApiService authService;
  final DailyPrayerApiService dailyPrayerApiService;
  final QuranApiService quranApiService;
  final IslamicActivityService islamicActivityService;
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
      assessmentService: widget.assessmentService,
      authService: widget.authService,
      dailyPrayerApiService: widget.dailyPrayerApiService,
      quranApiService: widget.quranApiService,
      islamicActivityService: widget.islamicActivityService,
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
      // If no PIN set, show setup screen
      if (!state.hasParentPin) {
        return _buildPinSetup(isParent: true);
      }
      // Show PIN entry
      return PinEntryScreen(
        state: state,
        isParentMode: true,
      );
    }

    // Child mode - show child selection
    if (state.currentMode == AppMode.child && state.currentChildAccount == null) {
      return _buildChildSelection();
    }

    // Child with no PIN - show setup
    if (state.currentMode == AppMode.child && state.currentChildAccount != null && !state.currentChildHasPin) {
      return _buildPinSetup(isParent: false, childName: state.currentChildAccount?.name);
    }

    // Child mode with child selected - show PIN entry
    if (state.currentMode == AppMode.child && state.currentChildAccount != null) {
      return PinEntryScreen(
        state: state,
        isParentMode: false,
        childName: state.currentChildAccount?.name,
      );
    }

    // Default - show main app shell
    return AppShell(state: state);
  }

  Widget _buildPinSetup({required bool isParent, String? childName}) {
    final title = isParent ? 'Setup PIN Orang Tua' : 'Setup PIN $childName';
    final subtitle = isParent
        ? 'Buat PIN 4 digit untuk mengakses mode orang tua'
        : 'Buat PIN 4 digit untuk $childName';

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
                  Icon(
                    isParent ? Icons.lock_outline : Icons.child_care,
                    size: 64,
                    color: const Color(0xFF23864B),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF6D756F)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // PIN input fields
                  _PinInput(
                    onComplete: (pin) async {
                      if (isParent) {
                        await state.setParentPin(pin);
                        // After setting PIN, show PIN entry
                        state.enterParentMode();
                      } else {
                        final childId = state.currentChildAccount?.id ?? state.selectedChildId;
                        await state.setChildPin(childId, pin);
                        // After setting PIN, enter child mode
                        state.enterChildMode(state.currentChildAccount!);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  if (!isParent)
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
                  const Icon(Icons.child_care, size: 64, color: Color(0xFF23864B)),
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
                    ...state.childProfiles.map((child) => Padding(
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
                          child: Text(child.name, style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                    )),
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

class _PinInput extends StatefulWidget {
  const _PinInput({required this.onComplete});

  final Future<void> Function(String pin) onComplete;

  @override
  State<_PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<_PinInput> {
  final List<String> _pin = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final filled = index < _pin.length;
            return Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: filled ? const Color(0xFF23864B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: filled ? const Color(0xFF23864B) : const Color(0xFFE7E1D6),
                  width: 2,
                ),
              ),
              child: Center(
                child: filled
                    ? const Icon(Icons.circle, size: 12, color: Colors.white)
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        // Number pad
        _buildNumberPad(),
      ],
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberButton('1'),
            _buildNumberButton('2'),
            _buildNumberButton('3'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberButton('4'),
            _buildNumberButton('5'),
            _buildNumberButton('6'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberButton('7'),
            _buildNumberButton('8'),
            _buildNumberButton('9'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 88),
            _buildNumberButton('0'),
            _buildDeleteButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberButton(String number) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isLoading ? null : () => _onNumberPressed(number),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isLoading ? null : _onDeletePressed,
            child: const Center(child: Icon(Icons.backspace_outlined, size: 28)),
          ),
        ),
      ),
    );
  }

  void _onNumberPressed(String number) {
    if (_pin.length >= 4) return;
    setState(() => _pin.add(number));
    if (_pin.length == 4) {
      _submitPin();
    }
  }

  void _onDeletePressed() {
    if (_pin.isEmpty) return;
    setState(() => _pin.removeLast());
  }

  Future<void> _submitPin() async {
    setState(() => _isLoading = true);
    try {
      await widget.onComplete(_pin.join());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _pin.clear();
        });
      }
    }
  }
}
