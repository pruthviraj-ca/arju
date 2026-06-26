/// reports_screen.dart
///
/// Full-featured Reports screen for the TruAssets CRM.
/// Streams leads and site visits from Firestore, applies a date-range
/// filter, and computes 6 metric cards plus Lead-by-Stage and
/// Lead-by-Source breakdowns — all in real time.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/lead_model.dart';
import '../../models/site_visit_model.dart';
import '../../routes/app_routes.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/report_metric_card.dart';
import './widgets/tabbed_breakdown_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Live data from Firestore
  List<LeadModel> _allLeads = [];
  List<SiteVisitModel> _allSiteVisits = [];
  StreamSubscription? _leadsSub;
  StreamSubscription? _visitsSub;
  bool _isLoading = true;

  // Date range filter — defaults to current calendar month
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;

    _leadsSub = FirestoreService.instance.streamLeads().listen((leads) {
      if (mounted) setState(() { _allLeads = leads; _isLoading = false; });
    });
    _visitsSub = FirestoreService.instance.streamSiteVisits().listen((visits) {
      if (mounted) setState(() => _allSiteVisits = visits);
    });
  }

  @override
  void dispose() {
    _leadsSub?.cancel();
    _visitsSub?.cancel();
    super.dispose();
  }

  // ─── Date helpers ──────────────────────────────────────────────────────────

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'none' || dateStr == '-') {
      return null;
    }
    try {
      return DateTime.parse(dateStr.replaceFirst(' ', 'T')).toLocal();
    } catch (_) {
      return null;
    }
  }

  bool _isInRange(DateTime date) {
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  // ─── Filtered data ────────────────────────────────────────────────────────

  List<LeadModel> get _filteredLeads {
    return _allLeads.where((lead) {
      final created = _parseDate(lead.createdAt);
      return created != null && _isInRange(created);
    }).toList();
  }

  List<SiteVisitModel> get _filteredVisits {
    return _allSiteVisits.where((v) {
      final visitDate = _parseDate(v.visitDate);
      return visitDate != null && _isInRange(visitDate);
    }).toList();
  }

  // ─── Computed metrics ──────────────────────────────────────────────────────

  int get _totalLeads => _filteredLeads.length;

  int get _totalSVs => _filteredVisits
      .where((v) => v.status.toLowerCase() == 'completed' || v.status.toLowerCase() == 'done')
      .length;

  int get _totalBookings => _filteredLeads
      .where((l) => l.status.toLowerCase() == 'won')
      .length;

  String get _leadsToSvRatio {
    if (_totalLeads == 0) return 'No data yet';
    return '${(_totalSVs / _totalLeads * 100).toStringAsFixed(1)}%';
  }

  String get _svToSaleRatio {
    if (_totalSVs == 0) return 'No data yet';
    return '${(_totalBookings / _totalSVs * 100).toStringAsFixed(1)}%';
  }

  Map<String, int> get _stageCounts {
    final counts = <String, int>{};
    for (final lead in _filteredLeads) {
      final stage = lead.status.isEmpty ? 'New' : lead.status;
      counts[stage] = (counts[stage] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> get _leadProjectCounts {
    final counts = <String, int>{};
    for (final lead in _filteredLeads) {
      final project = lead.property.isEmpty ? 'Unknown' : lead.property;
      counts[project] = (counts[project] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> get _sourceCounts {
    final counts = <String, int>{};
    for (final lead in _filteredLeads) {
      final source = lead.source.isEmpty ? 'Unknown' : lead.source;
      counts[source] = (counts[source] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> get _svStatusCounts {
    final counts = <String, int>{};
    for (final v in _filteredVisits) {
      final status = v.status.isEmpty ? 'Scheduled' : v.status;
      final capStatus = status[0].toUpperCase() + status.substring(1);
      counts[capStatus] = (counts[capStatus] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> get _svProjectCounts {
    final counts = <String, int>{};
    for (final v in _filteredVisits) {
      final project = v.property.isEmpty ? 'Unknown' : v.property;
      counts[project] = (counts[project] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> get _svSourceCounts {
    final counts = <String, int>{};
    for (final v in _filteredVisits) {
      final lead = _allLeads.firstWhere(
        (l) => l.id == v.leadId,
        orElse: () => const LeadModel(
          id: '', clientName: '', phone: '', property: '', status: '',
          lastTag: '', followUpDate: '', lastNote: '', isActive: false,
          callDuration: '', createdAt: '', callsCount: 0, source: 'Unknown'
        ),
      );
      final source = (lead.id.isEmpty || lead.source.isEmpty) ? 'Unknown' : lead.source;
      counts[source] = (counts[source] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> get _bookingStatusCounts {
    final counts = <String, int>{};
    for (final lead in _filteredLeads) {
      if (lead.status.toLowerCase() == 'won') {
        final stage = lead.status.isEmpty ? 'Won' : lead.status;
        counts[stage] = (counts[stage] ?? 0) + 1;
      }
    }
    return counts;
  }

  Map<String, int> get _bookingProjectCounts {
    final counts = <String, int>{};
    for (final lead in _filteredLeads) {
      if (lead.status.toLowerCase() == 'won') {
        final project = lead.property.isEmpty ? 'Unknown' : lead.property;
        counts[project] = (counts[project] ?? 0) + 1;
      }
    }
    return counts;
  }

  Map<String, int> get _bookingSourceCounts {
    final counts = <String, int>{};
    for (final lead in _filteredLeads) {
      if (lead.status.toLowerCase() == 'won') {
        final source = lead.source.isEmpty ? 'Unknown' : lead.source;
        counts[source] = (counts[source] ?? 0) + 1;
      }
    }
    return counts;
  }

  // ─── Date range picker ─────────────────────────────────────────────────────

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.darkText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  String get _dateRangeLabel {
    final fmt = DateFormat('MMM dd, yyyy');
    return '${fmt.format(_startDate)} – ${fmt.format(_endDate)}';
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.dashboardScreen, (r) => false,
        );
        return false;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppTheme.backgroundLight,
        drawer: const AppDrawer(currentRoute: '/reports-screen'),
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: () async =>
                            await Future.delayed(const Duration(milliseconds: 400)),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                          children: [
                            _buildDateRangePicker(),
                            const SizedBox(height: 16),
                            _buildMetricsGrid(),
                            const SizedBox(height: 16),
                            TabbedBreakdownCard(
                              leadStatusCounts: _stageCounts,
                              leadProjectCounts: _leadProjectCounts,
                              leadSourceCounts: _sourceCounts,
                              svStatusCounts: _svStatusCounts,
                              svProjectCounts: _svProjectCounts,
                              svSourceCounts: _svSourceCounts,
                              bookingStatusCounts: _bookingStatusCounts,
                              bookingProjectCounts: _bookingProjectCounts,
                              bookingSourceCounts: _bookingSourceCounts,
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── App Bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const CustomIconWidget(
                iconName: 'menu',
                color: AppTheme.primary,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Reports',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkText,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ─── Date Range Picker Row ─────────────────────────────────────────────────

  Widget _buildDateRangePicker() {
    return GestureDetector(
      onTap: _pickDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            CustomIconWidget(
              iconName: 'calendar_today',
              color: AppTheme.primary,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _dateRangeLabel,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
            ),
            CustomIconWidget(
              iconName: 'arrow_drop_down',
              color: AppTheme.mutedText,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ─── 2×3 Metrics Grid ─────────────────────────────────────────────────────

  Widget _buildMetricsGrid() {
    final cards = [
      ReportMetricCard(
        label: 'Total Leads',
        value: _totalLeads.toString(),
        iconName: 'people',
        iconColor: AppTheme.primary,
        iconBgColor: AppTheme.primaryContainer,
      ),
      ReportMetricCard(
        label: 'Total Site Visits Completed',
        value: _totalSVs.toString(),
        iconName: 'location_on',
        iconColor: AppTheme.purple,
        iconBgColor: AppTheme.purpleContainer,
      ),
      ReportMetricCard(
        label: 'Total Bookings',
        value: _totalBookings.toString(),
        iconName: 'check_circle',
        iconColor: AppTheme.success,
        iconBgColor: AppTheme.successContainer,
      ),
      ReportMetricCard(
        label: 'Brokerage Value',
        value: '₹0',
        iconName: 'account_balance_wallet',
        iconColor: AppTheme.accent,
        iconBgColor: AppTheme.accentContainer,
        subtitle: 'No data yet',
      ),
      ReportMetricCard(
        label: 'Leads to SV Ratio',
        value: _leadsToSvRatio,
        iconName: 'trending_up',
        iconColor: AppTheme.teal,
        iconBgColor: AppTheme.tealContainer,
      ),
      ReportMetricCard(
        label: 'SV to Sale Ratio',
        value: _svToSaleRatio,
        iconName: 'compare_arrows',
        iconColor: const Color(0xFF6366F1),
        iconBgColor: const Color(0xFFEEF2FF),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 600;
        final cardWidth = (constraints.maxWidth - 12) / 2;
        final cardHeight = isTablet ? (cardWidth / 1.8) : 100.0;
        final childAspectRatio = cardWidth / cardHeight;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: childAspectRatio,
          children: cards,
        );
      },
    );
  }
}
