/// lead_model.dart
///
/// Defines the [LeadModel] data class representing a real estate lead
/// in the TruAssets CRM system. Handles serialization to/from Firestore
/// documents and provides immutable data access via [copyWith].

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single real estate lead in the CRM pipeline.
///
/// Each lead contains client contact information, pipeline status,
/// follow-up scheduling data, and call history metadata.
class LeadModel {
  /// Firestore document ID (empty string for new, unsaved leads).
  final String id;

  /// Full name of the prospective client.
  final String clientName;

  /// Client's phone number (primary contact).
  final String phone;

  /// Property or project the client is interested in.
  final String property;

  /// Current pipeline status (e.g., 'new', 'called', 'follow-up', 'won').
  final String status;

  /// Most recent outcome tag from a call note (e.g., 'Interested', 'Callback').
  final String lastTag;

  /// ISO date string for the next scheduled follow-up, or 'none' if unset.
  final String followUpDate;

  /// ISO date-time string for the next scheduled follow-up, or null if unset.
  final String? followUpDateTime;

  /// Preview text of the most recent call note.
  final String lastNote;

  /// Whether this lead is still active in the pipeline.
  final bool isActive;

  /// Formatted string of the last call's duration (e.g., '2m 30s').
  final String callDuration;

  /// ISO 8601 timestamp of when this lead was created/imported.
  final String createdAt;

  /// Total number of calls made to this lead.
  final int callsCount;

  /// Client's alternate phone number (optional).
  final String alternatePhone;

  /// Client's email address (optional).
  final String email;

  /// Lead source (e.g. 'Meta', 'Google', etc.).
  final String source;

  /// Lead temperature (e.g. 'Hot', 'Warm', 'Cold', or empty).
  final String leadTemperature;

  /// Number of times email has been edited (max 1 edit allowed).
  final int emailEditCount;

  /// Number of times lead source has been edited (max 1 edit allowed).
  final int leadSourceEditCount;

  const LeadModel({
    required this.id,
    required this.clientName,
    required this.phone,
    required this.property,
    required this.status,
    required this.lastTag,
    required this.followUpDate,
    this.followUpDateTime,
    required this.lastNote,
    required this.isActive,
    required this.callDuration,
    required this.createdAt,
    required this.callsCount,
    this.alternatePhone = '',
    this.email = '',
    this.source = '',
    this.leadTemperature = '',
    this.emailEditCount = 0,
    this.leadSourceEditCount = 0,
  });

  /// Creates a [LeadModel] from a Firestore document snapshot.
  ///
  /// [doc] - The Firestore document containing lead data.
  /// Falls back to sensible defaults for any missing fields.
  factory LeadModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LeadModel(
      id: doc.id,
      clientName: data['clientName'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      property: data['propertyName'] as String? ?? data['property'] as String? ?? '',
      status: data['status'] as String? ?? 'new',
      lastTag: data['lastTag'] as String? ?? '',
      followUpDate: data['followUpDate'] as String? ?? 'none',
      followUpDateTime: data['followUpDateTime'] as String?,
      lastNote: data['lastNote'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      callDuration: data['callDuration'] as String? ?? '—',
      createdAt: _parseCreatedAt(data['createdAt']),
      callsCount: data['callsCount'] as int? ?? 0,
      alternatePhone: data['alternatePhone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      source: data['leadSource'] as String? ?? data['source'] as String? ?? '',
      leadTemperature: data['leadTemperature'] as String? ?? '',
      emailEditCount: data['emailEditCount'] as int? ?? 0,
      leadSourceEditCount: data['leadSourceEditCount'] as int? ?? 0,
    );
  }

  /// Converts this lead model into a Firestore-compatible map.
  ///
  /// Used when creating or updating a lead document in Firestore.
  Map<String, dynamic> toMap() {
    return {
      'clientName': clientName,
      'phone': phone,
      'property': property,
      'propertyName': property,
      'status': status,
      'lastTag': lastTag,
      'followUpDate': followUpDate,
      'followUpDateTime': followUpDateTime,
      'lastNote': lastNote,
      'isActive': isActive,
      'callDuration': callDuration,
      'createdAt': createdAt,
      'callsCount': callsCount,
      'alternatePhone': alternatePhone,
      'email': email,
      'source': source,
      'leadSource': source,
      'leadTemperature': leadTemperature,
      'emailEditCount': emailEditCount,
      'leadSourceEditCount': leadSourceEditCount,
    };
  }

  /// Creates a copy of this lead with optional field overrides.
  ///
  /// Any parameter left as `null` retains the current value.
  LeadModel copyWith({
    String? id,
    String? clientName,
    String? phone,
    String? property,
    String? status,
    String? lastTag,
    String? followUpDate,
    String? followUpDateTime,
    String? lastNote,
    bool? isActive,
    String? callDuration,
    String? createdAt,
    int? callsCount,
    String? alternatePhone,
    String? email,
    String? source,
    String? leadTemperature,
    int? emailEditCount,
    int? leadSourceEditCount,
  }) {
    return LeadModel(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      phone: phone ?? this.phone,
      property: property ?? this.property,
      status: status ?? this.status,
      lastTag: lastTag ?? this.lastTag,
      followUpDate: followUpDate ?? this.followUpDate,
      followUpDateTime: followUpDateTime ?? this.followUpDateTime,
      lastNote: lastNote ?? this.lastNote,
      isActive: isActive ?? this.isActive,
      callDuration: callDuration ?? this.callDuration,
      createdAt: createdAt ?? this.createdAt,
      callsCount: callsCount ?? this.callsCount,
      alternatePhone: alternatePhone ?? this.alternatePhone,
      email: email ?? this.email,
      source: source ?? this.source,
      leadTemperature: leadTemperature ?? this.leadTemperature,
      emailEditCount: emailEditCount ?? this.emailEditCount,
      leadSourceEditCount: leadSourceEditCount ?? this.leadSourceEditCount,
    );
  }

  /// Parses the `createdAt` field from Firestore, handling both
  /// [Timestamp] and [String] types gracefully.
  static String _parseCreatedAt(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is String) {
      return value;
    }
    return '';
  }
}
