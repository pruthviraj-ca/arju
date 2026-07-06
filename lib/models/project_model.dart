/// project_model.dart
///
/// Defines the [ProjectModel] data class representing a real estate project
/// in the TruAssets Inventory module. Each project contains details about
/// the development, location, land, towers, and amenities.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single real estate project (e.g. "Mantri Serenity").
///
/// Projects are stored at `/users/{uid}/projects/{projectId}` in Firestore
/// and contain towers and units as sub-collections.
class ProjectModel {
  /// Firestore document ID (empty string for new, unsaved projects).
  final String id;

  /// Name of the project (e.g. "Mantri Serenity").
  final String name;

  /// Name of the developer/builder.
  final String developerName;

  /// Type of project.
  final String projectType;

  /// Full street address.
  final String location;

  /// City name.
  final String city;

  /// Postal/PIN code.
  final String pincode;

  /// Total land parcel area (numeric value).
  final double landParcelArea;

  /// Unit for land parcel area measurement.
  final String landParcelUnit;

  /// Number of towers/blocks in the project.
  final int totalTowers;

  /// Denormalized total unit count for quick display.
  final int totalUnits;

  /// RERA registration number (optional).
  final String reraNumber;

  /// Expected possession date as ISO string (optional).
  final String possessionDate;

  /// List of amenity names (e.g. ['Gym', 'Pool', 'Parking']).
  final List<String> amenities;

  /// ISO 8601 timestamp of when this project was created.
  final String createdAt;

  /// ISO 8601 timestamp of the last update.
  final String updatedAt;

  static const List<String> projectTypes = [
    'Apartment',
    'Villa',
    'Plot',
    'Commercial',
  ];

  static const List<String> landParcelUnits = [
    'acres',
    'sq_ft',
    'sq_m',
    'cents',
  ];

  const ProjectModel({
    required this.id,
    required this.name,
    required this.developerName,
    required this.projectType,
    required this.location,
    this.city = '',
    this.pincode = '',
    required this.landParcelArea,
    this.landParcelUnit = 'acres',
    required this.totalTowers,
    this.totalUnits = 0,
    this.reraNumber = '',
    this.possessionDate = '',
    this.amenities = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a [ProjectModel] from a Firestore document snapshot.
  factory ProjectModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProjectModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      developerName: data['developerName'] as String? ?? '',
      projectType: data['projectType'] as String? ?? 'Apartment',
      location: data['location'] as String? ?? '',
      city: data['city'] as String? ?? '',
      pincode: data['pincode'] as String? ?? '',
      landParcelArea: (data['landParcelArea'] as num?)?.toDouble() ?? 0.0,
      landParcelUnit: data['landParcelUnit'] as String? ?? 'acres',
      totalTowers: data['totalTowers'] as int? ?? 0,
      totalUnits: data['totalUnits'] as int? ?? 0,
      reraNumber: data['reraNumber'] as String? ?? '',
      possessionDate: data['possessionDate'] as String? ?? '',
      amenities: List<String>.from(data['amenities'] ?? []),
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  /// Converts this project model into a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'developerName': developerName,
      'projectType': projectType,
      'location': location,
      'city': city,
      'pincode': pincode,
      'landParcelArea': landParcelArea,
      'landParcelUnit': landParcelUnit,
      'totalTowers': totalTowers,
      'totalUnits': totalUnits,
      'reraNumber': reraNumber,
      'possessionDate': possessionDate,
      'amenities': amenities,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Creates a copy of this project with optional field overrides.
  ProjectModel copyWith({
    String? id,
    String? name,
    String? developerName,
    String? projectType,
    String? location,
    String? city,
    String? pincode,
    double? landParcelArea,
    String? landParcelUnit,
    int? totalTowers,
    int? totalUnits,
    String? reraNumber,
    String? possessionDate,
    List<String>? amenities,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      developerName: developerName ?? this.developerName,
      projectType: projectType ?? this.projectType,
      location: location ?? this.location,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      landParcelArea: landParcelArea ?? this.landParcelArea,
      landParcelUnit: landParcelUnit ?? this.landParcelUnit,
      totalTowers: totalTowers ?? this.totalTowers,
      totalUnits: totalUnits ?? this.totalUnits,
      reraNumber: reraNumber ?? this.reraNumber,
      possessionDate: possessionDate ?? this.possessionDate,
      amenities: amenities ?? this.amenities,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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
