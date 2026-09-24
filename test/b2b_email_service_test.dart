import 'package:flutter_test/flutter_test.dart';
import 'package:mastui/models/lead_model.dart';
import 'package:mastui/services/b2b_email_service.dart';

void main() {
  group('B2bEmailService Pattern Generation Tests', () {
    final service = B2bEmailService.instance;

    test('Generates ranked B2B email patterns for two-part name', () {
      final patterns = service.generatePatterns('Rohit Sharma', 'razorpay.com');

      expect(patterns, isNotEmpty);
      expect(patterns.first, 'rohit.sharma@razorpay.com');
      expect(patterns, contains('rohit@razorpay.com'));
      expect(patterns, contains('rsharma@razorpay.com'));
      expect(patterns, contains('rohit_sharma@razorpay.com'));
      expect(patterns, contains('rohitsharma@razorpay.com'));
    });

    test('Strips professional honorifics and titles before generating patterns', () {
      final patternsDr = service.generatePatterns('Dr. Sameer Khan', 'dentalcare.in');
      expect(patternsDr.first, 'sameer.khan@dentalcare.in');
      expect(patternsDr, isNot(contains(contains('dr'))));

      final patternsProf = service.generatePatterns('Prof. Ananya Roy', 'university.edu');
      expect(patternsProf.first, 'ananya.roy@university.edu');
    });

    test('Handles single-word names cleanly', () {
      final patterns = service.generatePatterns('Cher', 'cher.com');
      expect(patterns, contains('cher@cher.com'));
      expect(patterns, contains('contact@cher.com'));
    });
  });

  group('B2bEmailService Domain Resolution Tests', () {
    final service = B2bEmailService.instance;

    test('Normalizes various URL formats to clean domains', () {
      expect(service.cleanDomain('https://www.razorpay.com/about/team'), 'razorpay.com');
      expect(service.cleanDomain('http://cred.club:8080/'), 'cred.club');
      expect(service.cleanDomain('https://sub.domain.co.in/path'), 'sub.domain.co.in');
    });

    test('Extracts domain from website, bio snippet, or business name with priority', () {
      // 1. Direct website priority
      final d1 = service.extractDomain(
        website: 'https://www.zomato.com',
        businessName: 'Zomato Media Pvt Ltd',
      );
      expect(d1, 'zomato.com');

      // 2. Extracts domain from bio snippet when website is missing
      final d2 = service.extractDomain(
        bioSnippet: 'Leading payment gateway in India. Visit razorpay.com for more info.',
        businessName: 'Razorpay',
      );
      expect(d2, 'razorpay.com');

      // 3. Infers domain from business name when neither is present
      final d3 = service.extractDomain(
        businessName: 'Ola Cabs Technologies Pvt Ltd',
      );
      expect(d3, 'olacabs.com');
    });

    test('Filters out generic social media and search engine domains', () {
      expect(service.extractDomain(website: 'https://linkedin.com/in/john'), isNull);
      expect(service.extractDomain(website: 'https://instagram.com/john'), isNull);
      expect(service.extractDomain(website: 'https://linktr.ee/john'), isNull);
    });
  });

  group('Lead Model B2B Work Email Serialization Tests', () {
    test('Correctly serializes and deserializes isWorkEmail, emailStatus, and alternativeEmails', () {
      final lead = Lead(
        id: 'b2b-lead-1',
        name: 'Kunal Shah',
        businessName: 'CRED',
        email: 'kunal@cred.club',
        platform: 'LinkedIn',
        profileUrl: 'https://linkedin.com/in/kunalshah1',
        extractedAt: DateTime.now(),
        isWorkEmail: true,
        emailStatus: 'verified',
        alternativeEmails: ['kunal.shah@cred.club', 'kshah@cred.club'],
      );

      final json = lead.toJson();
      expect(json['isWorkEmail'], isTrue);
      expect(json['emailStatus'], 'verified');
      expect(json['alternativeEmails'], contains('kunal.shah@cred.club'));

      final deserialized = Lead.fromJson(json);
      expect(deserialized.isWorkEmail, isTrue);
      expect(deserialized.emailStatus, 'verified');
      expect(deserialized.alternativeEmails?.length, 2);
      expect(deserialized.email, 'kunal@cred.club');
    });

    test('Lead copyWith preserves or overrides B2B work email fields', () {
      final lead = Lead(
        id: '1',
        name: 'Ritesh Agarwal',
        businessName: 'OYO',
        email: 'ritesh.agarwal@oyorooms.com',
        platform: 'LinkedIn',
        profileUrl: 'https://linkedin.com/in/riteshagarwal',
        extractedAt: DateTime.now(),
        isWorkEmail: true,
        emailStatus: 'mx_valid',
      );

      final updated = lead.copyWith(emailStatus: 'verified');
      expect(updated.isWorkEmail, isTrue);
      expect(updated.emailStatus, 'verified');
    });
  });
}
