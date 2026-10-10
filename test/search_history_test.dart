import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mastui/main.dart';
import 'package:mastui/models/lead_model.dart';
import 'package:mastui/screens/home_screen.dart';
import 'package:mastui/screens/history_detail_screen.dart';
import 'package:mastui/screens/history_screen.dart';
import 'package:mastui/services/search_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HomeScreen.enablePulseAnimation = false;
  });

  tearDown(() {
    HomeScreen.enablePulseAnimation = true;
  });

  group('SearchHistoryService tests', () {
    test('Records search session and prevents duplicates by merging leads',
        () async {
      final service = SearchHistoryService.instance;
      await service.clearHistory();

      final lead1 = Lead(
        id: 'lead-1',
        name: 'Dr. Smile',
        email: 'smile@example.com',
        platform: 'Web',
        profileUrl: 'https://example.com/smile',
        extractedAt: DateTime.now(),
      );

      final lead2 = Lead(
        id: 'lead-2',
        name: 'Dr. Bright',
        email: 'bright@example.com',
        platform: 'Web',
        profileUrl: 'https://example.com/bright',
        extractedAt: DateTime.now(),
      );

      // Record first session for "Dentists in London"
      await service.recordSearchSession(
        niche: 'Dentists',
        location: 'London',
        leads: [lead1],
      );

      var history = await service.loadHistory();
      expect(history.length, 1);
      expect(history.first.niche, 'Dentists');
      expect(history.first.location, 'London');
      expect(history.first.leadCount, 1);

      // Record again for identical niche and location (e.g. Load More or repeated search)
      await service.recordSearchSession(
        niche: 'Dentists',
        location: 'London',
        leads: [lead1, lead2], // lead1 is duplicate, lead2 is new
      );

      history = await service.loadHistory();
      // Should NOT create duplicate session item
      expect(history.length, 1);
      // Leads should be merged and deduplicated
      expect(history.first.leadCount, 2);

      // Deleting session works
      await service.deleteSession(history.first.id);
      history = await service.loadHistory();
      expect(history, isEmpty);
    });

    test('Does not save empty sessions with 0 leads', () async {
      final service = SearchHistoryService.instance;
      await service.clearHistory();

      await service.recordSearchSession(
        niche: 'Empty Niche',
        location: null,
        leads: [],
      );

      final history = await service.loadHistory();
      expect(history, isEmpty);
    });
  });

  group('History UI and End-to-End Navigation tests', () {
    testWidgets(
        'more_vert menu has History at the top and no Copy Emails item',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MastUiApp());
      await tester.pumpAndSettle();

      // Tap more_vert menu
      final moreButton = find.byIcon(Icons.more_vert_rounded);
      expect(moreButton, findsOneWidget);
      await tester.tap(moreButton);
      await tester.pumpAndSettle();

      // Verify "History" is present
      expect(find.text('History'), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);

      // Verify "Copy Emails" is NOT in the popup menu
      expect(find.text('Copy Emails'), findsNothing);
    });

    testWidgets(
        'Tapping History opens HistoryScreen and displays saved sessions',
        (WidgetTester tester) async {
      final service = SearchHistoryService.instance;
      await service.clearHistory();

      final lead = Lead(
        id: 'gym-1',
        name: 'Iron Gym',
        email: 'contact@irongym.com',
        phone: '+1234567890',
        platform: 'Instagram',
        profileUrl: 'https://instagram.com/irongym',
        niche: 'Gym & Fitness',
        location: 'California',
        extractedAt: DateTime.now(),
      );

      await service.recordSearchSession(
        niche: 'Gym & Fitness',
        location: 'California',
        leads: [lead],
      );

      await tester.pumpWidget(const MastUiApp());
      await tester.pumpAndSettle();

      // Open more_vert and tap History
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      // Verify HistoryScreen mounted
      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.text('Search History'), findsOneWidget);
      expect(find.text('Gym & Fitness'), findsOneWidget);
      expect(find.text('California'), findsOneWidget);
      expect(find.text('1 leads'), findsOneWidget);

      // Tap on the session card to open HistoryDetailScreen
      await tester.tap(find.text('Gym & Fitness'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryDetailScreen), findsOneWidget);
      expect(find.text('Iron Gym'), findsOneWidget);
      expect(find.text('Restore to Search'), findsOneWidget);

      // Tap "Restore to Search"
      await tester.tap(find.text('Restore to Search'));
      await tester.pumpAndSettle();

      // Verify back on HomeScreen with restored leads and parameters
      expect(find.byType(HistoryDetailScreen), findsNothing);
      expect(find.byType(HistoryScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Iron Gym'), findsOneWidget);
      expect(find.text('Gym & Fitness'), findsOneWidget);
    });

    testWidgets('Clear all history removes all sessions and shows empty state',
        (WidgetTester tester) async {
      final service = SearchHistoryService.instance;
      await service.clearHistory();

      await service.recordSearchSession(
        niche: 'Cafes',
        leads: [
          Lead(
            id: 'cafe-1',
            name: 'Central Perk',
            platform: 'Web',
            profileUrl: 'https://example.com/cafe',
            extractedAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cafes'), findsOneWidget);

      // Tap Clear All button in app bar
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      // Dialog confirmation appears
      expect(find.text('Clear all history?'), findsOneWidget);
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      // Verify empty state is displayed
      expect(find.text('No Search History'), findsOneWidget);
      expect(find.text('Start Searching'), findsOneWidget);
    });
  });
}
