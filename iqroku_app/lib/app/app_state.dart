import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/assets/app_assets.dart';
import '../data/assessment_service.dart';
import '../data/audio_playback_service.dart';
import '../data/dummy_iqroku_repository.dart';
import '../data/iqro_content_repository.dart';
import '../data/local_app_storage.dart';
import '../data/voice_recording_service.dart';
import '../models/iqro_models.dart';
import '../models/learning_status.dart';
import '../models/profile_models.dart';

class IqrokuState extends ChangeNotifier {
  IqrokuState({
    required this.repository,
    this.storage = const LocalAppStorage(),
    this.iqroContentRepository = const IqroContentRepository(),
    this.assessmentService = const MockAssessmentService(),
    VoiceRecordingService? voiceRecordingService,
    AudioPlaybackService? audioPlaybackService,
  }) : childProfiles = List.of(repository.children.take(freeChildLimit)),
       learningNotes = List.of(repository.learningNotes),
       learningAttempts = <LearningAttempt>[],
       voiceRecordingService =
           voiceRecordingService ?? LocalVoiceRecordingService(),
       audioPlaybackService =
           audioPlaybackService ?? LocalAudioPlaybackService() {
    _playbackCompleteSubscription = this.audioPlaybackService.onComplete.listen(
      (_) {
        playingAttemptId = null;
        notifyListeners();
      },
    );
  }

  static const freeChildLimit = 1;
  static const freeIqroBookLimit = 1;
  static const freeIqroPageLimit = 10;
  static const subscriptionPriceLabel = 'Rp49.000/bulan';

  final DummyIqrokuRepository repository;
  final LocalAppStorage storage;
  final IqroContentRepository iqroContentRepository;
  final AssessmentService assessmentService;
  final VoiceRecordingService voiceRecordingService;
  final AudioPlaybackService audioPlaybackService;
  final List<ChildProfile> childProfiles;
  final List<LearningNote> learningNotes;
  final List<LearningAttempt> learningAttempts;
  final Map<String, Map<int, Map<int, LearningStatus>>> _iqroProgress = {};
  Future<void> _saveQueue = Future.value();
  IqroContent? _iqroContent;
  Timer? _voiceTimer;
  StreamSubscription<void>? _playbackCompleteSubscription;
  DateTime? _voiceStartedAt;
  String? _activeVoicePath;

  AppLaunchStage launchStage = AppLaunchStage.onboarding;
  int selectedTab = 0;
  int selectedIqroBook = 1;
  int selectedIqroPage = 8;
  int selectedSurahIndex = 3;
  bool memorizationMode = false;
  String selectedChildId = 'nedy';
  bool familyPlusActive = false;
  bool childSetupCompleted = false;
  bool iqroContentLoading = false;
  bool isVoiceRecording = false;
  int voiceRecordingSeconds = 0;
  DateTime? subscriptionActivatedAt;
  String? iqroContentError;
  String? voiceRecordingError;
  String? playingAttemptId;
  String? playbackError;
  String? subscriptionNotice;

  ChildProfile get selectedChild {
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

  Future<void> restoreFromDisk() async {
    final stored = await storage.load();
    if (stored == null || stored.childProfiles.isEmpty) {
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
    selectedChildId = stored.selectedChildId.isEmpty
        ? childProfiles.first.id
        : stored.selectedChildId;
    familyPlusActive = stored.familyPlusActive;
    subscriptionActivatedAt = stored.subscriptionActivatedAt;
    childSetupCompleted = stored.childSetupCompleted;
    selectedIqroBook = stored.selectedIqroBook;
    selectedIqroPage = stored.selectedIqroPage;
    _ensureSelectedIqroAccess();

    if (childSetupCompleted) {
      launchStage = AppLaunchStage.authenticated;
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

  void completeSetup({
    String? name,
    int? age,
    String avatarAsset = AppAssets.avatarMale,
  }) {
    final cleanName = name?.trim();
    if (cleanName != null && cleanName.isNotEmpty) {
      final child = ChildProfile(
        id: cleanName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
        name: cleanName,
        age: age ?? 7,
        currentLesson: 'Iqro 1 - Halaman 1',
        progress: 0,
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
        notifyListeners();
        return;
      }
      selectedChildId = child.id;
      _seedIqroProgressForChild(child.id, currentPage: 1);
    }
    childSetupCompleted = true;
    launchStage = AppLaunchStage.authenticated;
    _persist();
    notifyListeners();
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
    _persist();
    notifyListeners();
  }

  void backToWelcome() {
    launchStage = AppLaunchStage.welcome;
    notifyListeners();
  }

  void selectTab(int index) {
    selectedTab = index;
    notifyListeners();
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
      id: '${selectedChildId}_${DateTime.now().microsecondsSinceEpoch}',
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
      playbackError = null;
      notifyListeners();
      await audioPlaybackService.play(audioPath);
    } catch (_) {
      playingAttemptId = null;
      playbackError = 'Rekaman belum bisa diputar. Coba rekam ulang.';
      notifyListeners();
    }
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
    notifyListeners();
  }

  void selectSurah(int index) {
    selectedSurahIndex = index;
    notifyListeners();
  }

  void setMemorizationMode(bool value) {
    memorizationMode = value;
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
    final result = await assessmentService.assess(
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

enum AppLaunchStage {
  onboarding,
  welcome,
  login,
  register,
  setupChild,
  authenticated,
}
