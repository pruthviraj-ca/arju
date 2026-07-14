import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/unit_model.dart';
import '../../../models/lead_model.dart';
import '../../../models/registration_stage_model.dart';
import '../../../services/firestore_service.dart';

/// Bottom sheet for viewing/editing a single unit's details.
class UnitEditSheet extends StatefulWidget {
  final UnitModel unit;
  final String projectId;
  final bool isAdmin;
  final String? towerName;

  const UnitEditSheet({
    super.key,
    required this.unit,
    required this.projectId,
    required this.isAdmin,
    this.towerName,
  });

  @override
  State<UnitEditSheet> createState() => _UnitEditSheetState();
}

class _UnitEditSheetState extends State<UnitEditSheet> {
  late String _status;
  late String _bhkType;
  late String _facing;
  late String _furnishing;
  late String _carParking;
  late String _unitType;
  late int _bedrooms;
  late int _bathrooms;
  late int _floor;
  late TextEditingController _priceCtrl;
  late TextEditingController _sbaCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _flatNoCtrl;
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _selectedLeadId;
  List<LeadModel> _leads = [];

  // Resale fields
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _ownerPhoneCtrl;
  late TextEditingController _ownerAskingPriceCtrl;
  late TextEditingController _listedPriceCtrl;
  late TextEditingController _ownerNotesCtrl;

  // Rental fields
  late TextEditingController _landlordNameCtrl;
  late TextEditingController _landlordPhoneCtrl;
  late TextEditingController _monthlyRentCtrl;
  late TextEditingController _securityDepositCtrl;
  late TextEditingController _landlordNotesCtrl;
  DateTime? _availableFrom;

  // Registration stages
  List<RegistrationStageModel> _regStages = [];
  StreamSubscription? _regStagesSub;

  @override
  void initState() {
    super.initState();
    _status = widget.unit.availabilityStatus;
    _bhkType = widget.unit.bhkType;
    _facing = widget.unit.facing;
    _furnishing = widget.unit.furnishing;
    _carParking = widget.unit.carParking;
    _unitType = widget.unit.unitType.isNotEmpty ? widget.unit.unitType : 'Fresh';
    _bedrooms = widget.unit.bedrooms;
    _bathrooms = widget.unit.bathrooms;
    _floor = widget.unit.floorNumber;
    _priceCtrl = TextEditingController(
      text: widget.unit.totalPrice > 0 ? widget.unit.totalPrice.toStringAsFixed(0) : '',
    );
    _sbaCtrl = TextEditingController(
      text: widget.unit.superBuiltupArea > 0 ? widget.unit.superBuiltupArea.toStringAsFixed(0) : '',
    );
    _notesCtrl = TextEditingController(text: widget.unit.notes);
    _flatNoCtrl = TextEditingController(text: widget.unit.unitNumber);
    _selectedLeadId = widget.unit.bookingLeadId;

    // Resale
    _ownerNameCtrl = TextEditingController(text: widget.unit.ownerName);
    _ownerPhoneCtrl = TextEditingController(text: widget.unit.ownerPhone);
    _ownerAskingPriceCtrl = TextEditingController(
      text: widget.unit.ownerAskingPrice > 0 ? widget.unit.ownerAskingPrice.toStringAsFixed(0) : '',
    );
    _listedPriceCtrl = TextEditingController(
      text: widget.unit.listedPrice > 0 ? widget.unit.listedPrice.toStringAsFixed(0) : '',
    );
    _ownerNotesCtrl = TextEditingController(text: widget.unit.ownerNotes);

    // Rental
    _landlordNameCtrl = TextEditingController(text: widget.unit.landlordName);
    _landlordPhoneCtrl = TextEditingController(text: widget.unit.landlordPhone);
    _monthlyRentCtrl = TextEditingController(
      text: widget.unit.monthlyRent > 0 ? widget.unit.monthlyRent.toStringAsFixed(0) : '',
    );
    _securityDepositCtrl = TextEditingController(
      text: widget.unit.securityDeposit > 0 ? widget.unit.securityDeposit.toStringAsFixed(0) : '',
    );
    _landlordNotesCtrl = TextEditingController(text: widget.unit.landlordNotes);
    if (widget.unit.availableFrom.isNotEmpty) {
      try {
        _availableFrom = DateTime.parse(widget.unit.availableFrom);
      } catch (_) {}
    }

    // Load leads for booking picker
    FirestoreService.instance.getLeadsOnce().then((leads) {
      if (mounted) setState(() => _leads = leads);
    });

    // Load registration stages if booked
    _loadRegistrationStages();
  }

