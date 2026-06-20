import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_icon_widget.dart';

class LeadSearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;
  final VoidCallback onFilterToggle;
  final bool isFilterExpanded;
  final bool isFilterActive;
  final int activeFiltersCount;

  const LeadSearchBarWidget({
    super.key,
    required this.controller,
    required this.onClear,
    required this.onFilterToggle,
    required this.isFilterExpanded,
    required this.isFilterActive,
    required this.activeFiltersCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor, width: 1),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  CustomIconWidget(
                    iconName: 'search',
                    color: AppTheme.mutedText,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.darkText,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by name, phone, or property...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFFD1D5DB),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  if (controller.text.isNotEmpty) ...[
                    IconButton(
                      onPressed: onClear,
                      icon: CustomIconWidget(
                        iconName: 'clear',
                        color: AppTheme.mutedText,
                        size: 18,
                      ),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onFilterToggle,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isFilterExpanded || isFilterActive)
                        ? AppTheme.success.withAlpha(26)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (isFilterExpanded || isFilterActive)
                          ? AppTheme.success.withAlpha(128)
                          : AppTheme.borderColor,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.filter_list,
                    color: (isFilterExpanded || isFilterActive)
                        ? AppTheme.success
                        : AppTheme.mutedText,
                    size: 22,
                  ),
                ),
                if (activeFiltersCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          '$activeFiltersCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
