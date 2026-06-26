import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_icon_widget.dart';
import '../../../utils/tag_colors.dart';

/// Displays a single call note card in the timeline.
class CallNoteCardWidget extends StatelessWidget {
  final Map<String, dynamic> note;

  const CallNoteCardWidget({super.key, required this.note});



  @override
  Widget build(BuildContext context) {
    final rawTag = note['tag'] as String? ?? '';
    final tag = (rawTag == 'Busy / Call Later') ? 'Callback' : rawTag;
    final text = note['text'] as String? ?? '';
    final createdAt = note['createdAt'] as String? ?? '';
    final followUpDate = note['followUpDate'] as String?;
    final followUpDateTime = note['followUpDateTime'] as String?;
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
                Builder(
                  builder: (context) {
                    final colors = getOutcomeTagColor(tag);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.borderColor, width: 1),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textColor,
                        ),
                      ),
                    );
                  },
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
                  Builder(
                    builder: (context) {
                      String label = 'Follow-up: $followUpDate';
                      if (followUpDateTime != null &&
                          followUpDateTime.isNotEmpty &&
                          followUpDateTime != 'none') {
                        try {
                          final dt = DateTime.parse(followUpDateTime).toLocal();
                          final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                          final amPm = dt.hour >= 12 ? 'PM' : 'AM';
                          final minute = dt.minute.toString().padLeft(2, '0');
                          label = 'Follow-up: $followUpDate at $hour:$minute $amPm';
                        } catch (_) {}
                      }
                      return Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      );
                    },
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