  void _loadRegistrationStages() {
    _regStagesSub?.cancel();
    _regStagesSub = FirestoreService.instance
        .streamRegistrationStages(widget.projectId, widget.unit.id)
        .listen((stages) {
      if (mounted) setState(() => _regStages = stages);
    });
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _sbaCtrl.dispose();
    _notesCtrl.dispose();
    _flatNoCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerPhoneCtrl.dispose();
    _ownerAskingPriceCtrl.dispose();
    _listedPriceCtrl.dispose();
    _ownerNotesCtrl.dispose();
    _landlordNameCtrl.dispose();
    _landlordPhoneCtrl.dispose();
    _monthlyRentCtrl.dispose();
    _securityDepositCtrl.dispose();
    _landlordNotesCtrl.dispose();
    _regStagesSub?.cancel();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final updates = <String, dynamic>{
        'availability_status': _status,
        'availabilityStatus': _status,
        'total_price': double.tryParse(_priceCtrl.text.trim()) ?? widget.unit.totalPrice,
        'totalPrice': double.tryParse(_priceCtrl.text.trim()) ?? widget.unit.totalPrice,
        'sba_sqft': double.tryParse(_sbaCtrl.text.trim()) ?? widget.unit.superBuiltupArea,
        'superBuiltupArea': double.tryParse(_sbaCtrl.text.trim()) ?? widget.unit.superBuiltupArea,
        'notes': _notesCtrl.text.trim(),
        'flat_number': _flatNoCtrl.text.trim(),
        'unitNumber': _flatNoCtrl.text.trim(),
        'bhkType': _bhkType,
        'main_door_facing': _facing,
        'facing': _facing,
        'furnishing': _furnishing,
        'car_parking': _carParking,
        'carParking': _carParking,
        'bedrooms': _bedrooms,
        'bathrooms': _bathrooms,
        'floor_number': _floor,
        'floorNumber': _floor,
        'unit_type': _unitType,
        'unitType': _unitType,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (_status == 'Booked' && _selectedLeadId != null) {
        updates['booking_lead_id'] = _selectedLeadId;
        updates['bookingLeadId'] = _selectedLeadId;
      } else if (_status != 'Booked') {
        updates['booking_lead_id'] = null;
        updates['bookingLeadId'] = null;
      }

      // Resale fields
      updates['owner_name'] = _unitType == 'Resale' ? _ownerNameCtrl.text.trim() : '';
      updates['owner_phone'] = _unitType == 'Resale' ? _ownerPhoneCtrl.text.trim() : '';
      updates['owner_asking_price'] = _unitType == 'Resale' ? (double.tryParse(_ownerAskingPriceCtrl.text.trim()) ?? 0.0) : 0.0;
      updates['listed_price'] = _unitType == 'Resale' ? (double.tryParse(_listedPriceCtrl.text.trim()) ?? 0.0) : 0.0;
      updates['owner_notes'] = _unitType == 'Resale' ? _ownerNotesCtrl.text.trim() : '';

      // Rental fields
      updates['landlord_name'] = _unitType == 'Rental' ? _landlordNameCtrl.text.trim() : '';
      updates['landlord_phone'] = _unitType == 'Rental' ? _landlordPhoneCtrl.text.trim() : '';
      updates['monthly_rent'] = _unitType == 'Rental' ? (double.tryParse(_monthlyRentCtrl.text.trim()) ?? 0.0) : 0.0;
      updates['security_deposit'] = _unitType == 'Rental' ? (double.tryParse(_securityDepositCtrl.text.trim()) ?? 0.0) : 0.0;
      updates['available_from'] = _unitType == 'Rental' && _availableFrom != null ? _availableFrom!.toIso8601String() : '';
      updates['landlord_notes'] = _unitType == 'Rental' ? _landlordNotesCtrl.text.trim() : '';

      await FirestoreService.instance.updateUnit(widget.projectId, widget.unit.id, updates);

      // Initialize registration stages when status changes to Booked
      if (_status == 'Booked') {
        await FirestoreService.instance.initializeRegistrationStages(
          widget.projectId, widget.unit.id,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text('Unit ${_flatNoCtrl.text.trim()} updated',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.error, content: Text('Error: $e')),
        );
      }
    }
  }

