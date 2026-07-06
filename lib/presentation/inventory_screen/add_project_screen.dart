import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_export.dart';
import '../../models/project_model.dart';
import '../../models/tower_model.dart';
import '../../models/unit_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_icon_widget.dart';

/// Add / Edit project form with multi-section layout and bulk unit generation.
class AddProjectScreen extends StatefulWidget {
  const AddProjectScreen({super.key});

  @override
  State<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends State<AddProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editProjectId;

  // Section 1 — Project Overview
  final _nameCtrl = TextEditingController();
  final _developerCtrl = TextEditingController();
  String _projectType = 'Apartment';
  final _reraCtrl = TextEditingController();
  DateTime? _possessionDate;

  // Section 2 — Location
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();

  // Section 3 — Land & Structure
  final _landAreaCtrl = TextEditingController();
  String _landUnit = 'acres';
  int _towerCount = 1;
  final List<TextEditingController> _towerNameCtrls = [TextEditingController(text: 'Tower A')];
  final _floorsCtrl = TextEditingController(text: '10');

  // Section 4 — Unit Types
  final List<_UnitTypeConfig> _unitTypes = [_UnitTypeConfig()];

  // Section 5 — Amenities
  final List<String> _selectedAmenities = [];
  static const List<String> _amenityOptions = [
    'Gym', 'Swimming Pool', 'Parking', 'Clubhouse', 'Garden',
    'Power Backup', 'Lift', 'Security', 'Play Area', 'Jogging Track',
    'Indoor Games', 'Terrace', 'Intercom', 'Rainwater Harvesting',
    'EV Charging', 'Co-working Space',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && args.containsKey('project')) {
      final project = args['project'] as ProjectModel;
      if (!_isEditMode) {
        _isEditMode = true;
        _editProjectId = project.id;
        _nameCtrl.text = project.name;
        _developerCtrl.text = project.developerName;
        _projectType = project.projectType;
        _reraCtrl.text = project.reraNumber;
        if (project.possessionDate.isNotEmpty) {
          _possessionDate = DateTime.tryParse(project.possessionDate);
        }
        _addressCtrl.text = project.location;
        _cityCtrl.text = project.city;
        _pincodeCtrl.text = project.pincode;
        _landAreaCtrl.text = project.landParcelArea > 0
            ? project.landParcelArea.toString()
            : '';
        _landUnit = project.landParcelUnit;
        _towerCount = project.totalTowers > 0 ? project.totalTowers : 1;
        _selectedAmenities.addAll(project.amenities);
        // Tower names would need to be loaded from sub-collection
        _updateTowerFields();
      }
    }
  }

  void _updateTowerFields() {
    while (_towerNameCtrls.length < _towerCount) {
      final idx = _towerNameCtrls.length;
      _towerNameCtrls.add(TextEditingController(
        text: 'Tower ${String.fromCharCode(65 + idx)}',
      ));
    }
    while (_towerNameCtrls.length > _towerCount) {
      _towerNameCtrls.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _developerCtrl.dispose();
    _reraCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _landAreaCtrl.dispose();
    _floorsCtrl.dispose();
    for (final c in _towerNameCtrls) {
      c.dispose();
    }
    for (final ut in _unitTypes) {
      ut.dispose();
    }
    super.dispose();
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now().toIso8601String();
      final totalFloors = int.tryParse(_floorsCtrl.text.trim()) ?? 10;

      // Calculate total units from unit type configs
      int totalUnits = 0;
      for (final ut in _unitTypes) {
        totalUnits += int.tryParse(ut.countCtrl.text.trim()) ?? 0;
      }

      final project = ProjectModel(
        id: _editProjectId ?? '',
        name: _nameCtrl.text.trim(),
        developerName: _developerCtrl.text.trim(),
        projectType: _projectType,
        location: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        pincode: _pincodeCtrl.text.trim(),
        landParcelArea: double.tryParse(_landAreaCtrl.text.trim()) ?? 0.0,
        landParcelUnit: _landUnit,
        totalTowers: _towerCount,
        totalUnits: totalUnits,
        reraNumber: _reraCtrl.text.trim(),
        possessionDate: _possessionDate?.toIso8601String() ?? '',
        amenities: _selectedAmenities,
        createdAt: _isEditMode ? '' : now,
        updatedAt: now,
      );

      final projectId = await FirestoreService.instance.addProject(project);

      // Only generate towers and units for new projects
      if (!_isEditMode) {
        // Create towers
        final towers = <TowerModel>[];
        for (int i = 0; i < _towerCount; i++) {
          towers.add(TowerModel(
            id: '',
            projectId: projectId,
            towerName: _towerNameCtrls[i].text.trim(),
            totalFloors: totalFloors,
            createdAt: now,
          ));
        }
        final towerIds = await FirestoreService.instance.addTowersBatch(projectId, towers);

        // Generate units from unit type configs
        final units = <UnitModel>[];
        int unitCounter = 1;
        for (final ut in _unitTypes) {
          final count = int.tryParse(ut.countCtrl.text.trim()) ?? 0;
          final sba = double.tryParse(ut.sbaCtrl.text.trim()) ?? 0.0;
          final ba = double.tryParse(ut.baCtrl.text.trim()) ?? 0.0;
          final ca = double.tryParse(ut.caCtrl.text.trim()) ?? 0.0;
          final pricePerSqft = double.tryParse(ut.priceCtrl.text.trim()) ?? 0.0;
          final computedTotal = pricePerSqft * sba;

          for (int i = 0; i < count; i++) {
            final towerIdx = _towerCount > 0 ? (unitCounter - 1) % _towerCount : 0;
            final towerPrefix = _towerNameCtrls.length > towerIdx
                ? _towerNameCtrls[towerIdx].text.trim().substring(0, 1)
                : '${towerIdx + 1}';
            final floor = ((unitCounter - 1) ~/ _towerCount) + 1;
            final unitNum = '$towerPrefix-${floor.toString().padLeft(2, '0')}${((unitCounter - 1) % 4 + 1).toString().padLeft(2, '0')}';

            units.add(UnitModel(
              id: '',
              projectId: projectId,
              towerId: towerIds.isNotEmpty ? towerIds[towerIdx] : null,
              unitNumber: unitNum,
              floorNumber: floor,
              bhkType: ut.bhkType,
              facing: ut.facing,
              superBuiltupArea: sba,
              builtupArea: ba,
              carpetArea: ca,
              basePricePerSqft: pricePerSqft,
              totalPrice: computedTotal,
              availabilityStatus: 'Available',
              createdAt: now,
              updatedAt: now,
            ));
            unitCounter++;
          }
        }

        if (units.isNotEmpty) {
          await FirestoreService.instance.addUnitsBatch(projectId, units);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  _isEditMode ? 'Project updated' : 'Project created with $totalUnits units',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
        if (_isEditMode) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.projectDetailScreen,
            arguments: {'projectId': projectId},
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.error,
            content: Text('Error: $e', style: GoogleFonts.inter(color: Colors.white)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? 'Edit Project' : 'Add Project',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkText,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.borderColor),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Project Overview', 'info'),
                const SizedBox(height: 12),
                _buildTextField('Project Name *', _nameCtrl, required: true, textCapitalization: TextCapitalization.words),
                const SizedBox(height: 12),
                _buildTextField('Developer / Builder Name *', _developerCtrl, required: true, textCapitalization: TextCapitalization.words),
                const SizedBox(height: 12),
                _buildDropdown('Project Type *', _projectType, ProjectModel.projectTypes,
                    (v) => setState(() => _projectType = v!)),
                const SizedBox(height: 12),
                _buildTextField('RERA Number', _reraCtrl, textCapitalization: TextCapitalization.none, autocorrect: false),
                const SizedBox(height: 12),
                _buildDatePicker('Possession Date'),
                const SizedBox(height: 24),

                _buildSectionHeader('Location', 'location_on'),
                const SizedBox(height: 12),
                _buildTextField('Full Address *', _addressCtrl, required: true, maxLines: 2, textCapitalization: TextCapitalization.sentences),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTextField('City *', _cityCtrl, required: true, textCapitalization: TextCapitalization.words)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Pincode', _pincodeCtrl, textCapitalization: TextCapitalization.none, autocorrect: false)),
                  ],
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('Land & Structure', 'landscape'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField('Land Parcel Area *', _landAreaCtrl,
                          required: true, keyboardType: TextInputType.number, textCapitalization: TextCapitalization.none, autocorrect: false),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown('Unit', _landUnit, ProjectModel.landParcelUnits,
                          (v) => setState(() => _landUnit = v!)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTowerStepper(),
                const SizedBox(height: 12),
                ...List.generate(_towerCount, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildTextField(
                    'Tower ${i + 1} Name',
                    _towerNameCtrls[i],
                    textCapitalization: TextCapitalization.words,
                  ),
                )),
                const SizedBox(height: 12),
                _buildTextField('Total Floors per Tower', _floorsCtrl,
                    keyboardType: TextInputType.number, textCapitalization: TextCapitalization.none, autocorrect: false),
                const SizedBox(height: 24),

                if (!_isEditMode) ...[
                  _buildSectionHeader('Unit Configuration', 'grid_view'),
                  const SizedBox(height: 8),
                  Text(
                    'Define unit type templates — units will be auto-generated on save.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_unitTypes.length, (i) => _buildUnitTypeCard(i)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _unitTypes.add(_UnitTypeConfig())),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      'Add Another Unit Type',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                  ),
                  const SizedBox(height: 24),
                ],

                _buildSectionHeader('Amenities', 'fitness_center'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _amenityOptions.map((a) {
                    final isSelected = _selectedAmenities.contains(a);
                    return FilterChip(
                      label: Text(a),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedAmenities.add(a);
                          } else {
                            _selectedAmenities.remove(a);
                          }
                        });
                      },
                      selectedColor: AppTheme.primaryContainer,
                      checkmarkColor: AppTheme.primary,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? AppTheme.primary : AppTheme.darkText,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _isEditMode ? 'Update Project' : 'Save & Generate Units',
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Builder helpers ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, String icon) {
    return Row(
      children: [
        CustomIconWidget(iconName: icon, color: AppTheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkText,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool autocorrect = true,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.mutedText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null
          : null,
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.inter(fontSize: 13))))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.mutedText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDatePicker(String label) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _possessionDate ?? DateTime.now().add(const Duration(days: 365)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: AppTheme.primary),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _possessionDate = picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.mutedText),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.borderColor),
          ),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: const Icon(Icons.calendar_today, size: 16, color: AppTheme.mutedText),
        ),
        child: Text(
          _possessionDate != null
              ? '${_possessionDate!.day}/${_possessionDate!.month}/${_possessionDate!.year}'
              : 'Select date',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: _possessionDate != null ? AppTheme.darkText : AppTheme.mutedText,
          ),
        ),
      ),
    );
  }

  Widget _buildTowerStepper() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Number of Towers',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkText),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _towerCount > 1
                    ? () => setState(() { _towerCount--; _updateTowerFields(); })
                    : null,
                icon: const Icon(Icons.remove, size: 16),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                color: AppTheme.primary,
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$_towerCount',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => setState(() { _towerCount++; _updateTowerFields(); }),
                icon: const Icon(Icons.add, size: 16),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                color: AppTheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnitTypeCard(int index) {
    final ut = _unitTypes[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Unit Type ${index + 1}',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.darkText),
              ),
              const Spacer(),
              if (_unitTypes.length > 1)
                IconButton(
                  onPressed: () => setState(() {
                    _unitTypes[index].dispose();
                    _unitTypes.removeAt(index);
                  }),
                  icon: const Icon(Icons.close, size: 16, color: AppTheme.error),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDropdown('BHK Type', ut.bhkType, UnitModel.bhkTypes,
                    (v) => setState(() => ut.bhkType = v!)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown('Facing', ut.facing, UnitModel.facings,
                    (v) => setState(() => ut.facing = v!)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildTextField('SBA (sq ft)', ut.sbaCtrl, keyboardType: TextInputType.number, textCapitalization: TextCapitalization.none, autocorrect: false)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Built-up', ut.baCtrl, keyboardType: TextInputType.number, textCapitalization: TextCapitalization.none, autocorrect: false)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Carpet', ut.caCtrl, keyboardType: TextInputType.number, textCapitalization: TextCapitalization.none, autocorrect: false)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTextField('Price/sq ft (₹)', ut.priceCtrl,
                    keyboardType: TextInputType.number, textCapitalization: TextCapitalization.none, autocorrect: false),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField('No. of Units', ut.countCtrl,
                    keyboardType: TextInputType.number, required: true, textCapitalization: TextCapitalization.none, autocorrect: false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Internal helper to hold state for a single unit type configuration row.
class _UnitTypeConfig {
  String bhkType = '3BHK';
  String facing = 'East';
  final sbaCtrl = TextEditingController();
  final baCtrl = TextEditingController();
  final caCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final countCtrl = TextEditingController(text: '10');

  void dispose() {
    sbaCtrl.dispose();
    baCtrl.dispose();
    caCtrl.dispose();
    priceCtrl.dispose();
    countCtrl.dispose();
  }
}
