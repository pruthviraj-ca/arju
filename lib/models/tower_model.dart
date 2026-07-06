/// tower_model.dart
///
/// Defines the [TowerModel] data class representing a tower/block
/// within a real estate project. Towers are stored as a sub-collection
/// under each project document.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single tower or block within a project.
///
/// Stored at `/users/{uid}/projects/{projectId}/towers/{towerId}`.
class TowerModel {
  /// Firestore document ID (empty for new towers).
  final String id;

  /// Parent project's Firestore document ID.
  final String projectId;

  /// Display name of the tower (e.g. "Tower A", "Block 1").
  final String towerName;

  /// Number of floors in this tower.
  final int totalFloors;

  /// ISO 8601 creation timestamp.
  final String createdAt;

  const TowerModel({
    required this.id,
    required this.projectId,
    required this.towerName,
    required this.totalFloors,
    required this.createdAt,
  });

  /// Creates a [TowerModel] from a Firestore document snapshot.
  factory TowerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TowerModel(
      id: doc.id,
      projectId: data['projectId'] as String? ?? '',
      towerName: data['towerName'] as String? ?? '',
      totalFloors: data['totalFloors'] as int? ?? 0,
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  /// Converts this tower model into a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'towerName': towerName,
      'totalFloors': totalFloors,
      'createdAt': createdAt,
    };
  }

  /// Creates a copy of this tower with optional field overrides.
  TowerModel copyWith({
    String? id,
    String? projectId,
    String? towerName,
    int? totalFloors,
    String? createdAt,
  }) {
    return TowerModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      towerName: towerName ?? this.towerName,
      totalFloors: totalFloors ?? this.totalFloors,
      createdAt: createdAt ?? this.createdAt,
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
