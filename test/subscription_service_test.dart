import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mastui/models/subscription_plan.dart';
import 'package:mastui/services/subscription_service.dart';
import 'package:mastui/widgets/remove_ads_capsule.dart';
import 'package:mastui/widgets/remove_ads_paywall_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SubscriptionPlan Model Tests', () {
    test('Correctly serializes and deserializes SubscriptionPlan', () {
      const plan = SubscriptionPlan(
        id: 'getlead_remove_ads_monthly',
        title: 'Monthly',
        price: '₹299',
        billingPeriod: '/ month',
        badge: 'Save 20%',
        isPopular: true,
        currencyCode: 'INR',
      );

      final json = plan.toJson();
      final fromJson = SubscriptionPlan.fromJson(json);

      expect(fromJson, equals(plan));
      expect(fromJson.id, 'getlead_remove_ads_monthly');
      expect(fromJson.price, '₹299');
      expect(fromJson.badge, 'Save 20%');
    });

    test('SubscriptionPlan copyWith preserves and overrides values', () {
      const plan = SubscriptionPlan(
        id: 'test_id',
        title: 'Weekly',
        price: '₹99',
        billingPeriod: '/ week',
      );

      final modified = plan.copyWith(price: '₹149', badge: 'Popular');
      expect(modified.price, '₹149');
      expect(modified.badge, 'Popular');
      expect(modified.title, 'Weekly');
    });
  });

  group('SubscriptionService Tests', () {
    test('Initial state is not ad-free and defaults load properly', () async {
      final service = SubscriptionService.instance;
      await service.init(enableStore: false);

      expect(service.isAdFree, isFalse);
      expect(service.plansNotifier.value.isNotEmpty, isTrue);
      expect(service.plansNotifier.value.length, 3);
      expect(service.plansNotifier.value[0].title, 'Weekly');
      expect(service.plansNotifier.value[1].title, 'Monthly');
      expect(service.plansNotifier.value[2].title, 'Yearly');
    });

    test('Can toggle ad-free state via notifier', () {
      final service = SubscriptionService.instance;
      service.isAdFreeNotifier.value = true;
      expect(service.isAdFree, isTrue);

      service.isAdFreeNotifier.value = false;
      expect(service.isAdFree, isFalse);
    });
  });

  group('RemoveAds UI Tests', () {
    testWidgets('RemoveAdsCapsule renders correctly for free and ad-free states',
        (tester) async {
      final service = SubscriptionService.instance;
      service.isAdFreeNotifier.value = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: SafeArea(child: RemoveAdsCapsule()),
            ),
          ),
        ),
      );

      expect(find.text('Remove Ads'), findsOneWidget);
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);

      // Now set to ad-free
      service.isAdFreeNotifier.value = true;
      await tester.pumpAndSettle();

      expect(find.text('Ad-Free'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('RemoveAdsPaywallSheet renders minimalist layout and plans',
        (tester) async {
      final service = SubscriptionService.instance;
      await service.init(enableStore: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => RemoveAdsPaywallSheet.show(ctx),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Remove Ads'), findsWidgets);
      expect(
        find.text(
          'GetLead is completely free. All lead searches, filters, and exports are included. This optional prepaid plan removes all advertisements.',
        ),
        findsOneWidget,
      );
      expect(find.text('Weekly Prepaid'), findsOneWidget);
      expect(find.text('Monthly Prepaid'), findsOneWidget);
      expect(find.text('Yearly Prepaid'), findsOneWidget);
      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
    });
  });
}
