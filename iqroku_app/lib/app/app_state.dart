import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/assets/app_assets.dart';
import '../data/assessment_service.dart';
import '../data/audio_playback_service.dart';
import '../data/auth_api_service.dart';
import '../data/daily_prayer_api_service.dart';
import '../data/dummy_iqroku_repository.dart';
import '../data/islamic_activity_service.dart';
import '../data/iqro_content_repository.dart';
import '../data/local_app_storage.dart';
import '../data/mimo_assessment_service.dart';
import '../data/quran_api_service.dart';
import '../data/voice_recording_service.dart';
import '../models/iqro_models.dart';
import '../models/learning_status.dart';
import '../models/prayer_models.dart';
import '../models/profile_models.dart';
import '../models/quran_models.dart';


String _generateUuid() {
  final random = Random.secure();
  final values = List<int>.generate(16, (_) => random.nextInt(256));
  // Version 4 UUID
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return "${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20)}";
}

class IqrokuState extends ChangeNotifier {
  IqrokuState({
    required this.repository,
    LocalAppStorage? storage,
    this.iqroContentRepository = const IqroContentRepository(),
    this.assessmentService = const MockAssessmentService(),
    AuthApiService? authService,
    this.dailyPrayerApiService = const DailyPrayerApiService(),
    this.quranApiService = const QuranApiService(),
    this.islamicActivityService = const IslamicActivityService(),
    VoiceRecordingService? voiceRecordingService,
    AudioPlaybackService? audioPlaybackService,
  }) : storage = storage ?? LocalAppStorage(),
       authService = authService ?? AuthApiService(),
       childProfiles = List.of(repository.children.take(freeChildLimit)),
       learningNotes = List.of(repository.learningNotes),
       learningAttempts = <LearningAttempt>[],
       voiceRecordingService =
           voiceRecordingService ?? LocalVoiceRecordingService(),
       audioPlaybackService =
           audioPlaybackService ?? LocalAudioPlaybackService() {
    if (childProfiles.isNotEmpty && selectedChildId.isEmpty) {
      selectedChildId = childProfiles.first.id;
    }
    _playbackCompleteSubscription = this.audioPlaybackService.onComplete.listen(
      (_) {
        playingAttemptId = null;
        playingQuranAudioUrl = null;
        notifyListeners();
      },
    );
  }

  static const freeChildLimit = 1;
  static const freeIqroBookLimit = 1;
  static const freeIqroPageLimit = 10;
  static const quranMemorizationBookId = 99;
  static const subscriptionPriceLabel = 'Rp49.000/bulan';

  final DummyIqrokuRepository repository;
  final LocalAppStorage storage;
  final IqroContentRepository iqroContentRepository;
  final AssessmentService assessmentService;
  final AuthApiService authService;
  final DailyPrayerApiService dailyPrayerApiService;
  final QuranApiService quranApiService;
  final IslamicActivityService islamicActivityService;
  final VoiceRecordingService voiceRecordingService;
  final AudioPlaybackService audioPlaybackService;
  final List<ChildProfile> childProfiles;
  final List<LearningNote> learningNotes;
  final List<LearningAttempt> learningAttempts;
  final Map<String, Map<int, Map<int, LearningStatus>>> _iqroProgress = {};
  Future<void> _saveQueue = Future.value();
  IqroContent? _iqroContent;
  List<Surah>? _quranSurahs;
  SurahDetail? _selectedSurahDetail;
  PrayerSchedule? _prayerSchedule;
  QiblaDirection? _qiblaDirection;
  List<DailyPrayer>? _dailyPrayers;
  Timer? _voiceTimer;
  StreamSubscription<void>? _playbackCompleteSubscription;
  DateTime? _voiceStartedAt;
  String? _activeVoicePath;

  AppLaunchStage launchStage = AppLaunchStage.onboarding;
  int selectedTab = 0;

  AssessmentService get _activeAssessmentService {
    if (authToken != null && authToken!.isNotEmpty) {
      return MiMoAssessmentService(authService: authService);
    }
    return assessmentService;
  }
  int selectedIqroBook = 1;
  int selectedIqroPage = 8;
  int selectedSurahIndex = 3;
  QuranView quranView = QuranView.list;
  ActivityView activityView = ActivityView.schedule;
  bool memorizationMode = false;
  bool murottalMode = false;
  int? quranMemorizationRecordingSurahId;
  String selectedChildId = '';
  bool familyPlusActive = false;
  bool childSetupCompleted = false;
  bool iqroContentLoading = false;
  bool quranLoading = false;
  bool surahDetailLoading = false;
  bool islamicActivityLoading = false;
  bool dailyPrayersLoading = false;
  bool isVoiceRecording = false;
  bool authLoading = false;
  int voiceRecordingSeconds = 0;
  DateTime? subscriptionActivatedAt;
  ParentAccount? parentAccount;
  String? authToken;
  String? authError;
  String? iqroContentError;
  String? quranError;
  String? islamicActivityError;
  String? dailyPrayersError;
  String? voiceRecordingError;
  String? playingAttemptId;
  String? playingQuranAudioUrl;
  String? playbackError;
  String? subscriptionNotice;

  ChildProfile get selectedChild {
    if (childProfiles.isEmpty) {
      return const ChildProfile(
        id: '',
        name: 'Anak',
        age: 7,
        currentLesson: 'Iqro 1 - Halaman 1',
        progress: 0,
        avatarAsset: 'assets/brand/male-avatar.png',
      );
    }
    if (selectedChildId.isEmpty) {
      return childProfiles.first;
    }
    return childProfiles.firstWhere(
      (child) => child.id == selectedChildId,
      orElse: () => childProfiles.first,
    );
  }

  int get childLimit => familyPlusActive ? 5 : freeChildLimit;
  bool get canAddFreeChild => childProfiles.length < childLimit;
  String get planLabel => familyPlusActive ? 'IqroKu Plus' : 'Free';
  String get childQuotaLabel => '${childProfiles.length}/$childLimit anak';
  bool get subscriptionActive => familyPlusActive;
  String get subscriptionRenewalLabel {
    final activatedAt = subscriptionActivatedAt;
    if (!familyPlusActive || activatedAt == null) {
      return 'Belum aktif';
    }
    return _dateLabel(activatedAt.add(const Duration(days: 30)));
  }

  List<IqroBook> get iqroBooks {
    final content = _iqroContent;
    if (content == null || content.books.isEmpty) {
      return repository.iqroBooks;
    }

    return content.books
        .map((book) {
          return book.toBook(completedPages: _completedPagesForBook(book.id));
        })
        .toList(growable: false);
  }

