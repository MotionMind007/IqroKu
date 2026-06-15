import 'package:flutter/foundation.dart';

import '../data/dummy_iqroku_repository.dart';
import '../models/learning_status.dart';

class IqrokuState extends ChangeNotifier {
  IqrokuState({required this.repository});

  final DummyIqrokuRepository repository;

  AppLaunchStage launchStage = AppLaunchStage.welcome;
  int selectedTab = 0;
  int selectedIqroBook = 1;
  int selectedIqroPage = 8;
  LearningStatus selectedIqroStatus = LearningStatus.learning;
  int selectedSurahIndex = 3;
  bool memorizationMode = false;
  String selectedChildId = 'nedy';

  void continueFromWelcome() {
    launchStage = AppLaunchStage.login;
    notifyListeners();
  }

  void loginAsDemoUser() {
    launchStage = AppLaunchStage.authenticated;
    selectedTab = 0;
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
    notifyListeners();
  }

  void selectIqroPage(int page) {
    selectedIqroPage = page;
    notifyListeners();
  }

  void setIqroStatus(LearningStatus status) {
    selectedIqroStatus = status;
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
    notifyListeners();
  }
}

enum AppLaunchStage { welcome, login, authenticated }
