import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mastui/main.dart';
import 'package:mastui/models/lead_model.dart';
import 'package:mastui/screens/home_screen.dart';
import 'package:mastui/widgets/lead_card.dart';

void main() {
  testWidgets('GetLead app mounts and displays search controls cleanly',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MastUiApp());
    await tester.pumpAndSettle();

    // Verify main screen elements
    expect(find.byType(MastUiApp), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('GetLead'), findsOneWidget);
    expect(find.text('Generate Leads'), findsOneWidget);

    // Verify more_vert menu in top AppBar
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

    // Verify adjacent filter button at bottom
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

    // Tap filter button to open bottom sheet
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    // Verify filter bottom sheet content
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Platform'), findsOneWidget);
    expect(find.text('Apply Filters'), findsOneWidget);

    // Close bottom sheet
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsNothing);
  });

  testWidgets('LeadCard renders without overflow on narrow width and respects clean UI',
      (WidgetTester tester) async {
    final lead = Lead(
      id: 'test-1',
      name: 'SDC Business Solutions',
      businessName: 'Digital Marketing Agency',
      email: 'contact@sdcbusiness.com',
      phone: '+919876543210',
      website: 'https://sdcbusiness.com',
      platform: 'Instagram',
      profileUrl: 'https://instagram.com/sdcbusiness',
      niche: 'Digital Marketing',
      bioSnippet: 'Premier Digital Marketing agency helping brands grow.',
      extractedAt: DateTime.now(),
    );

    // Simulate narrow mobile screen (320px width)
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: LeadCard(
                lead: lead,
                onDelete: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Clickable platform badge is present
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_outward_rounded), findsOneWidget);

    // Category container is removed as requested
    expect(find.text('Digital Marketing'), findsNothing);

    // Close/delete button is present
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Email, phone and website are properly shown
    expect(find.text('contact@sdcbusiness.com'), findsOneWidget);
    expect(find.text('+919876543210'), findsOneWidget);
    expect(find.text('https://sdcbusiness.com'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget); // website open iconbutton

    expect(tester.takeException(), isNull);
  });

  testWidgets('LeadCard cleanly hides missing email and phone without affecting other fields',
      (WidgetTester tester) async {
    final minimalLead = Lead(
      id: 'test-2',
      name: 'Minimal Lead',
      platform: 'LinkedIn',
      profileUrl: 'https://linkedin.com/in/minimal',
      extractedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LeadCard(lead: minimalLead),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Minimal Lead'), findsOneWidget);
    expect(find.text('LinkedIn'), findsOneWidget);
    expect(find.byIcon(Icons.mail_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.phone_outlined), findsNothing);
    expect(find.byIcon(Icons.language_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