  IqroBook get selectedIqroBookData {
    return iqroBooks.firstWhere(
      (book) => book.id == selectedIqroBook,
      orElse: () => iqroBooks.first,
    );
  }

  IqroMaterialBook? get selectedIqroMaterialBook {
    return _materialBookFor(selectedIqroBook);
  }

  IqroMaterialPage? get selectedIqroMaterialPage {
    final book = selectedIqroMaterialBook;
    if (book == null) {
      return null;
    }

    return book.pages.firstWhere(
      (page) => page.pageNumber == selectedIqroPage,
      orElse: () => book.pages.first,
    );
  }

  LearningAttempt? get selectedPageLatestAttempt {
    for (final attempt in learningAttempts) {
      if (attempt.childId == selectedChildId &&
          attempt.bookId == selectedIqroBook &&
          attempt.pageNumber == selectedIqroPage) {
        return attempt;
      }
    }
    return null;
  }

  List<LearningAttempt> get selectedChildLearningAttempts {
    return learningAttempts
        .where((attempt) => attempt.childId == selectedChildId)
        .take(8)
        .toList(growable: false);
  }

  LearningStatus get selectedIqroStatus {
    return statusForIqroPage(selectedIqroBook, selectedIqroPage);
  }

  List<IqroPage> get selectedIqroPages {
    return iqroPagesForBook(selectedIqroBook);
  }

  List<IqroPage> iqroPagesForBook(int bookId) {
    final pageStatuses = _progressForBook(selectedChildId, bookId);
    final totalPages = _totalPagesForBook(bookId);
    return List.generate(totalPages, (index) {
      final page = index + 1;
      return IqroPage(
        bookId: bookId,
        pageNumber: page,
        status: pageStatuses[page] ?? LearningStatus.notStarted,
      );
    });
  }

  bool isIqroPageLocked(int bookId, int pageNumber) {
    return !_canAccessIqroPage(bookId, pageNumber);
  }

  bool get isSelectedIqroPageLocked {
    return isIqroPageLocked(selectedIqroBook, selectedIqroPage);
  }

  int get selectedIqroCompletedPages {
    return _completedPagesForBook(selectedIqroBook);
  }

  int get selectedIqroTotalPages => selectedIqroBookData.totalPages;

  List<Surah> get quranSurahs => _quranSurahs ?? repository.surahs;

  Surah get selectedSurahData {
    final surahs = quranSurahs.isEmpty ? repository.surahs : quranSurahs;
    final index = selectedSurahIndex.clamp(0, surahs.length - 1);
    return surahs[index];
  }

  SurahDetail? get selectedSurahDetail => _selectedSurahDetail;

  AyahPreview get selectedQuranPreview {
    final detail = _selectedSurahDetail;
    if (detail == null || detail.ayahs.isEmpty) {
      return repository.readerPreview;
    }
    final previewAyahs = detail.ayahs.take(3).toList(growable: false);
    return AyahPreview(
      arabic: previewAyahs.map((ayah) => ayah.arabic).join('\n'),
      translation: previewAyahs
          .map((ayah) => '${ayah.number}. ${ayah.translation}')
          .join('\n'),
    );
  }

  List<PrayerTime> get prayerTimes {
    return _prayerSchedule?.times ?? repository.prayerTimes;
  }

  PrayerTime get activePrayerTime {
    return prayerTimes.firstWhere(
      (time) => time.active,
      orElse: () => prayerTimes.first,
    );
  }

  String get prayerLocationLabel {
    return _qiblaDirection?.locationLabel ??
        _prayerSchedule?.locationLabel ??
        'Jayapura, Papua (fallback)';
  }

  String get prayerDateLabel {
    return _prayerSchedule?.dateLabel ?? _todayLabel();
  }

  List<DailyPrayer> get dailyPrayers => _dailyPrayers ?? _fallbackDailyPrayers;

  double get qiblaDegrees => _qiblaDirection?.degrees ?? 295;

  double get activityLatitude {
    return _qiblaDirection?.latitude ?? _prayerSchedule?.latitude ?? -2.5489;
  }

  double get activityLongitude {
    return _qiblaDirection?.longitude ?? _prayerSchedule?.longitude ?? 140.7197;
  }

  LocationSource get activityLocationSource {
    return _qiblaDirection?.locationSource ??
        _prayerSchedule?.locationSource ??
        LocationSource.fallback;
  }

  bool get quranAudioPlaying => playingQuranAudioUrl != null;

  LearningAttempt? get selectedSurahLatestMemorizationAttempt {
    for (final attempt in learningAttempts) {
      if (attempt.childId == selectedChildId &&
          attempt.bookId == quranMemorizationBookId &&
          attempt.pageNumber == selectedSurahData.id) {
        return attempt;
      }
    }
    return null;
  }

  QuranMode get quranMode {
    if (murottalMode) {
      return QuranMode.murottal;
    }
    if (memorizationMode) {
      return QuranMode.memorization;
    }
    return QuranMode.reading;
  }

  bool get isQuranMemorizationRecording {
    return isVoiceRecording &&
        quranMemorizationRecordingSurahId == selectedSurahData.id;
  }

  int completedPagesForBook(int bookId) {
    return _completedPagesForBook(bookId);
  }

  int learningPagesForBook(int bookId) {
    return _countPagesForBook(bookId, LearningStatus.learning);
  }

  int reviewPagesForBook(int bookId) {
    return _countPagesForBook(bookId, LearningStatus.review);
  }

  LearningAttempt? latestAttemptForIqroPage(int bookId, int pageNumber) {
    for (final attempt in learningAttempts) {
      if (attempt.childId == selectedChildId &&
          attempt.bookId == bookId &&
          attempt.pageNumber == pageNumber) {
        return attempt;
      }
    }
    return null;
  }

  void openIqroPage(int bookId, int pageNumber) {
    if (!_canAccessIqroPage(bookId, pageNumber)) {
      _showSubscriptionNotice();
      return;
    }
    selectedIqroBook = bookId;
    selectedIqroPage = pageNumber.clamp(1, _totalPagesForBook(bookId));
    selectedTab = 1;
    _persist();
    notifyListeners();
  }

  LearningStatus statusForIqroPage(int bookId, int page) {
    return _progressForBook(selectedChildId, bookId)[page] ??
        LearningStatus.notStarted;
  }

