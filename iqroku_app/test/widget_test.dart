import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iqroku/app/app_state.dart';
import 'package:iqroku/app/iqroku_app.dart';
import 'package:iqroku/data/dummy_iqroku_repository.dart';
import 'package:iqroku/models/learning_status.dart';

void main() {
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

    await tester.pumpWidget(const IqrokuApp());

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

    final loginButton = find.byKey(const ValueKey('login_submit_button'));
    await tester.ensureVisible(loginButton);
    await tester.pump();
    await tester.tap(loginButton);
    await tester.pump();

    expect(find.text('Tambah Profil Anak'), findsOneWidget);

    final skipSetupButton = find.text('Lewati, tambah nanti');
    await tester.scrollUntilVisible(
      skipSetupButton,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(skipSetupButton);
    await tester.pump();

    expect(find.text('Aisyah'), findsOneWidget);
    expect(find.text('Menu Utama'), findsOneWidget);

    await tester.tap(find.text('Belajar'));
    await tester.pump();

    expect(find.text('Belajar Iqro'), findsOneWidget);
    expect(find.text('Pilih Halaman'), findsOneWidget);
  });

  test('Iqro progress, notes, and local storage are updated', () async {
    SharedPreferences.setMockInitialValues({});
    final state = IqrokuState(repository: const DummyIqrokuRepository());

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

    final restored = IqrokuState(repository: const DummyIqrokuRepository());
    await restored.restoreFromDisk();

    expect(restored.selectedIqroCompletedPages, 8);
    expect(restored.selectedIqroPage, 9);
    expect(restored.learningNotes.first.title, 'Iqro 1 - Halaman 8');
  });
}
