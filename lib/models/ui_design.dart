/// A single UI design entry: the screenshot users browse and the
/// prompt they copy into v0 / Lovable / Cursor / Claude.
class UiDesign {
  const UiDesign({
    required this.id,
    required this.title,
    required this.category,
    required this.platforms,
    required this.styleTags,
    required this.prompt,
    this.packId,
    this.packName,
    this.order = 0,
    this.imageAsset,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String category;
  /// Targets this design was made for: `mobile`, `web`, or both.
  final List<String> platforms;
  final List<String> styleTags;
  final String prompt;

  /// Style pack this screen belongs to (e.g. `soft-dark`), if any. Screens of
  /// one pack share a single style + palette so they read as one app.
  final String? packId;
  final String? packName;

  /// Position within the pack's screen set.
  final int order;

  /// Bundled asset path, for designs shipped inside the APK.
  final String? imageAsset;

  /// R2/CDN URL, for designs fetched over the air. Takes second place to
  /// [imageAsset] so a bundled copy renders instantly and works offline.
  final String? imageUrl;

  factory UiDesign.fromJson(Map<String, dynamic> json) => UiDesign(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        platforms: _platformsFrom(json['platforms']),
        styleTags: (json['styleTags'] as List<dynamic>? ?? []).cast<String>(),
        prompt: json['prompt'] as String,
        packId: json['packId'] as String?,
        packName: json['packName'] as String?,
        order: (json['order'] as num?)?.toInt() ?? 0,
        imageAsset: json['imageAsset'] as String?,
        imageUrl: json['imageUrl'] as String?,
      );

  /// Catalogs created before platform filtering are mobile-screen designs.
  static List<String> _platformsFrom(Object? value) {
    if (value is! List) return const ['mobile'];
    final platforms = value
        .whereType<String>()
        .where((platform) => platform == 'mobile' || platform == 'web')
        .toSet()
        .toList();
    return platforms.isEmpty ? const ['mobile'] : platforms;
  }
}
