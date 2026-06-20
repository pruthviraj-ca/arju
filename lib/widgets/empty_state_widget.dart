/// empty_state_widget.dart
///
/// Reusable empty-state placeholder displayed when a list or screen
/// has no content to show. Supports an optional action button to
/// guide the user towards a next step (e.g., importing leads).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import './custom_icon_widget.dart';

/// Centered empty-state widget with an icon, title, description, and
/// an optional call-to-action button.
///
/// Use this whenever a list or content area has zero items to display.
class EmptyStateWidget extends StatelessWidget {
  /// Material icon name to display in the circular icon container.
  final String iconName;

  /// Bold headline text shown below the icon.
  final String title;

  /// Supporting description text shown below the title.
  final String description;

  /// Label for the optional action button. If `null`, no button is shown.
  final String? actionLabel;

  /// Callback invoked when the action button is tapped.
  /// Required if [actionLabel] is provided.
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.iconName,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIconContainer(),
            const SizedBox(height: 20),
            _buildTitle(),
            const SizedBox(height: 8),
            _buildDescription(),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              _buildActionButton(),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the circular icon container in the primary color.
  Widget _buildIconContainer() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Center(
        child: CustomIconWidget(
          iconName: iconName,
          color: AppTheme.primary,
          size: 40,
        ),
      ),
    );
  }

  /// Builds the bold headline text.
  Widget _buildTitle() {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppTheme.darkText,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Builds the supporting description text.
  Widget _buildDescription() {
    return Text(
      description,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppTheme.mutedText,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Builds the optional call-to-action button.
  Widget _buildActionButton() {
    return ElevatedButton.icon(
      onPressed: onAction,
      icon: CustomIconWidget(
        iconName: 'add',
        color: Colors.white,
        size: 18,
      ),
      label: Text(actionLabel!),
    );
  }
}
