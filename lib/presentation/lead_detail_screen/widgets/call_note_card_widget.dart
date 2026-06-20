import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Displays a single call note card in the timeline.
class CallNoteCardWidget extends StatelessWidget {
  final Map<String, dynamic> note;

  const CallNoteCardWidget({super.key, required this.note});

  Color _tagColor(String tag) {
    switch (tag) {
      case 'Interested':
        return AppTheme.success;
      case 'Callback':
      case 'Busy / Call Later':
        return AppTheme.statusCalled;
      case 'Site Visit Ready':
        return AppTheme.purple;
      case 'Not Answering':
        return AppTheme.mutedText;
      case 'Not Interested':
      case 'Finalised Elsewhere':
      case 'Location Mismatched':
      case 'Location Mismatch':
      case 'Channel Partner':
        return AppTheme.error;
      case 'Wrong Number':
        return AppTheme.error;
      case 'Postponed Buying':
      case 'Postponed Buying Plan':
        return AppTheme.warning;
      case 'Source Inventory':
        return AppTheme.purple;
      case 'Low Budget':
        return AppTheme.error;
      case 'Site Visit Completed':
        return const Color(0xFF155724);
      case 'Site Visit Missed':
        return const Color(0xFF991B1B);
      case 'Rescheduled':
        return const Color(0xFF7D3C00);
      default:
        return AppTheme.mutedText;
    }
  }

  Color _tagBg(String tag) {
    switch (tag) {
      case 'Interested':
        return AppTheme.successContainer;
      case 'Callback':
      case 'Busy / Call Later':
        return AppTheme.statusCalledBg;
      case 'Site Visit Ready':
        return AppTheme.purpleContainer;
      case 'Not Answering':
        return const Color(0xFFF3F4F6);
      case 'Not Interested':
      case 'Finalised Elsewhere':
      case 'Location Mismatched':
      case 'Location Mismatch':
      case 'Channel Partner':
        return AppTheme.errorContainer;
      case 'Wrong Number':
        return AppTheme.errorContainer;
      case 'Postponed Buying':
      case 'Postponed Buying Plan':
        return AppTheme.warningContainer;
      case 'Source Inventory':
        return AppTheme.purpleContainer;
      case 'Low Budget':
        return AppTheme.errorContainer;
      case 'Site Visit Completed':
        return const Color(0xFFD4EDDA);
      case 'Site Visit Missed':
        return const Color(0xFFFDE8E8);
      case 'Rescheduled':
        return const Color(0xFFFFE8CC);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawTag = note['tag'] as String? ?? '';
    final tag = (rawTag == 'Busy / Call Later') ? 'Callback' : rawTag;
    final text = note['text'] as String? ?? '';
    final createdAt = note['createdAt'] as String? ?? '';
    final followUpDate = note['followUpDate'] as String?;
    final callDuration = note['callDuration'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
          // Header: date + tag
          Row(
            children: [
              CustomIconWidget(
                iconName: 'access_time',
                color: AppTheme.mutedText,
                size: 13,
              ),
              const SizedBox(width: 4),
              Text(
                createdAt,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.mutedText,
                ),
              ),
              const Spacer(),
              if (tag.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _tagBg(tag),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _tagColor(tag),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Note text
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.darkText,
              height: 1.5,
            ),
          ),
          // Footer: follow-up + call duration
          if ((followUpDate != null && followUpDate.isNotEmpty) ||
              (callDuration != null && callDuration.isNotEmpty)) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppTheme.borderColor),
            const SizedBox(height: 8),
            Row(
              children: [
                if (followUpDate != null && followUpDate.isNotEmpty) ...[
                  CustomIconWidget(
                    iconName: 'event',
                    color: AppTheme.primary,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Follow-up: $followUpDate',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
                const Spacer(),
                if (callDuration != null && callDuration.isNotEmpty) ...[
                  CustomIconWidget(
                    iconName: 'timer',
                    color: AppTheme.mutedText,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    callDuration,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
