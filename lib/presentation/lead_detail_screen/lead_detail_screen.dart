import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../core/app_export.dart';
import '../../widgets/custom_icon_widget.dart';
import '../../widgets/in_app_dialer_widget.dart';
import '../../services/twilio_voice_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'dart:async';
import '../../widgets/status_badge_widget.dart';
import '../../models/lead_model.dart';
import '../../models/note_model.dart';
import '../../models/unit_model.dart';
import '../../services/firestore_service.dart';
import './widgets/call_note_card_widget.dart';
import './widgets/add_note_form_widget.dart';
import './widgets/site_visit_scheduler_widget.dart';
import '../../utils/tag_colors.dart';

class LeadDetailScreen extends StatefulWidget {
  const LeadDetailScreen({super.key});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  StreamSubscription? _leadSub;
  StreamSubscription? _notesSub;
  List<String> _bucketLeads = [];
  int _currentIndex = 0;
  bool _isFromBucket = false;
  double _dragStartX = 0;
  double _dragEndX = 0;

  LeadModel? _leadModel;
  String? _leadId;
  String? _origin;
  String? _returnTo;
  String? _returnBucket;
  List<NoteModel> _notes = [];
  bool _initialized = false;
  bool _isEditingStatus = false;

  // Pre-fill from dialer
  String _dialerNoteText = '';
  int _dialerDurationMinutes = 0;
  int _dialerDurationSeconds = 0;

  final GlobalKey<AddNoteFormWidgetState> _addNoteFormKey = GlobalKey<AddNoteFormWidgetState>();

  @override
  void initState() {
    super.initState();
    TwilioVoiceService.instance.loadConfig();
  }

  static const List<String> _statuses = [
    'new',
    'called',
    'follow-up',
    'site visit scheduled',
    'site visit done',
    'won',
    'lost/dead',
  ];

  static const List<String> _closedStatuses = ['won', 'lost/dead'];

  bool get _isClosed => _closedStatuses.contains(_lead['status']);

