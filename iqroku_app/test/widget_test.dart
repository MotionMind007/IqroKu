import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iqroku/app/app_state.dart';
import 'package:iqroku/app/iqroku_app.dart';
import 'package:iqroku/data/audio_playback_service.dart';
import 'package:iqroku/data/auth_api_service.dart';
import 'package:iqroku/data/daily_prayer_api_service.dart';
import 'package:iqroku/data/dummy_iqroku_repository.dart';
import 'package:iqroku/data/islamic_activity_service.dart';
import 'package:iqroku/data/quran_api_service.dart';
import 'package:iqroku/data/voice_recording_service.dart';
import 'package:iqroku/models/iqro_models.dart';
import 'package:iqroku/models/learning_status.dart';
import 'package:iqroku/models/prayer_models.dart';
import 'package:iqroku/models/profile_models.dart';
import 'package:iqroku/models/quran_models.dart';

class TestFlutterSecureStoragePlatform extends FlutterSecureStoragePlatform {
  TestFlutterSecureStoragePlatform(this.data);
  final Map<String, String> data;

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => data.containsKey(key);
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => data.remove(key);
  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      data.clear();
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => data[key];
  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => data;
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => data[key] = value;
}

void main() {
  late Map<String, String> secureData;

  setUp(() {
    secureData = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      secureData,
    );
  });

  testWidgets('IqroKu starts from welcome and reaches learning tab', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      IqrokuApp(
        authService: FakeAuthApiService(),
        dailyPrayerApiService: const FakeDailyPrayerApiService(),
        quranApiService: const FakeQuranApiService(),
        islamicActivityService: const FakeIslamicActivityService(),
        voiceRecordingService: FakeVoiceRecordingService(),
        audioPlaybackService: FakeAudioPlaybackService(),
      ),
    );

    expect(find.text('Belajar Iqro Bertahap'), findsOneWidget);

    await tester.tap(find.text('Lewati'));
    await tester.pump();

    expect(
      find.text('Belajar Ngaji Lebih Mudah, Terarah, dan Menyenangkan'),
      findsOneWidget,
    );

    final welcomeButton = find.byKey(const ValueKey('welcome_continue_button'));
    await tester.tap(welcomeButton);
    await tester.pump();

    expect(find.text('Masuk ke IqroKu'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'parent@iqroku.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'secret123',
    );
    final loginButton = find.byKey(const ValueKey('login_submit_button'));
    await tester.ensureVisible(loginButton);
    await tester.pump();
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Tambah Profil Anak'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Nama Anak'), 'Nedy');
    await tester.enterText(
      find.widgetWithText(TextField, 'PIN Anak (4 digit)'),
      '1234',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Konfirmasi PIN'),
      '1234',
    );
    await tester.pump();
    final saveChildButton = find.widgetWithText(
      FilledButton,
      'Simpan & Mulai Belajar',
    );
    await tester.scrollUntilVisible(
      saveChildButton,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveChildButton);
    await tester.pumpAndSettle();

    expect(find.text('Pilih Mode'), findsOneWidget);

    await tester.tap(find.text('Mode Anak'));
    await tester.pumpAndSettle();

    expect(find.text('Nedy'), findsOneWidget);
    expect(find.text('Pilih Profil Anak'), findsOneWidget);

    await tester.tap(find.text('Nedy'));
    await tester.pumpAndSettle();

    expect(find.text('Masukkan PIN Nedy'), findsOneWidget);

    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(find.text(digit).last);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Menu Utama'), findsOneWidget);

    await tester.tap(find.text('Belajar'));
    await tester.pump();

    expect(find.text('Belajar Iqro'), findsOneWidget);
    expect(find.text('Pilih Halaman'), findsOneWidget);
  });

  test('Iqro progress, notes, and local storage are updated', () async {
    SharedPreferences.setMockInitialValues({});
    final state = IqrokuState(
      repository: const DummyIqrokuRepository(),
      voiceRecordingService: FakeVoiceRecordingService(),
      audioPlaybackService: FakeAudioPlaybackService(),
    );

    state.updateIqroPageStatus(LearningStatus.fluent);

    expect(state.selectedIqroCompletedPages, 8);
    expect(state.selectedChild.currentLesson, 'Iqro 1 - Halaman 9');
    expect((state.selectedChild.progress * 100).round(), 29);
    expect(state.learningNotes.first.title, 'Iqro 1 - Halaman 8');
    expect(state.learningNotes.first.status, LearningStatus.fluent);

    state.goToNextIqroPage();

    expect(state.selectedIqroPage, 9);
    expect(state.selectedIqroStatus, LearningStatus.learning);

    await state.flushLocalStorageForTests();

    final restored = IqrokuState(
      repository: const DummyIqrokuRepository(),
      voiceRecordingService: FakeVoiceRecordingService(),
      audioPlaybackService: FakeAudioPlaybackService(),
    );
    await restored.restoreFromDisk();

    expect(restored.selectedIqroCompletedPages, 8);
    expect(restored.selectedIqroPage, 9);
    expect(restored.learningNotes.first.title, 'Iqro 1 - Halaman 8');
  });

  test('Iqro JSON material is loaded from app assets', () async {
    final payload = await File(
      'assets/content/iqro_complete_jilid_1-6.json',
    ).readAsString();
    final content = IqroContent.fromJson(
      jsonDecode(payload) as Map<String, Object?>,
    );

    expect(content.books, hasLength(6));
    expect(content.books.first.totalPages, 32);
    expect(content.books.first.pages.first.lines.first, ['أ', '=', 'ا', 'ب']);
  });

  test('Voice practice attempts are stored locally', () async {
    SharedPreferences.setMockInitialValues({});
    final state = IqrokuState(
      repository: const DummyIqrokuRepository(),
      voiceRecordingService: FakeVoiceRecordingService(),
      audioPlaybackService: FakeAudioPlaybackService(),
    );

    await state.startVoicePractice();
    expect(state.isVoiceRecording, isTrue);

    await state.finishVoicePractice();
    expect(state.isVoiceRecording, isFalse);
    expect(state.learningAttempts, hasLength(1));
    expect(state.learningAttempts.first.bookId, 1);
    expect(state.learningAttempts.first.pageNumber, 8);
    expect(
      state.learningAttempts.first.durationSeconds,
      greaterThanOrEqualTo(1),
    );
    expect(state.learningAttempts.first.audioPath, endsWith('.m4a'));
    expect(state.learningAttempts.first.assessmentStatus.name, 'recorded');

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(state.learningAttempts.first.score, isNull);
    expect(state.learningAttempts.first.status, LearningStatus.learning);
    expect(state.learningAttempts.first.note, contains('review orang tua'));

    await state.toggleAttemptPlayback(state.learningAttempts.first);
    expect(state.playingAttemptId, state.learningAttempts.first.id);

    await state.toggleAttemptPlayback(state.learningAttempts.first);
    expect(state.playingAttemptId, isNull);

    await state.flushLocalStorageForTests();

    final restored = IqrokuState(
      repository: const DummyIqrokuRepository(),
      voiceRecordingService: FakeVoiceRecordingService(),
      audioPlaybackService: FakeAudioPlaybackService(),
    );
    await restored.restoreFromDisk();

    expect(restored.learningAttempts, hasLength(1));
    expect(restored.selectedPageLatestAttempt?.pageNumber, 8);
  });

  test('Parent settings can reset progress and logout', () async {
    SharedPreferences.setMockInitialValues({});
    final state = IqrokuState(
      repository: const DummyIqrokuRepository(),
      voiceRecordingService: FakeVoiceRecordingService(),
      audioPlaybackService: FakeAudioPlaybackService(),
    );

    state.updateIqroPageStatus(LearningStatus.fluent);
    state.resetSelectedChildProgress();

    expect(state.selectedIqroCompletedPages, 0);
    expect(state.selectedIqroPage, 1);
    expect(state.selectedChild.currentLesson, 'Iqro 1 - Halaman 1');

    state.logout();

    expect(state.launchStage, AppLaunchStage.welcome);
    expect(state.selectedTab, 0);
  });

  test('Free plan allows Iqro 1 and locks Iqro 2+', () async {
    SharedPreferences.setMockInitialValues({});
    final state = IqrokuState(
      repository: const DummyIqrokuRepository(),
      voiceRecordingService: FakeVoiceRecordingService(),
      audioPlaybackService: FakeAudioPlaybackService(),
    );

    state.selectIqroPage(10);
    expect(state.selectedIqroPage, 10);

    state.goToNextIqroPage();
    expect(state.selectedIqroPage, 11);
    expect(state.subscriptionNotice, isNull);

    state.selectIqroBook(2);
    expect(state.selectedIqroBook, 2);
    expect(state.selectedIqroPage, 1);
    expect(state.isIqroPageLocked(2, 1), isTrue);
    expect(state.subscriptionNotice, contains('jilid 2'));

    state.activateFamilyPlus();
    expect(state.subscriptionActivatedAt, isNotNull);
    expect(state.subscriptionRenewalLabel, isNot('Belum aktif'));

    state.selectIqroBook(2);
    expect(state.selectedIqroBook, 2);
    expect(state.isIqroPageLocked(2, 1), isFalse);
  });

  test(
    'Parent review result updates attempt and page status locally',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = IqrokuState(
        repository: const DummyIqrokuRepository(),
        voiceRecordingService: FakeVoiceRecordingService(),
        audioPlaybackService: FakeAudioPlaybackService(),
      );

      await state.startVoicePractice();
      await state.finishVoicePractice();
      final attemptId = state.learningAttempts.first.id;

      state.applyParentReviewResult(
        attemptId: attemptId,
        status: LearningStatus.fluent,
      );

      expect(state.learningAttempts.first.status, LearningStatus.fluent);
      expect(
        state.learningAttempts.first.assessmentStatus,
        ReadingAssessmentStatus.fluent,
      );
      expect(state.statusForIqroPage(1, 8), LearningStatus.fluent);

      state.applyParentReviewResult(
        attemptId: attemptId,
        status: LearningStatus.review,
        repeatFromPage: 8,
      );

      expect(state.learningAttempts.first.status, LearningStatus.review);
      expect(
        state.learningAttempts.first.assessmentStatus,
        ReadingAssessmentStatus.needsReview,
      );
      expect(state.statusForIqroPage(1, 8), LearningStatus.review);
      expect(state.statusForIqroPage(1, 1), LearningStatus.fluent);
      expect(state.isIqroPageLocked(1, 1), isFalse);
      expect(state.isIqroPageLocked(1, 7), isFalse);
      expect(state.isIqroPageLocked(1, 8), isFalse);
      expect(state.isIqroPagePremiumLocked(1, 1), isFalse);
      expect(state.isIqroPagePremiumLocked(2, 1), isTrue);
      expect(state.selectedChild.repeatFromPage, 8);
    },
  );

  test('Remote progress is restored after login', () async {
    SharedPreferences.setMockInitialValues({});
    final authService = FakeAuthApiService();
    authService.children.add(
      const ChildProfile(
        id: 'child-remote',
        name: 'Nedy',
        age: 7,
        currentLesson: 'Iqro 1 - Halaman 1',
        progress: 0,
        avatarAsset: 'assets/brand/male-avatar.png',
      ),
    );
    authService.progress['child-remote'] = const [
      RemoteIqroProgress(
        childId: 'child-remote',
        bookId: 1,
        pageNumber: 1,
        status: LearningStatus.fluent,
      ),
      RemoteIqroProgress(
        childId: 'child-remote',
        bookId: 1,
        pageNumber: 2,
        status: LearningStatus.fluent,
      ),
      RemoteIqroProgress(
        childId: 'child-remote',
        bookId: 1,
        pageNumber: 3,
        status: LearningStatus.learning,
      ),
    ];
    authService.attempts['child-remote'] = const [
      LearningAttempt(
        id: 'attempt-remote',
        childId: 'child-remote',
        bookId: 1,
        pageNumber: 3,
        date: '2026-06-19',
        durationSeconds: 12,
        status: LearningStatus.review,
        assessmentStatus: ReadingAssessmentStatus.needsReview,
        audioPath: '/uploads/audio/attempt-remote.m4a',
      ),
    ];

    final state = IqrokuState(
      repository: const DummyIqrokuRepository(),
      authService: authService,
      voiceRecordingService: FakeVoiceRecordingService(),
      audioPlaybackService: FakeAudioPlaybackService(),
    );

    await state.loginWithEmail(email: 'parent@iqroku.test', password: 'secret');

    expect(state.launchStage, AppLaunchStage.authenticated);
    expect(state.selectedIqroPage, 3);
    expect(state.selectedIqroCompletedPages, 2);
    expect(state.selectedChild.currentLesson, 'Iqro 1 - Halaman 3');
    expect(
      state.selectedPageLatestAttempt?.assessmentStatus,
      ReadingAssessmentStatus.needsReview,
    );
  });

  test('Login without parent PIN requires parent PIN setup first', () async {
    SharedPreferences.setMockInitialValues({});
    final authService = FakeAuthApiService(parentHasPin: false);

    final state = IqrokuState(
      repository: const DummyIqrokuRepository(),
      authService: authService,
      voiceRecordingService: FakeVoiceRecordingService(),
      audioPlaybackService: FakeAudioPlaybackService(),
    );

    await state.loginWithEmail(email: 'parent@iqroku.test', password: 'secret');

    expect(state.launchStage, AppLaunchStage.setupParentPin);
    expect(state.hasParentPin, isFalse);

    await state.completeParentPinSetup('1234');

    expect(state.hasParentPin, isTrue);
    expect(state.parentAccount?.hasPin, isTrue);
    expect(state.launchStage, AppLaunchStage.setupChild);
  });
}

