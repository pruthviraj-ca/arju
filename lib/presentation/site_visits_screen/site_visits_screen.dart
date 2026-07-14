import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_export.dart';
import '../../models/lead_model.dart';
import '../../models/site_visit_model.dart';
import '../../models/note_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/custom_icon_widget.dart';
import '../../utils/phone_utils.dart';

class SiteVisitsScreen extends StatefulWidget {
  const SiteVisitsScreen({super.key});

  @override
  State<SiteVisitsScreen> createState() => _SiteVisitsScreenState();
}

class _SiteVisitsScreenState extends State<SiteVisitsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  bool _isLoading = true;

  StreamSubscription? _visitsSub;
  StreamSubscription? _leadsSub;
  List<SiteVisitModel> _allVisits = [];
  Map<String, LeadModel> _leadMap = {};

  @override
  void initState() {
    super.initState();
    // Listen to leads to get phone number and other lead details
    _leadsSub = FirestoreService.instance.streamLeads().listen((leads) {
      if (mounted) {
        setState(() {
          _leadMap = {for (var l in leads) l.id: l};
        });
      }
    });

    _visitsSub = FirestoreService.instance.streamSiteVisits().listen((visits) {
      if (mounted) {
        setState(() {
          _allVisits = visits;
          _isLoading = false;
        });
      }
    });

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _visitsSub?.cancel();
    _leadsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  DateTime _parseDateTime(String dateStr, String timeStr) {
    if (dateStr.isEmpty || dateStr == 'none') {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    try {
      final dateParts = dateStr.split('-');
      if (dateParts.length != 3) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      if (timeStr.isEmpty || timeStr.toLowerCase() == 'none' || !timeStr.contains(RegExp(r'[0-9]'))) {
        return DateTime(year, month, day);
      }

      final cleanTime = timeStr.trim().toUpperCase();
      final isPm = cleanTime.contains('PM');
      final isAm = cleanTime.contains('AM');
      final timeOnly = cleanTime.replaceAll('PM', '').replaceAll('AM', '').trim();
      final timeParts = timeOnly.split(':');
      if (timeParts.length < 2) {
        return DateTime(year, month, day);
      }
      var hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      if (isPm && hour != 12) {
        hour += 12;
      } else if (isAm && hour == 12) {
        hour = 0;
      }

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      try {
        return DateTime.parse(dateStr);
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
  }

  List<SiteVisitModel> get _filteredVisits {
    var result = List<SiteVisitModel>.from(_allVisits);

    // Filter by Status
    if (_selectedFilter != 'All') {
      result = result.where((v) {
        final statusLower = v.status.toLowerCase();
        if (_selectedFilter == 'Scheduled') {
          return statusLower == 'scheduled';
        } else if (_selectedFilter == 'Completed') {
          return statusLower == 'completed' || statusLower == 'done';
        } else if (_selectedFilter == 'Missed') {
          return statusLower == 'missed';
        } else if (_selectedFilter == 'Rescheduled') {
          return statusLower == 'rescheduled';
        }
        return true;
      }).toList();
    }

    // Filter by Search Query (Client Name or Property)
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((v) {
        return v.clientName.toLowerCase().contains(q) ||
            v.property.toLowerCase().contains(q);
      }).toList();
    }

    // Sort visits by combined date + time descending (latest first)
    result.sort((a, b) {
      final dateTimeA = _parseDateTime(a.visitDate, a.visitTime);
      final dateTimeB = _parseDateTime(b.visitDate, b.visitTime);
      return dateTimeB.compareTo(dateTimeA);
    });

    return result;
  }

  Future<void> _handleRefresh() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addAutoLogNote({
    required String leadId,
    required String clientName,
    required String text,
    required String tag,
  }) async {
    final now = DateTime.now();
    final createdAt =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final note = NoteModel(
      id: '',
      text: text,
      tag: tag,
      callDuration: '',
      createdAt: createdAt,
      isAutoLog: true,
    );
    await FirestoreService.instance.addNote(leadId, note);
  }

  void _markVisitDone(String visitId, String leadId, String clientName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Confirm Completed',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Mark site visit as Completed for $clientName?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.mutedText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF28A745),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final leadSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirestoreService.instance.currentUid)
          .collection('leads')
          .doc(leadId)
          .get();

      String currentTemp = '';
      if (leadSnap.exists) {
        currentTemp = leadSnap.data()?['leadTemperature'] as String? ?? '';
      }

      String targetTemp = currentTemp;
      if (currentTemp.isEmpty || currentTemp == 'Cold') {
        targetTemp = 'Warm';
      }

      await FirestoreService.instance.updateSiteVisit(visitId, {'status': 'Completed'});

      await FirestoreService.instance.updateLead(leadId, {
        'siteVisitStatus': 'Completed',
      });

      await FirestoreService.instance.updateLeadStatus(
        leadId: leadId,
        newStatus: 'site visit done',
        triggeredBy: 'site_visit_completed',
        clientName: clientName,
        logStatusChange: false,
      );

      await FirestoreService.instance.updateLeadTemperature(
        leadId: leadId,
        newTemp: targetTemp,
        triggeredBy: 'site_visit_completed',
        clientName: clientName,
        oldTemp: currentTemp,
      );

      await _addAutoLogNote(
        leadId: leadId,
        clientName: clientName,
        text: '$clientName completed site visit',
        tag: 'Site Visit Completed',
      );
      
      _handleRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.success,
            content: Text('Site visit marked as Completed'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.error,
            content: Text('Error updating status: $e'),
          ),
        );
      }
    }
  }

  void _markVisitMissed(String visitId, String leadId, String clientName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Confirm Missed',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Mark site visit as Missed for $clientName?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.mutedText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE05252),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirestoreService.instance.updateSiteVisit(visitId, {'status': 'Missed'});
      await FirestoreService.instance.updateLead(leadId, {
        'siteVisitStatus': 'Missed',
      });
      await FirestoreService.instance.updateLeadStatus(
        leadId: leadId,
        newStatus: 'called',
        triggeredBy: 'site_visit_missed',
        clientName: clientName,
        logStatusChange: false,
      );
      await _addAutoLogNote(
        leadId: leadId,
        clientName: clientName,
        text: '$clientName missed site visit',
        tag: 'Site Visit Missed',
      );
      
      _handleRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.error,
            content: Text('Site visit marked as Missed'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.error,
            content: Text('Error updating status: $e'),
          ),
        );
      }
    }
  }

  void _rescheduleVisit(String visitId, String leadId, String clientName) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const RescheduleDateTimePickerDialog(
        title: 'Select new site visit date & time',
        confirmLabel: 'Reschedule',
      ),
    );

    if (result == null) return;

    final DateTime date = result['date'];
    final TimeOfDay time = result['time'];

    final dateIso = date.toIso8601String().substring(0, 10);
    
    // Format Time
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final min = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final timeStr = '$hour:$min $period';

    try {
      await FirestoreService.instance.updateSiteVisit(visitId, {
        'status': 'Rescheduled',
        'scheduledDate': dateIso,
        'scheduledTime': timeStr,
        'visitDate': dateIso,
        'visitTime': timeStr,
      });

      await FirestoreService.instance.updateLead(leadId, {
        'siteVisitStatus': 'Rescheduled',
      });

      await FirestoreService.instance.updateLeadStatus(
        leadId: leadId,
        newStatus: 'site visit scheduled',
        triggeredBy: 'site_visit_rescheduled',
        clientName: clientName,
        logStatusChange: false,
      );

      await _addAutoLogNote(
        leadId: leadId,
        clientName: clientName,
        text: '$clientName rescheduled site visit to $dateIso at $timeStr',
        tag: 'Rescheduled',
      );

      _handleRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFF97316),
            content: Text('Site visit rescheduled to $dateIso at $timeStr'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.error,
            content: Text('Error rescheduling site visit: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredVisits;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen == true) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboardScreen, (route) => false);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppTheme.backgroundLight,
        drawer: const AppDrawer(currentRoute: '/site-visits-screen'),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppTheme.borderColor,
        leading: Builder(
          builder: (context) => IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: CustomIconWidget(
              iconName: 'menu',
              color: AppTheme.primary,
              size: 24,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Site Visits',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkText,
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${_allVisits.length} total · ${_allVisits.where((v) => v.status.toLowerCase() == 'scheduled').length} scheduled · ',
                  ),
                  TextSpan(
                    text: '${_allVisits.where((v) => ['completed', 'done'].contains(v.status.toLowerCase())).length}',
                    style: const TextStyle(
                      color: Color(0xFF28A745),
                    ),
                  ),
                  const TextSpan(
                    text: ' completed · ',
                  ),
                  TextSpan(
                    text: '${_allVisits.where((v) => v.status.toLowerCase() == 'missed').length}',
                    style: const TextStyle(
                      color: Color(0xFFE05252),
                    ),
                  ),
                  const TextSpan(
                    text: ' missed',
                  ),
                ],
              ),
              softWrap: true,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppTheme.mutedText,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search & Filters bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Search field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by client or property...',
                      hintStyle: GoogleFonts.inter(fontSize: 14, color: AppTheme.mutedText),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.mutedText),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20, color: AppTheme.mutedText),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                      ),
                      filled: true,
                      fillColor: AppTheme.backgroundLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Chips
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['All', 'Scheduled', 'Completed', 'Missed', 'Rescheduled'].map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              filter,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? Colors.white : AppTheme.darkText,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedFilter = filter);
                              }
                            },
                            selectedColor: AppTheme.primary,
                            backgroundColor: AppTheme.backgroundLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? AppTheme.primary : AppTheme.borderColor,
                              ),
                            ),
                            showCheckmark: false,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // Visits List
            Expanded(
              child: _isLoading
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: 3,
                      itemBuilder: (context, index) => const SiteVisitCardSkeletonWidget(),
                    )
                  : RefreshIndicator(
                      onRefresh: _handleRefresh,
                      color: AppTheme.primary,
                      child: filtered.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryContainer,
                                          shape: BoxShape.circle,
                                        ),
                                        child: CustomIconWidget(
                                          iconName: 'event',
                                          color: AppTheme.primary,
                                          size: 40,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No site visits found',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.darkText,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _searchQuery.isNotEmpty || _selectedFilter != 'All'
                                            ? 'Try changing your search query or filters.'
                                            : 'Schedule site visits directly from lead details.',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: AppTheme.mutedText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final visit = filtered[index];
                                final lead = _leadMap[visit.leadId];
                                return _SiteVisitListCard(
                                  visit: visit,
                                  lead: lead,
                                  onMarkDone: () => _markVisitDone(
                                    visit.id,
                                    visit.leadId,
                                    lead?.clientName ?? visit.clientName,
                                  ),
                                  onMarkMissed: () => _markVisitMissed(
                                    visit.id,
                                    visit.leadId,
                                    lead?.clientName ?? visit.clientName,
                                  ),
                                  onReschedule: () => _rescheduleVisit(
                                    visit.id,
                                    visit.leadId,
                                    lead?.clientName ?? visit.clientName,
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _SiteVisitListCard extends StatelessWidget {
  final SiteVisitModel visit;
  final LeadModel? lead;
  final VoidCallback onMarkDone;
  final VoidCallback onMarkMissed;
  final VoidCallback onReschedule;

  const _SiteVisitListCard({
    required this.visit,
    this.lead,
    required this.onMarkDone,
    required this.onMarkMissed,
    required this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    final statusLower = visit.status.toLowerCase();
    final isPending = statusLower == 'scheduled';
    final isDone = statusLower == 'completed' || statusLower == 'done';
    final isMissed = statusLower == 'missed';
    final isRescheduled = statusLower == 'rescheduled';

    Color statusColor = AppTheme.purple;
    Color statusBg = AppTheme.purpleContainer;
    String statusText = 'Scheduled';

    if (isDone) {
      statusColor = const Color(0xFF28A745);
      statusBg = const Color(0xFFD4EDDA);
      statusText = 'Completed';
    } else if (isMissed) {
      statusColor = const Color(0xFFE05252);
      statusBg = const Color(0xFFFDE8E8);
      statusText = 'Missed';
    } else if (isRescheduled) {
      statusColor = const Color(0xFFF97316);
      statusBg = const Color(0xFFFFE8CC);
      statusText = 'Rescheduled';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.leadDetailScreen,
            arguments: {
              'leadId': visit.leadId,
              'origin': AppRoutes.siteVisitsScreen,
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Status badge & Call Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (lead != null && lead!.phone.isNotEmpty)
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withAlpha(26),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call, color: AppTheme.success, size: 16),
                      ),
                      onPressed: () async {
                        final formattedPhone = formatPhoneForCall(lead!.phone);
                        final uri = Uri(scheme: 'tel', path: formattedPhone);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Name & Property
              Text(
                visit.clientName,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.apartment, size: 14, color: AppTheme.mutedText),
                  const SizedBox(width: 6),
                  Text(
                    visit.property,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.mutedText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppTheme.borderColor),
              const SizedBox(height: 12),
              // Date, Time & Quick Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SCHEDULED FOR',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 13, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            visit.visitDate,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkText,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, size: 13, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            visit.visitTime,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (isPending || isRescheduled) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildOutlinedButton(
                                label: 'Completed',
                                color: const Color(0xFF28A745),
                                onPressed: onMarkDone,
                              ),
                              _buildOutlinedButton(
                                label: 'Missed',
                                color: const Color(0xFFE05252),
                                onPressed: onMarkMissed,
                              ),
                              _buildOutlinedButton(
                                label: 'Reschedule',
                                color: const Color(0xFFF97316),
                                onPressed: onReschedule,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.transparent,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class RescheduleDateTimePickerDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;

  const RescheduleDateTimePickerDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
  });

  @override
  State<RescheduleDateTimePickerDialog> createState() =>
      _RescheduleDateTimePickerDialogState();
}

class _RescheduleDateTimePickerDialogState
    extends State<RescheduleDateTimePickerDialog> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _selectedDate != null ? _formatDate(_selectedDate!) : 'Select Date';
    final timeStr = _selectedTime != null ? _formatTime(_selectedTime!) : 'Select Time';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 20),
            // Date picker field
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Date',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText),
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, size: 16, color: AppTheme.mutedText),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Time picker field
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Time',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText),
                        ),
                        Text(
                          timeStr,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, size: 16, color: AppTheme.mutedText),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: AppTheme.mutedText, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: (_selectedDate == null || _selectedTime == null)
                      ? null
                      : () {
                          Navigator.pop(context, {
                            'date': _selectedDate,
                            'time': _selectedTime,
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    widget.confirmLabel,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
