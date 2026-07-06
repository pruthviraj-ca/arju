import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_export.dart';
import '../../models/project_model.dart';
import '../../models/tower_model.dart';
import '../../models/unit_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/availability_summary_widget.dart';
import './widgets/breakdown_chips_widget.dart';
import './widgets/unit_edit_sheet.dart';

/// Project detail page showing summary stats, breakdowns, and filterable unit list.
class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  String? _projectId;
  ProjectModel? _project;
  List<TowerModel> _towers = [];
  List<UnitModel> _allUnits = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  StreamSubscription? _projectSub;
  StreamSubscription? _towersSub;
  StreamSubscription? _unitsSub;
  StreamSubscription? _profileSub;

  // Filters
  String _statusFilter = 'All';
  String? _bhkFilter;
  String? _facingFilter;
  String? _towerFilter;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _projectId = args['projectId'] as String?;
      }
      if (_projectId != null) {
        _startListening();
      }
      _initialized = true;
    }
  }

  void _startListening() {
    _profileSub = FirestoreService.instance.streamUserProfile().listen((profile) {
      if (mounted) {
        final role = (profile?['role'] as String? ?? '').toLowerCase();
        setState(() => _isAdmin = role.contains('co founder') || role.contains('admin'));
      }
    });

    _projectSub = FirestoreService.instance.streamProjects().listen((projects) {
      if (mounted) {
        final match = projects.where((p) => p.id == _projectId).toList();
        if (match.isNotEmpty) setState(() => _project = match.first);
      }
    });

    _towersSub = FirestoreService.instance.streamTowers(_projectId!).listen((towers) {
      if (mounted) setState(() => _towers = towers);
    });

    _unitsSub = FirestoreService.instance.streamUnits(_projectId!).listen((units) {
      if (mounted) {
        setState(() {
          _allUnits = units;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _projectSub?.cancel();
    _towersSub?.cancel();
    _unitsSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }

  List<UnitModel> get _filteredUnits {
    return _allUnits.where((u) {
      if (_statusFilter != 'All' && u.availabilityStatus != _statusFilter) return false;
      if (_bhkFilter != null && u.bhkType != _bhkFilter) return false;
      if (_facingFilter != null && u.facing != _facingFilter) return false;
      if (_towerFilter != null && u.towerId != _towerFilter) return false;
      return true;
    }).toList();
  }

  Map<String, int> get _facingBreakdown {
    final available = _allUnits.where((u) => u.availabilityStatus == 'Available');
    final map = <String, int>{};
    for (final u in available) {
      map[u.facing] = (map[u.facing] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get _bhkBreakdown {
    final available = _allUnits.where((u) => u.availabilityStatus == 'Available');
    final map = <String, int>{};
    for (final u in available) {
      map[u.bhkType] = (map[u.bhkType] ?? 0) + 1;
    }
    return map;
  }

  String _getTowerName(String? towerId) {
    if (towerId == null) return '';
    final match = _towers.where((t) => t.id == towerId);
    return match.isNotEmpty ? match.first.towerName : '';
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
    if (_isLoading || _project == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceLight,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context, AppRoutes.inventoryScreen, (r) => false),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    final p = _project!;
    final filtered = _filteredUnits;
    final available = _allUnits.where((u) => u.availabilityStatus == 'Available').length;
    final resale = _allUnits.where((u) => u.availabilityStatus == 'Resale').length;
    final rental = _allUnits.where((u) => u.availabilityStatus == 'Rental').length;
    final booked = _allUnits.where((u) => u.availabilityStatus == 'Booked').length;
    final hold = _allUnits.where((u) =>
        u.availabilityStatus == 'Hold' || u.availabilityStatus == 'Blocked').length;
    final sold = _allUnits.where((u) => u.availabilityStatus == 'Sold').length;

    // Get unique BHK types and facings for filter dropdowns
    final uniqueBhks = _allUnits.map((u) => u.bhkType).toSet().toList()..sort();
    final uniqueFacings = _allUnits.map((u) => u.facing).toSet().toList()..sort();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.inventoryScreen, (r) => false),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.name,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.darkText),
            ),
            Text(
              p.developerName,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText),
            ),
          ],
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.addProjectScreen,
                arguments: {'project': p},
              ),
              tooltip: 'Edit Project',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.borderColor),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Card ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(p.name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.darkText)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(p.projectType, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                        ),
                      ],
                    ),
                    if (p.reraNumber.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('RERA: ${p.reraNumber}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText)),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CustomIconWidget(iconName: 'location_on', color: AppTheme.mutedText, size: 14),
                        const SizedBox(width: 4),
                        Expanded(child: Text(p.location, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        _InfoChip(icon: 'landscape', label: '${p.landParcelArea} ${p.landParcelUnit}'),
                        _InfoChip(icon: 'domain', label: '${p.totalTowers} Towers'),
                        _InfoChip(icon: 'home', label: '${_allUnits.length} Units'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Availability Summary ──
              Text('Availability Summary', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkText)),
              const SizedBox(height: 8),
              AvailabilitySummaryWidget(
                available: available,
                resale: resale,
                rental: rental,
                booked: booked,
                hold: hold,
                sold: sold,
              ),
              const SizedBox(height: 16),

              // ── Breakdowns ──
              BreakdownChipsWidget(
                title: 'Available by Facing',
                breakdown: _facingBreakdown,
                chipColor: AppTheme.teal,
              ),
              const SizedBox(height: 12),
              BreakdownChipsWidget(
                title: 'Available by BHK',
                breakdown: _bhkBreakdown,
                chipColor: AppTheme.primary,
              ),
              const SizedBox(height: 20),

              // ── Filters ──
              Text('Units', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkText)),
              const SizedBox(height: 8),
              // Status filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', ...UnitModel.availabilityStatuses].map((s) {
                    final isActive = s == _statusFilter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(s),
                        selected: isActive,
                        onSelected: (_) => setState(() => _statusFilter = s),
                        selectedColor: AppTheme.primaryContainer,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                          color: isActive ? AppTheme.primary : AppTheme.darkText,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              // Secondary filters
              Row(
                children: [
                  Expanded(
                    child: _buildMiniDropdown('BHK', _bhkFilter, uniqueBhks,
                        (v) => setState(() => _bhkFilter = v)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniDropdown('Facing', _facingFilter, uniqueFacings,
                        (v) => setState(() => _facingFilter = v)),
                  ),
                  if (_towers.length > 1) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMiniDropdown(
                        'Tower',
                        _towerFilter,
                        _towers.map((t) => t.id).toList(),
                        (v) => setState(() => _towerFilter = v),
                        displayMap: {for (var t in _towers) t.id: t.towerName},
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Results count
              Text(
                '${filtered.length} unit${filtered.length == 1 ? '' : 's'} found',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText),
              ),
              const SizedBox(height: 8),

              // ── Unit List ──
              ...filtered.map((u) => _buildUnitRow(u)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniDropdown(
    String hint,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    Map<String, String>? displayMap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('All $hint', style: GoogleFonts.inter(fontSize: 11)),
            ),
            ...items.map((i) => DropdownMenuItem(
              value: i,
              child: Text(
                displayMap?[i] ?? i,
                style: GoogleFonts.inter(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildUnitRow(UnitModel u) {
    final statusColor = _getStatusColor(u.availabilityStatus);
    final towerName = _getTowerName(u.towerId);

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => UnitEditSheet(
            unit: u,
            projectId: _projectId!,
            isAdmin: _isAdmin,
            towerName: towerName.isNotEmpty ? towerName : null,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            // Unit info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        u.unitNumber,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.darkText),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'F${u.floorNumber}',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText),
                      ),
                      if (towerName.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          towerName,
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${u.bhkType} · ${u.facing} · ${u.superBuiltupArea.toStringAsFixed(0)} sqft',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText),
                  ),
                ],
              ),
            ),
            // Price + status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  u.formattedPrice,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.darkText),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withAlpha(60)),
                  ),
                  child: Text(
                    u.availabilityStatus,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
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

class _InfoChip extends StatelessWidget {
  final String icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomIconWidget(iconName: icon, color: AppTheme.mutedText, size: 14),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.mutedText)),
      ],
    );
  }
}
