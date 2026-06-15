import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iqroku/app/iqroku_app.dart';

void main() {
  testWidgets('IqroKu starts from welcome and reaches learning tab', (
    tester,
  ) async {
    await tester.pumpWidget(const IqrokuApp());

    expect(
      find.text('Belajar Ngaji Lebih Mudah, Terarah, dan Menyenangkan'),
      findsOneWidget,
    );

    final welcomeButton = find.byKey(const ValueKey('welcome_continue_button'));
    await tester.scrollUntilVisible(welcomeButton, 240);
    await tester.tap(welcomeButton);
    await tester.pump();

    expect(find.text('Masuk ke IqroKu'), findsOneWidget);

    final loginButton = find.byKey(const ValueKey('login_submit_button'));
    await tester.scrollUntilVisible(
      loginButton,
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -80));
    await tester.pump();
    await tester.tap(loginButton);
    await tester.pump();

    expect(find.text('Aisyah'), findsOneWidget);
    expect(find.text('Menu Utama'), findsOneWidget);

    await tester.tap(find.text('Belajar'));
    await tester.pump();

    expect(find.text('Belajar Iqro'), findsOneWidget);
    expect(find.text('Pilih Halaman'), findsOneWidget);
  });
}
