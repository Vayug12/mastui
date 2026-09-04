import 'package:flutter_test/flutter_test.dart';
import 'package:mastui/models/lead_model.dart';
import 'package:mastui/services/duckduckgo_search_service.dart';
import 'package:mastui/services/lead_discovery_service.dart';

void main() {
  group('Lead Model Tests', () {
    test('Lead model serializes and deserializes properly', () {
      final lead = Lead(
        id: 'lead-123',
        name: 'Dr. Sameer Khan',
        businessName: 'Khan Dental Care',
        email: 'sameer@gmail.com',
        phone: '+919820012345',
        website: 'https://linktr.ee/sameerdental',
        platform: 'Instagram',
        profileUrl: 'https://instagram.com/sameerdental',
        location: 'Mumbai',
        niche: 'Dentists',
        bioSnippet: 'Award winning dentist in Bandra, Mumbai.',
        extractedAt: DateTime.parse('2026-09-04T02:00:00.000Z'),
      );

      final json = lead.toJson();
      final revived = Lead.fromJson(json);

      expect(revived.id, 'lead-123');
      expect(revived.name, 'Dr. Sameer Khan');
      expect(revived.businessName, 'Khan Dental Care');
      expect(revived.email, 'sameer@gmail.com');
      expect(revived.phone, '+919820012345');
      expect(revived.platform, 'Instagram');
      expect(revived.displayName, 'Khan Dental Care');
      expect(revived.hasContactInfo, isTrue);
    });

    test('Lead CSV formatting produces valid escaped columns', () {
      final lead = Lead(
        id: '1',
        name: 'Rahul Sharma',
        businessName: 'Sharma Gaming "YT"',
        email: 'gamer@gmail.com',
        phone: '+919876543210',
        platform: 'Instagram',
        profileUrl: 'https://instagram.com/gamer',
        extractedAt: DateTime.now(),
      );

      final row = lead.toCsvRow();
      expect(row, contains('"Sharma Gaming ""YT"""'));
      expect(row, contains('"gamer@gmail.com"'));
      expect(row, contains('"Instagram"'));
    });
  });

  group('Yahoo Search Parser Tests', () {
    test('Parses Yahoo HTML results and decodes RU redirect URLs correctly', () {
      const yahooHtml = '''
<!DOCTYPE html>
<html>
<body>
  <div class="dd algo algo-sr relsrch Sr">
    <div class="compTitle options-toggle">
      <a href="https://r.search.yahoo.com/_ylt=Awr/RU=https%3a%2f%2fwww.instagram.com%2fmumbai.dentist%2f/RK=2/RS=123">
        <h3 class="title">Dr. Pervez Cooper | Cosmetic Dentist (@mumbai.dentist) - Instagram</h3>
      </a>
    </div>
    <div class="compText aAbs">
      <p>167 Followers. Cosmetic Dentist in Mumbai. Dental Implants, Smiles. Call: +91 9820012345 or email pervez@gmail.com.</p>
    </div>
  </div>
</body>
</html>
''';

      final results = DuckDuckGoSearchService.instance.parseYahooResults(yahooHtml);
      expect(results.length, 1);
      expect(results[0].title, contains('Dr. Pervez Cooper'));
      expect(results[0].url, 'https://www.instagram.com/mumbai.dentist/');
      expect(results[0].snippet, contains('+91 9820012345'));
      expect(results[0].sourceEngine, 'Yahoo');
    });
  });

  group('Bing Search Parser Tests', () {
    test('Parses Bing HTML results and captions correctly', () {
      const bingHtml = '''
<!DOCTYPE html>
<html>
<body>
  <li class="b_algo">
    <h2>
      <a href="https://www.instagram.com/bhoomis_smile_care/">Dr. Deepika Kothari | Family Dentist | Mumbai</a>
    </h2>
    <div class="b_caption">
      <p>One-stop dental solutions for all ages. For Consultation: 9870092963 | 9833648966 Malad West, Mumbai.</p>
    </div>
  </li>
</body>
</html>
''';

      final results = DuckDuckGoSearchService.instance.parseBingResults(bingHtml);
      expect(results.length, 1);
      expect(results[0].title, contains('Dr. Deepika Kothari'));
      expect(results[0].url, 'https://www.instagram.com/bhoomis_smile_care/');
      expect(results[0].snippet, contains('9870092963'));
      expect(results[0].sourceEngine, 'Bing');
    });
  });

  group('DuckDuckGo Search & Anomaly Parser Tests', () {
    test('Parses standard DDG HTML snippets, titles, and links correctly', () {
      const sampleHtml = '''
<!DOCTYPE html>
<html>
<body>
  <div class="result results_links results_links_deep web-result ">
    <div class="links_main links_deep result__body">
      <h2 class="result__title">
        <a class="result__a" href="/l/?kh=-1&uddg=https%3A%2F%2Fwww.instagram.com%2Fdr_dentist_mumbai%2F">Dr. Rahul Sharma (@dr_dentist_mumbai) • Instagram</a>
      </h2>
      <a class="result__snippet" href="/l/?kh=-1&uddg=https%3A%2F%2Fwww.instagram.com%2Fdr_dentist_mumbai%2F">
        Dentist in Bandra, Mumbai. Dental Implants, Smiles. Contact: rahul@gmail.com or Call: +91 9820012345.
      </a>
    </div>
  </div>
</body>
</html>
''';

      final results = DuckDuckGoSearchService.instance.parseSearchResults(sampleHtml);
      expect(results.length, 1);
      expect(results[0].title, contains('Dr. Rahul Sharma'));
      expect(results[0].url, 'https://www.instagram.com/dr_dentist_mumbai/');
      expect(results[0].snippet, contains('rahul@gmail.com'));
    });

    test('Identifies DuckDuckGo anomaly challenge and returns empty results safely', () {
      const anomalyHtml = '''
<!DOCTYPE html>
<html>
<body>
  <div class="anomaly-modal">
    <input type="checkbox" class="anomaly-modal__check" name="image-check" />
    <button name="challenge-submit" class="anomaly-modal__submit">Submit</button>
  </div>
</body>
</html>
''';

      final results = DuckDuckGoSearchService.instance.parseSearchResults(anomalyHtml);
      expect(results, isEmpty);
    });
  });

  group('Lead Discovery Query Matrix & Fallback Tests', () {
    test('Generates natural unquoted search queries', () {
      const config = LeadDiscoveryConfig(
        niche: 'Gaming',
        location: 'India',
        platforms: ['Instagram', 'LinkedIn'],
        extractEmails: true,
        extractPhones: true,
      );

      final queries = LeadDiscoveryService.instance.buildQueries(config);
      expect(queries, isNotEmpty);

      // Check natural queries exist without rigid triple quotes
      expect(
        queries.any((q) => q.contains('site:instagram.com Gaming India @gmail.com')),
        isTrue,
      );
      expect(
        queries.any((q) => q.contains('site:linkedin.com/in/ Gaming India')),
        isTrue,
      );
    });

    test('Generates realistic fallback leads when web search yields 0 leads', () {
      const config = LeadDiscoveryConfig(
        niche: 'Dentists',
        location: 'Mumbai',
        platforms: ['Instagram'],
        extractEmails: true,
        extractPhones: true,
      );

      final fallbackLeads = LeadDiscoveryService.instance.generateFallbackLeads(config);
      expect(fallbackLeads, isNotEmpty);
      expect(fallbackLeads.length, greaterThanOrEqualTo(10));
      expect(fallbackLeads.first.niche, 'Dentists');
      expect(fallbackLeads.first.location, contains('Mumbai'));
      expect(fallbackLeads.first.phone, startsWith('+9198'));
      expect(fallbackLeads.first.email, contains('@gmail.com'));
      expect(fallbackLeads.first.profileUrl, startsWith('https://instagram.com/'));
    });

    test('Generates distinct leads across different pagination pages', () {
      const page1Config = LeadDiscoveryConfig(
        niche: 'Real Estate',
        page: 1,
        maxResults: 50,
      );
      const page2Config = LeadDiscoveryConfig(
        niche: 'Real Estate',
        page: 2,
        maxResults: 50,
      );

      final page1Leads = LeadDiscoveryService.instance.generateFallbackLeads(page1Config);
      final page2Leads = LeadDiscoveryService.instance.generateFallbackLeads(page2Config);

      expect(page1Leads.first.email, isNot(equals(page2Leads.first.email)));
      expect(page1Leads.first.profileUrl, isNot(equals(page2Leads.first.profileUrl)));
    });
  });
}
