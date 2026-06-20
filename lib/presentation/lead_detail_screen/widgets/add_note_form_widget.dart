import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';
import '../../../models/note_model.dart';
import '../../../services/firestore_service.dart';

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

  static const List<String> _leftTags = [
    'Callback',
    'Interested',
    'Not Answering',
    'Postponed Buying Plan',
    'Site Visit Ready',
    'Source Inventory',
  ];

  static const List<String> _rightTags = [
    'Channel Partner',
    'Finalised Elsewhere',
    'Location Mismatch',
    'Low Budget',
    'Not Interested',
    'Wrong Number',
  ];

  bool get _showFollowUp =>
      _selectedTag != null && _leftTags.contains(_selectedTag);

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
    });
  }

  Future<void> _pickFollowUpDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    
    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _followUpDate != null 
            ? TimeOfDay.fromDateTime(_followUpDate!) 
            : const TimeOfDay(hour: 9, minute: 0),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primary),
          ),
          child: child!,
        ),
      );

      if (pickedTime != null) {
        setState(() {
          _followUpDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
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
    final isLeftColumn = _leftTags.contains(_selectedTag);
    if (isLeftColumn && _followUpDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a follow-up date.')));
      return;
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

    final hasFollowUp = isLeftColumn && followUpDate != null;

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
      final bool isRightColumnTag = _rightTags.contains(selectedTag);
      String newStatus = isRightColumnTag ? 'lost/dead' : 'called';
      final Map<String, dynamic> leadUpdates = {
        'lastTag': selectedTag,
        'lastNote': noteText,
        'status': newStatus,
        'callsCount': FieldValue.increment(1),
      };

      if (isRightColumnTag) {
        leadUpdates['leadTemperature'] = '';
      } else {
        try {
          final leadSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(FirestoreService.instance.currentUid)
              .collection('leads')
              .doc(widget.leadId)
              .get();
          if (leadSnap.exists) {
            final currentTemp = leadSnap.data()?['leadTemperature'] as String?;
            if (currentTemp == null || currentTemp.isEmpty) {
              leadUpdates['leadTemperature'] = 'Cold';
            }
          }
        } catch (e) {
          debugPrint('Error fetching lead temperature: $e');
        }
      }

      if (hasFollowUp) {
        leadUpdates['followUpDate'] = _formatDateIso(followUpDate);
        leadUpdates['followUpDateTime'] = followUpDate.toIso8601String();
        leadUpdates['status'] = 'follow-up';
      } else {
        leadUpdates['followUpDate'] = 'none';
        leadUpdates['followUpDateTime'] = null;
        if (isRightColumnTag) {
          leadUpdates['status'] = 'lost/dead';
        }
      }

      if (durationStr != null) {
        leadUpdates['callDuration'] = durationStr;
      }

      await FirestoreService.instance.updateLead(widget.leadId, leadUpdates);

      // 3. Clear form state after successful save
      setState(() {
        _isSaving = false;
        _noteCtrl.clear();
        _selectedTag = null;
        _followUpDate = null;
        _durationMinutes = 0;
        _durationSeconds = 0;
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
                  'Note saved successfully',
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

  Widget _buildTagChip(String tag, {required bool isLeft}) {
    final isSelected = _selectedTag == tag;
    
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (isSelected) {
      if (isLeft) {
        bgColor = const Color(0xFFD4EDDA);
        borderColor = const Color(0xFF28A745);
        textColor = const Color(0xFF155724);
      } else {
        bgColor = const Color(0xFFFDE8E8);
        borderColor = const Color(0xFFE05252);
        textColor = const Color(0xFF991B1B);
      }
    } else {
      bgColor = Colors.transparent;
      borderColor = const Color(0xFFCCCCCC);
      textColor = const Color(0xFF777777);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedTag = tag;
              if (!isLeft) {
                _followUpDate = null;
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tag,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              const Icon(Icons.add_comment, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Add Call Note',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Note textarea
          TextField(
            controller: _noteCtrl,
            maxLines: 4,
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
          _FormLabel(label: 'Outcome Tag'),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column (Follow-up Required)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Follow-up Required',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF28A745),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._leftTags.map((t) => _buildTagChip(t, isLeft: true)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right Column (No Follow-up Needed)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Follow-up Needed',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFE05252),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._rightTags.map((t) => _buildTagChip(t, isLeft: false)),
                  ],
                ),
              ),
            ],
          ),
          // Follow-up date (conditional)
          if (_showFollowUp) ...[
            const SizedBox(height: 12),
            _FormLabel(label: 'Next Follow-up Date & Time'),
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
          ],
          const SizedBox(height: 12),
          // Call duration
          _FormLabel(label: 'Call Duration (optional)'),
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
