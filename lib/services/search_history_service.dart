import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lead_model.dart';
import '../models/search_history_session.dart';

/// Manages local persistence, deduplication, and retrieval of lead discovery search sessions.
class SearchHistoryService {
  SearchHistoryService._();
  static final instance = SearchHistoryService._();

  static const String _storageKey = 'search_history_sessions_v1';
  static const int _maxSessions = 50;

  /// Loads all saved search sessions, ordered most recent first.
  Future<List<SearchHistorySession>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey);
      if (rawList == null || rawList.isEmpty) return [];

      final sessions = rawList
          .map((item) {
            try {
              return SearchHistorySession.fromJson(
                jsonDecode(item) as Map<String, dynamic>,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<SearchHistorySession>()
          .toList();

      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sessions;
    } catch (_) {
      return [];
    }
  }

  /// Saves a list of search sessions to SharedPreferences.
  Future<void> saveHistory(List<SearchHistorySession> sessions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final capped = sessions.take(_maxSessions).toList();
      final serialized = capped.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_storageKey, serialized);
    } catch (_) {}
  }

  /// Automatically records or updates a search session.
  /// Prevents duplicate sessions by merging leads for identical niche + location.
  Future<void> recordSearchSession({
    required String niche,
    String? location,
    required List<Lead> leads,
  }) async {
    final cleanNiche = niche.trim();
    if (cleanNiche.isEmpty || leads.isEmpty) return;

    final cleanLocation =
        (location != null && location.trim().isNotEmpty) ? location.trim() : null;

    final sessions = await loadHistory();

    // Check for an existing session with identical niche and location (case-insensitive)
    final existingIndex = sessions.indexWhere(
      (s) =>
          s.niche.trim().toLowerCase() == cleanNiche.toLowerCase() &&
          (s.location ?? '').trim().toLowerCase() ==
              (cleanLocation ?? '').trim().toLowerCase(),
    );

    if (existingIndex >= 0) {
      final existingSession = sessions[existingIndex];

      // Merge leads without duplicates
      final leadMap = <String, Lead>{};
      for (final lead in existingSession.leads) {
        final key = _leadKey(lead);
        leadMap[key] = lead;
      }
      for (final lead in leads) {
        final key = _leadKey(lead);
        leadMap[key] = lead;
      }

      final updatedSession = existingSession.copyWith(
        leads: leadMap.values.toList(),
        updatedAt: DateTime.now(),
      );

      sessions.removeAt(existingIndex);
      sessions.insert(0, updatedSession);
    } else {
      // Deduplicate given leads first
      final uniqueLeads = <String, Lead>{};
      for (final lead in leads) {
        uniqueLeads[_leadKey(lead)] = lead;
      }

      final newSession = SearchHistorySession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        niche: cleanNiche,
        location: cleanLocation,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        leads: uniqueLeads.values.toList(),
      );

      sessions.insert(0, newSession);
    }

    await saveHistory(sessions);
  }

  /// Deletes a specific session by ID.
  Future<void> deleteSession(String sessionId) async {
    final sessions = await loadHistory();
    sessions.removeWhere((s) => s.id == sessionId);
    await saveHistory(sessions);
  }

  /// Clears all stored search history sessions.
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }

  /// Generates a unique key for a lead to prevent duplicates.
  String _leadKey(Lead lead) {
    if (lead.email != null && lead.email!.trim().isNotEmpty) {
      return lead.email!.trim().toLowerCase();
    }
    if (lead.profileUrl.trim().isNotEmpty) {
      return lead.profileUrl.trim().toLowerCase();
    }
    if (lead.phone != null && lead.phone!.trim().isNotEmpty) {
      return lead.phone!.trim();
    }
    return '${lead.name.toLowerCase()}_${lead.platform}';
  }
}
