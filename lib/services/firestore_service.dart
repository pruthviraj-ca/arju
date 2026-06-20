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
  Future<void> addNote(String leadId, NoteModel note) async {
    final noteRef = note.id.isEmpty
        ? _leadsRef().doc(leadId).collection('notes').doc()
        : _leadsRef().doc(leadId).collection('notes').doc(note.id);
    await noteRef.set(note.toMap());
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
}