class FakeQuranApiService extends QuranApiService {
  const FakeQuranApiService();

  @override
  Future<List<Surah>> fetchSurahs() async {
    return const [
      Surah(
        id: 1,
        name: 'Al-Fatihah',
        meaning: 'Pembuka',
        arabicName: 'الفاتحة',
        ayahCount: 7,
        juz: 1,
      ),
      Surah(
        id: 112,
        name: 'Al-Ikhlas',
        meaning: 'Ikhlas',
        arabicName: 'الإخلاص',
        ayahCount: 4,
        juz: 30,
      ),
    ];
  }

  @override
  Future<SurahDetail> fetchSurahDetail(int surahId) async {
    return const SurahDetail(
      surah: Surah(
        id: 1,
        name: 'Al-Fatihah',
        meaning: 'Pembuka',
        arabicName: 'الفاتحة',
        ayahCount: 7,
        juz: 1,
      ),
      audioUrl: 'https://example.test/fatihah.mp3',
      ayahs: [
        QuranAyah(
          number: 1,
          arabic: 'بسم الله الرحمن الرحيم',
          translation: 'Dengan nama Allah Yang Maha Pengasih.',
        ),
      ],
    );
  }
}

class FakeIslamicActivityService extends IslamicActivityService {
  const FakeIslamicActivityService();