  void _confirmDelete() {
    final isBooked = widget.unit.availabilityStatus == 'Booked';
    final hasLead = widget.unit.bookingLeadId != null && widget.unit.bookingLeadId!.isNotEmpty;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete unit ${widget.unit.unitNumber}?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This cannot be undone.',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText)),
            if (isBooked && hasLead) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.error.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error.withAlpha(40)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This unit is currently booked and linked to a lead. Deleting it will remove the booking association.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.mutedText)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isDeleting = true);
              try {
                await FirestoreService.instance.deleteUnit(widget.projectId, widget.unit.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.success,
                      content: Text('Unit ${widget.unit.unitNumber} deleted',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  );
                }
              } catch (e) {
                setState(() => _isDeleting = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: AppTheme.error, content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Available': return AppTheme.success;
      case 'Booked': return AppTheme.statusCalled;
      case 'Sold': return AppTheme.mutedText;
      case 'Hold': return AppTheme.accent;
      default: return AppTheme.mutedText;
    }
  }

  String _statusEmoji(String status) {
    switch (status) {
      case 'Available': return '✅';
      case 'Booked': return '📋';
      case 'Hold': return '🔒';
      case 'Sold': return '❌';
      default: return '•';
    }
  }

  void _showStageEditDialog(RegistrationStageModel stage) {
    final notesCtrl = TextEditingController(text: stage.notes);
    String currentStatus = stage.status;
    DateTime? completedDate;
    if (stage.completedDate.isNotEmpty) {
      try { completedDate = DateTime.parse(stage.completedDate); } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            stage.stageName,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mutedText)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: RegistrationStageModel.validStatuses.map((s) {
                  final isActive = s == currentStatus;
                  final color = s == 'completed' ? AppTheme.success : s == 'in_progress' ? AppTheme.statusCalled : AppTheme.mutedText;
                  final label = s == 'pending' ? '⬜ Pending' : s == 'in_progress' ? '🔄 In Progress' : '✅ Completed';
                  return FilterChip(
                    label: Text(label),
                    selected: isActive,
                    onSelected: (_) {
                      setDialogState(() => currentStatus = s);
                      if (s == 'completed' && completedDate == null) {
                        completedDate = DateTime.now();
                      }
                    },
                    selectedColor: color.withAlpha(30),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive ? color : AppTheme.darkText,
                    ),
                  );
                }).toList(),
              ),
              if (currentStatus == 'completed') ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: completedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => completedDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Completed Date',
                      labelStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderColor)),
                    ),
                    child: Text(
                      completedDate != null
                          ? '${completedDate!.day}/${completedDate!.month}/${completedDate!.year}'
                          : 'Select date',
                      style: GoogleFonts.inter(fontSize: 13, color: completedDate != null ? AppTheme.darkText : AppTheme.mutedText),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: notesCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Notes',
                  labelStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderColor)),
                  hintText: 'Loan ref, doc number...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.mutedText)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await FirestoreService.instance.updateRegistrationStage(
                  widget.projectId, widget.unit.id, stage.id,
                  {
                    'status': currentStatus,
                    'completed_date': currentStatus == 'completed' && completedDate != null
                        ? completedDate!.toIso8601String()
                        : '',
                    'notes': notesCtrl.text.trim(),
                    'updated_at': DateTime.now().toIso8601String(),
                  },
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.unit;
    final completedCount = _regStages.where((s) => s.isCompleted).length;
    final progressPercent = _regStages.isNotEmpty ? (completedCount / _regStages.length * 100).toInt() : 0;

    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              children: [
                Text(
                  'Unit ${u.unitNumber}',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.darkText),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_status).withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(_status).withAlpha(80)),
                  ),
                  child: Text(
                    _status,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _getStatusColor(_status)),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _isDeleting ? null : _confirmDelete,
                  icon: _isDeleting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.error))
                      : const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
                  tooltip: 'Delete Unit',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Unit Type Selector ──
            Text('Unit Type', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkText)),
            const SizedBox(height: 8),
            Row(
              children: UnitModel.unitTypes.map((t) {
                final isActive = t == _unitType;
                final color = t == 'Fresh' ? AppTheme.teal : t == 'Resale' ? AppTheme.warning : AppTheme.purple;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: t != UnitModel.unitTypes.last ? 8 : 0),
                    child: InkWell(
                      onTap: () => setState(() => _unitType = t),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive ? color.withAlpha(20) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isActive ? color : AppTheme.borderColor, width: isActive ? 2 : 1),
                        ),
                        child: Text(
                          t,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? color : AppTheme.darkText),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Quick Status Picker ──
            Text('Change Status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkText)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Available', 'Booked', 'Hold', 'Sold'].map((s) {
                final isActive = s == _status;
                final color = _getStatusColor(s);
                return InkWell(
                  onTap: () => setState(() {
                    _status = s;
                    if (s != 'Booked') _selectedLeadId = null;
                  }),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? color.withAlpha(25) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive ? color : AppTheme.borderColor,
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_statusEmoji(s), style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(s, style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? color : AppTheme.darkText,
                        )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Lead picker when Booked
            if (_status == 'Booked') ...[
              Text('Link to Lead', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkText)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedLeadId,
                hint: Text('Select a lead', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.mutedText)),
                items: _leads.map((l) => DropdownMenuItem(
                  value: l.id,
                  child: Text('${l.clientName} (${l.phone})', style: GoogleFonts.inter(fontSize: 12)),
                )).toList(),
                onChanged: (v) => setState(() => _selectedLeadId = v),
                decoration: _inputDec(''),
                isExpanded: true,
              ),
              const SizedBox(height: 12),

              // ── Registration Progress ──
              if (_regStages.isNotEmpty) ...[
                const Divider(color: AppTheme.borderColor),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Registration Progress', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.statusCalled)),
                    const Spacer(),
                    Text('$completedCount/${_regStages.length} ($progressPercent%)',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.statusCalled)),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _regStages.isNotEmpty ? completedCount / _regStages.length : 0,
                    backgroundColor: AppTheme.borderColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.statusCalled),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 10),
                // Compact stage list
                ...List.generate(_regStages.length, (i) {
                  final stage = _regStages[i];
                  final statusIcon = stage.isCompleted
                      ? '✅'
                      : stage.isInProgress
                          ? '🔄'
                          : '⬜';
                  final statusColor = stage.isCompleted
                      ? AppTheme.success
                      : stage.isInProgress
                          ? AppTheme.statusCalled
                          : AppTheme.mutedText;
                  String subtitle = '';
                  if (stage.isCompleted && stage.completedDate.isNotEmpty) {
                    try {
                      final d = DateTime.parse(stage.completedDate);
                      subtitle = '${d.day}/${d.month}/${d.year}';
                    } catch (_) {}
                  }
                  if (stage.notes.isNotEmpty) {
                    subtitle += subtitle.isNotEmpty ? ' · ${stage.notes}' : stage.notes;
                  }
                  return InkWell(
                    onTap: () => _showStageEditDialog(stage),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(statusIcon, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${stage.stageNumber}. ${stage.stageName}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: stage.isCompleted ? FontWeight.w600 : FontWeight.w400,
                                    color: statusColor,
                                    decoration: stage.isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                if (subtitle.isNotEmpty)
                                  Text(
                                    subtitle,
                                    style: GoogleFonts.inter(fontSize: 10, color: AppTheme.mutedText),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 16, color: AppTheme.mutedText),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
            ],

            const Divider(color: AppTheme.borderColor),
            const SizedBox(height: 12),

            // ── Editable Fields ──
            Text('Unit Details', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkText)),
            const SizedBox(height: 8),

            // Flat No + Floor
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _flatNoCtrl,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: _inputDec('Flat No.'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: '$_floor',
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: _inputDec('Floor'),
                    onChanged: (v) => _floor = int.tryParse(v) ?? _floor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // BHK + Facing
            Row(
              children: [
                Expanded(
                  child: _miniDropdown('BHK', _bhkType, UnitModel.bhkTypes,
                      (v) => setState(() => _bhkType = v!)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _miniDropdown('Main Door Facing', _facing, UnitModel.facings,
                      (v) => setState(() => _facing = v!)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // SBA + Price
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sbaCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: _inputDec('SBA in SqFt'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: _inputDec('Total Price (₹)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Bedrooms + Bathrooms
            Row(
              children: [
                Expanded(
                  child: _miniDropdown('Bedrooms', '$_bedrooms', ['1','2','3','4','5'],
                      (v) => setState(() => _bedrooms = int.tryParse(v ?? '2') ?? 2)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _miniDropdown('Bathrooms', '$_bathrooms', ['1','2','3','4'],
                      (v) => setState(() => _bathrooms = int.tryParse(v ?? '2') ?? 2)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Furnishing + Car Parking
            Row(
              children: [
                Expanded(
                  child: _miniDropdown('Furnishing', _furnishing, UnitModel.furnishingOptions,
                      (v) => setState(() => _furnishing = v!)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _miniDropdown('Car Parking', _carParking, UnitModel.carParkingOptions,
                      (v) => setState(() => _carParking = v!)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Resale Owner Details ──
            if (_unitType == 'Resale') ...[
              const Divider(color: AppTheme.borderColor),
              const SizedBox(height: 8),
              Text('Resale Owner Details', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.warning)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ownerNameCtrl,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: _inputDec('Owner Name'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ownerPhoneCtrl,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: _inputDec('Owner Phone'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ownerAskingPriceCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: _inputDec('Asking Price (₹)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _listedPriceCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: _inputDec('Listed Price (₹)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ownerNotesCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: _inputDec('Owner Notes').copyWith(
                  hintText: 'Flexibility, reason for selling...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // ── Rental Owner Details ──
            if (_unitType == 'Rental') ...[
              const Divider(color: AppTheme.borderColor),
              const SizedBox(height: 8),
              Text('Rental Owner Details', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.purple)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _landlordNameCtrl,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: _inputDec('Landlord Name'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _landlordPhoneCtrl,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: _inputDec('Landlord Phone'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _monthlyRentCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: _inputDec('Monthly Rent (₹)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _securityDepositCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: _inputDec('Security Deposit (₹)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _availableFrom ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (picked != null) setState(() => _availableFrom = picked);
                },
                child: InputDecorator(
                  decoration: _inputDec('Available From'),
                  child: Text(
                    _availableFrom != null
                        ? '${_availableFrom!.day}/${_availableFrom!.month}/${_availableFrom!.year}'
                        : 'Select date...',
                    style: GoogleFonts.inter(fontSize: 13, color: _availableFrom != null ? AppTheme.darkText : AppTheme.mutedText),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _landlordNotesCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: _inputDec('Landlord Notes').copyWith(
                  hintText: 'Restrictions, preferences...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Notes
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: _inputDec('Notes').copyWith(
                hintText: 'Internal remarks...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.mutedText),
              ),
            ),
            const SizedBox(height: 20),

            // Save
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Save Changes', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label) {
    return InputDecoration(
      labelText: label.isNotEmpty ? label : null,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.mutedText),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.borderColor),
      ),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
    );
  }

  Widget _miniDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: GoogleFonts.inter(fontSize: 12)))).toList(),
      onChanged: onChanged,
      isExpanded: true,
      decoration: _inputDec(label),
    );
  }
}
