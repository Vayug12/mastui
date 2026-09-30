import 'package:flutter_test/flutter_test.dart';
import 'package:mastui/models/lead_model.dart';
import 'package:mastui/services/duckduckgo_search_service.dart';
import 'package:mastui/services/lead_discovery_service.dart';
import 'package:mastui/services/pdf_export_service.dart';

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

  group('PdfExportService Tests', () {
    test('Generates valid standard PDF 1.4 byte output with proper header and trailer', () {
      final leads = [
        Lead(
          id: '1',
          name: 'Priya Sharma',
          businessName: 'Sharma Dental Clinic',
          email: 'priya@sharmadental.com',
          phone: '+91 98765 43210',
          platform: 'Instagram',
          profileUrl: 'https://instagram.com/sharmadental',
          location: 'Delhi',
          niche: 'Dentists',
          extractedAt: DateTime.now(),
        ),
      ];

      final pdfBytes = PdfExportService.instance.generateLeadReportPdf(
        leads,
        niche: 'Dentists',
      );

      final pdfString = String.fromCharCodes(pdfBytes);
      expect(pdfString.startsWith('%PDF-1.4'), isTrue);
      expect(pdfString.contains('%%EOF'), isTrue);
      expect(pdfString.contains('/Type /Catalog'), isTrue);
      expect(pdfString.contains('/Type /Pages'), isTrue);
      expect(pdfString.contains('/Type /Page'), isTrue);
      expect(pdfString.contains('Sharma Dental Clinic'), isTrue);
      expect(pdfString.contains('priya@sharmadental.com'), isTrue);
      expect(pdfString.contains('Delhi'), isTrue);
    });

    test('Handles multi-page pagination for large lead counts cleanly', () {
      final leads = List.generate(
        25,
        (i) => Lead(
          id: 'lead-$i',
          name: 'Lead $i',
          businessName: 'Business Corp $i',
          email: 'contact$i@business.com',
          phone: '+1 555 010$i',
          platform: 'LinkedIn',
          profileUrl: 'https://linkedin.com/in/lead-$i',
          location: 'New York, USA',
          niche: 'SaaS Founders',
          extractedAt: DateTime.now(),
        ),
      );

      final pdfBytes = PdfExportService.instance.generateLeadReportPdf(
        leads,
        niche: 'SaaS Founders',
      );

      final pdfString = String.fromCharCodes(pdfBytes);
      expect(pdfString.startsWith('%PDF-1.4'), isTrue);
      expect(pdfString.contains('%%EOF'), isTrue);
      expect(pdfString.contains('/Count 3'), isTrue); // 25 leads across 3 pages (9 + 10 + 6)
      expect(pdfString.contains('Page 1 of 3'), isTrue);
      expect(pdfString.contains('Page 2 of 3'), isTrue);
      expect(pdfString.contains('Page 3 of 3'), isTrue);
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

    test('Decodes live Bing redirect tracking URLs with &amp; and base64 u parameter', () {
      // Live Bing HTML snippet with tracking URL
      const bingHtmlWithTracking = '''
<!DOCTYPE html>
<html>
<body>
  <li class="b_algo">
    <h2>
      <a href="https://www.bing.com/ck/a?!&amp;&amp;p=123&amp;u=a1aHR0cHM6Ly9saW5rZWRpbi5jb20vaW4vc2FtcGxl&amp;ntb=1">Sample Executive - Founder - Fintech | LinkedIn</a>
    </h2>
    <div class="b_caption">
      <p>Bangalore, Karnataka, India. Founder at Tech Solutions. Contact: founder@gmail.com</p>
    </div>
  </li>
</body>
</html>
''';

      final results = DuckDuckGoSearchService.instance.parseBingResults(bingHtmlWithTracking);
      expect(results.length, 1);
      expect(results[0].url, 'https://linkedin.com/in/sample');
      expect(results[0].url, isNot(contains('bing.com')));
    });

    test('cleanRedirectUrl decodes relative and absolute tracking URLs cleanly', () {
      const bingRedirect = 'https://www.bing.com/ck/a?!&amp;&amp;p=abc&amp;u=a1aHR0cHM6Ly9wbGFpZC5jb20vcmVzb3VyY2VzLw&amp;ntb=1';
      expect(
        DuckDuckGoSearchService.instance.cleanRedirectUrl(bingRedirect),
        'https://plaid.com/resources/',
      );

      const yahooRedirect = 'https://r.search.yahoo.com/_ylt=123/RU=https%3a%2f%2finstagram.com%2fdentist/RK=2/RS=456';
      expect(
        DuckDuckGoSearchService.instance.cleanRedirectUrl(yahooRedirect),
        'https://instagram.com/dentist',
      );
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
    test('Generates high-accuracy exact-phrase quoted search queries', () {
      const config = LeadDiscoveryConfig(
        niche: 'Gaming',
        location: 'India',
        platforms: ['Instagram', 'LinkedIn'],
        extractEmails: true,
        extractPhones: true,
      );

      final queries = LeadDiscoveryService.instance.buildQueries(config);
      expect(queries, isNotEmpty);

      // Check exact quoted phrase queries exist
      expect(
        queries.any((q) => q.contains('site:instagram.com "Gaming" "India" "@gmail.com"')),
        isTrue,
      );
      expect(
        queries.any((q) => q.contains('site:linkedin.com/in/ "Gaming" "India"')),
        isTrue,
      );
    });

    test('Streams empty list gracefully when web search yields 0 leads (Zero Fake Data Policy)', () async {
      DuckDuckGoSearchService.instance.testMockResults = [];
      const config = LeadDiscoveryConfig(
        niche: 'Dentists',
        location: 'Mumbai',
        platforms: ['Instagram'],
        extractEmails: true,
        extractPhones: true,
      );

      final leads = await LeadDiscoveryService.instance.discoverLeadsStream(config).toList();
      DuckDuckGoSearchService.instance.testMockResults = null;

      expect(leads, isEmpty);
    });

    test('LeadDiscoveryConfig defaults to unlimited leads (maxResults is null)', () {
      const config = LeadDiscoveryConfig(niche: 'Real Estate');
      expect(config.maxResults, isNull);
    });

    test('Filters out random 3rd-party article URLs when social platform is requested', () async {
      DuckDuckGoSearchService.instance.testMockResults = [
        const SearchResultItem(
          title: 'Top 10 Digital Marketing Agencies in India - DigitalWorld Blog',
          url: 'https://digitalworld.in/top-10-marketing-agencies',
          snippet: 'Check out the top marketing agencies. Contact us at info@digitalworld.in or 9876543210',
          sourceEngine: 'Yahoo',
        ),
        const SearchResultItem(
          title: 'Rahul Sharma (@rahul_digital) • Instagram',
          url: 'https://www.instagram.com/rahul_digital/',
          snippet: 'Digital Marketing Expert in Mumbai. Email: rahul@gmail.com | WhatsApp: +919820012345',
          sourceEngine: 'Yahoo',
        ),
      ];

      const config = LeadDiscoveryConfig(
        niche: 'Digital Marketing',
        platforms: ['Instagram'],
      );

      final leads = await LeadDiscoveryService.instance.discoverLeadsStream(config).toList();
      DuckDuckGoSearchService.instance.testMockResults = null;

      expect(leads.length, 1);
      expect(leads.first.platform, 'Instagram');
      expect(leads.first.profileUrl, 'https://instagram.com/rahul_digital/');
      expect(leads.first.email, 'rahul@gmail.com');
    });

    test('Strict Location Filter: Only returns leads matching requested location and discards other cities', () async {
      DuckDuckGoSearchService.instance.testMockResults = [
        const SearchResultItem(
          title: 'Dr. Amit Verma - Dentist in Lucknow (@lucknow_dentist) • Instagram',
          url: 'https://www.instagram.com/lucknow_dentist/',
          snippet: 'Best Dental Clinic in Hazratganj, Lucknow. Email: amit@lucknowdental.com | Phone: +919876543210',
          sourceEngine: 'Bing',
        ),
        const SearchResultItem(
          title: 'Dr. Rohit Mehta - Dentist in Delhi (@delhi_dentist) • Instagram',
          url: 'https://www.instagram.com/delhi_dentist/',
          snippet: 'Dental specialist in Connaught Place, New Delhi. Email: rohit@delhidental.com | Phone: +919811122233',
          sourceEngine: 'Bing',
        ),
        const SearchResultItem(
          title: 'Dr. Pooja Patil - Mumbai Dental (@mumbai_smiles) • Instagram',
          url: 'https://www.instagram.com/mumbai_smiles/',
          snippet: 'Cosmetic Dentist in Bandra West, Mumbai. Email: pooja@mumbaidoc.com | Phone: +919820011223',
          sourceEngine: 'Bing',
        ),
      ];

      const config = LeadDiscoveryConfig(
        niche: 'Dentist',
        location: 'Lucknow',
        platforms: ['Instagram'],
      );

      final leads = await LeadDiscoveryService.instance.discoverLeadsStream(config).toList();
      DuckDuckGoSearchService.instance.testMockResults = null;

      expect(leads.length, 1);
      expect(leads.first.name, contains('Amit Verma'));
      expect(leads.first.email, 'amit@lucknowdental.com');
      expect(leads.first.location, 'Lucknow');
    });

    test('Strict Location Filter: Supports multi-word location matching (e.g. Lucknow, UP)', () async {
      DuckDuckGoSearchService.instance.testMockResults = [
        const SearchResultItem(
          title: 'Lucknow Cafe (@lucknowcafe) • Instagram',
          url: 'https://www.instagram.com/lucknowcafe/',
          snippet: 'Authentic dining in Gomti Nagar, Lucknow. Email: info@lucknowcafe.com',
          sourceEngine: 'Yahoo',
        ),
        const SearchResultItem(
          title: 'Kanpur Sweets (@kanpursweets) • Instagram',
          url: 'https://www.instagram.com/kanpursweets/',
          snippet: 'Finest sweets in Kanpur. Email: kanpur@sweets.com',
          sourceEngine: 'Yahoo',
        ),
      ];

      const config = LeadDiscoveryConfig(
        niche: 'Cafe',
        location: 'Lucknow, UP',
        platforms: ['Instagram'],
      );

      final leads = await LeadDiscoveryService.instance.discoverLeadsStream(config).toList();
      DuckDuckGoSearchService.instance.testMockResults = null;

      expect(leads.length, 1);
      expect(leads.first.email, 'info@lucknowcafe.com');
    });

    test('Hybrid Architecture: Does NOT misidentify sentences like "visit us at brand.com" as emails', () async {
      DuckDuckGoSearchService.instance.testMockResults = [
        const SearchResultItem(
          title: 'Fashion Brand Store (@fashion_store) • Instagram',
          url: 'https://www.instagram.com/fashion_store/',
          snippet: 'Trendy fashion in Delhi. Visit us at mybrand.com or shop at store.in for new arrivals.',
          sourceEngine: 'Yahoo',
        ),
      ];

      const config = LeadDiscoveryConfig(
        niche: 'Fashion',
        platforms: ['Instagram'],
        extractEmails: false,
        extractPhones: false,
      );

      final leads = await LeadDiscoveryService.instance.discoverLeadsStream(config).toList();
      DuckDuckGoSearchService.instance.testMockResults = null;

      expect(leads.length, 1);
      // "us at mybrand.com" or "shop at store.in" MUST NOT be parsed as emails
      expect(leads.first.email, isNull);
    });

    test('Hybrid Architecture: Rejects placeholder domains and generic platform emails', () async {
      DuckDuckGoSearchService.instance.testMockResults = [
        const SearchResultItem(
          title: 'Designer Studio (@designer_studio) • Instagram',
          url: 'https://www.instagram.com/designer_studio/',
          snippet: 'Studio in Bangalore. Contact: support@instagram.com or user@example.com for queries.',
          sourceEngine: 'Yahoo',
        ),
      ];

      const config = LeadDiscoveryConfig(
        niche: 'Design',
        platforms: ['Instagram'],
        extractEmails: false,
        extractPhones: false,
      );

      final leads = await LeadDiscoveryService.instance.discoverLeadsStream(config).toList();
      DuckDuckGoSearchService.instance.testMockResults = null;

      expect(leads.length, 1);
      // Both support@instagram.com and user@example.com MUST be blacklisted
      expect(leads.first.email, isNull);
    });

    test('Hybrid Architecture: Rejects prices and pin codes mistakenly formatted as phone numbers', () async {
      DuckDuckGoSearchService.instance.testMockResults = [
        const SearchResultItem(
          title: 'Apparel Hub (@apparel_hub) • Instagram',
          url: 'https://www.instagram.com/apparel_hub/',
          snippet: 'Best clothes in Mumbai. Special wedding suit price: 1500099999. Pincode: 110001.',
          sourceEngine: 'Yahoo',
        ),
      ];

      const config = LeadDiscoveryConfig(
        niche: 'Apparel',
        platforms: ['Instagram'],
        extractEmails: false,
        extractPhones: false,
      );

      final leads = await LeadDiscoveryService.instance.discoverLeadsStream(config).toList();
      DuckDuckGoSearchService.instance.testMockResults = null;

      expect(leads.length, 1);
      expect(leads.first.phone, isNull);
    });
  });
}