  @override
  Future<PrayerSchedule> fetchPrayerSchedule() async {
    return const PrayerSchedule(
      locationLabel: 'Jakarta, Indonesia',
      dateLabel: '16 Jun 2026 / 01 Muharram 1448 H',
      latitude: -6.2088,
      longitude: 106.8456,
      locationSource: LocationSource.device,
      times: [
        PrayerTime(name: 'Subuh', time: '04:37'),
        PrayerTime(name: 'Dzuhur', time: '11:53', active: true),
        PrayerTime(name: 'Ashar', time: '15:35'),
        PrayerTime(name: 'Maghrib', time: '17:48'),
        PrayerTime(name: 'Isya', time: '19:01'),
      ],
    );
  }

  @override
  Future<QiblaDirection> fetchQiblaDirection() async {
    return const QiblaDirection(
      degrees: 295,
      latitude: -6.2088,
      longitude: 106.8456,
      locationLabel: 'Jakarta, Indonesia',
      locationSource: LocationSource.device,
    );
  }
}

class FakeAuthApiService extends AuthApiService {
  FakeAuthApiService({bool parentHasPin = true}) {
    parent = parent.copyWith(hasPin: parentHasPin);
  }

  ParentAccount parent = const ParentAccount(
    id: 'parent-test',
    name: 'Parent Test',
    email: 'parent@iqroku.test',
    hasPin: true,
  );
  final children = <ChildProfile>[];
  final childPins = <String, String>{};
  final progress = <String, List<RemoteIqroProgress>>{};
  final attempts = <String, List<LearningAttempt>>{};

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    return AuthResult(parent: parent, sessionToken: 'session-test');
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return AuthResult(parent: parent, sessionToken: 'session-test');
  }

  @override
  Future<List<ChildProfile>> loadChildren(String parentId) async {
    return List.of(children);
  }

  @override
  Future<List<RemoteIqroProgress>> loadProgress(String childId) async {
    return progress[childId] ?? const [];
  }

  @override
  Future<List<LearningAttempt>> loadAttempts(String childId) async {
    return attempts[childId] ?? const [];
  }

  @override
  Future<ChildProfile> createChild({
    required String parentId,
    required String name,
    required int age,
    required String avatarAsset,
  }) async {
    final child = ChildProfile(
      id: 'child-${children.length + 1}',
      name: name,
      age: age,
      currentLesson: 'Iqro 1 - Halaman 1',
      progress: 0,
      avatarAsset: avatarAsset,
    );
    children.add(child);
    return child;
  }

  @override
  Future<void> setChildPin(String childId, String pin) async {
    childPins[childId] = pin;
  }

  @override
  Future<void> setParentPin(String pin) async {
    parent = parent.copyWith(hasPin: true);
  }

  @override
  Future<bool> verifyParentPin(String pin) async {
    return parent.hasPin;
  }

  @override
  Future<ChildAccount> childLogin(String childId, String pin) async {
    if (childPins[childId] != pin) {
      throw const AuthApiException(401, 'invalid_pin');
    }
    final child = children.firstWhere((child) => child.id == childId);
    return ChildAccount(
      id: child.id,
      name: child.name,
      age: child.age,
      avatarAsset: child.avatarAsset,
    );
  }
}

