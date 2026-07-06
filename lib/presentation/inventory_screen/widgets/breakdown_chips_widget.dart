import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

/// Displays a row of chips showing count breakdowns (facing or BHK).
class BreakdownChipsWidget extends StatelessWidget {
  final String title;
  final Map<String, int> breakdown;
  final Color chipColor;

  const BreakdownChipsWidget({
    super.key,
    required this.title,
    required this.breakdown,
    this.chipColor = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    // Only show entries with count > 0
    final filtered = Map.fromEntries(
      breakdown.entries.where((e) => e.value > 0),
    );

    if (filtered.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.mutedText,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: filtered.entries.map((e) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: chipColor.withAlpha(15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: chipColor.withAlpha(50)),
              ),
              child: Text(
                '${e.key}: ${e.value}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: chipColor,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
