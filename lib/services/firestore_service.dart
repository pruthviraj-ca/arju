/// firestore_service.dart
///
/// Centralized Firestore data-access layer for the TruAssets CRM.
/// Provides a singleton interface for all CRUD and streaming operations
/// on leads, notes, site visits, call logs, and user profiles.
/// All operations are scoped to the currently authenticated user's
/// Firestore sub-tree: /users/{uid}/...

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lead_model.dart';
import '../models/note_model.dart';
import '../models/site_visit_model.dart';
import '../models/project_model.dart';
import '../models/tower_model.dart';
import '../models/unit_model.dart';
import 'auth_service.dart';

/// Singleton service for all Firestore database operations.
///
/// All collections are namespaced under `/users/{uid}/` to ensure
/// complete data isolation between users.
class FirestoreService {
  FirestoreService._();

  /// Global singleton instance.
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Caching and UID Isolation ─────────────────────────────────────────────
  List<LeadModel>? _leadsCache;
  StreamController<List<LeadModel>>? _leadsStreamController;
  StreamSubscription<List<LeadModel>>? _leadsSubscription;

  List<SiteVisitModel>? _siteVisitsCache;
  StreamController<List<SiteVisitModel>>? _siteVisitsStreamController;
  StreamSubscription<List<SiteVisitModel>>? _siteVisitsSubscription;

  String? _lastCachedUid;

  void _checkUidAndResetCache() {
    final currentUid = _uid;
    if (_lastCachedUid != currentUid) {
      _lastCachedUid = currentUid;
      _leadsCache = null;
      _leadsSubscription?.cancel();
      _leadsSubscription = null;
      _leadsStreamController?.close();
      _leadsStreamController = null;

      _siteVisitsCache = null;
      _siteVisitsSubscription?.cancel();
      _siteVisitsSubscription = null;
      _siteVisitsStreamController?.close();
      _siteVisitsStreamController = null;
    }
  }

  // ─── UID Helpers ──────────────────────────────────────────────────────────

  /// The current authenticated user's UID, or `null` if not signed in.
  String? get _uid => AuthService.instance.currentUser?.uid;

  /// Public accessor for the current user's UID, used by call-log writers
  /// in screen-level code that needs the UID directly.
  String? get currentUid => _uid;

  // ─── Collection References ─────────────────────────────────────────────────

  /// Returns the leads collection reference for the current user.
  ///
  /// Throws [Exception] if no user is authenticated.
  CollectionReference<Map<String, dynamic>> _leadsRef() {
    if (_uid == null) throw Exception('User not authenticated');
    return _db.collection('users').doc(_uid).collection('leads');
  }

  /// Returns the site visits collection reference for the current user.
  ///
  /// Throws [Exception] if no user is authenticated.
  CollectionReference<Map<String, dynamic>> _siteVisitsRef() {
    if (_uid == null) throw Exception('User not authenticated');
    return _db.collection('users').doc(_uid).collection('siteVisits');
  }

  /// Returns the user profile document reference for the current user.
  ///
  /// Throws [Exception] if no user is authenticated.
  DocumentReference<Map<String, dynamic>> _userRef() {
    if (_uid == null) throw Exception('User not authenticated');
    return _db.collection('users').doc(_uid);
  }

  // ─── Leads ────────────────────────────────────────────────────────────────

