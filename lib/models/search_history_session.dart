import '../models/lead_model.dart';

/// Represents a saved search session containing discovered leads and search parameters.
class SearchHistorySession {
  final String id;
  final String niche;
  final String? location;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Lead> leads;

  const SearchHistorySession({
    required this.id,
    required this.niche,
    this.location,
    required this.createdAt,
    required this.updatedAt,
    required this.leads,
  });

  int get leadCount => leads.length;

  SearchHistorySession copyWith({
    String? id,
    String? niche,
    String? location,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Lead>? leads,
  }) {
    return SearchHistorySession(
      id: id ?? this.id,
      niche: niche ?? this.niche,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      leads: leads ?? this.leads,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'niche': niche,
        'location': location,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'leads': leads.map((lead) => lead.toJson()).toList(),
      };

  factory SearchHistorySession.fromJson(Map<String, dynamic> json) {
    final rawLeads = json['leads'] as List<dynamic>? ?? [];
    final leads = rawLeads
        .map((item) {
          try {
            return Lead.fromJson(item as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Lead>()
        .toList();

    return SearchHistorySession(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      niche: json['niche'] as String? ?? 'Leads',
      location: json['location'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      leads: leads,
    );
  }
}
