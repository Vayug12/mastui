import '../utils/lead_sanitizer.dart';

/// Structured lead representation discovered across public profiles and directories.
class Lead {
  final String id;
  final String name;
  final String? businessName;
  final String? email;
  final String? phone;
  final String? website;
  final String platform;
  final String profileUrl;
  final String? location;
  final String? niche;
  final String? bioSnippet;
  final DateTime extractedAt;
  final bool isWorkEmail;
  final String? emailStatus;
  final List<String>? alternativeEmails;
  final String? decisionMakerName;
  final String? decisionMakerRole;
  final String? decisionMakerEmail;
  final String? decisionMakerLinkedIn;

  const Lead({
    required this.id,
    required this.name,
    this.businessName,
    this.email,
    this.phone,
    this.website,
    required this.platform,
    required this.profileUrl,
    this.location,
    this.niche,
    this.bioSnippet,
    required this.extractedAt,
    this.isWorkEmail = false,
    this.emailStatus,
    this.alternativeEmails,
    this.decisionMakerName,
    this.decisionMakerRole,
    this.decisionMakerEmail,
    this.decisionMakerLinkedIn,
  });

  bool get hasContactInfo =>
      (email != null && email!.isNotEmpty) ||
      (phone != null && phone!.isNotEmpty);

  /// Primary clean display title (e.g. "Katiliana" or "Sugardot" or "Sharma Dental Clinic")
  /// Automatically strips search engine breadcrumbs like "//www. instagram . com >"
  /// and ignores platform junk like "Instagram https".
  String get displayName {
    final cleanBiz = LeadSanitizer.cleanTitle(businessName);
    final cleanN = LeadSanitizer.cleanTitle(name);

    if (cleanBiz.isNotEmpty && !LeadSanitizer.isPlatformJunk(cleanBiz)) {
      final parsed = LeadSanitizer.parseNameAndHandle(
        cleanBiz,
        fallbackHandle: cleanN.isNotEmpty && !LeadSanitizer.isPlatformJunk(cleanN) ? cleanN : null,
      );
      return parsed.$1;
    }

    if (cleanN.isNotEmpty && !LeadSanitizer.isPlatformJunk(cleanN)) {
      final parsed = LeadSanitizer.parseNameAndHandle(cleanN);
      return parsed.$1;
    }

    return 'Business Lead';
  }

  /// Secondary subtitle (e.g. "@katyta__b", "@sugardotsolutions", or Contact Person name).
  /// Returns null if identical to displayName, empty, or platform junk.
  String? get secondaryDisplayName {
    final cleanBiz = LeadSanitizer.cleanTitle(businessName);
    final cleanN = LeadSanitizer.cleanTitle(name);

    if (cleanBiz.isNotEmpty && !LeadSanitizer.isPlatformJunk(cleanBiz)) {
      final parsed = LeadSanitizer.parseNameAndHandle(
        cleanBiz,
        fallbackHandle: cleanN.isNotEmpty && !LeadSanitizer.isPlatformJunk(cleanN) ? cleanN : null,
      );
      if (parsed.$2 != null && parsed.$2 != displayName && !LeadSanitizer.isPlatformJunk(parsed.$2)) {
        return parsed.$2;
      }
      if (cleanN.isNotEmpty && cleanN != displayName && !LeadSanitizer.isPlatformJunk(cleanN)) {
        return cleanN;
      }
    }

    if (cleanN.isNotEmpty && !LeadSanitizer.isPlatformJunk(cleanN)) {
      final parsed = LeadSanitizer.parseNameAndHandle(cleanN);
      if (parsed.$2 != null && parsed.$2 != displayName && !LeadSanitizer.isPlatformJunk(parsed.$2)) {
        return parsed.$2;
      }
    }

    return null;
  }

