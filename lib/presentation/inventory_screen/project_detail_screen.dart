import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_export.dart';
import '../../models/project_model.dart';
import '../../models/tower_model.dart';
import '../../models/unit_model.dart';
import '../../models/registration_stage_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_icon_widget.dart';
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
  bool _migrationDone = false;

  StreamSubscription? _projectSub;
  StreamSubscription? _towersSub;
  StreamSubscription? _unitsSub;
  StreamSubscription? _profileSub;

  // Filters
  String _typeFilter = 'All';
  String _statusFilter = 'All';
  String? _bhkFilter;
  String? _facingFilter;
  String? _towerFilter;

  // Registration stage cache for booked units (unitId -> stages)
  final Map<String, List<RegistrationStageModel>> _regStagesCache = {};
  final Map<String, StreamSubscription?> _regStageSubs = {};

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
        setState(() => _isAdmin = true);
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
        // Run one-time migration for this project
        if (!_migrationDone) {
          _migrationDone = true;
          FirestoreService.instance.migrateUnitTypesForProject(_projectId!);
        }
        // Subscribe to registration stages for booked units
        _updateRegistrationStageSubs();
      }
    });
  }

  void _updateRegistrationStageSubs() {
    final bookedUnitIds = _allUnits
        .where((u) => u.availabilityStatus == 'Booked')
        .map((u) => u.id)
        .toSet();

    // Subscribe to new booked units
    for (final uid in bookedUnitIds) {
      if (!_regStageSubs.containsKey(uid)) {
        _regStageSubs[uid] = FirestoreService.instance
            .streamRegistrationStages(_projectId!, uid)
            .listen((stages) {
          if (mounted) {
            setState(() => _regStagesCache[uid] = stages);
          }
        });
      }
    }

    // Unsubscribe from units no longer booked
    final toRemove = _regStageSubs.keys
        .where((uid) => !bookedUnitIds.contains(uid))
        .toList();
    for (final uid in toRemove) {
      _regStageSubs[uid]?.cancel();
      _regStageSubs.remove(uid);
      // Keep cache so data is preserved if re-booked
    }
  }

  @override
  void dispose() {
    _projectSub?.cancel();
    _towersSub?.cancel();
    _unitsSub?.cancel();
    _profileSub?.cancel();
    for (final sub in _regStageSubs.values) {
      sub?.cancel();
    }
    super.dispose();
  }

  List<UnitModel> get _filteredUnits {
    return _allUnits.where((u) {
      // Type filter
      if (_typeFilter != 'All' && u.unitType != _typeFilter) return false;
      // Status filter
      if (_statusFilter != 'All' && u.availabilityStatus != _statusFilter) return false;
      if (_bhkFilter != null && u.bhkType != _bhkFilter) return false;
      if (_facingFilter != null && u.facing != _facingFilter) return false;
      if (_towerFilter != null && u.towerId != _towerFilter) return false;
      return true;
    }).toList();
  }



  // ─── Count helpers for filter chips ────────────────────────────────────────

  int _countByType(String type) {
    if (type == 'All') return _allUnits.length;
    return _allUnits.where((u) => u.unitType == type).length;
  }

  int _countByStatus(String status) {
    if (status == 'All') return _allUnits.length;
    return _allUnits.where((u) => u.availabilityStatus == status).length;
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
      case 'Hold': return AppTheme.accent;
      default: return AppTheme.mutedText;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Fresh': return AppTheme.teal;
      case 'Resale': return AppTheme.warning;
      case 'Rental': return AppTheme.purple;
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
          if (_isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.primary, size: 22),
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.addProjectScreen,
                    arguments: {'project': p},
                  );
                } else if (value == 'delete') {
                  _confirmDeleteProject(p);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text('Edit Project', style: GoogleFonts.inter(fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Text('Delete Project', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.error)),
                    ],
                  ),
                ),
              ],
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

              // ── About this Project ──
              if (p.description.isNotEmpty) ...[
                _AboutProjectSection(description: p.description),
                const SizedBox(height: 16),
              ],

              // ── FILTER ROW 1: Unit Type ──
              Text('Unit Type', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mutedText)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', ...UnitModel.unitTypes].map((t) {
                    final isActive = t == _typeFilter;
                    final count = _countByType(t);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(t == 'All' ? 'All ($count)' : '$t ($count)'),
                        selected: isActive,
                        onSelected: (_) => setState(() => _typeFilter = t),
                        selectedColor: t == 'All'
                            ? AppTheme.primaryContainer
                            : _getTypeColor(t).withAlpha(30),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                          color: isActive
                              ? (t == 'All' ? AppTheme.primary : _getTypeColor(t))
                              : AppTheme.darkText,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              // ── FILTER ROW 2: Unit Status ──
              Text('Unit Status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mutedText)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', ...UnitModel.availabilityStatuses].map((s) {
                    final isActive = s == _statusFilter;
                    final count = _countByStatus(s);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(s == 'All' ? 'All ($count)' : '$s ($count)'),
                        selected: isActive,
                        onSelected: (_) => setState(() => _statusFilter = s),
                        selectedColor: s == 'All'
                            ? AppTheme.primaryContainer
                            : _getStatusColor(s).withAlpha(30),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                          color: isActive
                              ? (s == 'All' ? AppTheme.primary : _getStatusColor(s))
                              : AppTheme.darkText,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Units Header + Add ──
              Row(
                children: [
                  Expanded(
                    child: Text('Units', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkText)),
                  ),
                  if (_isAdmin)
                    TextButton.icon(
                      onPressed: () => _showAddUnitSheet(p),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text('Add Unit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Secondary filters (BHK, Facing, Tower)
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
          hint: Text('All $hint', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText)),
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
    final typeColor = _getTypeColor(u.unitType);
    final towerName = _getTowerName(u.towerId);

    // Registration stages for booked units
    final stages = _regStagesCache[u.id] ?? [];
    final completedStages = stages.where((s) => s.isCompleted).length;
    final lastCompleted = stages.where((s) => s.isCompleted).toList();
    final lastStageName = lastCompleted.isNotEmpty
        ? lastCompleted.last.stageName
        : null;

    return GestureDetector(
      onTap: () => _showEditUnitSheet(u, towerName),
      onLongPress: () => _showChangeStatusSheet(u),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LINE 1: [Flat No.]  Tower X               [Price]
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        u.unitNumber,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.darkText),
                      ),
                      if (towerName.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          towerName,
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  u.displayPrice,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.darkText),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.mutedText),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showEditUnitSheet(u, towerName);
                    } else if (val == 'status') {
                      _showChangeStatusSheet(u);
                    } else if (val == 'delete') {
                      _confirmDeleteUnit(u);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Text('Edit', style: GoogleFonts.inter(fontSize: 12)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'status',
                      child: Row(
                        children: [
                          const Icon(Icons.swap_horiz, size: 16, color: AppTheme.accent),
                          const SizedBox(width: 8),
                          Text('Change Status', style: GoogleFonts.inter(fontSize: 12)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                          const SizedBox(width: 8),
                          Text('Delete', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),

            // LINE 2: [N]BHK · [Facing] · [SBA] sqft · [Furnishing]   [Status badge]
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${u.bhkType} · ${u.facing} · ${u.superBuiltupArea.toStringAsFixed(0)} sqft · ${u.furnishing}',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
            const SizedBox(height: 4),

            // LINE 3: Type-specific info
            Row(
              children: [
                // Type chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: typeColor.withAlpha(60)),
                  ),
                  child: Text(
                    u.unitType,
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: typeColor),
                  ),
                ),
                const SizedBox(width: 8),
                // Type-specific details
                if (u.unitType == 'Resale' && u.ownerName.isNotEmpty)
                  Expanded(
                    child: Text(
                      '👤 ${u.ownerName}  📞 ${u.ownerPhone}  Ask: ${u.formattedAskingPrice}',
                      style: GoogleFonts.inter(fontSize: 10, color: AppTheme.warning),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else if (u.unitType == 'Rental' && u.landlordName.isNotEmpty)
                  Expanded(
                    child: Text(
                      '👤 ${u.landlordName}  📞 ${u.landlordPhone}  ${u.formattedRent}',
                      style: GoogleFonts.inter(fontSize: 10, color: AppTheme.purple),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      '🚗 ${u.carParking}  🛁 ${u.bathrooms} baths',
                      style: GoogleFonts.inter(fontSize: 10, color: AppTheme.mutedText),
                    ),
                  ),
              ],
            ),

            // LINE 4: Registration progress (Booked units only)
            if (u.availabilityStatus == 'Booked' && stages.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '📋 Registration: ',
                    style: GoogleFonts.inter(fontSize: 10, color: AppTheme.statusCalled),
                  ),
                  Expanded(
                    child: Text(
                      lastStageName != null
                          ? '$lastStageName ✓ · $completedStages/${stages.length}'
                          : '0/${stages.length} complete',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.statusCalled),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditUnitSheet(UnitModel u, String towerName) {
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
  }

  void _showChangeStatusSheet(UnitModel u) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Status - ${u.unitNumber}',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.darkText),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.8,
              children: [
                _statusChip(u, 'Available', '✅ Available', AppTheme.success),
                _statusChip(u, 'Booked', '📋 Booked', AppTheme.statusCalled),
                _statusChip(u, 'Hold', '🔒 Hold', AppTheme.accent),
                _statusChip(u, 'Sold', '❌ Sold', AppTheme.mutedText),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(UnitModel u, String status, String label, Color color) {
    final isSelected = u.availabilityStatus == status;
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        await FirestoreService.instance.updateUnit(
          _projectId!,
          u.id,
          {
            'availability_status': status,
            'availabilityStatus': status,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );
        // Initialize registration stages when first set to Booked
        if (status == 'Booked') {
          await FirestoreService.instance.initializeRegistrationStages(
            _projectId!, u.id,
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.success,
              content: Text('Status of ${u.unitNumber} updated to $status'),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(30) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: isSelected ? 2.5 : 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  void _confirmDeleteUnit(UnitModel u) {
    final isBooked = u.availabilityStatus == 'Booked';
    final hasLead = u.bookingLeadId != null && u.bookingLeadId!.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete unit ${u.unitNumber}?', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This cannot be undone.',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText),
            ),
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
              await FirestoreService.instance.deleteUnit(_projectId!, u.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppTheme.success,
                    content: Text('Unit ${u.unitNumber} deleted'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─── Delete Project Confirmation ──────────────────────────────────────────────
  void _confirmDeleteProject(ProjectModel project) {
    final bookedCount = _allUnits.where((u) => u.availabilityStatus == 'Booked').length;
    final totalCount = _allUnits.length;

    showDialog(
      context: context,
      builder: (ctx1) => AlertDialog(
        title: Text('Delete ${project.name}?', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          'All $totalCount unit${totalCount == 1 ? '' : 's'} will also be deleted. This cannot be undone.',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx1),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.mutedText)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx1);
              if (bookedCount > 0) {
                _showSecondDeleteWarning(project, bookedCount);
              } else {
                _executeDeleteProject(project);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showSecondDeleteWarning(ProjectModel project, int bookedCount) {
    showDialog(
      context: context,
      builder: (ctx2) => AlertDialog(
        title: Text('Warning', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.error)),
        content: Text(
          '$bookedCount unit${bookedCount == 1 ? '' : 's'} are booked and linked to leads. Deleting will remove all bookings. Continue?',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx2),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.mutedText)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx2);
              _executeDeleteProject(project);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: Text('Continue', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDeleteProject(ProjectModel project) async {
    try {
      await FirestoreService.instance.deleteProjectWithChildren(_projectId!);
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.inventoryScreen, (r) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text('Project "${project.name}" deleted',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.error, content: Text('Error: $e')),
        );
      }
    }
  }

  // ─── Add Unit Bottom Sheet ───────────────────────────────────────────────────
  void _showAddUnitSheet(ProjectModel project) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddUnitSheet(
        projectId: _projectId!,
        towers: _towers,
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

/// Collapsible "About this Project" section.
class _AboutProjectSection extends StatefulWidget {
  final String description;
  const _AboutProjectSection({required this.description});

  @override
  State<_AboutProjectSection> createState() => _AboutProjectSectionState();
}

class _AboutProjectSectionState extends State<_AboutProjectSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'About this Project',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.darkText),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppTheme.mutedText,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                widget.description,
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.darkText, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet for adding a new unit to a project.
class _AddUnitSheet extends StatefulWidget {
  final String projectId;
  final List<TowerModel> towers;
  const _AddUnitSheet({required this.projectId, required this.towers});

  @override
  State<_AddUnitSheet> createState() => _AddUnitSheetState();
}

class _AddUnitSheetState extends State<_AddUnitSheet> {
  final _flatNoCtrl = TextEditingController();
  final _sbaCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  int _floor = 1;
  String _bhkType = '3BHK';
  String _facing = 'East';
  int _bedrooms = 2;
  int _bathrooms = 2;
  String _furnishing = 'Unfurnished';
  String _carParking = 'None';
  String _status = 'Available';
  String _unitType = 'Fresh';
  String? _towerId;
  bool _isSaving = false;

  // Resale fields
  final _ownerNameCtrl = TextEditingController();
  final _ownerPhoneCtrl = TextEditingController();
  final _ownerAskingPriceCtrl = TextEditingController();
  final _listedPriceCtrl = TextEditingController();
  final _ownerNotesCtrl = TextEditingController();

  // Rental fields
  final _landlordNameCtrl = TextEditingController();
  final _landlordPhoneCtrl = TextEditingController();
  final _monthlyRentCtrl = TextEditingController();
  final _securityDepositCtrl = TextEditingController();
  final _landlordNotesCtrl = TextEditingController();
  DateTime? _availableFrom;

  @override
  void dispose() {
    _flatNoCtrl.dispose();
    _sbaCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
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
    super.dispose();
  }

  Future<void> _save() async {
    if (_flatNoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppTheme.error, content: Text('Flat No. is required', style: GoogleFonts.inter(color: Colors.white))),
      );
      return;
    }
    if (_priceCtrl.text.trim().isEmpty && _unitType != 'Rental') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppTheme.error, content: Text('Price is required', style: GoogleFonts.inter(color: Colors.white))),
      );
      return;
    }
    // Tower validation: require selection when towers exist
    if (widget.towers.isNotEmpty && _towerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppTheme.error, content: Text('Please select a Tower / Block', style: GoogleFonts.inter(color: Colors.white))),
      );
      return;
    }
    // Resale validation
    if (_unitType == 'Resale') {
      if (_ownerNameCtrl.text.trim().isEmpty || _ownerPhoneCtrl.text.trim().isEmpty || _ownerAskingPriceCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.error, content: Text('Owner Name, Phone, and Asking Price are required for Resale', style: GoogleFonts.inter(color: Colors.white))),
        );
        return;
      }
    }
    // Rental validation
    if (_unitType == 'Rental') {
      if (_landlordNameCtrl.text.trim().isEmpty || _landlordPhoneCtrl.text.trim().isEmpty || _monthlyRentCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.error, content: Text('Landlord Name, Phone, and Monthly Rent are required for Rental', style: GoogleFonts.inter(color: Colors.white))),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now().toIso8601String();
      final sba = double.tryParse(_sbaCtrl.text.trim()) ?? 0.0;
      final totalPrice = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
      final unit = UnitModel(
        id: '',
        projectId: widget.projectId,
        towerId: _towerId,
        unitNumber: _flatNoCtrl.text.trim(),
        floorNumber: _floor,
        bhkType: _bhkType,
        facing: _facing,
        superBuiltupArea: sba,
        bedrooms: _bedrooms,
        bathrooms: _bathrooms,
        basePricePerSqft: sba > 0 ? totalPrice / sba : 0,
        totalPrice: totalPrice,
        furnishing: _furnishing,
        carParking: _carParking,
        availabilityStatus: _status,
        unitType: _unitType,
        notes: _notesCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
        // Resale
        ownerName: _unitType == 'Resale' ? _ownerNameCtrl.text.trim() : '',
        ownerPhone: _unitType == 'Resale' ? _ownerPhoneCtrl.text.trim() : '',
        ownerAskingPrice: _unitType == 'Resale' ? (double.tryParse(_ownerAskingPriceCtrl.text.trim()) ?? 0.0) : 0.0,
        listedPrice: _unitType == 'Resale' ? (double.tryParse(_listedPriceCtrl.text.trim()) ?? 0.0) : 0.0,
        ownerNotes: _unitType == 'Resale' ? _ownerNotesCtrl.text.trim() : '',
        // Rental
        landlordName: _unitType == 'Rental' ? _landlordNameCtrl.text.trim() : '',
        landlordPhone: _unitType == 'Rental' ? _landlordPhoneCtrl.text.trim() : '',
        monthlyRent: _unitType == 'Rental' ? (double.tryParse(_monthlyRentCtrl.text.trim()) ?? 0.0) : 0.0,
        securityDeposit: _unitType == 'Rental' ? (double.tryParse(_securityDepositCtrl.text.trim()) ?? 0.0) : 0.0,
        availableFrom: _unitType == 'Rental' && _availableFrom != null ? _availableFrom!.toIso8601String() : '',
        landlordNotes: _unitType == 'Rental' ? _landlordNotesCtrl.text.trim() : '',
      );
      final unitId = await FirestoreService.instance.addUnit(widget.projectId, unit);
      // Initialize registration stages if adding as Booked
      if (_status == 'Booked') {
        await FirestoreService.instance.initializeRegistrationStages(widget.projectId, unitId);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text('Unit ${_flatNoCtrl.text.trim()} added',
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

  @override
  Widget build(BuildContext context) {
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
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.borderColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Add New Unit', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.darkText)),
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

            // Flat No + Floor
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _flatNoCtrl,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: _inputDec('Flat No. *'),
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
            const SizedBox(height: 12),
            // BHK + Facing
            Row(
              children: [
                Expanded(
                  child: _miniDropdown('BHK Type', _bhkType, UnitModel.bhkTypes, (v) => setState(() => _bhkType = v!)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _miniDropdown('Main Door Facing', _facing, UnitModel.facings, (v) => setState(() => _facing = v!)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // SBA
            TextFormField(
              controller: _sbaCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: _inputDec('SBA in SqFt'),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            // Tower + Unit Status (always show tower when towers exist)
            Row(
              children: [
                if (widget.towers.isNotEmpty) ...[
                  Expanded(
                    child: _miniDropdownNullable(
                      'Select Tower... *',
                      _towerId,
                      widget.towers.map((t) => t.id).toList(),
                      (v) => setState(() => _towerId = v),
                      displayMap: {for (var t in widget.towers) t.id: t.towerName},
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _miniDropdown(
                    'Unit Status',
                    _status,
                    UnitModel.availabilityStatuses,
                    (v) => setState(() => _status = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Total Price
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: _inputDec(_unitType == 'Rental' ? 'Total Price (₹)' : 'Total Price (₹) *'),
            ),
            const SizedBox(height: 12),

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
                decoration: _inputDec('Owner Name *'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ownerPhoneCtrl,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: _inputDec('Owner Phone *'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ownerAskingPriceCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: _inputDec('Owner Asking Price (₹) *'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _listedPriceCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: _inputDec('Our Listed Price (₹)'),
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
                  hintText: 'Flexibility, urgency, reason for selling...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText),
                ),
              ),
              const SizedBox(height: 12),
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
                decoration: _inputDec('Landlord Name *'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _landlordPhoneCtrl,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: _inputDec('Landlord Phone *'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _monthlyRentCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: _inputDec('Monthly Rent (₹) *'),
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
              // Available From date picker
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
              const SizedBox(height: 12),
            ],

            // Notes
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: _inputDec('Notes (optional)'),
            ),
            const SizedBox(height: 20),
            // Save
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Add Unit', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label) {
    return InputDecoration(
      labelText: label,
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

  Widget _miniDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged, {Map<String, String>? displayMap}) {
    return DropdownButtonFormField<String>(
      value: (value != null && items.contains(value)) ? value : null,
      hint: Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText)),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(displayMap?[i] ?? i, style: GoogleFonts.inter(fontSize: 12)))).toList(),
      onChanged: onChanged,
      isExpanded: true,
      decoration: _inputDec(label),
    );
  }

  /// Dropdown that starts with null (no default selected), for tower selection.
  Widget _miniDropdownNullable(String placeholder, String? value, List<String> items, ValueChanged<String?> onChanged, {Map<String, String>? displayMap}) {
    return DropdownButtonFormField<String>(
      value: (value != null && items.contains(value)) ? value : null,
      hint: Text(placeholder, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText)),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(displayMap?[i] ?? i, style: GoogleFonts.inter(fontSize: 12)))).toList(),
      onChanged: onChanged,
      isExpanded: true,
      decoration: _inputDec('Tower / Block *'),
    );
  }
}
