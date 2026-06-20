import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_export.dart';
import '../../models/lead_model.dart';
import '../../services/firestore_service.dart';
import '../../services/twilio_voice_service.dart';
import '../../services/migration_service.dart';
import '../../widgets/app_navigation.dart';
import './widgets/follow_up_buckets_widget.dart';
import './widgets/stat_cards_widget.dart';

// TODO: Replace with Riverpod/Bloc for production state management
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  // Live state from Firestore
  List<LeadModel> _leads = [];
  List<Map<String, dynamic>> _callLogs = [];
  StreamSubscription? _leadsSub;
  StreamSubscription? _callLogsSub;

  String? _pendingLeadId;
  String? _pendingSource;
  String? _pendingReturnBucket;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> get _leadMaps => _leads.map((l) {
    final map = l.toMap();
    map['id'] = l.id;
    return map;
  }).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Load VoIP config & run migration on app start
    TwilioVoiceService.instance.loadConfig();
    MigrationService.run();

    _leadsSub = FirestoreService.instance.streamLeads().listen((leads) {
      if (mounted) setState(() => _leads = leads);
    });
    _callLogsSub = FirestoreService.instance.streamCallLogs().listen((logs) {
      if (mounted) setState(() => _callLogs = logs);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _leadsSub?.cancel();
    _callLogsSub?.cancel();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
  }

  DateTime? _dateFromValue(dynamic value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    if (value is String &&
        value.trim().isNotEmpty &&
        value != 'none' &&
        value != '-') {
      try {
        return DateTime.parse(value.replaceFirst(' ', 'T')).toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isLostLead(Map<String, dynamic> lead) {
    final status = (lead['status'] as String? ?? '').toLowerCase();
    return status == 'lost/dead' || status == 'lost' || status == 'dead';
  }

  bool _isClosedLead(Map<String, dynamic> lead) {
    final status = (lead['status'] as String? ?? '').toLowerCase();
    final isActive = lead['isActive'] as bool? ?? true;
    return !isActive || status == 'lost/dead' || status == 'won' || status == 'lost' || status == 'dead';
  }

  List<Map<String, dynamic>> get _pipelineLeads =>
      _leadMaps.where((lead) => !_isLostLead(lead)).toList();

  List<Map<String, dynamic>> get _openPipelineLeads =>
      _leadMaps.where((lead) => !_isClosedLead(lead)).toList();

  int _callCountForDay(DateTime day) {
    return _callLogs.where((log) {
      final dt = _dateFromValue(log['createdAt']);
      return dt != null && _isSameDay(dt, day);
    }).length;
  }

  int _leadCountForDay(DateTime day) {
    return _pipelineLeads.where((lead) {
      final dt = _dateFromValue(lead['createdAt']);
      return dt != null && _isSameDay(dt, day);
    }).length;
  }

  // Computed stats
  int get _callsDoneToday {
    return _callCountForDay(DateTime.now());
  }

  int get _callsDoneYesterday {
    return _callCountForDay(DateTime.now().subtract(const Duration(days: 1)));
  }

  int get _totalLeads => _leadMaps.length;
  int get _activeLeads {
    final lostCount = _leadMaps.where((lead) {
      final status = (lead['status'] as String? ?? '').toLowerCase();
      return status == 'lost/dead' || status == 'lost' || status == 'dead';
    }).length;
    return _leadMaps.length - lostCount;
  }
  int get _newLeadsToday => _leadCountForDay(DateTime.now());
  int get _openOverdueCount => _overdue.length;

  String get _avgCallTime {
    if (_callLogs.isEmpty) return '0s';
    int totalSecs = 0;
    int count = 0;
    for (final log in _callLogs) {
      final secs = log['durationSeconds'] as int? ?? 0;
      totalSecs += secs;
      count++;
    }
    final avg = totalSecs / count;
    final avgMins = avg ~/ 60;
    final avgSecs = (avg % 60).round();
    if (avgMins > 0) {
      return '${avgMins}m ${avgSecs}s';
    }
    return '${avgSecs}s';
  }

  // ─── Helper: ISO date string from DateTime ──────────────────────────────
  String _isoDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  // ─── Bucket data — corrected date comparisons (local timezone) ─────────

  List<Map<String, dynamic>> get _followUpToday {
    final todayStr = _isoDate(DateTime.now());
    final results = _openPipelineLeads
        .where((l) => l['followUpDate'] == todayStr)
        .toList();
    debugPrint('[TODAY BUCKET] today=$todayStr | count=${results.length}');
    return results;
  }

  List<Map<String, dynamic>> get _followUpTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomStr = _isoDate(tomorrow);
    final results = _openPipelineLeads
        .where((l) => l['followUpDate'] == tomStr)
        .toList();
    debugPrint('[TOMORROW BUCKET] tomorrow=$tomStr | count=${results.length}');
    return results;
  }

  /// DUE = followUpDate was exactly yesterday (1 day late)
  List<Map<String, dynamic>> get _due {
    final now = DateTime.now();
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    final yesterdayStr = _isoDate(yesterday);

    debugPrint('[DUE BUCKET] computed yesterday=$yesterdayStr');

    final results = _openPipelineLeads.where((l) {
      final fu = l['followUpDate'] as String? ?? 'none';
      if (fu == 'none' || fu.isEmpty) return false;
      final isDue = fu == yesterdayStr;
      if (isDue) {
        debugPrint('[DUE BUCKET] ✓ lead "${l['clientName']}" followUpDate=$fu');
      }
      return isDue;
    }).toList();

    debugPrint('[DUE BUCKET] total=${results.length}');
    return results;
  }

  /// OVERDUE = followUpDate is 2 or more days in the past
  List<Map<String, dynamic>> get _overdue {
    final now = DateTime.now();
    final twoDaysAgo = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 2));
    final boundaryStr = _isoDate(twoDaysAgo);

    debugPrint('[OVERDUE BUCKET] boundary (<=) $boundaryStr');

    final results = _openPipelineLeads.where((l) {
      final fu = l['followUpDate'] as String? ?? 'none';
      if (fu == 'none' || fu.isEmpty) return false;
      final isOverdue = fu.compareTo(boundaryStr) <= 0;
      if (isOverdue) {
        debugPrint(
          '[OVERDUE BUCKET] ✓ lead "${l['clientName']}" followUpDate=$fu',
        );
      }
      return isOverdue;
    }).toList();

    debugPrint('[OVERDUE BUCKET] total=${results.length}');
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = _formatDate(now);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final expandBucket = args?['expandBucket'] as String?;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen == true) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Application'),
            content: const Text('Are you sure you want to exit?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppTheme.backgroundLight,
        drawer: const AppDrawer(currentRoute: '/dashboard-screen'),
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
                'Dashboard',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkText,
                ),
              ),
              Text(
                dateStr,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.mutedText,
                ),
              ),
            ],
          ),
          actions: [
            Builder(
              builder: (context) {
                final notifications = _notifications;
                return Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      onPressed: () => _showNotificationsSheet(notifications),
                      icon: CustomIconWidget(
                        iconName: 'notifications',
                        color: AppTheme.primary,
                        size: 24,
                      ),
                    ),
                    if (notifications.isNotEmpty)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppTheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 16,
                vertical: 16,
              ),
              child: isTablet ? _buildTabletLayout(expandBucket) : _buildPhoneLayout(expandBucket),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneLayout(String? expandBucket) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FollowUpBucketsWidget(
          todayLeads: _followUpToday,
          tomorrowLeads: _followUpTomorrow,
          dueLeads: _due,
          overdueLeads: _overdue,
          onCallNow: _onCallNow,
          initialBucket: expandBucket,
        ),
        const SizedBox(height: 20),
        StatCardsWidget(
          callsDoneToday: _callsDoneToday,
          callsDoneYesterday: _callsDoneYesterday,
          totalLeads: _totalLeads,
          newLeadsToday: _newLeadsToday,
          activeLeads: _activeLeads,
          overdueLeads: _openOverdueCount,
          avgCallTime: _avgCallTime,
          hasCalls: _callLogs.isNotEmpty,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTabletLayout(String? expandBucket) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: StatCardsWidget(
            callsDoneToday: _callsDoneToday,
            callsDoneYesterday: _callsDoneYesterday,
            totalLeads: _totalLeads,
            newLeadsToday: _newLeadsToday,
            activeLeads: _activeLeads,
            overdueLeads: _openOverdueCount,
            avgCallTime: _avgCallTime,
            hasCalls: _callLogs.isNotEmpty,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 4,
          child: FollowUpBucketsWidget(
            todayLeads: _followUpToday,
            tomorrowLeads: _followUpTomorrow,
            dueLeads: _due,
            overdueLeads: _overdue,
            onCallNow: _onCallNow,
            initialBucket: expandBucket,
          ),
        ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingLeadId != null) {
      final leadIdToNavigate = _pendingLeadId!;
      final returnBucket = _pendingReturnBucket;
      // Clear pending state immediately so we don't trigger navigation twice
      setState(() {
        _pendingLeadId = null;
        _pendingSource = null;
        _pendingReturnBucket = null;
      });

      // Increment callsMade/callsCount in Firestore and check temperature
      _incrementCallCount(leadIdToNavigate);

      // Navigate to Lead Detail after a small delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pushNamed(
            context,
            AppRoutes.leadDetailScreen,
            arguments: {
              'leadId': leadIdToNavigate,
              'returnTo': 'Dashboard',
              'returnBucket': returnBucket,
            },
          );
        }
      });
    }
  }

  Future<void> _incrementCallCount(String leadId) async {
    try {
      final uid = FirestoreService.instance.currentUid;
      if (uid != null) {
        final leadDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('leads')
            .doc(leadId);
        
        final doc = await leadDocRef.get();
        final Map<String, dynamic> updates = {
          'callsMade': FieldValue.increment(1),
          'callsCount': FieldValue.increment(1),
          'lastCalledAt': DateTime.now().toIso8601String(),
        };

        if (doc.exists) {
          final temp = doc.data()?['leadTemperature'] as String?;
          if (temp == null || temp.isEmpty) {
            updates['leadTemperature'] = 'Cold';
          }
        }

        await leadDocRef.update(updates);
      }
    } catch (e) {
      debugPrint('Error updating lead call status: $e');
    }
  }

  Future<void> _onCallNow(Map<String, dynamic> lead, String bucketTitle) async {
    final leadId = lead['id'] as String;
    String? phone = lead['phone'] as String?;

    if (phone == null || phone.isEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirestoreService.instance.currentUid)
            .collection('leads')
            .doc(leadId)
            .get();
        if (doc.exists) {
          phone = doc.data()?['phone'] as String?;
        }
      } catch (e) {
        debugPrint('Error fetching phone from Firestore: $e');
      }
    }

    if (phone != null && phone.isNotEmpty) {
      // Normalize: strip +91, spaces, dashes -> plain 10 digits -> prepend 91
      String digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        digits = digits.substring(digits.length - 10);
      }
      final normalizedPhone = '91$digits';

      final uri = Uri.parse('tel:$normalizedPhone');
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          setState(() {
            _pendingLeadId = leadId;
            _pendingSource = 'Dashboard';
            _pendingReturnBucket = bucketTitle;
          });
        } else {
          debugPrint('Could not launch tel:$normalizedPhone');
        }
      } catch (e) {
        debugPrint('Error launching dialer: $e');
      }
    } else {
      debugPrint('No phone number found for lead $leadId');
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
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]}, ${months[dt.month]} ${dt.day}, ${dt.year}';
  }

  List<Map<String, dynamic>> get _notifications {
    final now = DateTime.now();
    final List<Map<String, dynamic>> list = [];
    final hours = [10, 13, 16, 19, 22];

    final overdueCount = _overdue.length;
    final dueTodayCount = _followUpToday.length;

    for (int hour in hours) {
      final milestone = DateTime(now.year, now.month, now.day, hour, 0);
      if (now.isAfter(milestone)) {
        String timeStr =
            '${hour > 12 ? hour - 12 : hour}:00 ${hour >= 12 ? 'PM' : 'AM'}';
        String title = '';
        String body = '';

        if (hour == 10) {
          title = 'Morning Kickoff';
          body =
              'Are you sleeping? You have $overdueCount overdue leads! Start to work and start calling fast!';
        } else if (hour == 13) {
          title = 'Midday Check-in';
          body =
              'Time is ticking! $dueTodayCount follow-ups due today and $overdueCount overdue. Start calling fast!';
        } else if (hour == 16) {
          title = 'Afternoon Push';
          body =
              'Keep going! Still got $overdueCount overdue follow-ups waiting. Dial them now!';
        } else if (hour == 19) {
          title = 'Evening Wrap-up';
          body =
              'Almost end of the day. Finish your $dueTodayCount pending calls and resolve the $overdueCount overdue leads!';
        } else {
          title = 'Late Catch-up';
          body =
              'Don\'t let $overdueCount overdue leads slide to tomorrow. Call them now!';
        }

        list.add({
          'time': timeStr,
          'title': title,
          'body': body,
          'timestamp': milestone,
        });
      }
    }

    list.sort(
      (a, b) =>
          (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
    );
    return list;
  }

  void _showNotificationsSheet(List<Map<String, dynamic>> notifications) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkText,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${notifications.length} Alerts',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (notifications.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        CustomIconWidget(
                          iconName: 'notifications_none',
                          color: AppTheme.mutedText,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No alerts yet today',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hourly action reminders start at 10:00 AM.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppTheme.borderColor),
                    itemBuilder: (context, idx) {
                      final item = notifications[idx];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.errorContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.campaign,
                            color: AppTheme.error,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['title'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkText,
                              ),
                            ),
                            Text(
                              item['time'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.mutedText,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            item['body'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: AppTheme.darkText.withAlpha(204),
                              height: 1.3,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRoutes.myLeadsScreen);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