  Map<String, dynamic> get _lead {
    if (_leadModel == null) return _fallbackLead(_leadId ?? 'unknown');
    return {
      'id': _leadModel!.id,
      'clientName': _leadModel!.clientName,
      'phone': _leadModel!.phone,
      'property': _leadModel!.property,
      'status': _leadModel!.status,
      'lastTag': _leadModel!.lastTag,
      'followUpDate': _leadModel!.followUpDate,
      'lastNote': _leadModel!.lastNote,
      'isActive': _leadModel!.isActive,
      'callDuration': _leadModel!.callDuration,
      'createdAt': _leadModel!.createdAt,
      'callsCount': _leadModel!.callsCount,
      'alternatePhone': _leadModel!.alternatePhone,
      'email': _leadModel!.email,
      'source': _leadModel!.source,
      'leadTemperature': _leadModel!.leadTemperature,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _leadId = args['leadId'] as String?;
        _origin = args['origin'] as String?;
        _returnTo = args['returnTo'] as String?;
        _returnBucket = args['returnBucket'] as String?;
        _bucketLeads = List<String>.from(args['bucketLeads'] ?? <String>[]);
        _currentIndex = args['currentIndex'] as int? ?? 0;
        _isFromBucket = args['source'] == 'dashboard_bucket';
      } else if (args is String) {
        _leadId = args;
      }
      if (_leadId != null) {
        _leadSub = FirestoreService.instance.streamLead(_leadId!).listen((lead) {
          if (mounted) setState(() => _leadModel = lead);
        });
        _notesSub = FirestoreService.instance.streamNotes(_leadId!).listen((notes) {
          if (mounted) setState(() => _notes = notes);
        });
      }
      _initialized = true;
    }
  }

  void _navigateToLeadAtIndex(int index) {
    if (index < 0 || index >= _bucketLeads.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(index < 0 ? 'First lead reached' : 'Last lead reached'),
          duration: const Duration(milliseconds: 500),
        ),
      );
      return;
    }
    
    final String nextLeadId = _bucketLeads[index];
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LeadDetailScreen(),
        settings: RouteSettings(
          arguments: {
            'leadId': nextLeadId,
            'origin': _origin,
            'returnTo': _returnTo,
            'returnBucket': _returnBucket,
            'source': 'dashboard_bucket',
            'bucketLeads': _bucketLeads,
            'currentIndex': index,
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final bool isNext = index > _currentIndex;
          final Offset begin = isNext ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
          const Offset end = Offset.zero;
          final Animatable<Offset> tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _leadSub?.cancel();
    _notesSub?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _fallbackLead(String id) => {
    'id': id,
    'clientName': 'Unknown Lead',
    'phone': '—',
    'property': '—',
    'status': 'new',
    'lastTag': '',
    'followUpDate': 'none',
    'lastNote': '',
    'isActive': true,
    'callDuration': '—',
    'createdAt': '—',
    'callsCount': 0,
    'alternatePhone': '',
    'email': '',
    'source': '',
    'leadTemperature': '',
  };

  void _refreshLead() {
    // Left empty for compatibility. Streams auto-update the UI.
  }

  Future<void> _openDialer() async {
    final result = await showInAppDialer(context, lead: _lead);
    if (result != null && mounted) {
      // Save call log to Firestore /calllog
      await _saveCallLog(result);

      final Map<String, dynamic> updates = {
        'lastCalledAt': DateTime.now().toIso8601String(),
        'callsCount': FieldValue.increment(1),
        'callsMade': FieldValue.increment(1),
      };
      if (_leadModel != null && _leadModel!.leadTemperature.isEmpty) {
        updates['leadTemperature'] = 'Cold';
        await FirestoreService.instance.logTemperatureChange(
          leadId: _leadId!,
          clientName: _leadModel!.clientName,
          oldTemp: '',
          newTemp: 'Cold',
        );
      }
      await FirestoreService.instance.updateLead(_leadId!, updates);

      // Pre-fill the Add Note form
      _addNoteFormKey.currentState?.prefillFromDialer(
        noteText: result.noteText,
        durationSeconds: result.durationSeconds,
      );
    }
  }

  Future<void> _saveCallLog(DialerResult result) async {
    try {
      final uid = FirestoreService.instance.currentUid;
      if (uid == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('calllog')
          .add({
        'leadId': result.leadId,
        'clientName': _lead['clientName'] ?? '',
        'phone': _lead['phone'] ?? '',
        'property': _lead['property'] ?? '',
        'durationSeconds': result.durationSeconds,
        'durationFormatted': result.durationFormatted,
        'noteText': result.noteText,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving call log: $e');
    }
  }

  void _updateStatus(String newStatus) async {
    if (_leadModel == null) return;
    final newStatusLower = newStatus.toLowerCase();

    await FirestoreService.instance.updateLeadStatus(
      leadId: _leadModel!.id,
      newStatus: newStatus,
      triggeredBy: 'manual',
      clientName: _leadModel!.clientName,
      oldStatus: _leadModel!.status,
    );

    setState(() {
      _isEditingStatus = false;
    });

    // Check if we can link unit when status is Won
    if (newStatusLower == 'won') {
      final propName = _leadModel!.property;
      final project = await FirestoreService.instance.getProjectByName(propName);
      if (project != null) {
        await _promptUnitLink(project.id, project.name);
      }
    }
  }

  Future<void> _promptUnitLink(String projectId, String projectName) async {
    final units = await FirestoreService.instance.streamUnits(projectId).first;
    final availableUnits = units.where((u) => u.availabilityStatus == 'Available').toList();

    if (!mounted) return;

    if (availableUnits.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('No Available Units', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Text('There are no available units in $projectName to link this booking to.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    UnitModel? selectedUnit;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text('Link Booking to Unit', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Link this booking to a unit in $projectName?',
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<UnitModel>(
                    value: selectedUnit,
                    dropdownColor: Colors.white,
                    hint: Text('Select available unit', style: GoogleFonts.inter(fontSize: 13)),
                    isExpanded: true,
                    items: availableUnits.map((u) {
                      return DropdownMenuItem(
                        value: u,
                        child: Text('${u.unitNumber} (${u.bhkType} · ${u.facing})', style: GoogleFonts.inter(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedUnit = val;
                      });
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Skip', style: GoogleFonts.inter(color: AppTheme.mutedText)),
                ),
                ElevatedButton(
                  onPressed: selectedUnit == null
                      ? null
                      : () async {
                          Navigator.pop(dialogCtx);
                          try {
                            await FirestoreService.instance.updateUnit(
                              projectId,
                              selectedUnit!.id,
                              {
                                'availability_status': 'Booked',
                                'availabilityStatus': 'Booked',
                                'booking_lead_id': _leadId,
                                'bookingLeadId': _leadId,
                                'updatedAt': DateTime.now().toIso8601String(),
                              },
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppTheme.success,
                                  content: Text('Unit ${selectedUnit!.unitNumber} linked successfully!'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppTheme.error,
                                  content: Text('Failed to link unit: $e'),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Link Unit', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }



  void _showEditLeadModal() {
    if (_leadModel == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EditLeadModal(
          lead: _leadModel!,
          onSaved: (updatedLead) async {
            await FirestoreService.instance.addLead(updatedLead);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppTheme.success,
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Lead updated successfully',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  String _formatCreatedAt(String raw) {
    if (raw.isEmpty || raw == '—') return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
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
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month]} ${dt.day}, ${dt.year} at ${hour}:${minute} ${amPm}';
    } catch (_) {
      return raw;
    }
  }

  String _formatDateOnly(String raw) {
    if (raw.isEmpty || raw == '—') return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
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
    } catch (_) {
      return raw;
    }
  }

  String _formatFollowUp(String raw) {
    if (raw == 'none' || raw.isEmpty) return 'Not set';
    try {
      final dt = DateTime.parse(raw);
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
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mappedNotes = _notes.map((n) {
      return {
        'id': n.id,
        'text': n.text,
        'tag': n.tag,
        'followUpDate': n.followUpDate != null ? _formatFollowUp(n.followUpDate!) : null,
        'followUpDateTime': n.followUpDateTime,
        'callDuration': n.callDuration,
        'createdAt': _formatCreatedAt(n.createdAt),
        'isAutoLog': n.isAutoLog,
        'rawCreatedAt': n.createdAt,
        'isEdited': n.isEdited,
        'serverCreatedAt': n.serverCreatedAt,
      };
    }).toList();
    final rawTag = _lead['lastTag'] as String? ?? '';
    final tag = (rawTag == 'Busy / Call Later') ? 'Callback' : rawTag;
    final followUp = _formatFollowUp(
      _lead['followUpDate'] as String? ?? 'none',
    );
    final createdAt = _formatCreatedAt(_lead['createdAt'] as String? ?? '—');
    final leadAdded = _formatDateOnly(_lead['createdAt'] as String? ?? '—');

    void goBack() {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        if (_returnTo == 'Dashboard') {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.dashboardScreen,
            (route) => false,
            arguments: {
              'expandBucket': _returnBucket,
            },
          );
        } else if (_origin == AppRoutes.siteVisitsScreen) {
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.siteVisitsScreen, (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.myLeadsScreen, (route) => false);
        }
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        goBack();
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceLight,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
            onPressed: goBack,
          ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _lead['clientName'] as String,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkText,
                    ),
                  ),
                ),
                if (_isFromBucket) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${_bucketLeads.length}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              _lead['property'] as String,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
            onPressed: () => _showEditLeadModal(),
            tooltip: 'Edit Lead',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StatusBadgeWidget(status: _lead['status'] as String),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.borderColor),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _isFromBucket ? (details) {
          _dragStartX = details.globalPosition.dx;
          _dragEndX = details.globalPosition.dx;
        } : null,
        onHorizontalDragUpdate: _isFromBucket ? (details) {
          _dragEndX = details.globalPosition.dx;
        } : null,
        onHorizontalDragEnd: _isFromBucket ? (details) {
          final double difference = _dragEndX - _dragStartX;
          if (difference.abs() > 80) {
            if (difference > 0) {
              _navigateToLeadAtIndex(_currentIndex - 1);
            } else {
              _navigateToLeadAtIndex(_currentIndex + 1);
            }
          }
        } : null,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // ── Left column content (stacked on mobile) ──────────────────────
              _ClientInfoCard(
                lead: _lead,
                createdAt: createdAt,
                leadAdded: leadAdded,
                followUp: followUp,
                tag: tag,
                isEditingStatus: _isEditingStatus,
                statuses: _statuses,
                onEditStatus: () =>
                    setState(() => _isEditingStatus = !_isEditingStatus),
                onStatusChanged: _updateStatus,
                onTempChanged: (temp) async {
                  if (_leadModel != null) {
                    final oldTemp = _leadModel!.leadTemperature;
                    if (oldTemp != temp) {
                      final updated = _leadModel!.copyWith(leadTemperature: temp);
                      await FirestoreService.instance.addLead(updated);
                      await FirestoreService.instance.logTemperatureChange(
                        leadId: _leadModel!.id,
                        clientName: _leadModel!.clientName,
                        oldTemp: oldTemp,
                        newTemp: temp,
                      );
                    }
                  }
                },
                onCall: _openDialer,
                onPropertyTap: () async {
                  final propName = _lead['property'] as String? ?? '';
                  final project = await FirestoreService.instance.getProjectByName(propName);
                  if (project != null && context.mounted) {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.projectDetailScreen,
                      arguments: {'projectId': project.id},
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Project not found in Inventory')),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),

              // ── 1. Add Call Note form — top, for quick logging ───────────────
              AddNoteFormWidget(
                key: _addNoteFormKey,
                leadId: _lead['id'] as String,
                onNoteSaved: _refreshLead,
              ),
              const SizedBox(height: 16),

              // ── 2. Call Notes Timeline — second ─────────────────────────────
              _SectionTitle(
                icon: 'history',
                title: 'Call Notes Timeline',
                count: mappedNotes.length,
              ),
              const SizedBox(height: 12),
              if (mappedNotes.isEmpty)
                _EmptyNotes()
              else
                ...mappedNotes.map((n) => CallNoteCardWidget(
                  note: n,
                  leadId: _lead['id'] as String,
                  isAutoLog: n['isAutoLog'] as bool? ?? false,
                  rawCreatedAt: n['rawCreatedAt'] as String? ?? '',
                  isEdited: n['isEdited'] as bool? ?? false,
                )),

              const SizedBox(height: 16),

              // ── 3. Schedule Site Visit — last, button only (hidden for closed) ─
              if (!_isClosed) ...[
                SiteVisitSchedulerWidget(
                  leadId: _lead['id'] as String,
                  clientName: _lead['clientName'] as String,
                  defaultProperty: _lead['property'] as String,
                  onScheduled: _refreshLead,
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
    ),
    );
  }
}

// ─── Client Info Card ─────────────────────────────────────────────────────────
class _ClientInfoCard extends StatefulWidget {
  final Map<String, dynamic> lead;
  final String createdAt;
  final String leadAdded;
  final String followUp;
  final String tag;
  final bool isEditingStatus;
  final List<String> statuses;
  final VoidCallback onEditStatus;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onTempChanged;
  final VoidCallback onCall;
  final VoidCallback? onPropertyTap;

  const _ClientInfoCard({
    required this.lead,
    required this.createdAt,
    required this.leadAdded,
    required this.followUp,
    required this.tag,
    required this.isEditingStatus,
    required this.statuses,
    required this.onEditStatus,
    required this.onStatusChanged,
    required this.onTempChanged,
    required this.onCall,
    this.onPropertyTap,
  });

  @override
  State<_ClientInfoCard> createState() => _ClientInfoCardState();
}

class _ClientInfoCardState extends State<_ClientInfoCard> {
  String? _selectedTemplate;

  static const Map<String, String> _templates = {
    'Email / Call Response': '''Dear [Customer's Name],

Thank you for getting in touch with TruAssets! We're delighted to know you're exploring property opportunities and we're here to make that journey seamless and rewarding for you.

Your inquiry has been received, and one of our property experts will be reaching out shortly to understand your requirements and guide you through the next steps. Whether you're buying, selling or investing, our team is committed to helping you make informed and confident decisions.

In the meantime, feel free to explore verified listings and valuable insights at www.truassets.in

We look forward to being a part of your property journey.

Warm regards,
Team TruAssets
"Elevating Real Estate Experiences"
📞 +91 74839 50552''',

    'Post Qualification': '''Dear [Customer's Name],

Thank you for taking the time to speak with me today. I appreciate your interest in exploring property options with TruAssets and I'm excited to assist you in finding the right match.

As discussed, we're happy to arrange a site visit at your convenience to give you a closer look at the property and address any questions you may have.

Please feel free to confirm a suitable date and time for the visit. I'll make sure everything is ready for a smooth and informative experience.

Looking forward to meeting you soon!

Warm regards,
Team TruAssets
📞 +91 74839 50552
🌐 www.truassets.in''',

    'RNR (No Response)': '''Dear [Customer's Name],

I tried reaching you earlier regarding your property inquiry with TruAssets but I may have caught you at a busy time.

I'd be happy to assist you with property options that match your needs—whether it's for buying, selling, or renting. Please let me know a convenient time to speak or feel free to call me directly whenever you're free.

Looking forward to connecting and helping you move closer to your ideal property.

Warm regards,
Team TruAssets
📞 +91 74839 50552
🌐 www.truassets.in''',

    'Post Site Visit': '''Dear [Customer's Name],

It was a pleasure meeting you today and showing you around the property. I truly appreciate you taking the time to visit and explore the options with TruAssets.

I hope the site visit gave you better clarity on the space, amenities and potential it holds for your future. If you have any questions, need further information or would like to revisit or explore more options, please do not hesitate to reach out.

At TruAssets, we are committed to helping you find the perfect property that meets your needs and aspirations. I look forward to assisting you further in your home-buying journey.

Warm regards,
Team TruAssets
📞 +91 74839 50552
🌐 www.truassets.in''',
  };

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkText,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.darkText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'OK',
                style: GoogleFonts.inter(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendWhatsAppMessage() async {
    if (_selectedTemplate == null) {
      _showAlert('Select Template', 'Please select a WhatsApp template first.');
      return;
    }

    final phoneRaw = widget.lead['phone'] as String? ?? '';
    // Normalize phone number
    String phone = phoneRaw.replaceAll(RegExp(r'\D'), '');
    if (phone.length == 10) {
      phone = '91$phone';
    } else if (phone.startsWith('0')) {
      phone = '91${phone.substring(1)}';
    }

    if (phone.isEmpty || phone.length < 11) {
      _showAlert('No Phone', 'No valid phone number found for this lead.');
      return;
    }

    // Fill lead name in template
    final leadName = widget.lead['clientName'] as String? ?? 'Valued Customer';
    final templateText = _templates[_selectedTemplate] ?? '';
    final filledMessage = templateText.replaceAll("[Customer's Name]", leadName);
    final encodedMessage = Uri.encodeComponent(filledMessage);

    // Try WhatsApp Business first (com.whatsapp.w4b)
    final waBizUrl = Uri.parse('whatsapp://send?phone=$phone&text=$encodedMessage');

    // Also prepare wa.me fallback
    final waWebUrl = Uri.parse('https://wa.me/$phone?text=$encodedMessage');

    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        // Try WhatsApp Business package directly via intent
        final intentUrl = Uri.parse(
          'intent://send?phone=$phone&text=$encodedMessage#Intent;package=com.whatsapp.w4b;scheme=whatsapp;end'
        );
        if (await canLaunchUrl(intentUrl)) {
          await launchUrl(intentUrl, mode: LaunchMode.externalApplication);
        } else {
          // Fallback: try regular WhatsApp via intent
          final intentRegular = Uri.parse(
            'intent://send?phone=$phone&text=$encodedMessage#Intent;package=com.whatsapp;scheme=whatsapp;end'
          );
          if (await canLaunchUrl(intentRegular)) {
            await launchUrl(intentRegular, mode: LaunchMode.externalApplication);
          } else {
            await launchUrl(waWebUrl, mode: LaunchMode.externalApplication);
          }
        }
      } else {
        // iOS — try whatsapp:// scheme (Business and regular share the scheme on iOS)
        if (await canLaunchUrl(waBizUrl)) {
          await launchUrl(waBizUrl, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(waWebUrl, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      _showAlert('Error', 'Could not open WhatsApp Business. Please make sure it is installed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.lead['status'] as String;
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.lead['clientName'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone,
                          size: 12,
                          color: AppTheme.mutedText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.lead['phone'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _TemperatureSelector(
                currentTemp: widget.lead['leadTemperature'] as String? ?? '',
                status: widget.lead['status'] as String? ?? '',
                onTempChanged: widget.onTempChanged,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(height: 1, color: AppTheme.borderColor),
          const SizedBox(height: 22),
          // Info rows
          _InfoRow(
            icon: 'apartment',
            label: 'Property',
            value: widget.lead['property'] as String? ?? '—',
            onTap: widget.onPropertyTap,
          ),
          const SizedBox(height: 8),
          if (widget.lead['alternatePhone'] != null && (widget.lead['alternatePhone'] as String).isNotEmpty) ...[
            _InfoRow(
              icon: Icons.phone_android,
              label: 'Alternate Phone',
              value: widget.lead['alternatePhone'] as String,
            ),
            const SizedBox(height: 8),
          ],
          if (widget.lead['email'] != null && (widget.lead['email'] as String).isNotEmpty) ...[
            _InfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: widget.lead['email'] as String,
            ),
            const SizedBox(height: 8),
          ],
          if (widget.lead['source'] != null && (widget.lead['source'] as String).isNotEmpty) ...[
            _InfoRow(
              icon: Icons.campaign_outlined,
              label: 'Lead Source',
              value: widget.lead['source'] as String,
            ),
            const SizedBox(height: 8),
          ],
          _InfoRow(
            icon: Icons.access_time_outlined,
            label: 'Lead Generated',
            value: widget.createdAt,
            overflow: null,
          ),
          const SizedBox(height: 8),
          _InfoRow(icon: 'event', label: 'Follow-up', value: widget.followUp),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.bar_chart_outlined,
                      color: AppTheme.mutedText,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Calls Made: ',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.mutedText,
                      ),
                    ),
                    Text(
                      '${widget.lead['callsCount'] ?? 0}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onCall,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF28A745),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.call,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.borderColor),
          const SizedBox(height: 14),
          // Status row
          Row(
            children: [
              Text(
                'Status',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onEditStatus,
                child: Row(
                  children: [
                    StatusBadgeWidget(status: status),
                    const SizedBox(width: 4),
                    Icon(
                      widget.isEditingStatus ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: AppTheme.mutedText,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.isEditingStatus) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.statuses.map((s) {
                final isSelected = s == status;
                return GestureDetector(
                  onTap: () => widget.onStatusChanged(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.getStatusBgColor(s)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(
                              color: AppTheme.getStatusColor(s),
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: Text(
                      _statusLabel(s),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.getStatusColor(s)
                            : AppTheme.mutedText,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          // Tag badge
          if (widget.tag.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Last Outcome',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mutedText,
                  ),
                ),
                const Spacer(),
                Builder(
                  builder: (context) {
                    final colors = getOutcomeTagColor(widget.tag);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.borderColor, width: 1),
                      ),
                      child: Text(
                        widget.tag,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textColor,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],

          // ─── WhatsApp Template Section ─────────────────────────────────────
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderColor),
          const SizedBox(height: 12),
          Text(
            'WhatsApp Template',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF25D366),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFF25D366), width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedTemplate,
                      hint: Text(
                        'Select template...',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.mutedText,
                        ),
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.darkText,
                      ),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFF25D366),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _selectedTemplate = val;
                        });
                      },
                      items: _templates.keys.map((String key) {
                        return DropdownMenuItem<String>(
                          value: key,
                          child: Text(key),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendWhatsAppMessage,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: Center(
                    child: SvgPicture.string(
                      _whatsappSvg,
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'new':
        return 'New';
      case 'called':
        return 'Called';
      case 'follow-up':
        return 'Follow-Up';
      case 'site visit scheduled':
        return 'SV Scheduled';
      case 'site visit done':
        return 'Site Visit Done';
      case 'won':
        return 'Won';
      case 'lost/dead':
        return 'Lost / Dead';
      default:
        return s;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final dynamic icon;
  final String label;
  final String value;
  final TextOverflow? overflow;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.overflow = TextOverflow.ellipsis,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon is IconData)
          Icon(icon as IconData, color: AppTheme.mutedText, size: 14)
        else
          CustomIconWidget(iconName: icon as String, color: AppTheme.mutedText, size: 14),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText),
        ),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: onTap != null ? AppTheme.primary : AppTheme.darkText,
                decoration: onTap != null ? TextDecoration.underline : null,
              ),
              overflow: overflow,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Section Title ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String icon;
  final String title;
  final int count;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CustomIconWidget(iconName: icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkText,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Empty Notes ──────────────────────────────────────────────────────────────
class _EmptyNotes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.notes, color: AppTheme.borderColor, size: 36),
          const SizedBox(height: 8),
          Text(
            'No call notes yet',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your first note after a call below.',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText),
          ),
        ],
      ),
    );
  }
}

class _EditLeadModal extends StatefulWidget {
  final LeadModel lead;
  final Future<void> Function(LeadModel) onSaved;

  const _EditLeadModal({
    required this.lead,
    required this.onSaved,
  });

  @override
  State<_EditLeadModal> createState() => _EditLeadModalState();
}

class _EditLeadModalState extends State<_EditLeadModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameKey = GlobalKey();
  final _emailKey = GlobalKey();
  final _propertyKey = GlobalKey();
  final _sourceKey = GlobalKey();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _altPhoneCtrl;
  late TextEditingController _emailCtrl;
  String? _selectedProperty;
  String? _selectedSource;
  bool _isSaving = false;

  final List<String> _properties = [
    'Mantri Serenity',
    'Mantri Courtyard',
  ];

  final List<String> _sources = [
    'Meta',
    'Google',
    'MagicBricks',
    '99acres',
    'NoBroker',
    'Referral',
    'Walk-in',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.lead.clientName);
    _phoneCtrl = TextEditingController(text: widget.lead.phone);
    _altPhoneCtrl = TextEditingController(text: widget.lead.alternatePhone);
    _emailCtrl = TextEditingController(text: widget.lead.email);
    _selectedProperty = _properties.contains(widget.lead.property) ? widget.lead.property : null;
    _selectedSource = _sources.contains(widget.lead.source) ? widget.lead.source : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Lead Details',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkText,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              Text(
                'Full Name *',
                key: _nameKey,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkText),
                decoration: _inputDecoration('Full Name', Icons.person_outline),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              Text(
                'Primary Phone Number *',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneCtrl,
                readOnly: true,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xBF999999)),
                decoration: _disabledInputDecoration('Primary Phone'),
              ),
              const SizedBox(height: 3),
              Text(
                'Cannot be edited after lead is created',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFF999999),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Alternate Phone Number',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _altPhoneCtrl,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkText),
                decoration: _inputDecoration('Alternate Phone (optional)', Icons.phone_android),
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
              ),
              const SizedBox(height: 16),

              Text(
                'Email Address *',
                key: _emailKey,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailCtrl,
                readOnly: widget.lead.emailEditCount >= 1,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                autofillHints: const [AutofillHints.email],
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: widget.lead.emailEditCount >= 1
                      ? const Color(0xBF999999)
                      : AppTheme.darkText,
                ),
                decoration: widget.lead.emailEditCount >= 1
                    ? _disabledInputDecoration(_emailCtrl.text.isEmpty ? 'Not provided' : _emailCtrl.text)
                    : _inputDecoration('Email Address *', Icons.email_outlined),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Email Address is required' : null,
              ),
              const SizedBox(height: 3),
              Text(
                widget.lead.emailEditCount >= 1
                    ? 'Already edited once — cannot be changed again'
                    : 'Can only be edited once',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFF999999),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Property Name *',
                key: _propertyKey,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedProperty,
                items: _properties.map((p) {
                  return DropdownMenuItem<String>(
                    value: p,
                    child: Text(p, style: GoogleFonts.inter(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedProperty = val;
                  });
                },
                validator: (v) => (v == null || v.isEmpty) ? 'Please select a property' : null,
                decoration: _inputDecoration('Select Property *', Icons.business_outlined),
              ),
              const SizedBox(height: 16),

              Text(
                'Lead Source *',
                key: _sourceKey,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedSource,
                disabledHint: _selectedSource != null
                    ? Text(_selectedSource!, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xBF999999)))
                    : null,
                items: _sources.map((s) {
                  return DropdownMenuItem<String>(
                    value: s,
                    child: Text(s, style: GoogleFonts.inter(fontSize: 14)),
                  );
                }).toList(),
                onChanged: widget.lead.leadSourceEditCount >= 1
                    ? null
                    : (val) {
                        setState(() {
                          _selectedSource = val;
                        });
                      },
                validator: (v) => (v == null || v.isEmpty) ? 'Please select a lead source' : null,
                decoration: widget.lead.leadSourceEditCount >= 1
                    ? _disabledInputDecoration(_selectedSource ?? 'Select Lead Source')
                    : _inputDecoration('Select Lead Source *', Icons.campaign_outlined),
              ),
              const SizedBox(height: 3),
              Text(
                widget.lead.leadSourceEditCount >= 1
                    ? 'Already edited once — cannot be changed again'
                    : 'Can only be edited once',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFF999999),
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Save Details',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: AppTheme.mutedText),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
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
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
    );
  }

  InputDecoration _disabledInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.lock, size: 16, color: Color(0xFF999999)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xBF999999),
      ),
    );
  }

  void _save() async {
    debugPrint('Save Details pressed: name=${_nameCtrl.text.trim()}, email=${_emailCtrl.text.trim()}, property=$_selectedProperty, source=$_selectedSource');

    final bool isNameValid = _nameCtrl.text.trim().isNotEmpty;
    final bool isEmailValid = _emailCtrl.text.trim().isNotEmpty;
    final bool isPropertyValid = _selectedProperty != null && _selectedProperty!.isNotEmpty;
    final bool isSourceValid = _selectedSource != null && _selectedSource!.isNotEmpty;

    _formKey.currentState!.validate();

    if (!isNameValid) {
      Scrollable.ensureVisible(
        _nameKey.currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5,
      );
      return;
    }

    if (!isEmailValid) {
      Scrollable.ensureVisible(
        _emailKey.currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5,
      );
      return;
    }

    if (!isPropertyValid) {
      Scrollable.ensureVisible(
        _propertyKey.currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5,
      );
      return;
    }

    if (!isSourceValid) {
      Scrollable.ensureVisible(
        _sourceKey.currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final originalEmail = widget.lead.email;
      final originalSource = widget.lead.source;

      final newEmail = _emailCtrl.text.trim();
      final newSource = _selectedSource ?? '';

      final emailChanged = newEmail != originalEmail;
      final sourceChanged = newSource != originalSource;

      int newEmailEditCount = widget.lead.emailEditCount;
      if (emailChanged && widget.lead.emailEditCount == 0) {
        newEmailEditCount = 1;
      }

      int newSourceEditCount = widget.lead.leadSourceEditCount;
      if (sourceChanged && widget.lead.leadSourceEditCount == 0) {
        newSourceEditCount = 1;
      }

      final updatedLead = widget.lead.copyWith(
        clientName: _nameCtrl.text.trim(),
        property: _selectedProperty ?? '',
        phone: _phoneCtrl.text.trim(),
        alternatePhone: _altPhoneCtrl.text.trim(),
        email: newEmail,
        source: newSource,
        emailEditCount: newEmailEditCount,
        leadSourceEditCount: newSourceEditCount,
      );

      await widget.onSaved(updatedLead);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      debugPrint('Save error: $error');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to save changes. Please try again.\n\nDetails: $error'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}

class _TemperatureSelector extends StatelessWidget {
  final String currentTemp;
  final String status;
  final ValueChanged<String> onTempChanged;

  const _TemperatureSelector({
    required this.currentTemp,
    required this.status,
    required this.onTempChanged,
  });

  @override
  Widget build(BuildContext context) {
    final statusLower = status.toLowerCase();
    final isWonOrLost = statusLower == 'won' || 
                        statusLower == 'lost' || 
                        statusLower == 'dead' || 
                        statusLower == 'lost/dead';

    if (isWonOrLost || currentTemp.isEmpty || currentTemp == 'none') {
      return const SizedBox.shrink();
    }

    Color bg;
    Color border;
    Color text;
    String label;

    switch (currentTemp) {
      case 'Hot':
        bg = const Color(0xFFD4EDDA);
        border = const Color(0xFF28A745);
        text = const Color(0xFF155724);
        label = '🔥 HOT';
        break;
      case 'Warm':
        bg = const Color(0xFFFFE8CC);
        border = const Color(0xFFFD7E14);
        text = const Color(0xFF7D3C00);
        label = '🌤 WARM';
        break;
      case 'Cold':
        bg = const Color(0xFFFFFACC);
        border = const Color(0xFFFFC107);
        text = const Color(0xFF7A6500);
        label = '❄️ COLD';
        break;
      default:
        return const SizedBox.shrink();
    }

    final badgeChild = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
          if (currentTemp == 'Warm' || currentTemp == 'Hot') ...[
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down, size: 14, color: text),
          ],
        ],
      ),
    );

    if (currentTemp == 'Cold') {
      return badgeChild;
    }

    return PopupMenuButton<String>(
      onSelected: onTempChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'Warm', child: Text('🌤 Warm')),
        const PopupMenuItem(value: 'Hot', child: Text('🔥 Hot')),
      ],
      child: badgeChild,
    );
  }
}

const String _whatsappSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512" fill="white">
  <path d="M380.9 97.1C339 55.1 283.2 32 223.9 32c-122.4 0-222 99.6-222 222 0 39.1 10.2 77.3 29.6 111L0 480l117.7-30.9c32.4 17.7 68.9 27 106.1 27h.1c122.3 0 224.1-99.6 224.1-222 0-59.3-25.2-115-67.1-157zm-157 341.6c-33.2 0-65.7-8.9-94-25.7l-6.7-4-69.8 18.3 18.7-68.1-4.4-7c-18.5-29.4-28.2-63.3-28.2-98.2 0-101.7 82.8-184.5 184.6-184.5 49.3 0 95.6 19.2 130.4 54.1 34.8 34.9 56.2 81.2 56.1 130.5 0 101.8-84.9 184.6-186.6 184.6zm101.2-138.2c-5.5-2.8-32.8-16.2-37.9-18-5.1-1.9-8.8-2.8-12.5 2.8-3.7 5.6-14.3 18-17.6 21.8-3.2 3.7-6.5 4.2-12 1.4-32.6-16.3-54-29.1-75.5-66-5.7-9.8 5.7-9.1 16.3-30.3 1.8-3.7.9-6.9-.5-9.7-1.4-2.8-12.5-30.1-17.1-41.2-4.5-10.8-9.1-9.3-12.5-9.5-3.2-.2-6.9-.2-10.6-.2-3.7 0-9.7 1.4-14.8 6.9-5.1 5.6-19.4 19-19.4 46.3 0 27.3 19.9 53.7 22.6 57.4 2.8 3.7 39.1 59.7 94.8 83.8 35.2 15.2 49 16.5 66.6 13.9 10.7-1.6 32.8-13.4 37.4-26.4 4.6-13 4.6-24.1 3.2-26.4-1.3-2.5-5-3.9-10.5-6.6z"/>
</svg>
''';
