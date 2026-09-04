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
  });

  bool get hasContactInfo =>
      (email != null && email!.isNotEmpty) ||
      (phone != null && phone!.isNotEmpty);

  String get displayName =>
      businessName != null && businessName!.isNotEmpty
          ? businessName!
          : (name.isNotEmpty ? name : 'Business Lead');

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
    );
  }

  /// Exports lead as a comma-separated row for CSV export.
  String toCsvRow() {
    String escape(String? val) {
      if (val == null || val.isEmpty) return '""';
      final clean = val.replaceAll('"', '""').replaceAll('\n', ' ').trim();
      return '"$clean"';
    }

    return [
      escape(displayName),
      escape(name),
      escape(email),
      escape(phone),
      escape(platform),
      escape(location),
      escape(niche),
      escape(website),
      escape(profileUrl),
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
