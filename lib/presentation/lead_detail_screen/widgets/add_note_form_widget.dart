import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../theme/app_theme.dart';
import '../../../models/note_model.dart';
import '../../../services/firestore_service.dart';
import '../../../utils/tag_colors.dart';

/// Add Note form with outcome tag, follow-up date, call duration, and Save Note.
class AddNoteFormWidget extends StatefulWidget {
  final String leadId;
  final VoidCallback onNoteSaved;

  const AddNoteFormWidget({
    super.key,
    required this.leadId,
    required this.onNoteSaved,
  });

  @override
  State<AddNoteFormWidget> createState() => AddNoteFormWidgetState();
}

class AddNoteFormWidgetState extends State<AddNoteFormWidget> {
  final TextEditingController _noteCtrl = TextEditingController();
  String? _selectedTag;
  DateTime? _followUpDate;
  int _durationMinutes = 0;
  int _durationSeconds = 0;
  bool _isSaving = false;
  bool _showForm = false;

  String? _validationError;
  int? _followUpCount;
  bool _isLoadingFollowUpCount = false;

  static const List<String> _followUpTags = [
    'Callback',
    'Interested',
    'Not Answering',
    'Postponed Buying Plan',
    'Prospect',
    'Site Visit Ready',
  ];

  static const List<String> _noFollowUpTags = [
    'Booked',
    'Channel Partner',
    'Closed with Colleague',
    'Dropped Buying Plans',
    'Finalised Elsewhere',
    'Location Mismatch',
    'Low Budget',
    'Not Interested',
    'Not Responding',
    'Source Inventory',
    'Wrong Number',
  ];

  /// Per-tag status mapping. null = keep current status.
  static const Map<String, String?> _tagStatusMap = {
    'Booked': 'won',
    'Channel Partner': 'lost/dead',
    'Closed with Colleague': 'lost/dead',
    'Dropped Buying Plans': 'lost/dead',
    'Finalised Elsewhere': 'lost/dead',
    'Location Mismatch': 'lost/dead',
    'Low Budget': 'lost/dead',
    'Not Interested': 'lost/dead',
    'Not Responding': 'lost/dead',
    'Source Inventory': null,
    'Wrong Number': 'lost/dead',
    'Callback': 'follow-up',
    'Interested': 'follow-up',
    'Not Answering': 'follow-up',
    'Postponed Buying Plan': 'follow-up',
    'Prospect': 'site visit done',
    'Site Visit Ready': 'follow-up',
  };

  bool get _showFollowUp =>
      _selectedTag != null && _followUpTags.contains(_selectedTag);

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Pre-fill from the in-app dialer after a call ends.
  void prefillFromDialer({
    required String noteText,
    required int durationSeconds,
  }) {
    setState(() {
      if (noteText.isNotEmpty) {
        _noteCtrl.text = noteText;
      }
      _durationMinutes = durationSeconds ~/ 60;
      _durationSeconds = durationSeconds % 60;
      _showForm = true;
    });
  }

  Future<void> _pickFollowUpDateTime() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final defaultDateTime = _getDefaultFollowUpDateTime();

