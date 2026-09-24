import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mastui/main.dart';
import 'package:mastui/models/lead_model.dart';
import 'package:mastui/screens/home_screen.dart';
import 'package:mastui/services/lead_discovery_service.dart';
import 'package:mastui/services/lead_storage_service.dart';
import 'package:mastui/widgets/lead_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('GetLead app mounts and displays search controls cleanly',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MastUiApp());
    await tester.pumpAndSettle();

    // Verify main screen elements
    expect(find.byType(MastUiApp), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.textContaining('GetLead'), findsOneWidget);
    expect(find.text('Generate Leads'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);

    // Verify more_vert menu and filter button in top AppBar
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
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

    // Tap Export button when empty -> shows toast/snack
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(find.text('No leads to export.'), findsOneWidget);
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

    // Email, phone, website, and 1-click WhatsApp are properly shown
    expect(find.text('contact@sdcbusiness.com'), findsOneWidget);
    expect(find.text('+919876543210'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('https://sdcbusiness.com'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget); // website open iconbutton

    expect(tester.takeException(), isNull);
  });

  testWidgets('LeadCard cleanly hides missing email, phone, and WhatsApp when not available',
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
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.byIcon(Icons.language_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fresh search automatically clears previous leads and shows discovery state',
      (WidgetTester tester) async {
    final streamController = StreamController<Lead>();
    LeadDiscoveryService.instance.mockStreamHandler = (config) => streamController.stream;
    HomeScreen.enablePulseAnimation = false;
    addTearDown(() {
      HomeScreen.enablePulseAnimation = true;
      streamController.close();
      LeadDiscoveryService.instance.mockStreamHandler = null;
    });

    // Initialize SharedPreferences mock platform channel
    SharedPreferences.setMockInitialValues({});

    final oldLead = Lead(
      id: 'old-real-estate-1',
      name: 'Old Real Estate Lead',
      platform: 'Instagram',
      profileUrl: 'https://instagram.com/realestate',
      niche: 'Real Estate',
      extractedAt: DateTime.now(),
    );
    await LeadStorageService.instance.saveLeads([oldLead]);

    await tester.pumpWidget(const MastUiApp());
    await tester.pumpAndSettle();

    expect(find.text('Old Real Estate Lead'), findsOneWidget);
    expect(find.text('1 leads'), findsOneWidget);

    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'Dentists');
    await tester.pump();

    // Tap "Generate Leads" button
    await tester.tap(find.text('Generate Leads'));
    await tester.pump();

    // 1. Verify old lead is AUTOMATICALLY CLEARED from view
    expect(find.text('Old Real Estate Lead'), findsNothing);
    expect(find.textContaining('Searching leads for "Dentists"'), findsOneWidget);

    // 2. Emit a new Dentist lead into the active stream
    streamController.add(
      Lead(
        id: 'new-dentist-1',
        name: 'Dr. Smile Dental Clinic',
        platform: 'Instagram',
        profileUrl: 'https://instagram.com/drsmile',
        niche: 'Dentists',
        extractedAt: DateTime.now(),
      ),
    );
    await tester.pump();

    // 3. Verify the new lead appears
    expect(find.text('Dr. Smile Dental Clinic'), findsOneWidget);

    // 4. Verify old lead is NEVER mixed with the new category
    expect(find.text('Old Real Estate Lead'), findsNothing);

    // Complete stream and settle
    await streamController.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
