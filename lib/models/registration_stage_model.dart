/// registration_stage_model.dart
///
/// Defines the [RegistrationStageModel] data class representing a single
/// stage in the property registration process for a booked unit.
/// Registration stages are stored as a sub-collection under each unit:
/// `/users/{uid}/projects/{projectId}/units/{unitId}/registration_stages/{stageId}`

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents one stage in the 10-step property registration process.
class RegistrationStageModel {
  /// Firestore document ID.
  final String id;

  /// Parent unit's Firestore document ID.
  final String unitId;

  /// Stage number (1–10), determines display order.
  final int stageNumber;

  /// Human-readable stage name.
  final String stageName;

  /// Current status: 'pending', 'in_progress', or 'completed'.
  final String status;

  /// Date when this stage was completed (ISO 8601, nullable).
  final String completedDate;

  /// Optional notes (e.g. "Loan from SBI, ref #12345").
  final String notes;

  /// Name/email of the user who last updated this stage.
  final String updatedBy;

  /// ISO 8601 timestamp of the last update.
  final String updatedAt;

  // ─── Static Constants ───────────────────────────────────────────────────

  /// The 10 registration stages in order.
  static const List<String> stageNames = [
    'Token Amount Paid',
    'Agreement of Sale Signed',
    'Home Loan Applied',
    'Home Loan Sanctioned',
    'Stamp Duty Paid',
    'Registration Appointment Scheduled',
    'Sub-Registrar Visit Completed',
    'Possession Letter Issued',
    'Possession Handover Done',
    'Society Transfer Done',
  ];

  /// Valid status values.
  static const List<String> validStatuses = [
    'pending',
    'in_progress',
    'completed',
  ];

  const RegistrationStageModel({
    required this.id,
    required this.unitId,
    required this.stageNumber,
    required this.stageName,
    this.status = 'pending',
    this.completedDate = '',
    this.notes = '',
    this.updatedBy = '',
    this.updatedAt = '',
  });

  /// Creates a [RegistrationStageModel] from a Firestore document snapshot.
  factory RegistrationStageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RegistrationStageModel(
      id: doc.id,
      unitId: data['unit_id'] as String? ?? '',
      stageNumber: (data['stage_number'] as num?)?.toInt() ?? 0,
      stageName: data['stage_name'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      completedDate: _parseTimestamp(data['completed_date']),
      notes: data['notes'] as String? ?? '',
      updatedBy: data['updated_by'] as String? ?? '',
      updatedAt: _parseTimestamp(data['updated_at']),
    );
  }

  /// Converts this stage model into a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'unit_id': unitId,
      'stage_number': stageNumber,
      'stage_name': stageName,
      'status': status,
      'completed_date': completedDate,
      'notes': notes,
      'updated_by': updatedBy,
      'updated_at': updatedAt,
    };
  }

  /// Creates a copy with optional field overrides.
  RegistrationStageModel copyWith({
    String? id,
    String? unitId,
    int? stageNumber,
    String? stageName,
    String? status,
    String? completedDate,
    String? notes,
    String? updatedBy,
    String? updatedAt,
  }) {
    return RegistrationStageModel(
      id: id ?? this.id,
      unitId: unitId ?? this.unitId,
      stageNumber: stageNumber ?? this.stageNumber,
      stageName: stageName ?? this.stageName,
      status: status ?? this.status,
      completedDate: completedDate ?? this.completedDate,
      notes: notes ?? this.notes,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Generates the initial 10 registration stages for a unit, all set to 'pending'.
  static List<RegistrationStageModel> createInitialStages(String unitId) {
    final now = DateTime.now().toIso8601String();
    return List.generate(stageNames.length, (i) {
      return RegistrationStageModel(
        id: '',
        unitId: unitId,
        stageNumber: i + 1,
        stageName: stageNames[i],
        status: 'pending',
        updatedAt: now,
      );
    });
  }

  /// Whether this stage is completed.
  bool get isCompleted => status == 'completed';

  /// Whether this stage is in progress.
  bool get isInProgress => status == 'in_progress';

  /// Whether this stage is pending.
  bool get isPending => status == 'pending';

  static String _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is String) {
      return value;
    }
    return '';
  }
}
