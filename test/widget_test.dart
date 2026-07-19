import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mastui/main.dart';
import 'package:mastui/screens/detail_screen.dart';

void main() {
  testWidgets('home lists style packs and opens the unified detail screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MastUiApp());

    // catalog.json is loaded with real async I/O (rootBundle), which never
    // completes inside the test's fake-async zone — runAsync lets it finish.
    for (var i = 0;
        i < 50 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    expect(find.text('MastUI'), findsOneWidget);

    // Match on the card key rather than a title — titles change every time the
    // pipeline syncs a new catalog.
    final packCards = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('pack-card-'),
    );
    expect(packCards, findsWidgets,
        reason: 'bundled catalog should contain at least one style pack');

    await tester.tap(packCards.first);
    await tester.pumpAndSettle();

    // Packs open the same DetailScreen as single designs, with the pack's
    // screens in a swipeable carousel.
    expect(find.byType(DetailScreen), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);

    // Actions live in the pinned bottom bar — visible without scrolling.
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Copy prompt'), findsOneWidget);

    String appBarTitle() => tester
        .widget<Text>(find
            .descendant(of: find.byType(AppBar), matching: find.byType(Text))
            .first)
        .data!;

    // Swiping the carousel switches to the next screen and the title follows.
    final titleBefore = appBarTitle();
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(appBarTitle(), isNot(titleBefore),
        reason: 'swiping a pack should show the next screen\'s details');
  });
}