  /// Whether lead has a valid, distinct external company website (not social profile or duplicate).
  bool get hasDistinctWebsite => LeadSanitizer.isDistinctWebsite(website, profileUrl);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'businessName': businessName,
        'email': email,
        'phone': phone,
        'website': website,
        'platform': platform,
        'profileUrl': profileUrl,
        'location': location,
        'niche': niche,
        'bioSnippet': bioSnippet,
        'extractedAt': extractedAt.toIso8601String(),
        'isWorkEmail': isWorkEmail,
        'emailStatus': emailStatus,
        'alternativeEmails': alternativeEmails,
        'decisionMakerName': decisionMakerName,
        'decisionMakerRole': decisionMakerRole,
        'decisionMakerEmail': decisionMakerEmail,
        'decisionMakerLinkedIn': decisionMakerLinkedIn,
      };

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      businessName: json['businessName'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      platform: json['platform'] as String? ?? 'Web',
      profileUrl: json['profileUrl'] as String? ?? '',
      location: json['location'] as String?,
      niche: json['niche'] as String?,
      bioSnippet: json['bioSnippet'] as String?,
      extractedAt: json['extractedAt'] != null
          ? DateTime.tryParse(json['extractedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isWorkEmail: json['isWorkEmail'] as bool? ?? false,
      emailStatus: json['emailStatus'] as String?,
      alternativeEmails: (json['alternativeEmails'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      decisionMakerName: json['decisionMakerName'] as String?,
      decisionMakerRole: json['decisionMakerRole'] as String?,
      decisionMakerEmail: json['decisionMakerEmail'] as String?,
      decisionMakerLinkedIn: json['decisionMakerLinkedIn'] as String?,
    );
  }

  /// Exports lead as a comma-separated row for CSV export.
  String toCsvRow() {
    String escape(String? val) {
      if (val == null || val.isEmpty) return '""';
      final clean = val.replaceAll('"', '""').replaceAll('\n', ' ').trim();
      return '"$clean"';
    }

    String escapeUrl(String? url) {
      if (url == null || url.trim().isEmpty) return '""';
      var clean = url.replaceAll('"', '""').replaceAll('\n', ' ').trim();
      if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
        clean = 'https://$clean';
      }
      return '"$clean"';
    }

    final contactPerson = secondaryDisplayName ??
        (name != displayName && !LeadSanitizer.isPlatformJunk(name) ? name : '');
    final cleanWebsite = hasDistinctWebsite ? website : '';

    return [
      escape(displayName),
      escape(contactPerson),
      escape(email),
      escape(phone),
      escape(platform),
      escape(location),
      escape(niche),
      escapeUrl(cleanWebsite),
      escapeUrl(profileUrl),
      escape(decisionMakerName),
      escape(decisionMakerRole),
      escape(decisionMakerEmail),
      escapeUrl(decisionMakerLinkedIn),
    ].join(',');
  }

  static String csvHeader() {
    return [
      '"Business / Title"',
      '"Contact Person"',
      '"Email"',
      '"Phone"',
      '"Platform"',
      '"Location"',
      '"Niche"',
      '"Website"',
      '"Profile URL"',
      '"Decision Maker"',
      '"Role"',
      '"Founder Email"',
      '"Founder LinkedIn"',
    ].join(',');
  }

  Lead copyWith({
    String? id,
    String? name,
    String? businessName,
    String? email,
    String? phone,
    String? website,
    String? platform,
    String? profileUrl,
    String? location,
    String? niche,
    String? bioSnippet,
    DateTime? extractedAt,
    bool? isWorkEmail,
    String? emailStatus,
    List<String>? alternativeEmails,
    String? decisionMakerName,
    String? decisionMakerRole,
    String? decisionMakerEmail,
    String? decisionMakerLinkedIn,
  }) {
    return Lead(
      id: id ?? this.id,
      name: name ?? this.name,
      businessName: businessName ?? this.businessName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      platform: platform ?? this.platform,
      profileUrl: profileUrl ?? this.profileUrl,
      location: location ?? this.location,
      niche: niche ?? this.niche,
      bioSnippet: bioSnippet ?? this.bioSnippet,
      extractedAt: extractedAt ?? this.extractedAt,
      isWorkEmail: isWorkEmail ?? this.isWorkEmail,
      emailStatus: emailStatus ?? this.emailStatus,
      alternativeEmails: alternativeEmails ?? this.alternativeEmails,
      decisionMakerName: decisionMakerName ?? this.decisionMakerName,
      decisionMakerRole: decisionMakerRole ?? this.decisionMakerRole,
      decisionMakerEmail: decisionMakerEmail ?? this.decisionMakerEmail,
      decisionMakerLinkedIn: decisionMakerLinkedIn ?? this.decisionMakerLinkedIn,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Lead &&
          runtimeType == other.runtimeType &&
          ((email != null && email == other.email) ||
              (phone != null && phone == other.phone) ||
              profileUrl == other.profileUrl);

  @override
  int get hashCode =>
      (email?.hashCode ?? 0) ^ (phone?.hashCode ?? 0) ^ profileUrl.hashCode;
}
