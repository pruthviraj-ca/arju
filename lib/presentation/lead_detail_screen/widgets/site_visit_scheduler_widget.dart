import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/site_visit_model.dart';
import '../../../models/note_model.dart';
import '../../../services/firestore_service.dart';

/// Site visit scheduler button shown in Lead Detail.
/// Clicking the button opens a bottom sheet to schedule the visit.
class SiteVisitSchedulerWidget extends StatelessWidget {
  final String leadId;
  final String clientName;
  final String defaultProperty;
  final VoidCallback onScheduled;

  const SiteVisitSchedulerWidget({
    super.key,
    required this.leadId,
    required this.clientName,
    required this.defaultProperty,
    required this.onScheduled,
  });

  void _showScheduleBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _ScheduleBottomSheetContent(
          leadId: leadId,
          clientName: clientName,
          defaultProperty: defaultProperty,
          onScheduled: onScheduled,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _showScheduleBottomSheet(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_available, size: 18),
            const SizedBox(width: 8),
            Text(
              'Schedule Site Visit',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleBottomSheetContent extends StatefulWidget {
  final String leadId;
  final String clientName;
  final String defaultProperty;
  final VoidCallback onScheduled;

  const _ScheduleBottomSheetContent({
    required this.leadId,
    required this.clientName,
    required this.defaultProperty,
    required this.onScheduled,
  });

  @override
  State<_ScheduleBottomSheetContent> createState() =>
      __ScheduleBottomSheetContentState();
}

class __ScheduleBottomSheetContentState
    extends State<_ScheduleBottomSheetContent> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedProperty;
  final List<String> _dropdownProperties = [
    'Mantri Serenity',
    'Mantri Courtyard',
  ];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Add default property if not empty and not already present to avoid assertion errors
    if (widget.defaultProperty.isNotEmpty &&
        !_dropdownProperties.contains(widget.defaultProperty)) {
      _dropdownProperties.add(widget.defaultProperty);
    }
    _selectedProperty = widget.defaultProperty.isNotEmpty ? widget.defaultProperty : null;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
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

  Future<void> _schedule() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both date and time.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 500));

    final visit = SiteVisitModel(
      id: '', // Auto-generated by Firestore
      leadId: widget.leadId,
      clientName: widget.clientName,
      property: _selectedProperty ?? widget.defaultProperty,
      visitDate: _selectedDate!.toIso8601String().substring(0, 10),
      visitTime: _formatTime(_selectedTime!),
      status: 'scheduled',
    );

    await FirestoreService.instance.addSiteVisit(visit);

    await FirestoreService.instance.updateLead(widget.leadId, {
      'status': 'site visit scheduled',
      'lastTag': 'Site Visit Ready',
      'statusChangedAt': DateTime.now().toIso8601String(),
    });

    final now = DateTime.now();
    final createdAt =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final autoNote = NoteModel(
      id: '',
      text: '${widget.clientName} scheduled site visit for ${visit.visitDate} at ${visit.visitTime}',
      tag: 'Site Visit Scheduled',
      callDuration: '',
      createdAt: createdAt,
      isAutoLog: true,
    );
    await FirestoreService.instance.addNote(widget.leadId, autoNote);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context); // Close bottom sheet
      widget.onScheduled();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.purple,
          content: Row(
            children: [
              const Icon(Icons.event_available, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                'Site visit scheduled for ${_formatDate(_selectedDate!)}',
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
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.event_available,
                    color: AppTheme.purple,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Schedule Site Visit',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.purple,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Date picker
          GestureDetector(
            onTap: _pickDate,
            child: _PickerField(
              icon: 'event',
              label: 'Visit Date',
              value: _selectedDate != null ? _formatDate(_selectedDate!) : null,
              placeholder: 'Select date',
            ),
          ),
          const SizedBox(height: 12),
          // Time picker
          GestureDetector(
            onTap: _pickTime,
            child: _PickerField(
              icon: 'access_time',
              label: 'Visit Time',
              value: _selectedTime != null ? _formatTime(_selectedTime!) : null,
              placeholder: 'Select time',
            ),
          ),
          const SizedBox(height: 12),
          // Property Dropdown
          DropdownButtonFormField<String>(
            value: _selectedProperty,
            items: _dropdownProperties.map((p) {
              return DropdownMenuItem<String>(
                value: p,
                child: Text(
                  p,
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText),
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedProperty = val;
              });
            },
            decoration: InputDecoration(
              labelText: 'Property Name',
              labelStyle: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.mutedText,
              ),
              prefixIcon: const Icon(
                Icons.apartment,
                size: 16,
                color: AppTheme.mutedText,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
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
                borderSide: const BorderSide(color: AppTheme.purple, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _schedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
                        const Icon(Icons.event_available, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Schedule Site Visit',
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

class _PickerField extends StatelessWidget {
  final String icon;
  final String label;
  final String? value;
  final String placeholder;

  const _PickerField({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(
            icon == 'event' ? Icons.event : Icons.access_time,
            size: 16,
            color: AppTheme.mutedText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppTheme.mutedText,
                  ),
                ),
                Text(
                  value ?? placeholder,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: value != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: value != null
                        ? AppTheme.darkText
                        : AppTheme.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 16, color: AppTheme.mutedText),
        ],
      ),
    );
  }
}
