import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/assets/app_assets.dart';
import '../data/dummy_iqroku_repository.dart';
import '../data/local_app_storage.dart';
import '../models/iqro_models.dart';
import '../models/learning_status.dart';
import '../models/profile_models.dart';

class IqrokuState extends ChangeNotifier {
  IqrokuState({
    required this.repository,
    this.storage = const LocalAppStorage(),
  }) : childProfiles = List.of(repository.children.take(freeChildLimit)),
       learningNotes = List.of(repository.learningNotes);

  static const freeChildLimit = 1;

  final DummyIqrokuRepository repository;
  final LocalAppStorage storage;
  final List<ChildProfile> childProfiles;
  final List<LearningNote> learningNotes;
  final Map<String, Map<int, Map<int, LearningStatus>>> _iqroProgress = {};
  Future<void> _saveQueue = Future.value();

  AppLaunchStage launchStage = AppLaunchStage.onboarding;
  int selectedTab = 0;
  int selectedIqroBook = 1;
  int selectedIqroPage = 8;
  int selectedSurahIndex = 3;
  bool memorizationMode = false;
  String selectedChildId = 'nedy';
  bool familyPlusActive = false;
  bool childSetupCompleted = false;

  ChildProfile get selectedChild {
    return childProfiles.firstWhere(
      (child) => child.id == selectedChildId,
      orElse: () => childProfiles.first,
    );
  }

  int get childLimit => familyPlusActive ? 5 : freeChildLimit;
  bool get canAddFreeChild => childProfiles.length < childLimit;
  String get planLabel => familyPlusActive ? 'Family Plus' : 'Free';
  String get childQuotaLabel => '${childProfiles.length}/$childLimit anak';

  IqroBook get selectedIqroBookData {
    return repository.iqroBooks.firstWhere(
      (book) => book.id == selectedIqroBook,
      orElse: () => repository.iqroBooks.first,
    );
  }

  LearningStatus get selectedIqroStatus {
    return statusForIqroPage(selectedIqroBook, selectedIqroPage);
  }

  List<IqroPage> get selectedIqroPages {
    final pageStatuses = _progressForBook(selectedChildId, selectedIqroBook);
    return List.generate(selectedIqroTotalPages, (index) {
      final page = index + 1;
      return IqroPage(
        bookId: selectedIqroBook,
        pageNumber: page,
        status: pageStatuses[page] ?? LearningStatus.notStarted,
      );
    });
  }

  int get selectedIqroCompletedPages {
    return _progressForBook(
      selectedChildId,
      selectedIqroBook,
    ).values.where((status) => status == LearningStatus.fluent).length;
  }

  int get selectedIqroTotalPages => selectedIqroBookData.totalPages;

  LearningStatus statusForIqroPage(int bookId, int page) {
    return _progressForBook(selectedChildId, bookId)[page] ??
        LearningStatus.notStarted;
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
    _iqroProgress
      ..clear()
      ..addAll(stored.iqroProgress);
    selectedChildId = stored.selectedChildId.isEmpty
        ? childProfiles.first.id
        : stored.selectedChildId;
    familyPlusActive = stored.familyPlusActive;
    childSetupCompleted = stored.childSetupCompleted;
    selectedIqroBook = stored.selectedIqroBook;
    selectedIqroPage = stored.selectedIqroPage;

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
    selectedIqroBook = bookId;
    selectedIqroPage = _firstActivePageForBook(bookId);
    _persist();
    notifyListeners();
  }

  void selectIqroPage(int page) {
    selectedIqroPage = page;
    _persist();
    notifyListeners();
  }

  void setIqroStatus(LearningStatus status) {
    updateIqroPageStatus(status);
  }

  void updateIqroPageStatus(LearningStatus status) {
    _progressForBook(selectedChildId, selectedIqroBook)[selectedIqroPage] =
        status;
    if (status == LearningStatus.fluent || status == LearningStatus.review) {
      _prependLearningNote(status);
    }
    _syncSelectedChildProgress();
    _persist();
    notifyListeners();
  }

  void goToNextIqroPage() {
    if (selectedIqroPage >= selectedIqroTotalPages) {
      return;
    }

    selectedIqroPage += 1;
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
    final learningEntry = statuses.entries
        .where((entry) => entry.value == LearningStatus.learning)
        .firstOrNull;
    if (learningEntry != null) {
      return learningEntry.key;
    }

    final firstNotFluent =
        List.generate(selectedIqroTotalPages, (index) => index + 1).firstWhere(
          (page) => statuses[page] != LearningStatus.fluent,
          orElse: () => 1,
        );
    return firstNotFluent;
  }

  void _syncSelectedChildProgress() {
    final childIndex = childProfiles.indexWhere(
      (child) => child.id == selectedChildId,
    );
    if (childIndex == -1) {
      return;
    }

    final totalPages = selectedIqroTotalPages;
    final completedPages = selectedIqroCompletedPages;
    final nextPage = _nextLearningPage(totalPages);
    final progress = (completedPages / totalPages).clamp(0.0, 1.0);

    childProfiles[childIndex] = childProfiles[childIndex].copyWith(
      currentLesson: 'Iqro $selectedIqroBook - Halaman $nextPage',
      progress: progress,
    );
  }

  int _nextLearningPage(int totalPages) {
    final statuses = _progressForBook(selectedChildId, selectedIqroBook);
    for (var page = 1; page <= totalPages; page++) {
      if (statuses[page] != LearningStatus.fluent) {
        return page;
      }
    }
    return totalPages;
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
    final now = DateTime.now();
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
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  void _persist() {
    final snapshot = StoredIqrokuState(
      childProfiles: List.of(childProfiles),
      iqroProgress: _copyProgress(),
      learningNotes: List.of(learningNotes),
      selectedChildId: selectedChildId,
      familyPlusActive: familyPlusActive,
      childSetupCompleted: childSetupCompleted,
      selectedIqroBook: selectedIqroBook,
      selectedIqroPage: selectedIqroPage,
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
}

enum AppLaunchStage {
  onboarding,
  welcome,
  login,
  register,
  setupChild,
  authenticated,
}
