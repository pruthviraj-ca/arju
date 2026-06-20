/// migration_service.dart
///
/// One-time data migration utility for the TruAssets CRM.
/// Upgrades existing lead documents that store `createdAt` as a
/// date-only string (e.g. "2025-06-10") to full ISO 8601 date-time
/// strings (e.g. "2025-06-10T14:30:00.000"). Runs once per device,
/// guarded by a [SharedPreferences] flag.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Static utility that upgrades legacy lead `createdAt` fields to
/// include full date-time timestamps.
class MigrationService {
  /// [SharedPreferences] key used to persist the migration completion flag.
  static const String _migrationKey = 'leads_date_time_migration_completed';

  // ─── Public Entry Point ────────────────────────────────────────────────────

  /// Runs the `createdAt` date-time migration for the current user's leads.
  ///
  /// The migration is idempotent — it only runs once per device. Subsequent
  /// calls return immediately after reading the completion flag from
  /// [SharedPreferences].
  ///
  /// Leads whose `createdAt` field is empty or contains only a date (no 'T'
  /// separator) will be updated to the current date-time.
  static Future<void> run() async {
    try {
      // Guard: skip if already completed on this device.
      final prefs = await SharedPreferences.getInstance();
      final isCompleted = prefs.getBool(_migrationKey) ?? false;
      if (isCompleted) {
        debugPrint('MigrationService: Already completed. Skipping.');
        return;
      }

      // Guard: skip if no authenticated user.
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('MigrationService: No authenticated user. Skipping.');
        return;
      }

      debugPrint('MigrationService: Starting migration for user: $uid…');

      await _migrateLeadsForUser(uid);

      // Mark migration as complete so it never runs again on this device.
      await prefs.setBool(_migrationKey, true);
    } catch (e) {
      debugPrint('MigrationService: Failed with error: $e');
    }
  }

  // ─── Private Helpers ───────────────────────────────────────────────────────

  /// Fetches all leads for [uid] and batch-updates any that have a legacy
  /// date-only `createdAt` field.
  static Future<void> _migrateLeadsForUser(String uid) async {
    final db = FirebaseFirestore.instance;
    final leadsRef = db.collection('users').doc(uid).collection('leads');
    final snapshot = await leadsRef.get();

    if (snapshot.docs.isEmpty) {
      debugPrint('MigrationService: No leads to migrate. Completing.');
      return;
    }

    final fallbackTimestamp = DateTime.now().toIso8601String();
    final batch = db.batch();
    int migrateCount = 0;

    for (final doc in snapshot.docs) {
      if (_needsDateTimeMigration(doc.data())) {
        batch.update(doc.reference, {'createdAt': fallbackTimestamp});
        migrateCount++;
      }
    }

    if (migrateCount > 0) {
      await batch.commit();
      debugPrint(
          'MigrationService: Successfully migrated $migrateCount leads.');
    } else {
      debugPrint(
          'MigrationService: All leads already have date-time timestamps.');
    }
  }

  /// Returns `true` if a lead document's `createdAt` field is missing or
  /// formatted as a date-only string (no ISO 'T' separator).
  static bool _needsDateTimeMigration(Map<String, dynamic> data) {
    final rawCreatedAt = data['createdAt'] as String? ?? '';
    return rawCreatedAt.isEmpty ||
        rawCreatedAt.length <= 10 ||
        !rawCreatedAt.contains('T');
  }
}
