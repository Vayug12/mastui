import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ui_design.dart';

/// Loads the design catalog from the Cloudflare Worker.
class DesignRepository {
  static const _catalogUrl =
      'https://mastui-api.sanjeev-yadav1201.workers.dev/catalog';

  List<UiDesign>? _cache;

  /// Force-clear the in-memory cache so the next [load] call fetches fresh
  /// data from the network. Called by pull-to-refresh.
  void refresh() {
    _cache = null;
  }

  Future<List<UiDesign>> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final response = await http
        .get(Uri.parse(_catalogUrl))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final designs = _parseCatalog(response.body);
      _cache = designs;
      return designs;
    }

    throw Exception('Failed to load designs (${response.statusCode})');
  }

  List<UiDesign> _parseCatalog(String json) {
    final list = (jsonDecode(json) as List<dynamic>)
        .map((entry) => UiDesign.fromJson(entry as Map<String, dynamic>))
        .toList();
    list.shuffle();
    return list;
  }

  /// Category filter values for the chip row — 'All' plus whatever the
  /// catalog actually contains, so an empty category never shows a chip.
  static List<String> categoriesOf(List<UiDesign> designs) => [
        'All',
        ...{for (final d in designs) d.category},
      ];

  /// Groups the catalog's pack screens into style packs, keeping each pack's
  /// screens in their designed order.
  static List<StylePack> packsOf(List<UiDesign> designs) {
    final byPack = <String, List<UiDesign>>{};
    for (final d in designs) {
      final packId = d.packId;
      if (packId != null) (byPack[packId] ??= []).add(d);
    }
    return [
      for (final entry in byPack.entries)
        StylePack(
          id: entry.key,
          name: entry.value.first.packName ?? entry.key,
          screens: entry.value..sort((a, b) => a.order.compareTo(b.order)),
        ),
    ];
  }

  /// Extracts all displayable items (both StylePacks and standalone UiDesigns)
  /// maintaining the randomized order of [designs].
  static List<Object> itemsOf(List<UiDesign> designs) {
    final addedPacks = <String>{};
    final items = <Object>[];

    for (final d in designs) {
      final packId = d.packId;
      if (packId != null) {
        if (!addedPacks.contains(packId)) {
          addedPacks.add(packId);
          final packScreens = designs.where((x) => x.packId == packId).toList()
            ..sort((a, b) => a.order.compareTo(b.order));
          items.add(
            StylePack(
              id: packId,
              name: packScreens.first.packName ?? packId,
              screens: packScreens,
            ),
          );
        }
      } else {
        items.add(d);
      }
    }
    return items;
  }
}

/// One visual style rendered as a consistent set of foundation screens —
/// same palette, typography and components, so it reads as one real app.
class StylePack {
  const StylePack({required this.id, required this.name, required this.screens});

  final String id;
  final String name;
  final List<UiDesign> screens;

  /// Cover image: the Home screen if present, else the first screen.
  UiDesign get cover => screens.firstWhere(
        (s) => s.category == 'Home',
        orElse: () => screens.first,
      );

  /// Style tags minus the palette name repeated on every screen.
  List<String> get tags => screens.first.styleTags;

  /// Targets represented by this pack's screens, ready for a future platform filter.
  List<String> get platforms => <String>{
        for (final screen in screens) ...screen.platforms,
      }.toList();
}
