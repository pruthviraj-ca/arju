import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/unit_model.dart';
import '../../../models/lead_model.dart';
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
  late TextEditingController _priceCtrl;
  late TextEditingController _notesCtrl;
  bool _isSaving = false;
  String? _selectedLeadId;
  List<LeadModel> _leads = [];

  @override
  void initState() {
    super.initState();
    _status = widget.unit.availabilityStatus;
    _priceCtrl = TextEditingController(
      text: widget.unit.totalPrice > 0 ? widget.unit.totalPrice.toStringAsFixed(0) : '',
    );
    _notesCtrl = TextEditingController(text: widget.unit.notes);
    _selectedLeadId = widget.unit.bookingLeadId;

    // Load leads for booking picker
    FirestoreService.instance.getLeadsOnce().then((leads) {
      if (mounted) setState(() => _leads = leads);
    });
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final updates = <String, dynamic>{
        'availabilityStatus': _status,
        'totalPrice': double.tryParse(_priceCtrl.text.trim()) ?? widget.unit.totalPrice,
        'notes': _notesCtrl.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (_status == 'Booked' && _selectedLeadId != null) {
        updates['bookingLeadId'] = _selectedLeadId;
      } else if (_status != 'Booked') {
        updates['bookingLeadId'] = null;
      }

      await FirestoreService.instance.updateUnit(widget.projectId, widget.unit.id, updates);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text('Unit ${widget.unit.unitNumber} updated',
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Available': return AppTheme.success;
      case 'Booked': return AppTheme.statusCalled;
      case 'Sold': return AppTheme.mutedText;
      case 'Resale': return AppTheme.warning;
      case 'Rental': return AppTheme.purple;
      case 'Blocked':
      case 'Hold': return AppTheme.accent;
      default: return AppTheme.mutedText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.unit;
    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
              ],
            ),
            const SizedBox(height: 16),
            // Info grid
            _InfoRow(label: 'Floor', value: '${u.floorNumber}'),
            if (widget.towerName != null) _InfoRow(label: 'Tower', value: widget.towerName!),
            _InfoRow(label: 'BHK', value: u.bhkType),
            _InfoRow(label: 'Facing', value: u.facing),
            _InfoRow(label: 'SBA', value: '${u.superBuiltupArea.toStringAsFixed(0)} sq ft'),
            _InfoRow(label: 'Built-up', value: '${u.builtupArea.toStringAsFixed(0)} sq ft'),
            _InfoRow(label: 'Carpet', value: '${u.carpetArea.toStringAsFixed(0)} sq ft'),
            _InfoRow(label: 'Price/sqft', value: '₹${u.basePricePerSqft.toStringAsFixed(0)}'),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.borderColor),
            const SizedBox(height: 12),

            if (widget.isAdmin) ...[
              // Status dropdown
              Text('Status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkText)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _status,
                items: UnitModel.availabilityStatuses
                    .map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.inter(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() {
                  _status = v!;
                  if (v != 'Booked') _selectedLeadId = null;
                }),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                ),
              ),
              const SizedBox(height: 12),

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
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                  ),
                  isExpanded: true,
                ),
                const SizedBox(height: 12),
              ],

              // Total Price
              Text('Total Price (₹)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkText)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                ),
              ),
              const SizedBox(height: 12),

              // Notes
              Text('Notes', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkText)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Internal remarks...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.mutedText),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
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
            ] else ...[
              // View-only for non-admin
              _InfoRow(label: 'Total Price', value: u.formattedPrice),
              if (u.notes.isNotEmpty) _InfoRow(label: 'Notes', value: u.notes),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkText),
            ),
          ),
        ],
      ),
    );
  }
}