  /// Streams the full list of leads for the current user, ordered by
  /// creation date (newest first). Supports optional pagination [limit].
  ///
  /// Returns an empty stream if no user is authenticated.
  Stream<List<LeadModel>> streamLeads({int? limit}) {
    if (_uid == null) return Stream.value([]);
    _checkUidAndResetCache();

    // Construct the query
    var query = _leadsRef().orderBy('createdAt', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }

    final controller = StreamController<List<LeadModel>>.broadcast();

    // Emit from cache if we have it
    final cache = _leadsCache;
    if (cache != null) {
      final cachedSlice = limit != null && cache.length > limit 
          ? cache.sublist(0, limit) 
          : cache;
      Future.microtask(() {
        if (!controller.isClosed) {
          controller.add(cachedSlice);
        }
      });
    }

    final sub = query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => LeadModel.fromFirestore(doc)).toList()
    ).listen((leads) {
      if (_leadsCache == null || leads.length > _leadsCache!.length) {
        _leadsCache = leads;
      }
      if (!controller.isClosed) {
        controller.add(leads);
      }
    }, onError: (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    });

    controller.onCancel = () {
      sub.cancel();
      controller.close();
    };

    return controller.stream;
  }

  /// Streams a single lead document by [leadId].
  ///
  /// Emits `null` if the document does not exist or if no user is
  /// authenticated.
  Stream<LeadModel?> streamLead(String leadId) {
    if (_uid == null) return Stream.value(null);
    return _leadsRef().doc(leadId).snapshots().map((doc) {
      if (doc.exists) return LeadModel.fromFirestore(doc);
      return null;
    });
  }

  /// Creates or fully overwrites a lead document in Firestore.
  ///
  /// If [lead.id] is empty a new document is created with an auto-generated
  /// ID; otherwise the document at [lead.id] is overwritten.
  Future<void> addLead(LeadModel lead) async {
    final ref =
        lead.id.isEmpty ? _leadsRef().doc() : _leadsRef().doc(lead.id);
    await ref.set(lead.toMap());
  }

  /// Batch-creates multiple leads in a single Firestore write operation.
  ///
  /// [leads] - List of [LeadModel] objects to import. Empty IDs will receive
  /// auto-generated Firestore document IDs.
  Future<void> addLeadsBatch(List<LeadModel> leads) async {
    final batch = _db.batch();
    for (final lead in leads) {
      final docRef =
          lead.id.isEmpty ? _leadsRef().doc() : _leadsRef().doc(lead.id);
      batch.set(docRef, lead.toMap());
    }
    await batch.commit();
  }

  /// Partially updates a lead document using field-level [updates].
  ///
  /// [leadId] - The Firestore document ID of the lead to update.
  /// [updates] - A map of field paths to new values.
  Future<void> updateLead(String leadId, Map<String, dynamic> updates) async {
    await _leadsRef().doc(leadId).update(updates);
  }

  /// Permanently deletes a lead document by [leadId].
  Future<void> deleteLead(String leadId) async {
    await _leadsRef().doc(leadId).delete();
  }

  /// Fetches the full list of leads once, ordered by creation date (newest first).
  Future<List<LeadModel>> getLeadsOnce() async {
    if (_uid == null) return [];
    final snapshot = await _leadsRef().orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => LeadModel.fromFirestore(doc)).toList();
  }

  /// Deletes multiple leads in a single batch transaction.
  Future<void> deleteLeadsBatch(List<String> leadIds) async {
    if (_uid == null || leadIds.isEmpty) return;
    final batch = _db.batch();
    for (final id in leadIds) {
      batch.delete(_leadsRef().doc(id));
    }
    await batch.commit();
  }

  // ─── Notes (Sub-collection under Lead) ────────────────────────────────────

  /// Streams all call notes for a given lead, ordered by creation date
  /// (newest first).
  ///
  /// [leadId] - The parent lead's Firestore document ID.
  /// Returns an empty stream if no user is authenticated.
  Stream<List<NoteModel>> streamNotes(String leadId) {
    if (_uid == null) return Stream.value([]);
    return _leadsRef()
        .doc(leadId)
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => NoteModel.fromFirestore(doc)).toList());
  }

  /// Saves a call note to the notes sub-collection of the specified lead.
  ///
  /// [leadId] - The parent lead's Firestore document ID.
  /// [note]   - The [NoteModel] to persist. Empty IDs receive auto-generated IDs.
  /// For new notes, `serverCreatedAt` is set to the Firestore server timestamp
  /// so the 15-minute edit window uses tamper-proof server time.
  Future<void> addNote(String leadId, NoteModel note) async {
    final noteRef = note.id.isEmpty
        ? _leadsRef().doc(leadId).collection('notes').doc()
        : _leadsRef().doc(leadId).collection('notes').doc(note.id);
    final data = note.toMap();
    // Set server timestamp for new notes only
    if (note.id.isEmpty) {
      data['serverCreatedAt'] = FieldValue.serverTimestamp();
    }
    await noteRef.set(data);
  }

  /// Updates only the text of an existing note and marks it as edited.
  ///
  /// [leadId] - The parent lead's Firestore document ID.
  /// [noteId] - The Firestore document ID of the note to update.
  /// [newText] - The new body text for the note.
  Future<void> updateNoteText(String leadId, String noteId, String newText) async {
    await _leadsRef().doc(leadId).collection('notes').doc(noteId).update({
      'text': newText,
      'isEdited': true,
    });
  }

  /// Logs a temperature change for a lead as an auto-log NoteModel in the notes sub-collection.
  Future<void> logTemperatureChange({
    required String leadId,
    required String clientName,
    required String oldTemp,
    required String newTemp,
  }) async {
    if (oldTemp == newTemp) return;

    String tag = '';
    String text = '';

    if (newTemp == 'Cold') {
      tag = 'Temp: Cold';
      text = '$clientName temperature set to Cold';
    } else if (newTemp == 'Warm') {
      tag = 'Temp: Warm';
      text = oldTemp == 'Hot'
          ? '$clientName temperature changed to Warm'
          : '$clientName temperature set to Warm';
    } else if (newTemp == 'Hot') {
      tag = 'Temp: Hot';
      text = '$clientName temperature changed to Hot';
    } else if (newTemp.isEmpty || newTemp == 'none') {
      tag = 'Temp: Cleared';
      text = '$clientName temperature tag removed';
    } else {
      return;
    }

    final now = DateTime.now();
    final createdAt =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final autoNote = NoteModel(
      id: '',
      text: text,
      tag: tag,
      callDuration: '',
      createdAt: createdAt,
      isAutoLog: true,
    );

    await addNote(leadId, autoNote);
  }

  /// Updates a lead's status in the database and creates a corresponding timeline log entry.
  /// If the status hasn't changed, this is a no-op.
  Future<void> updateLeadStatus({
    required String leadId,
    required String newStatus,
    required String triggeredBy,
    String? context,
    String? clientName,
    String? oldStatus,
    Map<String, dynamic>? additionalUpdates,
  }) async {
    if (_uid == null) return;
    
    String currentStatus = oldStatus ?? '';
    String name = clientName ?? 'Lead';
    String currentTemp = '';

    // If we don't have the old status or client name, fetch the lead document
    if (oldStatus == null || clientName == null) {
      final leadDoc = await _leadsRef().doc(leadId).get();
      if (!leadDoc.exists) return;
      final lead = LeadModel.fromFirestore(leadDoc);
      currentStatus = lead.status;
      name = lead.clientName;
      currentTemp = lead.leadTemperature;
    } else {
      // Still need temperature for auto-update if status becomes won/lost
      final leadDoc = await _leadsRef().doc(leadId).get();
      if (leadDoc.exists) {
        currentTemp = leadDoc.data()?['leadTemperature'] as String? ?? '';
      }
    }

    final newStatusLower = newStatus.toLowerCase();
    if (currentStatus.toLowerCase() == newStatusLower) {
      // Deduplication guard
      return;
    }

    // Determine temperature changes based on status (e.g. Won/Lost clears temp)
    final isWonOrLost = newStatusLower == 'won' || 
                        newStatusLower == 'lost' || 
                        newStatusLower == 'dead' || 
                        newStatusLower == 'lost/dead';
    final targetTemp = isWonOrLost ? '' : currentTemp;

    final updates = {
      'status': newStatus,
      'leadTemperature': targetTemp,
      'statusChangedAt': DateTime.now().toIso8601String(),
      ...?additionalUpdates,
    };
    await updateLead(leadId, updates);

    // Create temperature log if changed
    if (currentTemp != targetTemp) {
      await logTemperatureChange(
        leadId: leadId,
        clientName: name,
        oldTemp: currentTemp,
        newTemp: targetTemp,
      );
    }

    // Create timeline status change log entry
    final tag = _statusLogTag(newStatusLower);
    final text = _statusLogText(newStatusLower, name, triggeredBy, context);

    final now = DateTime.now();
    final createdAt =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final autoNote = NoteModel(
      id: '',
      text: text,
      tag: tag,
      callDuration: '',
      createdAt: createdAt,
      isAutoLog: true,
    );

    await addNote(leadId, autoNote);
  }

  /// Updates a lead's temperature tag in the database and creates a corresponding timeline log entry.
  /// If the temperature hasn't changed, this is a no-op.
  Future<void> updateLeadTemperature({
    required String leadId,
    required String newTemp,
    required String triggeredBy,
    String? clientName,
    String? oldTemp,
  }) async {
    if (_uid == null) return;

    String currentTemp = oldTemp ?? '';
    String name = clientName ?? 'Lead';

    if (oldTemp == null || clientName == null) {
      final leadDoc = await _leadsRef().doc(leadId).get();
      if (!leadDoc.exists) return;
      final lead = LeadModel.fromFirestore(leadDoc);
      currentTemp = lead.leadTemperature;
      name = lead.clientName;
    }

    if (currentTemp == newTemp) {
      // Deduplication guard
      return;
    }

    await updateLead(leadId, {'leadTemperature': newTemp});

    await logTemperatureChange(
      leadId: leadId,
      clientName: name,
      oldTemp: currentTemp,
      newTemp: newTemp,
    );
  }

  String _statusLogTag(String statusLower) {
    switch (statusLower) {
      case 'new':
        return 'Status: New';
      case 'called':
        return 'Status: Called';
      case 'follow-up':
        return 'Status: Follow-Up';
      case 'site visit scheduled':
        return 'Site Visit Scheduled';
      case 'site visit done':
      case 'visited':
        return 'Site Visit Completed';
      case 'won':
        return 'Status: Won';
      case 'lost':
      case 'lost/dead':
        return 'Status: Lost/Dead';
      default:
        return 'Status Changed';
    }
  }

  String _statusLogText(String statusLower, String clientName, String triggeredBy, String? context) {
    final statusLabel = _statusLabel(statusLower);
    switch (triggeredBy) {
      case 'manual':
        return '$clientName status set to $statusLabel';
      case 'outcome_tag':
        return '$clientName status set to $statusLabel (via outcome: ${context ?? ''})';
      case 'site_visit_completed':
        return '$clientName status set to $statusLabel (Site Visit Completed)';
      case 'site_visit_missed':
        return '$clientName status set to $statusLabel (Site Visit Missed)';
      case 'site_visit_scheduled':
        return '$clientName status set to $statusLabel (Site Visit Scheduled)';
      case 'site_visit_rescheduled':
        return '$clientName status set to $statusLabel (Site Visit Rescheduled)';
      default:
        return '$clientName status set to $statusLabel';
    }
  }

  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'new':
        return 'New';
      case 'called':
        return 'Called';
      case 'follow-up':
        return 'Follow-Up';
      case 'site visit scheduled':
        return 'SV Scheduled';
      case 'site visit done':
      case 'visited':
        return 'Site Visit Done';
      case 'won':
        return 'Won';
      case 'lost':
      case 'lost/dead':
        return 'Lost / Dead';
      default:
        return s;
    }
  }


  // ─── Site Visits ──────────────────────────────────────────────────────────

  /// Streams all site visits for the current user, ordered by visit date.
  ///
  /// Returns an empty stream if no user is authenticated.
  Stream<List<SiteVisitModel>> streamSiteVisits() {
    if (_uid == null) return Stream.value([]);
    _checkUidAndResetCache();

    final controller = StreamController<List<SiteVisitModel>>.broadcast();

    final cache = _siteVisitsCache;
    if (cache != null) {
      Future.microtask(() {
        if (!controller.isClosed) {
          controller.add(cache);
        }
      });
    }

    final sub = _siteVisitsRef()
        .orderBy('visitDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SiteVisitModel.fromFirestore(doc))
            .toList())
        .listen((visits) {
      _siteVisitsCache = visits;
      if (!controller.isClosed) {
        controller.add(visits);
      }
    }, onError: (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    });

    controller.onCancel = () {
      sub.cancel();
      controller.close();
    };

    return controller.stream;
  }

  /// Creates or overwrites a site visit document.
  ///
  /// [visit] - The [SiteVisitModel] to persist. Empty IDs receive auto-generated IDs.
  Future<void> addSiteVisit(SiteVisitModel visit) async {
    final ref = visit.id.isEmpty
        ? _siteVisitsRef().doc()
        : _siteVisitsRef().doc(visit.id);
    await ref.set(visit.toMap());
  }

  /// Partially updates a site visit document using field-level [updates].
  ///
  /// [visitId] - The Firestore document ID of the site visit to update.
  /// [updates] - A map of field paths to new values.
  Future<void> updateSiteVisit(
      String visitId, Map<String, dynamic> updates) async {
    await _siteVisitsRef().doc(visitId).update(updates);
  }

  // ─── User Profile ─────────────────────────────────────────────────────────

  /// Streams the current user's profile document.
  ///
  /// Emits `null` if the profile document does not exist or if no user
  /// is authenticated.
  Stream<Map<String, dynamic>?> streamUserProfile() {
    if (_uid == null) return Stream.value(null);
    return _userRef().snapshots().map((doc) => doc.data());
  }

  /// Merges [data] into the current user's profile document.
  ///
  /// Uses [SetOptions.merge] so existing fields not included in [data]
  /// are preserved.
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    await _userRef().set(data, SetOptions(merge: true));
  }

  // ─── Call Logs ────────────────────────────────────────────────────────────

  /// Streams all call log entries for the current user, ordered by
  /// creation date (newest first).
  ///
  /// Returns an empty stream if no user is authenticated.
  Stream<List<Map<String, dynamic>>> streamCallLogs() {
    if (_uid == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(_uid)
        .collection('calllog')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// Normalizes a phone number for comparison by stripping all non-digits,
  /// removing country code '91' and leading '0', and returning the last 10 digits.
  static String normalizePhone(String phone) {
    String cleaned = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      cleaned = cleaned.substring(2);
    }
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.length > 10) {
      cleaned = cleaned.substring(cleaned.length - 10);
    }
    return cleaned;
  }

  /// Searches for a duplicate lead by primary phone number.
  /// If multiple matches are found, it returns the most recently added one
  /// based on the `createdAt` timestamp.
  Future<LeadModel?> findDuplicateLead(String enteredPhone) async {
    if (_uid == null) return null;
    final normalizedEntered = normalizePhone(enteredPhone);
    if (normalizedEntered.isEmpty) return null;

    final querySnapshot = await _leadsRef().get();
    
    LeadModel? duplicate;
    DateTime? newestDate;

    for (final doc in querySnapshot.docs) {
      final lead = LeadModel.fromFirestore(doc);
      final normalizedLeadPhone = normalizePhone(lead.phone);
      if (normalizedEntered == normalizedLeadPhone) {
        final date = DateTime.tryParse(lead.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (duplicate == null || date.isAfter(newestDate!)) {
          duplicate = lead;
          newestDate = date;
        }
      }
    }
    return duplicate;
  }

  // ─── Projects (Inventory) ─────────────────────────────────────────────────

  /// Returns the projects collection reference for the current user.
  CollectionReference<Map<String, dynamic>> _projectsRef() {
    if (_uid == null) throw Exception('User not authenticated');
    return _db.collection('users').doc(_uid).collection('projects');
  }

  /// Streams all projects for the current user, ordered by name.
  Stream<List<ProjectModel>> streamProjects() {
    if (_uid == null) return Stream.value([]);
    return _projectsRef()
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ProjectModel.fromFirestore(doc)).toList());
  }

  /// Creates or overwrites a project document.
  Future<String> addProject(ProjectModel project) async {
    final ref = project.id.isEmpty
        ? _projectsRef().doc()
        : _projectsRef().doc(project.id);
    await ref.set(project.toMap());
    return ref.id;
  }

  /// Partially updates a project document.
  Future<void> updateProject(String projectId, Map<String, dynamic> updates) async {
    await _projectsRef().doc(projectId).update(updates);
  }

  /// Deletes a project document.
  Future<void> deleteProject(String projectId) async {
    await _projectsRef().doc(projectId).delete();
  }

  /// Finds a project by name (case-insensitive match).
  /// Returns the first match, or null if not found.
  Future<ProjectModel?> getProjectByName(String name) async {
    if (_uid == null || name.isEmpty) return null;
    final snapshot = await _projectsRef().get();
    final nameLower = name.toLowerCase().trim();
    for (final doc in snapshot.docs) {
      final project = ProjectModel.fromFirestore(doc);
      if (project.name.toLowerCase().trim() == nameLower) {
        return project;
      }
    }
    return null;
  }

  // ─── Towers (Sub-collection under Project) ────────────────────────────────

  /// Returns the towers sub-collection reference for a project.
  CollectionReference<Map<String, dynamic>> _towersRef(String projectId) {
    return _projectsRef().doc(projectId).collection('towers');
  }

  /// Streams all towers for a given project.
  Stream<List<TowerModel>> streamTowers(String projectId) {
    if (_uid == null) return Stream.value([]);
    return _towersRef(projectId)
        .orderBy('towerName')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TowerModel.fromFirestore(doc)).toList());
  }

  /// Batch-creates multiple towers in a single write.
  Future<List<String>> addTowersBatch(String projectId, List<TowerModel> towers) async {
    final batch = _db.batch();
    final ids = <String>[];
    for (final tower in towers) {
      final ref = tower.id.isEmpty
          ? _towersRef(projectId).doc()
          : _towersRef(projectId).doc(tower.id);
      batch.set(ref, tower.toMap());
      ids.add(ref.id);
    }
    await batch.commit();
    return ids;
  }

  /// Updates a single tower document.
  Future<void> updateTower(String projectId, String towerId, Map<String, dynamic> updates) async {
    await _towersRef(projectId).doc(towerId).update(updates);
  }

  // ─── Units (Sub-collection under Project) ─────────────────────────────────

  /// Returns the units sub-collection reference for a project.
  CollectionReference<Map<String, dynamic>> _unitsRef(String projectId) {
    return _projectsRef().doc(projectId).collection('units');
  }

  /// Streams all units for a given project, ordered by unit number.
  Stream<List<UnitModel>> streamUnits(String projectId) {
    if (_uid == null) return Stream.value([]);
    return _unitsRef(projectId)
        .orderBy('unitNumber')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UnitModel.fromFirestore(doc)).toList());
  }

  /// Batch-creates multiple units. Firestore limits batches to 500,
  /// so this splits into chunks for large projects.
  Future<void> addUnitsBatch(String projectId, List<UnitModel> units) async {
    const batchLimit = 499;
    for (int i = 0; i < units.length; i += batchLimit) {
      final chunk = units.sublist(
        i,
        i + batchLimit > units.length ? units.length : i + batchLimit,
      );
      final batch = _db.batch();
      for (final unit in chunk) {
        final ref = unit.id.isEmpty
            ? _unitsRef(projectId).doc()
            : _unitsRef(projectId).doc(unit.id);
        batch.set(ref, unit.toMap());
      }
      await batch.commit();
    }
  }

  /// Updates a single unit document (status, price, notes, booking link).
  Future<void> updateUnit(String projectId, String unitId, Map<String, dynamic> updates) async {
    await _unitsRef(projectId).doc(unitId).update(updates);
  }
}
