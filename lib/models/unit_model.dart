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

  /// Number of bedrooms.
  final int bedrooms;

  /// Number of bathrooms.
  final int bathrooms;

  /// Base price per square foot.
  final double basePricePerSqft;

  /// Total price (computed or manually overridden).
  final double totalPrice;

  /// Furnishing level.
  final String furnishing;

  /// Car parking allocation.
  final String carParking;

  /// Current availability/booking status.
  final String availabilityStatus;

  /// Unit type: Fresh (new from builder), Resale, or Rental.
  final String unitType;

  /// Linked lead ID when unit is booked (nullable).
  final String? bookingLeadId;

  /// Internal remarks on the unit (optional).
  final String notes;

  /// ISO 8601 creation timestamp.
  final String createdAt;

  /// ISO 8601 last-update timestamp.
  final String updatedAt;

  // ─── Resale-specific fields ───────────────────────────────────────────────

  /// Name of the current owner selling the unit (Resale only).
  final String ownerName;

  /// Phone number of the current owner (Resale only).
  final String ownerPhone;

  /// Price the owner is asking (Resale only).
  final double ownerAskingPrice;

  /// Price we list to buyers — may differ from owner's ask (Resale only).
  final double listedPrice;

  /// Notes about the owner's flexibility, urgency, reason for selling (Resale only).
  final String ownerNotes;

  // ─── Rental-specific fields ───────────────────────────────────────────────

  /// Name of the landlord giving unit for rent (Rental only).
  final String landlordName;

  /// Phone number of the landlord (Rental only).
  final String landlordPhone;

  /// Expected monthly rent amount (Rental only).
  final double monthlyRent;

  /// Security deposit amount (Rental only).
  final double securityDeposit;

  /// Date from which unit is available for move-in (Rental only, ISO 8601).
  final String availableFrom;

  /// Notes about landlord restrictions, preferences (Rental only).
  final String landlordNotes;

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

  /// Unit availability statuses (type-independent).
  static const List<String> availabilityStatuses = [
    'Available',
    'Booked',
    'Sold',
    'Hold',
  ];

  /// Unit type categories.
  static const List<String> unitTypes = [
    'Fresh',
    'Resale',
    'Rental',
  ];

  static const List<String> furnishingOptions = [
    'Unfurnished',
    'Semi-Furnished',
    'Fully Furnished',
  ];

  static const List<String> carParkingOptions = [
    'None',
    'One Covered',
    'One Open',
    'Two Covered',
    'Two Open',
    'One Covered + One Open',
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
    this.bedrooms = 2,
    this.bathrooms = 2,
    this.basePricePerSqft = 0.0,
    this.totalPrice = 0.0,
    this.furnishing = 'Unfurnished',
    this.carParking = 'None',
    this.availabilityStatus = 'Available',
    this.unitType = 'Fresh',
    this.bookingLeadId,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
    // Resale fields
    this.ownerName = '',
    this.ownerPhone = '',
    this.ownerAskingPrice = 0.0,
    this.listedPrice = 0.0,
    this.ownerNotes = '',
    // Rental fields
    this.landlordName = '',
    this.landlordPhone = '',
    this.monthlyRent = 0.0,
    this.securityDeposit = 0.0,
    this.availableFrom = '',
    this.landlordNotes = '',
  });

  /// Creates a [UnitModel] from a Firestore document snapshot.
  factory UnitModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UnitModel(
      id: doc.id,
      projectId: data['projectId'] as String? ?? '',
      towerId: data['towerId'] as String?,
      unitNumber: (data['flat_number'] ?? data['unitNumber'] ?? data['unit_number'] ?? '') as String,
      floorNumber: _parseInt(data['floor_number'] ?? data['floorNumber']),
      bhkType: data['bhkType'] as String? ?? '',
      facing: (data['main_door_facing'] ?? data['facing'] ?? '') as String,
      superBuiltupArea: _parseDouble(data['sba_sqft'] ?? data['superBuiltupArea'] ?? data['super_builtup_area']),
      bedrooms: _parseInt(data['bedrooms']),
      bathrooms: _parseInt(data['bathrooms']),
      basePricePerSqft: _parseDouble(data['basePricePerSqft'] ?? data['base_price_per_sqft']),
      totalPrice: _parseDouble(data['total_price'] ?? data['totalPrice']),
      furnishing: (data['furnishing'] ?? 'Unfurnished') as String,
      carParking: (data['car_parking'] ?? data['carParking'] ?? 'None') as String,
      availabilityStatus: (data['availability_status'] ?? data['availabilityStatus'] ?? 'Available') as String,
      unitType: (data['unit_type'] ?? data['unitType'] ?? 'Fresh') as String,
      bookingLeadId: (data['booking_lead_id'] ?? data['bookingLeadId']) as String?,
      notes: data['notes'] as String? ?? '',
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      // Resale fields
      ownerName: data['owner_name'] as String? ?? '',
      ownerPhone: data['owner_phone'] as String? ?? '',
      ownerAskingPrice: _parseDouble(data['owner_asking_price']),
      listedPrice: _parseDouble(data['listed_price']),
      ownerNotes: data['owner_notes'] as String? ?? '',
      // Rental fields
      landlordName: data['landlord_name'] as String? ?? '',
      landlordPhone: data['landlord_phone'] as String? ?? '',
      monthlyRent: _parseDouble(data['monthly_rent']),
      securityDeposit: _parseDouble(data['security_deposit']),
      availableFrom: data['available_from'] as String? ?? '',
      landlordNotes: data['landlord_notes'] as String? ?? '',
    );
  }

  /// Converts this unit model into a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'towerId': towerId,
      'flat_number': unitNumber,
      'unitNumber': unitNumber,
      'floor_number': floorNumber,
      'floorNumber': floorNumber,
      'bhkType': bhkType,
      'main_door_facing': facing,
      'facing': facing,
      'sba_sqft': superBuiltupArea,
      'superBuiltupArea': superBuiltupArea,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'basePricePerSqft': basePricePerSqft,
      'total_price': totalPrice,
      'totalPrice': totalPrice,
      'furnishing': furnishing,
      'car_parking': carParking,
      'carParking': carParking,
      'availability_status': availabilityStatus,
      'availabilityStatus': availabilityStatus,
      'unit_type': unitType,
      'unitType': unitType,
      'booking_lead_id': bookingLeadId,
      'bookingLeadId': bookingLeadId,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      // Resale fields
      'owner_name': ownerName,
      'owner_phone': ownerPhone,
      'owner_asking_price': ownerAskingPrice,
      'listed_price': listedPrice,
      'owner_notes': ownerNotes,
      // Rental fields
      'landlord_name': landlordName,
      'landlord_phone': landlordPhone,
      'monthly_rent': monthlyRent,
      'security_deposit': securityDeposit,
      'available_from': availableFrom,
      'landlord_notes': landlordNotes,
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
    int? bedrooms,
    int? bathrooms,
    double? basePricePerSqft,
    double? totalPrice,
    String? furnishing,
    String? carParking,
    String? availabilityStatus,
    String? unitType,
    String? bookingLeadId,
    String? notes,
    String? createdAt,
    String? updatedAt,
    // Resale
    String? ownerName,
    String? ownerPhone,
    double? ownerAskingPrice,
    double? listedPrice,
    String? ownerNotes,
    // Rental
    String? landlordName,
    String? landlordPhone,
    double? monthlyRent,
    double? securityDeposit,
    String? availableFrom,
    String? landlordNotes,
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
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      basePricePerSqft: basePricePerSqft ?? this.basePricePerSqft,
      totalPrice: totalPrice ?? this.totalPrice,
      furnishing: furnishing ?? this.furnishing,
      carParking: carParking ?? this.carParking,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      unitType: unitType ?? this.unitType,
      bookingLeadId: bookingLeadId ?? this.bookingLeadId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      ownerAskingPrice: ownerAskingPrice ?? this.ownerAskingPrice,
      listedPrice: listedPrice ?? this.listedPrice,
      ownerNotes: ownerNotes ?? this.ownerNotes,
      landlordName: landlordName ?? this.landlordName,
      landlordPhone: landlordPhone ?? this.landlordPhone,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      securityDeposit: securityDeposit ?? this.securityDeposit,
      availableFrom: availableFrom ?? this.availableFrom,
      landlordNotes: landlordNotes ?? this.landlordNotes,
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

  /// Formats the owner asking price for display (Resale units).
  String get formattedAskingPrice {
    if (ownerAskingPrice <= 0) return '—';
    if (ownerAskingPrice >= 10000000) {
      return '₹${(ownerAskingPrice / 10000000).toStringAsFixed(2)}Cr';
    } else if (ownerAskingPrice >= 100000) {
      return '₹${(ownerAskingPrice / 100000).toStringAsFixed(1)}L';
    }
    return '₹${ownerAskingPrice.toStringAsFixed(0)}';
  }

  /// Formats the monthly rent for display (Rental units).
  String get formattedRent {
    if (monthlyRent <= 0) return '—';
    if (monthlyRent >= 100000) {
      return '₹${(monthlyRent / 1000).toStringAsFixed(0)}K/mo';
    }
    return '₹${monthlyRent.toStringAsFixed(0)}/mo';
  }

  /// Formats the security deposit for display (Rental units).
  String get formattedDeposit {
    if (securityDeposit <= 0) return '—';
    if (securityDeposit >= 100000) {
      return '₹${(securityDeposit / 100000).toStringAsFixed(1)}L';
    }
    return '₹${securityDeposit.toStringAsFixed(0)}';
  }

  /// Display price based on unit type.
  String get displayPrice {
    if (unitType == 'Rental') return formattedRent;
    if (unitType == 'Resale' && listedPrice > 0) {
      if (listedPrice >= 10000000) {
        return '₹${(listedPrice / 10000000).toStringAsFixed(2)}Cr';
      } else if (listedPrice >= 100000) {
        return '₹${(listedPrice / 100000).toStringAsFixed(1)}L';
      }
      return '₹${listedPrice.toStringAsFixed(0)}';
    }
    return formattedPrice;
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

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}