  Future<void> loadIqroContent() async {
    if (iqroContentLoading || _iqroContent != null) {
      return;
    }

    iqroContentLoading = true;
    iqroContentError = null;
    notifyListeners();

    try {
      final content = await iqroContentRepository.load();
      _iqroContent = content;
      if (_materialBookFor(selectedIqroBook) == null &&
          content.books.isNotEmpty) {
        selectedIqroBook = content.books.first.id;
      }
      selectedIqroPage = selectedIqroPage.clamp(1, selectedIqroTotalPages);
      _ensureSelectedIqroAccess();
      iqroContentError = null;
    } catch (error) {
      iqroContentError = 'Materi Iqro belum bisa dimuat.';
      debugPrint('Iqro content load failed: $error');
    } finally {
      if (_iqroContent != null && selectedIqroMaterialPage != null) {
        iqroContentError = null;
      }
      iqroContentLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadQuranContent() async {
    if (quranLoading || _quranSurahs != null) {
      return;
    }

    quranLoading = true;
    quranError = null;
    notifyListeners();

    try {
      _quranSurahs = await quranApiService.fetchSurahs();
      if (quranSurahs.isNotEmpty) {
        selectedSurahIndex = selectedSurahIndex.clamp(
          0,
          quranSurahs.length - 1,
        );
      }
      await _loadSelectedSurahDetail();
    } catch (error) {
      quranError =
          'Al-Quran online belum bisa dimuat. Cek koneksi internet lalu coba lagi.';
      debugPrint('Quran content load failed: $error');
    } finally {
      quranLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadIslamicActivity() async {
    if (islamicActivityLoading) {
      return;
    }

    islamicActivityLoading = true;
    islamicActivityError = null;
    notifyListeners();

    try {
      final results = await Future.wait<Object>([
        islamicActivityService.fetchPrayerSchedule(),
        islamicActivityService.fetchQiblaDirection(),
      ]);
      _prayerSchedule = results[0] as PrayerSchedule;
      _qiblaDirection = results[1] as QiblaDirection;
    } catch (error) {
      islamicActivityError =
          'Jadwal sholat dan kiblat online belum bisa dimuat. Cek koneksi internet lalu coba lagi.';
      debugPrint('Islamic activity load failed: $error');
    } finally {
      islamicActivityLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDailyPrayers({bool forceRefresh = false}) async {
    if (dailyPrayersLoading || (_dailyPrayers != null && !forceRefresh)) {
      return;
    }

    dailyPrayersLoading = true;
    dailyPrayersError = null;
    notifyListeners();

    try {
      final prayers = await dailyPrayerApiService.fetchDailyPrayers();
      if (prayers.isNotEmpty) {
        _dailyPrayers = prayers;
      }
      dailyPrayersError = null;
    } catch (error) {
      dailyPrayersError =
          'Doa terbaru belum bisa dimuat. Menampilkan doa bawaan aplikasi.';
      debugPrint('Daily prayers load failed: $error');
    } finally {
      dailyPrayersLoading = false;
      notifyListeners();
    }
  }

  Future<void> restoreFromDisk() async {
    StoredIqrokuState? stored;
    try {
      stored = await storage.load();
    } catch (error) {
      debugPrint('Failed to restore state from disk: $error');
      // Corrupted data — start fresh
      return;
    }

    if (stored == null) {
      return;
    }

    childProfiles
      ..clear()
      ..addAll(stored.childProfiles);
    learningNotes
      ..clear()
      ..addAll(stored.learningNotes);
    learningAttempts
      ..clear()
      ..addAll(stored.learningAttempts);
    _iqroProgress
      ..clear()
      ..addAll(stored.iqroProgress);
    selectedChildId = childProfiles.isEmpty
        ? ''
        : stored.selectedChildId.isEmpty
        ? childProfiles.first.id
        : stored.selectedChildId;
    familyPlusActive = stored.familyPlusActive;
    subscriptionActivatedAt = stored.subscriptionActivatedAt;
    parentAccount = stored.parentAccount;
    authToken = stored.authToken;
    authService.authToken = stored.authToken;
    childSetupCompleted = stored.childSetupCompleted;
    selectedIqroBook = stored.selectedIqroBook;
    selectedIqroPage = stored.selectedIqroPage;
    if (childProfiles.isNotEmpty) {
      _ensureSelectedIqroAccess();
    }

    if (authToken != null && childSetupCompleted && childProfiles.isNotEmpty) {
      launchStage = AppLaunchStage.authenticated;
    } else if (authToken != null) {
      launchStage = AppLaunchStage.setupChild;
    }

    notifyListeners();
  }

  void completeOnboarding() {
    launchStage = AppLaunchStage.welcome;
    notifyListeners();
  }

  void continueFromWelcome() {
    launchStage = AppLaunchStage.login;
    notifyListeners();
  }

  void goToLogin() {
    launchStage = AppLaunchStage.login;
    notifyListeners();
  }

  void goToRegister() {
    launchStage = AppLaunchStage.register;
    notifyListeners();
  }

  void loginAsDemoUser() {
    launchStage = AppLaunchStage.setupChild;
    selectedTab = 0;
    notifyListeners();
  }

  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    if (name.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      authError = 'Nama, email, dan password wajib diisi.';
      notifyListeners();
      return;
    }

    authLoading = true;
    authError = null;
    notifyListeners();

    try {
      final result = await authService.register(
        name: name.trim(),
        email: email.trim(),
        password: password,
      );
      await _finishAuth(result);
    } catch (error) {
      authError = _authErrorMessage(error);
    } finally {
      authLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      authError = 'Email dan password wajib diisi.';
      notifyListeners();
      return;
    }

    authLoading = true;
    authError = null;
    notifyListeners();

    try {
      final result = await authService.login(
        email: email.trim(),
        password: password,
      );
      await _finishAuth(result);
    } catch (error) {
      authError = _authErrorMessage(error);
    } finally {
      authLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithGoogle({
    required String idToken,
    required String email,
    required String name,
    required String googleId,
  }) async {
    authLoading = true;
    authError = null;
    notifyListeners();

    try {
      final result = await authService.loginWithGoogle(
        idToken: idToken,
        email: email,
        name: name,
        googleId: googleId,
      );
      await _finishAuth(result);
    } catch (error) {
      authError = _authErrorMessage(error);
    } finally {
      authLoading = false;
      notifyListeners();
    }
  }

  Future<void> completeSetup({
    String? name,
    int? age,
    String avatarAsset = AppAssets.avatarMale,
  }) async {
    final cleanName = name?.trim();
    if (cleanName == null || cleanName.isEmpty) {
      authError = 'Isi nama anak dulu untuk mulai belajar.';
      notifyListeners();
      return;
    }

    authLoading = true;
    authError = null;
    notifyListeners();

    try {
      final parent = parentAccount;
      final child = parent == null
          ? ChildProfile(
              id: _localChildId(cleanName),
              name: cleanName,
              age: age ?? 7,
              currentLesson: 'Iqro 1 - Halaman 1',
              progress: 0,
              avatarAsset: avatarAsset,
            )
          : await authService.createChild(
              parentId: parent.id,
              name: cleanName,
              age: age ?? 7,
              avatarAsset: avatarAsset,
            );

      if (childProfiles.isEmpty) {
        childProfiles.add(child);
      } else if (!childSetupCompleted) {
        childProfiles[0] = child;
      } else if (childProfiles.length < childLimit) {
        childProfiles.add(child);
      } else {
        launchStage = AppLaunchStage.authenticated;
        return;
      }
      selectedChildId = child.id;
      _seedIqroProgressForChild(child.id, currentPage: 1);
      childSetupCompleted = true;
      launchStage = AppLaunchStage.authenticated;
      _persist();
    } catch (error) {
      authError = _authErrorMessage(error);
    } finally {
      authLoading = false;
      notifyListeners();
    }
  }

  void startAddChild() {
    if (!canAddFreeChild) {
      return;
    }

    launchStage = AppLaunchStage.setupChild;
    notifyListeners();
  }

  void activateFamilyPlus() {
    familyPlusActive = true;
    subscriptionActivatedAt ??= DateTime.now();
    subscriptionNotice = null;
    _persist();
    notifyListeners();
    final parent = parentAccount;
    if (parent != null) {
      unawaited(_syncSubscription(parent.id));
    }
  }

  void clearSubscriptionNotice() {
    subscriptionNotice = null;
    notifyListeners();
  }

  void resetSelectedChildProgress() {
    _iqroProgress.remove(selectedChildId);
    _seedIqroProgressForChild(selectedChildId, currentPage: 1);
    final childIndex = childProfiles.indexWhere(
      (child) => child.id == selectedChildId,
    );
    if (childIndex != -1) {
      childProfiles[childIndex] = childProfiles[childIndex].copyWith(
        currentLesson: 'Iqro 1 - Halaman 1',
        progress: 0,
      );
    }
    selectedIqroBook = 1;
    selectedIqroPage = 1;
    learningNotes.removeWhere((note) => note.title.startsWith('Iqro '));
    learningAttempts.removeWhere(
      (attempt) => attempt.childId == selectedChildId,
    );
    _persist();
    notifyListeners();
  }

  void logout() {
    launchStage = AppLaunchStage.welcome;
    selectedTab = 0;
    parentAccount = null;
    authToken = null;
    authService.authToken = null;
    authError = null;
    childProfiles.clear();
    learningNotes.clear();
    learningAttempts.clear();
    _iqroProgress.clear();
    familyPlusActive = false;
    subscriptionActivatedAt = null;
    childSetupCompleted = false;
    selectedChildId = '';
    _persist();
    notifyListeners();
  }

  void backToWelcome() {
    launchStage = AppLaunchStage.welcome;
    notifyListeners();
  }

  void selectTab(int index) {
    selectedTab = index;
    if (index == 2) {
      quranView = QuranView.list;
      memorizationMode = false;
      murottalMode = false;
    }
    if (index == 3) {
      activityView = ActivityView.schedule;
    }
    notifyListeners();
  }

  void openPrayerSchedule() {
    selectedTab = 3;
    activityView = ActivityView.schedule;
    notifyListeners();
  }

  void openQiblaCompass() {
    selectedTab = 3;
    activityView = ActivityView.qibla;
    notifyListeners();
  }

  void openDailyPrayers() {
    selectedTab = 5;
    notifyListeners();
    unawaited(loadDailyPrayers(forceRefresh: true));
  }

  void selectIqroBook(int bookId) {
    if (!_canAccessIqroBook(bookId)) {
      _showSubscriptionNotice();
      return;
    }
    unawaited(cancelVoicePractice());
    selectedIqroBook = bookId;
    selectedIqroPage = _firstActivePageForBook(bookId);
    _persist();
    notifyListeners();
  }

  void selectIqroPage(int page) {
    if (!_canAccessIqroPage(selectedIqroBook, page)) {
      _showSubscriptionNotice();
      return;
    }
    unawaited(cancelVoicePractice());
    selectedIqroPage = page.clamp(1, selectedIqroTotalPages);
    _persist();
    notifyListeners();
  }

  void setIqroStatus(LearningStatus status) {
    updateIqroPageStatus(status);
  }

  void updateIqroPageStatus(LearningStatus status) {
    if (!_canAccessIqroPage(selectedIqroBook, selectedIqroPage)) {
      _showSubscriptionNotice();
      return;
    }
    _progressForBook(selectedChildId, selectedIqroBook)[selectedIqroPage] =
        status;
    if (status == LearningStatus.fluent || status == LearningStatus.review) {
      _prependLearningNote(status);
    }
    _syncSelectedChildProgress();
    _persist();
    _syncProgressToBackend(
      childId: selectedChildId,
      bookId: selectedIqroBook,
      pageNumber: selectedIqroPage,
      status: status,
    );
    notifyListeners();
  }

  Future<void> startVoicePractice() async {
    if (isVoiceRecording) {
      return;
    }

    if (!_canAccessIqroPage(selectedIqroBook, selectedIqroPage)) {
      _showSubscriptionNotice();
      return;
    }

    await audioPlaybackService.stop();
    playingAttemptId = null;
    playingQuranAudioUrl = null;
    playbackError = null;
    voiceRecordingError = null;
    notifyListeners();

    try {
      _activeVoicePath = await voiceRecordingService.start(
        childId: selectedChildId,
        bookId: selectedIqroBook,
        pageNumber: selectedIqroPage,
      );
      _progressForBook(selectedChildId, selectedIqroBook)[selectedIqroPage] =
          LearningStatus.learning;
      isVoiceRecording = true;
      voiceRecordingSeconds = 0;
      _voiceStartedAt = DateTime.now();
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        voiceRecordingSeconds += 1;
        notifyListeners();
      });
    } on VoiceRecordingPermissionDenied {
      voiceRecordingError =
          'Izin microphone belum aktif. Aktifkan izin mic untuk merekam bacaan.';
    } catch (_) {
      voiceRecordingError =
          'Rekaman belum bisa dimulai. Coba ulang sebentar lagi.';
    }
    notifyListeners();
  }

  Future<void> finishVoicePractice() async {
    if (!isVoiceRecording) {
      return;
    }

    final duration = _effectiveVoiceDuration();
    _cancelVoiceTimer();
    isVoiceRecording = false;
    voiceRecordingSeconds = 0;
    _voiceStartedAt = null;
    final audioPath = await voiceRecordingService.stop() ?? _activeVoicePath;
    _activeVoicePath = null;

    final attempt = LearningAttempt(
      id: _generateUuid(),
      childId: selectedChildId,
      bookId: selectedIqroBook,
      pageNumber: selectedIqroPage,
      date: _todayLabel(),
      durationSeconds: duration,
      status: LearningStatus.learning,
      assessmentStatus: ReadingAssessmentStatus.recorded,
      audioPath: audioPath,
      note: audioPath == null
          ? 'Percobaan baca suara tersimpan tanpa file audio.'
          : 'Rekaman tersimpan. Menunggu penilaian bacaan.',
    );
    learningAttempts.insert(0, attempt);

    if (learningAttempts.length > 50) {
      learningAttempts.removeRange(50, learningAttempts.length);
    }

    _persist();
    notifyListeners();
    unawaited(_syncLearningAttempt(attempt));
    unawaited(_runAssessment(attempt.id));
  }

  Future<void> cancelVoicePractice() async {
    if (!isVoiceRecording && voiceRecordingSeconds == 0) {
      return;
    }

    _cancelVoiceTimer();
    await voiceRecordingService.cancel();
    isVoiceRecording = false;
    voiceRecordingSeconds = 0;
    _voiceStartedAt = null;
    _activeVoicePath = null;
    quranMemorizationRecordingSurahId = null;
    notifyListeners();
  }

  Future<void> toggleAttemptPlayback(LearningAttempt attempt) async {
    final audioPath = attempt.audioPath;
    if (audioPath == null || audioPath.isEmpty) {
      playbackError = 'File rekaman belum tersedia untuk percobaan ini.';
      notifyListeners();
      return;
    }

    if (playingAttemptId == attempt.id) {
      await audioPlaybackService.stop();
      playingAttemptId = null;
      playbackError = null;
      notifyListeners();
      return;
    }

    try {
      await audioPlaybackService.stop();
      playingAttemptId = attempt.id;
      playingQuranAudioUrl = null;
      playbackError = null;
      notifyListeners();
      await audioPlaybackService.play(audioPath);
    } catch (_) {
      playingAttemptId = null;
      playbackError = 'Rekaman belum bisa diputar. Coba rekam ulang.';
      notifyListeners();
    }
  }

  Future<void> toggleSelectedSurahMurottal() async {
    var detail = _selectedSurahDetail;
    if (detail == null || detail.surah.id != selectedSurahData.id) {
      await _loadSelectedSurahDetail();
      detail = _selectedSurahDetail;
    }

    final audioUrl = detail?.audioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      playbackError = 'Audio murottal surat ini belum tersedia.';
      notifyListeners();
      return;
    }

    if (playingQuranAudioUrl == audioUrl) {
      await audioPlaybackService.stop();
      playingQuranAudioUrl = null;
      playbackError = null;
      notifyListeners();
      return;
    }

    try {
      await audioPlaybackService.stop();
      playingAttemptId = null;
      playingQuranAudioUrl = audioUrl;
      playbackError = null;
      notifyListeners();
      await audioPlaybackService.play(audioUrl);
    } catch (_) {
      playingQuranAudioUrl = null;
      playbackError = 'Murottal belum bisa diputar. Cek koneksi internet.';
      notifyListeners();
    }
  }

  Future<void> startQuranMemorizationPractice() async {
    if (isVoiceRecording) {
      return;
    }

    await audioPlaybackService.stop();
    playingAttemptId = null;
    playingQuranAudioUrl = null;
    playbackError = null;
    voiceRecordingError = null;
    notifyListeners();

    try {
      _activeVoicePath = await voiceRecordingService.start(
        childId: selectedChildId,
        bookId: quranMemorizationBookId,
        pageNumber: selectedSurahData.id,
      );
      isVoiceRecording = true;
      quranMemorizationRecordingSurahId = selectedSurahData.id;
      voiceRecordingSeconds = 0;
      _voiceStartedAt = DateTime.now();
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        voiceRecordingSeconds += 1;
        notifyListeners();
      });
    } on VoiceRecordingPermissionDenied {
      voiceRecordingError =
          'Izin microphone belum aktif. Aktifkan izin mic untuk rekam hafalan.';
    } catch (_) {
      voiceRecordingError =
          'Rekaman hafalan belum bisa dimulai. Coba ulang sebentar lagi.';
    }
    notifyListeners();
  }

  Future<void> finishQuranMemorizationPractice() async {
    if (!isQuranMemorizationRecording) {
      return;
    }

    final duration = _effectiveVoiceDuration();
    _cancelVoiceTimer();
    isVoiceRecording = false;
    voiceRecordingSeconds = 0;
    _voiceStartedAt = null;
    final audioPath = await voiceRecordingService.stop() ?? _activeVoicePath;
    _activeVoicePath = null;
    quranMemorizationRecordingSurahId = null;

    final attempt = LearningAttempt(
      id: _generateUuid(),
      childId: selectedChildId,
      bookId: quranMemorizationBookId,
      pageNumber: selectedSurahData.id,
      date: _todayLabel(),
      durationSeconds: duration,
      status: LearningStatus.learning,
      assessmentStatus: ReadingAssessmentStatus.recorded,
      audioPath: audioPath,
      note:
          'Rekaman hafalan ${selectedSurahData.name} tersimpan. Penilaian AI hafalan akan disambungkan di tahap berikutnya.',
    );
    learningAttempts.insert(0, attempt);

    if (learningAttempts.length > 50) {
      learningAttempts.removeRange(50, learningAttempts.length);
    }

    _persist();
    notifyListeners();
    unawaited(_syncLearningAttempt(attempt));
  }

  void goToNextIqroPage() {
    if (selectedIqroPage >= selectedIqroTotalPages) {
      return;
    }

    final nextPage = selectedIqroPage + 1;
    if (!_canAccessIqroPage(selectedIqroBook, nextPage)) {
      _showSubscriptionNotice();
      return;
    }

    selectedIqroPage = nextPage;
    final statuses = _progressForBook(selectedChildId, selectedIqroBook);
    statuses.putIfAbsent(selectedIqroPage, () => LearningStatus.learning);
    _syncSelectedChildProgress();
    _persist();
    _syncProgressToBackend(
      childId: selectedChildId,
      bookId: selectedIqroBook,
      pageNumber: selectedIqroPage,
      status: LearningStatus.learning,
    );
    notifyListeners();
  }

  Future<void> selectSurah(int index) async {
    selectedSurahIndex = index;
    notifyListeners();
    await _loadSelectedSurahDetail();
  }

  Future<void> openQuranReader(int index) async {
    await selectSurah(index);
    selectedTab = 2;
    quranView = QuranView.reader;
    memorizationMode = false;
    murottalMode = false;
    notifyListeners();
  }

  Future<void> openQuranMemorization(int index) async {
    await selectSurah(index);
    selectedTab = 2;
    quranView = QuranView.memorization;
    memorizationMode = true;
    murottalMode = false;
    notifyListeners();
  }

  void openMurottal() {
    selectedTab = 2;
    quranView = QuranView.murottal;
    memorizationMode = false;
    murottalMode = true;
    notifyListeners();
  }

  void backToQuranList() {
    quranView = QuranView.list;
    memorizationMode = false;
    murottalMode = false;
    notifyListeners();
  }

  void goHome() {
    selectedTab = 0;
    quranView = QuranView.list;
    memorizationMode = false;
    murottalMode = false;
    notifyListeners();
  }

  void setMemorizationMode(bool value) {
    memorizationMode = value;
    if (value) {
      murottalMode = false;
    }
    notifyListeners();
  }

  void setQuranMode(QuranMode mode) {
    memorizationMode = mode == QuranMode.memorization;
    murottalMode = mode == QuranMode.murottal;
    quranView = mode == QuranMode.murottal
        ? QuranView.murottal
        : QuranView.list;
    notifyListeners();
  }

  void selectChild(String childId) {
    selectedChildId = childId;
    selectedIqroPage = _firstActivePageForBook(selectedIqroBook);
    _ensureSelectedIqroAccess();
    _persist();
    notifyListeners();
  }

  Map<int, LearningStatus> _progressForBook(String childId, int bookId) {
    _seedIqroProgressForChild(childId);
    return _iqroProgress
        .putIfAbsent(childId, () => {})
        .putIfAbsent(bookId, () => <int, LearningStatus>{});
  }

  void _seedIqroProgressForChild(String childId, {int? currentPage}) {
    if (_iqroProgress.containsKey(childId)) {
      return;
    }

    final child = childProfiles.firstWhere(
      (profile) => profile.id == childId,
      orElse: () => childProfiles.first,
    );
    final lessonPage = currentPage ?? _lessonPageFrom(child.currentLesson);
    final statuses = <int, LearningStatus>{};
    for (var page = 1; page < lessonPage; page++) {
      statuses[page] = LearningStatus.fluent;
    }
    statuses[lessonPage] = LearningStatus.learning;

    _iqroProgress[childId] = {1: statuses};
  }

  int _lessonPageFrom(String lesson) {
    final match = RegExp(r'Halaman\s+(\d+)').firstMatch(lesson);
    final page = int.tryParse(match?.group(1) ?? '');
    return (page ?? 1).clamp(1, selectedIqroTotalPages);
  }

  int _firstActivePageForBook(int bookId) {
    final statuses = _progressForBook(selectedChildId, bookId);
    final totalPages = _totalPagesForBook(bookId);
    final learningEntry = statuses.entries
        .where((entry) => entry.value == LearningStatus.learning)
        .firstOrNull;
    if (learningEntry != null) {
      return learningEntry.key.clamp(1, totalPages);
    }

    final firstNotFluent = List.generate(
      totalPages,
      (index) => index + 1,
    ).firstWhere((page) => statuses[page] != LearningStatus.fluent);
    return firstNotFluent;
  }

  void _syncSelectedChildProgress() {
    _syncChildProgress(selectedChildId, selectedIqroBook);
  }

  void _syncChildProgress(String childId, int bookId) {
    final childIndex = childProfiles.indexWhere((child) => child.id == childId);
    if (childIndex == -1) {
      return;
    }

    final totalPages = _totalPagesForBook(bookId);
    final completedPages = _completedPagesForBookForChild(childId, bookId);
    final nextPage = _nextLearningPageForChild(childId, bookId, totalPages);
    final progress = (completedPages / totalPages).clamp(0.0, 1.0);

    childProfiles[childIndex] = childProfiles[childIndex].copyWith(
      currentLesson: 'Iqro $bookId - Halaman $nextPage',
      progress: progress,
    );
  }

  int _nextLearningPageForChild(String childId, int bookId, int totalPages) {
    final statuses = _progressForBook(childId, bookId);
    for (var page = 1; page <= totalPages; page++) {
      if (statuses[page] != LearningStatus.fluent) {
        return page;
      }
    }
    return totalPages;
  }

  bool _canAccessIqroBook(int bookId) {
    return familyPlusActive || bookId <= freeIqroBookLimit;
  }

  bool _canAccessIqroPage(int bookId, int pageNumber) {
    return familyPlusActive ||
        (bookId == freeIqroBookLimit && pageNumber <= freeIqroPageLimit);
  }

  void _showSubscriptionNotice() {
    subscriptionNotice =
        'Akun Free hanya sampai Iqro 1 halaman 10. Aktifkan IqroKu Plus $subscriptionPriceLabel untuk lanjut belajar.';
    notifyListeners();
  }

  void _ensureSelectedIqroAccess() {
    if (_canAccessIqroPage(selectedIqroBook, selectedIqroPage)) {
      return;
    }

    selectedIqroBook = freeIqroBookLimit;
    selectedIqroPage = selectedIqroPage.clamp(1, freeIqroPageLimit);
  }

  Future<void> _runAssessment(String attemptId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final assessing = _replaceLearningAttempt(
      attemptId,
      (attempt) => attempt.copyWith(
        assessmentStatus: ReadingAssessmentStatus.assessing,
        note: 'Sedang menilai kelancaran, durasi, dan konsistensi bacaan.',
      ),
    );
    if (assessing == null) {
      return;
    }
    _persist();
    notifyListeners();

    final currentAttempt = learningAttempts.firstWhere(
      (attempt) => attempt.id == attemptId,
      orElse: () => assessing,
    );
    final result = await _activeAssessmentService.assess(
      AssessmentRequest(
        childId: currentAttempt.childId,
        bookId: currentAttempt.bookId,
        pageNumber: currentAttempt.pageNumber,
        targetLines: _targetLinesFor(
          currentAttempt.bookId,
          currentAttempt.pageNumber,
        ),
        audioPath: currentAttempt.audioPath,
        durationSeconds: currentAttempt.durationSeconds,
        attemptId: attemptId,
      ),
    );
    final assessed = _replaceLearningAttempt(attemptId, (attempt) {
      return attempt.copyWith(
        status: result.status,
        assessmentStatus: result.status == LearningStatus.fluent
            ? ReadingAssessmentStatus.fluent
            : ReadingAssessmentStatus.needsReview,
        score: result.score,
        feedback: result.feedback,
        note: result.note,
      );
    });
    if (assessed == null) {
      return;
    }

    _progressForBook(assessed.childId, assessed.bookId)[assessed.pageNumber] =
        assessed.status;
    _syncChildProgress(assessed.childId, assessed.bookId);
    _prependAssessmentLearningNote(assessed);
    _persist();
    _syncProgressToBackend(
      childId: assessed.childId,
      bookId: assessed.bookId,
      pageNumber: assessed.pageNumber,
      status: assessed.status,
    );
    notifyListeners();
  }

  LearningAttempt? _replaceLearningAttempt(
    String attemptId,
    LearningAttempt Function(LearningAttempt attempt) update,
  ) {
    final index = learningAttempts.indexWhere((attempt) {
      return attempt.id == attemptId;
    });
    if (index == -1) {
      return null;
    }

    final updated = update(learningAttempts[index]);
    learningAttempts[index] = updated;
    return updated;
  }

  void _prependAssessmentLearningNote(LearningAttempt attempt) {
    final title = 'Iqro ${attempt.bookId} - Halaman ${attempt.pageNumber}';
    final scoreText = attempt.score == null
        ? ''
        : ' Skor ${attempt.score}/100.';
    learningNotes.removeWhere((note) => note.title == title);
    learningNotes.insert(
      0,
      LearningNote(
        title: title,
        date: _todayLabel(),
        status: attempt.status,
        note: '$scoreText ${attempt.feedback ?? attempt.note ?? ''}'.trim(),
      ),
    );

    if (learningNotes.length > 20) {
      learningNotes.removeRange(20, learningNotes.length);
    }
  }

  void _prependLearningNote(LearningStatus status) {
    final title = 'Iqro $selectedIqroBook - Halaman $selectedIqroPage';
    learningNotes.removeWhere((note) => note.title == title);
    learningNotes.insert(
      0,
      LearningNote(
        title: title,
        date: _todayLabel(),
        status: status,
        note: status == LearningStatus.fluent
            ? '${selectedChild.name} sudah lancar. Lanjutkan ke halaman berikutnya.'
            : '${selectedChild.name} perlu mengulang halaman ini sebelum lanjut.',
      ),
    );

    if (learningNotes.length > 20) {
      learningNotes.removeRange(20, learningNotes.length);
    }
  }

  String _todayLabel() {
    return _dateLabel(DateTime.now());
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _persist() {
    final snapshot = StoredIqrokuState(
      childProfiles: List.of(childProfiles),
      iqroProgress: _copyProgress(),
      learningNotes: List.of(learningNotes),
      learningAttempts: List.of(learningAttempts),
      selectedChildId: selectedChildId,
      familyPlusActive: familyPlusActive,
      childSetupCompleted: childSetupCompleted,
      selectedIqroBook: selectedIqroBook,
      selectedIqroPage: selectedIqroPage,
      parentAccount: parentAccount,
      authToken: authToken,
      subscriptionActivatedAt: subscriptionActivatedAt,
    );
    _saveQueue = _saveQueue.then((_) => storage.save(snapshot));
    unawaited(_saveQueue);
  }

  Future<void> flushLocalStorageForTests() {
    return _saveQueue;
  }

  Map<String, Map<int, Map<int, LearningStatus>>> _copyProgress() {
    return _iqroProgress.map((childId, books) {
      return MapEntry(
        childId,
        books.map(
          (bookId, pages) =>
              MapEntry(bookId, Map<int, LearningStatus>.of(pages)),
        ),
      );
    });
  }

  int _completedPagesForBook(int bookId) {
    return _completedPagesForBookForChild(selectedChildId, bookId);
  }

  int _completedPagesForBookForChild(String childId, int bookId) {
    return _progressForBook(
      childId,
      bookId,
    ).values.where((status) => status == LearningStatus.fluent).length;
  }

  int _countPagesForBook(int bookId, LearningStatus status) {
    return _progressForBook(
      selectedChildId,
      bookId,
    ).values.where((pageStatus) => pageStatus == status).length;
  }

  int _totalPagesForBook(int bookId) {
    return iqroBooks
        .firstWhere((book) => book.id == bookId, orElse: () => iqroBooks.first)
        .totalPages;
  }

  IqroMaterialBook? _materialBookFor(int bookId) {
    final content = _iqroContent;
    if (content == null) {
      return null;
    }

    for (final book in content.books) {
      if (book.id == bookId) {
        return book;
      }
    }
    return null;
  }

  List<List<String>> _targetLinesFor(int bookId, int pageNumber) {
    final book = _materialBookFor(bookId);
    if (book == null) {
      return const [];
    }

    for (final page in book.pages) {
      if (page.pageNumber == pageNumber) {
        return page.lines;
      }
    }
    return const [];
  }

  Future<void> _finishAuth(AuthResult result) async {
    parentAccount = result.parent;
    authToken = result.sessionToken;
    authService.authToken = result.sessionToken;
    authError = null;

    final remoteChildren = await authService.loadChildren(result.parent.id);
    childProfiles
      ..clear()
      ..addAll(remoteChildren);
    _iqroProgress.clear();

    if (childProfiles.isEmpty) {
      selectedChildId = '';
      childSetupCompleted = false;
      launchStage = AppLaunchStage.setupChild;
    } else {
      selectedChildId = childProfiles.first.id;
      for (final child in childProfiles) {
        _seedIqroProgressForChild(child.id, currentPage: 1);
        await _loadRemoteProgressForChild(child.id);
        _syncChildProgress(child.id, 1);
      }
      childSetupCompleted = true;
      launchStage = AppLaunchStage.authenticated;
    }
    selectedTab = 0;
    selectedIqroBook = 1;
    selectedIqroPage = childProfiles.isEmpty ? 1 : _firstActivePageForBook(1);
    _persist();
  }

  Future<void> _loadRemoteProgressForChild(String childId) async {
    try {
      final records = await authService.loadProgress(childId);
      if (records.isEmpty) {
        return;
      }
      final childProgress = _iqroProgress.putIfAbsent(childId, () => {});
      for (final record in records) {
        if (record.childId != childId ||
            record.bookId < 1 ||
            record.pageNumber < 1) {
          continue;
        }
        childProgress.putIfAbsent(
          record.bookId,
          () => <int, LearningStatus>{},
        )[record.pageNumber] = record.status;
      }
    } on AuthApiException catch (error) {
      if (error.statusCode == 401) {
        _handleTokenExpired();
      }
      debugPrint('Remote progress load failed: ${error.code}');
    } catch (error) {
      debugPrint('Remote progress load failed: $error');
    }
  }

  bool _canSyncRemote(String childId) {
    return parentAccount != null &&
        authToken != null &&
        authToken!.isNotEmpty &&
        childId.isNotEmpty;
  }

  void _syncProgressToBackend({
    required String childId,
    required int bookId,
    required int pageNumber,
    required LearningStatus status,
  }) {
    if (!_canSyncRemote(childId)) {
      return;
    }

    unawaited(() async {
      try {
        await authService.updateProgress(
          childId: childId,
          bookId: bookId,
          pageNumber: pageNumber,
          status: status,
        );
      } on AuthApiException catch (error) {
        if (error.statusCode == 401) {
          _handleTokenExpired();
        }
        debugPrint('Progress sync failed: ${error.code}');
      } catch (error) {
        debugPrint('Progress sync failed: $error');
      }
    }());
  }

  Future<void> _syncLearningAttempt(LearningAttempt attempt) async {
    if (!_canSyncRemote(attempt.childId)) {
      return;
    }

    try {
      final remoteAttempt = await authService.createAttempt(
        id: attempt.id,
        childId: attempt.childId,
        bookId: attempt.bookId,
        pageNumber: attempt.pageNumber,
        durationSeconds: attempt.durationSeconds,
        audioPath: attempt.audioPath,
      );

      // Upload audio if available
      if (attempt.audioPath != null && attempt.audioPath!.isNotEmpty) {
        final uploadId = remoteAttempt.id.isNotEmpty ? remoteAttempt.id : attempt.id;
        try {
          await authService.uploadAudio(
            attemptId: uploadId,
            audioPath: attempt.audioPath!,
          );
        } catch (e) {
          debugPrint('Audio upload failed: $e');
        }
      }
    } on AuthApiException catch (error) {
      if (error.statusCode == 401) {
        _handleTokenExpired();
      }
      debugPrint('Learning attempt sync failed: ${error.code}');
    } catch (error) {
      debugPrint('Learning attempt sync failed: $error');
    }
  }

  Future<void> _syncSubscription(String parentId) async {
    try {
      await authService.activateSubscription(parentId);
    } on AuthApiException catch (error) {
      if (error.statusCode == 401) {
        _handleTokenExpired();
      }
      debugPrint('Subscription sync failed: ${error.code}');
    } catch (error) {
      debugPrint('Subscription sync failed: $error');
    }
  }

  void _handleTokenExpired() {
    authToken = null;
    authService.authToken = null;
    authError = 'Sesi telah berakhir, silakan masuk kembali';
    launchStage = AppLaunchStage.welcome;
    notifyListeners();
  }

  Future<void> _loadSelectedSurahDetail() async {
    final surah = selectedSurahData;
    if (_selectedSurahDetail?.surah.id == surah.id) {
      return;
    }

    surahDetailLoading = true;
    quranError = null;
    notifyListeners();

    try {
      _selectedSurahDetail = await quranApiService.fetchSurahDetail(surah.id);
    } catch (error) {
      quranError = 'Detail surat belum bisa dimuat.';
      debugPrint('Surah detail load failed: $error');
    } finally {
      surahDetailLoading = false;
      notifyListeners();
    }
  }

  String _authErrorMessage(Object error) {
    if (error is AuthApiException) {
      return switch (error.code) {
        'email_already_registered' => 'Email ini sudah terdaftar. Coba masuk.',
        'invalid_email_or_password' => 'Email atau password belum cocok.',
        'invalid_email' => 'Format email belum benar.',
        'password_min_6' => 'Password minimal 6 karakter.',
        'child_limit_requires_plus' =>
          'Akun Free hanya bisa punya 1 anak. Aktifkan Plus untuk tambah anak.',
        _ => 'Server belum bisa memproses. Coba ulang sebentar lagi.',
      };
    }
    return 'Belum bisa terhubung ke backend. Pastikan server IqroKu aktif.';
  }

  String _localChildId(String name) {
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return slug.isEmpty
        ? 'anak-${DateTime.now().millisecondsSinceEpoch}'
        : slug;
  }

  int _effectiveVoiceDuration() {
    final startedAt = _voiceStartedAt;
    if (startedAt == null) {
      return voiceRecordingSeconds.clamp(1, 3600);
    }

    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final duration = elapsed > voiceRecordingSeconds
        ? elapsed
        : voiceRecordingSeconds;
    return duration.clamp(1, 3600);
  }

  void _cancelVoiceTimer() {
    _voiceTimer?.cancel();
    _voiceTimer = null;
  }

  @override
  void dispose() {
    _cancelVoiceTimer();
    unawaited(_playbackCompleteSubscription?.cancel());
    audioPlaybackService.dispose();
    voiceRecordingService.dispose();
    super.dispose();
  }
}

const _fallbackDailyPrayers = [
  DailyPrayer(
    id: 'doa-belajar',
    title: 'Doa Sebelum Belajar',
    category: 'Belajar',
    arabic: 'رَبِّ زِدْنِي عِلْمًا وَارْزُقْنِي فَهْمًا',
    latin: 'Rabbi zidnii ilman warzuqnii fahman',
    meaning: 'Ya Rabb, tambahkanlah ilmuku dan berilah aku pemahaman.',
    sortOrder: 10,
  ),
  DailyPrayer(
    id: 'doa-orang-tua',
    title: 'Doa Kedua Orang Tua',
    category: 'Keluarga',
    arabic: 'رَبِّ اغْفِرْ لِي وَلِوَالِدَيَّ وَارْحَمْهُمَا',
    latin: 'Rabbighfir lii waliwaalidayya warhamhumaa',
    meaning:
        'Ya Rabb, ampunilah aku dan kedua orang tuaku, serta sayangilah mereka.',
    sortOrder: 20,
  ),
  DailyPrayer(
    id: 'doa-sebelum-tidur',
    title: 'Doa Sebelum Tidur',
    category: 'Harian',
    arabic: 'بِاسْمِكَ اللَّهُمَّ أَحْيَا وَأَمُوتُ',
    latin: 'Bismikallaahumma ahyaa wa amuut',
    meaning: 'Dengan nama-Mu ya Allah aku hidup dan aku mati.',
    sortOrder: 30,
  ),
  DailyPrayer(
    id: 'doa-bangun-tidur',
    title: 'Doa Bangun Tidur',
    category: 'Harian',
    arabic:
        'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
    latin:
        'Alhamdulillaahil ladzii ahyaanaa ba’da maa amaatanaa wa ilaihin nusyuur',
    meaning:
        'Segala puji bagi Allah yang menghidupkan kami setelah mematikan kami, dan kepada-Nya kami kembali.',
    sortOrder: 40,
  ),
];

enum AppLaunchStage {
  onboarding,
  welcome,
  login,
  register,
  setupChild,
  authenticated,
}

enum QuranMode { reading, memorization, murottal }

enum QuranView { list, reader, memorization, murottal }

enum ActivityView { schedule, qibla }