    DateTime initialDate = _followUpDate ?? defaultDateTime;
    if (initialDate.isBefore(today)) {
      initialDate = defaultDateTime;
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: DateTime.now().add(const Duration(days: 180)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    
    if (pickedDate != null && mounted) {
      final TimeOfDay initialTime = _followUpDate != null 
          ? TimeOfDay.fromDateTime(_followUpDate!) 
          : TimeOfDay.fromDateTime(defaultDateTime);

      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primary),
          ),
          child: child!,
        ),
      );

      if (pickedTime != null) {
        final newDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        if (newDateTime.isBefore(DateTime.now())) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Follow-up time cannot be in the past. Please select a future time.'),
              backgroundColor: AppTheme.error,
            ),
          );
          return;
        }

        setState(() {
          _followUpDate = newDateTime;
          _validationError = null;
        });

        _loadFollowUpCountForDate(newDateTime);
      }
    }
  }

  String _formatDateTime(DateTime dt) {
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
    return '${months[dt.month]} ${dt.day}, ${dt.year} at ${hour.toString().padLeft(2, '0')}:${minute} ${amPm}';
  }

  String _formatDateIso(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _saveNote() async {
    setState(() => _validationError = null);

    if (_noteCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter call notes.')));
      return;
    }
    if (_selectedTag == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an outcome tag.')));
      return;
    }
    final isFollowUpTag = _followUpTags.contains(_selectedTag);
    if (isFollowUpTag) {
      if (_followUpDate == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a follow-up date.')));
        return;
      }
      if (_followUpDate!.isBefore(DateTime.now())) {
        setState(() {
          _validationError = '⚠️ Follow-up time cannot be in the past. Please select a future time.';
        });
        return;
      }
    }
    setState(() => _isSaving = true);

    // Capture values BEFORE clearing state
    final noteText = _noteCtrl.text.trim();
    final selectedTag = _selectedTag!;
    final followUpDate = _followUpDate;

    final now = DateTime.now();
    final createdAt =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final durationStr = (_durationMinutes > 0 || _durationSeconds > 0)
        ? '${_durationMinutes}m ${_durationSeconds.toString().padLeft(2, '0')}s'
        : null;

    final hasFollowUp = isFollowUpTag && followUpDate != null;

    final note = NoteModel(
      id: '',
      text: noteText,
      tag: selectedTag,
      followUpDate: hasFollowUp ? _formatDateIso(followUpDate) : null,
      followUpDateTime: hasFollowUp ? followUpDate.toIso8601String() : null,
      callDuration: durationStr ?? '',
      createdAt: createdAt,
    );

    try {
      // 1. Save the note
      await FirestoreService.instance.addNote(widget.leadId, note);

      // 2. Directly update the lead fields (reliable, no stream race condition)
      final Map<String, dynamic> leadUpdates = {
        'lastTag': selectedTag,
        'lastNote': noteText,
        'callsCount': FieldValue.increment(1),
        'lastCallNoteAt': DateTime.now().toIso8601String(),
        'statusChangedAt': DateTime.now().toIso8601String(),
      };

      // ── Per-tag status mapping with site-visit override ──
      final String? mappedStatus = _tagStatusMap[selectedTag];
      final bool isLostOrWon = mappedStatus == 'won' || mappedStatus == 'lost/dead';

      // Fetch current lead data for override logic
      String currentStatus = '';
      String currentTemp = '';
      String clientName = 'Lead';
      try {
        final leadSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirestoreService.instance.currentUid)
            .collection('leads')
            .doc(widget.leadId)
            .get();
        if (leadSnap.exists) {
          currentStatus = leadSnap.data()?['status'] as String? ?? '';
          currentTemp = leadSnap.data()?['leadTemperature'] as String? ?? '';
          clientName = leadSnap.data()?['clientName'] as String? ?? 'Lead';
        }
      } catch (e) {
        debugPrint('Error fetching lead data: $e');
      }

      String finalStatus = '';
      if (mappedStatus == null) {
        // "Source Inventory" — keep whatever status the lead currently has
        finalStatus = currentStatus.isNotEmpty ? currentStatus : 'called';
      } else if (isLostOrWon) {
        // Won/Lost always override any status (including Visited)
        finalStatus = mappedStatus;
      } else if (currentStatus == 'site visit done') {
        // "Visited" is persistent — non-Lost/non-Won tags don't downgrade it
        finalStatus = 'site visit done';
      } else {
        // Normal case: use the mapped status
        finalStatus = mappedStatus;
      }

      // Check if final status is won or lost/dead
      final finalStatusLower = finalStatus.toLowerCase();
      final finalIsLostOrWon = finalStatusLower == 'won' ||
                                finalStatusLower == 'lost' ||
                                finalStatusLower == 'dead' ||
                                finalStatusLower == 'lost/dead';

      String targetTemp = currentTemp;
      if (finalIsLostOrWon) {
        targetTemp = '';
      } else if (currentTemp.isEmpty) {
        targetTemp = 'Cold';
      }

      // Follow-up date handling
      if (hasFollowUp) {
        leadUpdates['followUpDate'] = _formatDateIso(followUpDate);
        leadUpdates['followUpDateTime'] = followUpDate.toIso8601String();
      } else {
        leadUpdates['followUpDate'] = 'none';
        leadUpdates['followUpDateTime'] = null;
      }

      if (durationStr != null) {
        leadUpdates['callDuration'] = durationStr;
      }

      // Update lead other updates
      await FirestoreService.instance.updateLead(widget.leadId, leadUpdates);

      // Centralized status update with logging
      await FirestoreService.instance.updateLeadStatus(
        leadId: widget.leadId,
        newStatus: finalStatus,
        triggeredBy: 'outcome_tag',
        context: selectedTag,
        clientName: clientName,
        oldStatus: currentStatus,
      );

      // Centralized temperature update with logging
      await FirestoreService.instance.updateLeadTemperature(
        leadId: widget.leadId,
        newTemp: targetTemp,
        triggeredBy: 'outcome_tag',
        clientName: clientName,
        oldTemp: currentTemp,
      );

      // 3. Clear form state after successful save
      setState(() {
        _isSaving = false;
        _noteCtrl.clear();
        _selectedTag = null;
        _followUpDate = null;
        _durationMinutes = 0;
        _durationSeconds = 0;
        _showForm = false;
        _validationError = null;
        _followUpCount = null;
      });

      widget.onNoteSaved();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Call note saved successfully',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.error,
            content: Text('Error saving note: $e', style: GoogleFonts.inter(color: Colors.white)),
          ),
        );
      }
    }
  }

  DateTime _getDefaultFollowUpDateTime() {
    final now = DateTime.now();
    var target = now.add(const Duration(minutes: 15));
    final rem = target.minute % 5;
    if (rem != 0) {
      target = target.add(Duration(minutes: 5 - rem));
    }
    return DateTime(target.year, target.month, target.day, target.hour, target.minute);
  }

  Future<String> _getApiBaseUrl() async {
    if (kIsWeb && !Uri.base.toString().contains('localhost')) {
      return Uri.base.origin;
    }
    try {
      final uid = FirestoreService.instance.currentUid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data();
          final twilio = data?['twilioConfig'] as Map<String, dynamic>?;
          final fUrl = twilio?['functionUrl'] as String?;
          if (fUrl != null && fUrl.trim().isNotEmpty) {
            return fUrl.endsWith('/') ? fUrl.substring(0, fUrl.length - 1) : fUrl;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting functionUrl: $e');
    }
    return 'https://us-central1-truassets-crm-akp-web.cloudfunctions.net';
  }

  Future<void> _loadFollowUpCountForDate(DateTime date) async {
    final agentId = FirestoreService.instance.currentUid;
    if (agentId == null) return;

    final dateStr = _formatDateIso(date);
    
    setState(() {
      _isLoadingFollowUpCount = true;
      _followUpCount = null;
    });

    try {
      final baseUrl = await _getApiBaseUrl();
      String url;
      if (baseUrl.contains('.cloudfunctions.net')) {
        url = '$baseUrl/followupCount';
      } else {
        url = '$baseUrl/api/leads/followup-count';
      }

      final dio = Dio();
      final response = await dio.get(
        url,
        queryParameters: {
          'date': dateStr,
          'agent_id': agentId,
          'exclude_lead_id': widget.leadId,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final count = response.data['count'] as int?;
        if (mounted) {
          setState(() {
            _followUpCount = count;
            _isLoadingFollowUpCount = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingFollowUpCount = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading follow-up count: $e');
      if (mounted) {
        setState(() {
          _isLoadingFollowUpCount = false;
        });
      }
    }
  }

  void _onTagSelected(String tag, bool isFollowUp) {
    setState(() {
      _selectedTag = tag;
      _validationError = null;
      if (!isFollowUp) {
        _followUpDate = null;
        _followUpCount = null;
      } else {
        if (_followUpDate == null) {
          _followUpDate = _getDefaultFollowUpDateTime();
          _loadFollowUpCountForDate(_followUpDate!);
        }
      }
    });
  }

  Widget _buildTagChip(String tag, {required bool isFollowUp}) {
    final isSelected = _selectedTag == tag;
    
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (isSelected) {
      final tagColor = getOutcomeTagColor(tag);
      bgColor = tagColor.bgColor;
      borderColor = tagColor.borderColor;
      textColor = tagColor.textColor;
    } else {
      bgColor = Colors.transparent;
      borderColor = const Color(0xFFCCCCCC);
      textColor = const Color(0xFF777777);
    }

    return GestureDetector(
      onTap: () => _onTagSelected(tag, isFollowUp),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Text(
          tag,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildFollowUpCountMessage(int count) {
    Color color;
    String text;

    if (count == 0) {
      color = const Color(0xFF059669); // Neutral/green
      text = 'No follow-ups scheduled on this date';
    } else if (count >= 1 && count <= 3) {
      color = const Color(0xFFD97706); // Amber/orange
      text = '📅 $count follow-up(s) already scheduled on this date';
    } else {
      color = const Color(0xFFDC2626); // Red
      text = '📅 $count follow-up(s) already scheduled on this date';
    }

    return Row(
      children: [
        if (count == 0) ...[
          Icon(
            Icons.check_circle_outline,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void toggleCallNoteForm() {
    setState(() {
      _showForm = !_showForm;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: toggleCallNoteForm,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDDDDD), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add, size: 16, color: Colors.black),
                    const SizedBox(width: 8),
                    Text(
                      'Add Call Note',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showForm ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: const Color(0xFF666666),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _showForm
              ? Container(
                  margin: const EdgeInsets.only(top: 15),
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
                      // Note textarea
                      TextField(
                        controller: _noteCtrl,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText),
                        decoration: InputDecoration(
                          hintText: 'What happened in this call?',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.mutedText,
                          ),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Outcome tag dropdown replacement
                      const _FormLabel(label: 'Outcome Tag'),
                      const SizedBox(height: 10),
                      // Follow-up Required section
                      Text(
                        'Follow-up Required',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF28A745),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _followUpTags.map((t) => _buildTagChip(t, isFollowUp: true)).toList(),
                      ),
                      const SizedBox(height: 12),
                      // No Follow-up Needed section
                      Text(
                        'No Follow-up Needed',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE05252),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _noFollowUpTags.map((t) => _buildTagChip(t, isFollowUp: false)).toList(),
                      ),

                      // Follow-up date (conditional)
                      if (_showFollowUp) ...[
                        const SizedBox(height: 12),
                        const _FormLabel(label: 'Next Follow-up Date & Time'),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _pickFollowUpDateTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.event,
                                  size: 16,
                                  color: AppTheme.mutedText,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _followUpDate != null
                                        ? _formatDateTime(_followUpDate!)
                                        : 'Select follow-up date & time',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: _followUpDate != null
                                          ? AppTheme.darkText
                                          : AppTheme.mutedText,
                                      fontWeight: _followUpDate != null
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: AppTheme.mutedText,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_validationError != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: AppTheme.error,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _validationError!,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_followUpDate != null) ...[
                          const SizedBox(height: 6),
                          if (_isLoadingFollowUpCount)
                            Row(
                              children: [
                                const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Checking scheduled follow-ups...',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.mutedText,
                                  ),
                                ),
                              ],
                            )
                          else if (_followUpCount != null)
                            _buildFollowUpCountMessage(_followUpCount!),
                        ],
                      ],
                      const SizedBox(height: 12),
                      // Call duration
                      const _FormLabel(label: 'Call Duration (optional)'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _DurationField(
                              label: 'Min',
                              value: _durationMinutes,
                              max: 59,
                              onChanged: (v) => setState(() => _durationMinutes = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DurationField(
                              label: 'Sec',
                              value: _durationSeconds,
                              max: 59,
                              onChanged: (v) => setState(() => _durationSeconds = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveNote,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.save, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Save Note',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String label;
  const _FormLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.darkText,
      ),
    );
  }
}

class _DurationField extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _DurationField({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText),
          ),
          const Spacer(),
          IconButton(
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            color: AppTheme.primary,
          ),
          SizedBox(
            width: 28,
            child: Text(
              value.toString().padLeft(2, '0'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkText,
              ),
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            color: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}
