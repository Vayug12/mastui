import 'package:flutter_test/flutter_test.dart';
import 'package:mastui/services/email_verification_service.dart';

void main() {
  group('EmailVerificationService Tests', () {
    final service = EmailVerificationService.instance;

    test('Instantly verifies known trusted providers without latency', () async {
      expect(service.isTrustedOrCached('user@gmail.com'), isTrue);
      expect(service.isTrustedOrCached('sales@yahoo.com'), isTrue);
      expect(service.isTrustedOrCached('founder@outlook.com'), isTrue);
      expect(service.isTrustedOrCached('team@zoho.com'), isTrue);
      expect(service.isTrustedOrCached('contact@icloud.com'), isTrue);

      final valid = await service.isEmailValid('hello@gmail.com');
      expect(valid, isTrue);
    });

    test('Rejects invalid or malformed email strings', () async {
      expect(await service.isEmailValid(''), isFalse);
      expect(await service.isEmailValid('notanemail'), isFalse);
      expect(await service.isEmailValid('missingat.com'), isFalse);
      expect(await service.isEmailValid('@domain.com'), isFalse);
      expect(await service.isEmailValid('user@'), isFalse);
    });

    test('Recognizes case-insensitive domain checks', () async {
      expect(service.isTrustedOrCached('User@GMAIL.COM'), isTrue);
      expect(service.isTrustedOrCached('test@Yahoo.Co.In'), isTrue);
    });
  });
}
