import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/project_model.dart';
import '../../../models/unit_model.dart';
import '../../../widgets/custom_icon_widget.dart';

/// A card displaying a project in the Inventory list with live unit stats.
class ProjectCardWidget extends StatelessWidget {
  final ProjectModel project;
  final List<UnitModel> units;
  final VoidCallback onTap;

  const ProjectCardWidget({
    super.key,
    required this.project,
    required this.units,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final available = units.where((u) => u.unitType == 'Fresh' && u.availabilityStatus == 'Available').length;
    final resale = units.where((u) => u.unitType == 'Resale' && u.availabilityStatus == 'Available').length;
    final rental = units.where((u) => u.unitType == 'Rental' && u.availabilityStatus == 'Available').length;
    final booked = units.where((u) =>
        u.availabilityStatus == 'Booked' || u.availabilityStatus == 'Sold' || u.availabilityStatus == 'Hold').length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
            // Row 1: Name + Type badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.name,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _TypeBadge(type: project.projectType),
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: Location
            Row(
              children: [
                CustomIconWidget(
                  iconName: 'location_on',
                  color: AppTheme.mutedText,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    project.location.isNotEmpty ? project.location : project.city,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.mutedText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Description preview (if exists)
            if (project.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                project.description,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.mutedText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            // Row 3: Towers
            Row(
              children: [
                _StatChip(
                  icon: 'domain',
                  label: '${project.totalTowers} Towers',
                  color: AppTheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 4: Availability stats
            Row(
              children: [
                _MiniStat(label: 'Available', count: available, color: AppTheme.success),
                const SizedBox(width: 10),
                _MiniStat(label: 'Resale', count: resale, color: AppTheme.warning),
                const SizedBox(width: 10),
                _MiniStat(label: 'Rental', count: rental, color: AppTheme.purple),
                const SizedBox(width: 10),
                _MiniStat(label: 'Booked', count: booked, color: AppTheme.statusCalled),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    switch (type.toLowerCase()) {
      case 'apartment':
        bg = AppTheme.primaryContainer;
        text = AppTheme.primary;
        break;
      case 'villa':
        bg = AppTheme.successContainer;
        text = AppTheme.success;
        break;
      case 'plot':
        bg = AppTheme.warningContainer;
        text = AppTheme.warning;
        break;
      case 'commercial':
        bg = AppTheme.purpleContainer;
        text = AppTheme.purple;
        break;
      default:
        bg = AppTheme.primaryContainer;
        text = AppTheme.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        type,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomIconWidget(iconName: icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _MiniStat({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: AppTheme.mutedText,
          ),
        ),
      ],
    );
  }
}