class FakeDailyPrayerApiService extends DailyPrayerApiService {
  const FakeDailyPrayerApiService();

  @override
  Future<List<DailyPrayer>> fetchDailyPrayers() async {
    return const [
      DailyPrayer(
        id: 'doa-belajar',
        title: 'Doa Sebelum Belajar',
        category: 'Belajar',
        arabic: 'رَبِّ زِدْنِي عِلْمًا',
        latin: 'Rabbi zidnii ilman',
        meaning: 'Ya Rabb, tambahkanlah ilmuku.',
        sortOrder: 10,
      ),
    ];
  }
}

class FakeVoiceRecordingService implements VoiceRecordingService {
  String? _activePath;

  @override
  Future<String> start({
    required String childId,
    required int bookId,
    required int pageNumber,
  }) async {
    _activePath = '/tmp/${childId}_j${bookId}_p$pageNumber.m4a';
    return _activePath!;
  }

  @override
  Future<String?> stop() async {
    final path = _activePath;
    _activePath = null;
    return path;
  }

  @override
  Future<void> cancel() async {
    _activePath = null;
  }

  @override
  void dispose() {}
}

class FakeAudioPlaybackService implements AudioPlaybackService {
  final StreamController<void> _completeController =
      StreamController<void>.broadcast();
  String? playingPath;
  Map<String, String>? playingHeaders;

  @override
  Stream<void> get onComplete => _completeController.stream;

  @override
  Future<void> play(String path, {Map<String, String>? headers}) async {
    playingPath = path;
    playingHeaders = headers;
  }

  @override
  Future<void> stop() async {
    playingPath = null;
    playingHeaders = null;
  }

  @override
  void dispose() {
    _completeController.close();
  }

  void complete() {
    _completeController.add(null);
  }
}
