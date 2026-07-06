/// unit_model.dart
///
/// Defines the [UnitModel] data class representing an individual unit
/// (flat, villa, plot, shop) within a real estate project. Units are
/// the most granular inventory item and track availability, pricing,
/// area measurements, and optional lead linkage for bookings.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single inventory unit within a project.
///
/// Stored at `/users/{uid}/projects/{projectId}/units/{unitId}`.
class UnitModel {
  /// Firestore document ID (empty for new units).
  final String id;

  /// Parent project's Firestore document ID.
  final String projectId;

  /// Parent tower's Firestore document ID (nullable for tower-less projects).
  final String? towerId;

  /// Display unit number (e.g. "A-401").
  final String unitNumber;

  /// Floor number within the tower.
  final int floorNumber;

  /// BHK configuration type.
  final String bhkType;

  /// Compass facing direction.
  final String facing;

  /// Super built-up area in square feet.
  final double superBuiltupArea;

  /// Built-up area in square feet.
  final double builtupArea;

  /// Carpet area in square feet.
  final double carpetArea;

  /// Base price per square foot.
  final double basePricePerSqft;

  /// Total price (computed or manually overridden).
  final double totalPrice;

  /// Current availability/booking status.
  final String availabilityStatus;

  /// Linked lead ID when unit is booked (nullable).
  final String? bookingLeadId;

  /// Internal remarks on the unit (optional).
  final String notes;

  /// ISO 8601 creation timestamp.
  final String createdAt;

  /// ISO 8601 last-update timestamp.
  final String updatedAt;

  // ─── Static Enum Lists ──────────────────────────────────────────────────

  static const List<String> bhkTypes = [
    '1BHK',
    '2BHK',
    '2.5BHK',
    '3BHK',
    '3.5BHK',
    '4BHK',
    '4.5BHK',
    '5BHK',
    'Studio',
    'Duplex',
    'Penthouse',
    'Plot',
    'Shop',
    'Office',
  ];

  static const List<String> facings = [
    'East',
    'West',
    'North',
    'South',
    'North-East',
    'North-West',
    'South-East',
    'South-West',
  ];

  static const List<String> availabilityStatuses = [
    'Available',
    'Booked',
    'Sold',
    'Resale',
    'Rental',
    'Blocked',
    'Hold',
  ];

  const UnitModel({
    required this.id,
    required this.projectId,
    this.towerId,
    required this.unitNumber,
    required this.floorNumber,
    required this.bhkType,
    required this.facing,
    this.superBuiltupArea = 0.0,
    this.builtupArea = 0.0,
    this.carpetArea = 0.0,
    this.basePricePerSqft = 0.0,
    this.totalPrice = 0.0,
    this.availabilityStatus = 'Available',
    this.bookingLeadId,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a [UnitModel] from a Firestore document snapshot.
  factory UnitModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UnitModel(
      id: doc.id,
      projectId: data['projectId'] as String? ?? '',
      towerId: data['towerId'] as String?,
      unitNumber: data['unitNumber'] as String? ?? '',
      floorNumber: data['floorNumber'] as int? ?? 0,
      bhkType: data['bhkType'] as String? ?? '',
      facing: data['facing'] as String? ?? '',
      superBuiltupArea: (data['superBuiltupArea'] as num?)?.toDouble() ?? 0.0,
      builtupArea: (data['builtupArea'] as num?)?.toDouble() ?? 0.0,
      carpetArea: (data['carpetArea'] as num?)?.toDouble() ?? 0.0,
      basePricePerSqft: (data['basePricePerSqft'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      availabilityStatus: data['availabilityStatus'] as String? ?? 'Available',
      bookingLeadId: data['bookingLeadId'] as String?,
      notes: data['notes'] as String? ?? '',
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  /// Converts this unit model into a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'towerId': towerId,
      'unitNumber': unitNumber,
      'floorNumber': floorNumber,
      'bhkType': bhkType,
      'facing': facing,
      'superBuiltupArea': superBuiltupArea,
      'builtupArea': builtupArea,
      'carpetArea': carpetArea,
      'basePricePerSqft': basePricePerSqft,
      'totalPrice': totalPrice,
      'availabilityStatus': availabilityStatus,
      'bookingLeadId': bookingLeadId,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Creates a copy of this unit with optional field overrides.
  UnitModel copyWith({
    String? id,
    String? projectId,
    String? towerId,
    String? unitNumber,
    int? floorNumber,
    String? bhkType,
    String? facing,
    double? superBuiltupArea,
    double? builtupArea,
    double? carpetArea,
    double? basePricePerSqft,
    double? totalPrice,
    String? availabilityStatus,
    String? bookingLeadId,
    String? notes,
    String? createdAt,
    String? updatedAt,
  }) {
    return UnitModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      towerId: towerId ?? this.towerId,
      unitNumber: unitNumber ?? this.unitNumber,
      floorNumber: floorNumber ?? this.floorNumber,
      bhkType: bhkType ?? this.bhkType,
      facing: facing ?? this.facing,
      superBuiltupArea: superBuiltupArea ?? this.superBuiltupArea,
      builtupArea: builtupArea ?? this.builtupArea,
      carpetArea: carpetArea ?? this.carpetArea,
      basePricePerSqft: basePricePerSqft ?? this.basePricePerSqft,
      totalPrice: totalPrice ?? this.totalPrice,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      bookingLeadId: bookingLeadId ?? this.bookingLeadId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Formats the total price for display (e.g. "₹85.5L" or "₹1.2Cr").
  String get formattedPrice {
    if (totalPrice <= 0) return '—';
    if (totalPrice >= 10000000) {
      return '₹${(totalPrice / 10000000).toStringAsFixed(2)}Cr';
    } else if (totalPrice >= 100000) {
      return '₹${(totalPrice / 100000).toStringAsFixed(1)}L';
    }
    return '₹${totalPrice.toStringAsFixed(0)}';
  }

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
