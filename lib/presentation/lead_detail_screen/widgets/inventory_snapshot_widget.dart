import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_export.dart';
import '../../../models/project_model.dart';
import '../../../models/unit_model.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_icon_widget.dart';

class InventorySnapshotWidget extends StatefulWidget {
  final String projectName;

  const InventorySnapshotWidget({
    super.key,
    required this.projectName,
  });

  @override
  State<InventorySnapshotWidget> createState() => _InventorySnapshotWidgetState();
}

class _InventorySnapshotWidgetState extends State<InventorySnapshotWidget> {
  ProjectModel? _project;
  List<UnitModel> _units = [];
  bool _isExpanded = false;
  bool _isLoading = true;

  StreamSubscription? _projectSub;
  StreamSubscription? _unitsSub;

  @override
  void initState() {
    super.initState();
    _loadProjectAndUnits();
  }

  @override
  void didUpdateWidget(covariant InventorySnapshotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.projectName != oldWidget.projectName) {
      _loadProjectAndUnits();
    }
  }

  void _loadProjectAndUnits() {
    _projectSub?.cancel();
    _unitsSub?.cancel();
    setState(() {
      _isLoading = true;
      _project = null;
      _units = [];
    });

    if (widget.projectName.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    FirestoreService.instance.getProjectByName(widget.projectName).then((project) {
      if (!mounted) return;
      if (project == null) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _project = project;
      });

      _unitsSub = FirestoreService.instance.streamUnits(project.id).listen((units) {
        if (mounted) {
          setState(() {
            _units = units;
            _isLoading = false;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _projectSub?.cancel();
    _unitsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
          ),
        ),
      );
    }

    if (_project == null) {
      return const SizedBox.shrink();
    }

    final available = _units.where((u) => u.availabilityStatus == 'Available').toList();
    final resaleCount = _units.where((u) => u.availabilityStatus == 'Resale').length;
    final rentalCount = _units.where((u) => u.availabilityStatus == 'Rental').length;

    // Calculate facing breakdown for Available units
    final facingMap = <String, int>{};
    for (final u in available) {
      facingMap[u.facing] = (facingMap[u.facing] ?? 0) + 1;
    }
    final facingString = facingMap.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.key[0]}:${e.value}') // Use abbreviation e.g., E:12, W:9
        .join('  ');

    // Calculate BHK breakdown for Available units
    final bhkMap = <String, int>{};
    for (final u in available) {
      bhkMap[u.bhkType] = (bhkMap[u.bhkType] ?? 0) + 1;
    }
    final bhkString = bhkMap.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.key}:${e.value}')
        .join('  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row (Clickable to Expand/Collapse)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'apartment',
                    color: AppTheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_project!.name} — Availability',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppTheme.mutedText,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          
          if (_isExpanded) ...[
            const Divider(height: 1, color: AppTheme.borderColor),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Availability row
                  Row(
                    children: [
                      _buildCountItem('✅', '${available.length} Available', AppTheme.success),
                      const SizedBox(width: 14),
                      _buildCountItem('🔄', '$resaleCount Resale', AppTheme.warning),
                      const SizedBox(width: 14),
                      _buildCountItem('🏷️', '$rentalCount Rental', AppTheme.purple),
                    ],
                  ),
                  if (facingString.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Facing:  ',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mutedText,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            facingString,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (bhkString.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BHK:      ',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mutedText,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            bhkString,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.borderColor),
                  const SizedBox(height: 4),
                  // Link to view full inventory
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.projectDetailScreen,
                          arguments: {'projectId': _project!.id},
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'View Full Inventory →',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCountItem(String icon, String label, Color color) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
