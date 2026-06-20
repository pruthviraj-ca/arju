import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class LeadFilterChipsWidget extends StatelessWidget {
  final List<String> statusFilters;
  final List<String> tagFilters;
  final List<String> tempFilters;
  final String selectedStatus;
  final String selectedTag;
  final String selectedTemp;
  final void Function(String) onStatusChanged;
  final void Function(String) onTagChanged;
  final void Function(String) onTempChanged;

  const LeadFilterChipsWidget({
    super.key,
    required this.statusFilters,
    required this.tagFilters,
    required this.tempFilters,
    required this.selectedStatus,
    required this.selectedTag,
    required this.selectedTemp,
    required this.onStatusChanged,
    required this.onTagChanged,
    required this.onTempChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status filter row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 55,
                  child: Text(
                    'Status',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: statusFilters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final filter = statusFilters[idx];
                        final isSelected = filter == selectedStatus;
                        return _FilterChip(
                          label: filter,
                          isSelected: isSelected,
                          onTap: () => onStatusChanged(filter),
                          selectedColor: AppTheme.primary,
                          selectedBg: AppTheme.primaryContainer,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Tag / Outcome filter row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 55,
                  child: Text(
                    'Outcome',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: tagFilters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final tag = tagFilters[idx];
                        final isSelected = tag == selectedTag;
                        final isAll = tag == 'All';
                        return _FilterChip(
                          label: tag,
                          isSelected: isSelected,
                          onTap: () => onTagChanged(tag),
                          selectedColor: isAll ? AppTheme.primary : AppTheme.accent,
                          selectedBg: isAll ? AppTheme.primaryContainer : AppTheme.accentContainer,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Temperature filter row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 55,
                  child: Text(
                    'Temp',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: tempFilters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final temp = tempFilters[idx];
                        final isSelected = temp == selectedTemp;
                        
                        Color bg;
                        Color border;
                        Color text;
                        
                        switch (temp) {
                          case 'Hot':
                            bg = isSelected ? const Color(0xFFD4EDDA) : Colors.white;
                            border = const Color(0xFF28A745);
                            text = isSelected ? const Color(0xFF155724) : const Color(0xFF28A745);
                            break;
                          case 'Warm':
                            bg = isSelected ? const Color(0xFFFFE8CC) : Colors.white;
                            border = const Color(0xFFFD7E14);
                            text = isSelected ? const Color(0xFFD9480F) : const Color(0xFFFD7E14);
                            break;
                          case 'Cold':
                            bg = isSelected ? const Color(0xFFFFFACC) : Colors.white;
                            border = const Color(0xFFFFC107);
                            text = isSelected ? const Color(0xFF856404) : const Color(0xFFFFC107);
                            break;
                          default: // 'All'
                            bg = isSelected ? AppTheme.primaryContainer : Colors.white;
                            border = isSelected ? AppTheme.primary : AppTheme.borderColor;
                            text = isSelected ? AppTheme.primary : AppTheme.mutedText;
                        }
                        
                        return GestureDetector(
                          onTap: () => onTempChanged(temp),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: border,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              temp,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: text,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color selectedBg;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.selectedColor,
    required this.selectedBg,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? selectedColor.withAlpha(128)
                : AppTheme.borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? selectedColor : AppTheme.mutedText,
          ),
        ),
      ),
    );
  }
}
