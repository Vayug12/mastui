import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lead_model.dart';

/// Manages local persistence, clipboard copying, CSV file saving, and sharing for leads.
class LeadStorageService {
  LeadStorageService._();
  static final instance = LeadStorageService._();

  static const String _storageKey = 'saved_lead_records_v1';

  /// Loads all saved leads from SharedPreferences.
  Future<List<Lead>> loadLeads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey);
      if (rawList == null || rawList.isEmpty) return [];

      return rawList
          .map((item) {
            try {
              return Lead.fromJson(jsonDecode(item) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<Lead>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves a list of leads with automatic deduplication.
  Future<void> saveLeads(List<Lead> leads) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = leads.map((l) => jsonEncode(l.toJson())).toList();
      await prefs.setStringList(_storageKey, serialized);
    } catch (_) {}
  }

  /// Clears all stored leads.
  Future<void> clearLeads() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Generates a full CSV string with headers from the given leads.
  String generateCsv(List<Lead> leads) {
    final buffer = StringBuffer();
    buffer.writeln(Lead.csvHeader());
    for (final lead in leads) {
      buffer.writeln(lead.toCsvRow());
    }
    return buffer.toString();
  }

  /// Saves the CSV file locally on the phone/device.
  Future<File?> saveCsvFile(List<Lead> leads, {String? niche}) async {
    if (leads.isEmpty) return null;
    try {
      final csvString = generateCsv(leads);
      final safeNiche = (niche != null && niche.trim().isNotEmpty)
          ? niche.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          : 'leads';
      final fileName = 'leads_${safeNiche}_${DateTime.now().millisecondsSinceEpoch}.csv';

      Directory directory;
      try {
        directory = await getApplicationDocumentsDirectory();
      } catch (_) {
        directory = await getTemporaryDirectory();
      }

      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvString);
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Exports and invokes native save/share sheet so the user can download
  /// or save the CSV locally on their phone (Downloads, Files, Google Drive, WhatsApp, etc.).
  Future<bool> exportAndDownloadCsv(List<Lead> leads, {String? niche}) async {
    if (leads.isEmpty) return false;
    try {
      final file = await saveCsvFile(leads, niche: niche);
      if (file == null || !await file.exists()) {
        final csv = generateCsv(leads);
        await Clipboard.setData(ClipboardData(text: csv));
        return true;
      }

      final xFile = XFile(
        file.path,
        mimeType: 'text/csv',
        name: file.uri.pathSegments.last,
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          subject: 'GetLead Export (${leads.length} leads)',
          text: 'Exported ${leads.length} business leads from GetLead.',
        ),
      );
      return true;
    } catch (_) {
      final csv = generateCsv(leads);
      await Clipboard.setData(ClipboardData(text: csv));
      return true;
    }
  }

  /// Copies all unique email addresses from leads to clipboard.
  Future<int> copyAllEmailsToClipboard(List<Lead> leads) async {
    final emails = leads
        .map((l) => l.email?.trim())
        .where((e) => e != null && e.isNotEmpty)
        .toSet()
        .toList();

    if (emails.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: emails.join(', ')));
    }
    return emails.length;
  }

  /// Copies all unique phone numbers from leads to clipboard.
  Future<int> copyAllPhonesToClipboard(List<Lead> leads) async {
    final phones = leads
        .map((l) => l.phone?.trim())
        .where((p) => p != null && p.isNotEmpty)
        .toSet()
        .toList();

    if (phones.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: phones.join(', ')));
    }
    return phones.length;
  }
}
