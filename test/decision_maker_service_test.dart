import 'package:flutter_test/flutter_test.dart';
import 'package:mastui/models/lead_model.dart';
import 'package:mastui/services/b2b_email_service.dart';
import 'package:mastui/services/decision_maker_service.dart';

void main() {
  group('DecisionMakerService Zero-Hallucination & Anti-Pollution Tests', () {
    final service = DecisionMakerService.instance;

    test('Rejects enrichment when businessName is empty or missing', () async {
      final leadNoBusiness = Lead(
        id: 'lead-1',
        name: 'Steven Amos',
        businessName: null,
        platform: 'LinkedIn',
        profileUrl: 'https://linkedin.com/in/steven-amos',
        extractedAt: DateTime.now(),
      );

      final result1 = await service.enrichDecisionMaker(leadNoBusiness);
      expect(result1, isNull);
    });

    test('B2bEmailService only extracts domain from real website or bio and never guesses blindly', () {
      final emailService = B2bEmailService.instance;
      expect(emailService.extractDomain(website: 'https://atherenergy.com'), 'atherenergy.com');
      expect(emailService.extractDomain(bioSnippet: 'Visit razorpay.com for more'), 'razorpay.com');
      expect(emailService.extractDomain(website: null, bioSnippet: 'No domain here'), isNull);
    });
  });
}
