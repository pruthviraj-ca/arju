/// site_visit_model.dart
///
/// Defines the [SiteVisitModel] data class representing a scheduled
/// property site visit in the TruAssets CRM. Tracks the visit date,
/// time, associated lead, and current status (scheduled/done/missed).

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a scheduled site visit for a real estate lead.
///
/// Site visits are stored as a top-level collection in Firestore,
/// linked to their parent lead via [leadId]. Status transitions
/// follow: scheduled → done | missed.
class SiteVisitModel {
  /// Firestore document ID (empty string for new, unsaved visits).
  final String id;

  /// The ID of the lead this visit is associated with.
  final String leadId;

  /// Full name of the client attending the visit.
  final String clientName;

  /// Property or project name being visited.
  final String property;

  /// ISO date string for the scheduled visit (e.g., '2025-06-15').
  final String visitDate;

  /// Formatted time string for the visit (e.g., '10:30 AM').
  final String visitTime;

  /// Current visit status: 'scheduled', 'done', or 'missed'.
  final String status;

  const SiteVisitModel({
    required this.id,
    required this.leadId,
    required this.clientName,
    required this.property,
    required this.visitDate,
    required this.visitTime,
    required this.status,
  });

  /// Creates a [SiteVisitModel] from a Firestore document snapshot.
  ///
  /// [doc] - The Firestore document containing site visit data.
  /// Falls back to sensible defaults for any missing fields.
  factory SiteVisitModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SiteVisitModel(
      id: doc.id,
      leadId: data['leadId'] as String? ?? '',
      clientName: data['clientName'] as String? ?? '',
      property: data['property'] as String? ?? '',
      visitDate: data['visitDate'] as String? ?? '',
      visitTime: data['visitTime'] as String? ?? '',
      status: data['status'] as String? ?? 'scheduled',
    );
  }

  /// Converts this site visit model into a Firestore-compatible map.
  ///
  /// Used when creating or updating a site visit document in Firestore.
  Map<String, dynamic> toMap() {
    return {
      'leadId': leadId,
      'clientName': clientName,
      'property': property,
      'visitDate': visitDate,
      'visitTime': visitTime,
      'status': status,
    };
  }
}
