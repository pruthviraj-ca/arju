import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Representation of visual style tokens for pipeline and call tags.
class TagColor {
  final Color textColor;
  final Color bgColor;
  final Color borderColor;

  const TagColor({
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
  });
}

/// Retrieves color styling for pipeline statuses, matching the definitions in [AppTheme] / My Leads badge styles.
TagColor getStatusTagColor(String status) {
  final cleanStatus = status.toLowerCase().trim();
  final textColor = AppTheme.getStatusColor(cleanStatus);
  final bgColor = AppTheme.getStatusBgColor(cleanStatus);
  final borderColor = textColor.withAlpha(77);
  return TagColor(
    textColor: textColor,
    bgColor: bgColor,
    borderColor: borderColor,
  );
}

/// Retrieves color styling for call outcome tags, matching the switch-case definitions in My Leads tag chips.
TagColor getOutcomeTagColor(String tag) {
  final cleanTag = tag.trim();
  Color color;
  Color bg;

  switch (cleanTag) {
    // GREEN
    case 'Interested':
    case 'Booked':
    case 'Prospect':
    case 'Site Visit Completed':
      color = AppTheme.success;
      bg = AppTheme.successContainer;
      break;

    // GREY
    case 'Not Answering':
      color = AppTheme.mutedText;
      bg = const Color(0xFFF3F4F6);
      break;

    // BLUE
    case 'Callback':
    case 'Busy / Call Later':
      color = const Color(0xFF185FA5);
      bg = const Color(0xFFE6F1FB);
      break;

    // PURPLE
    case 'Site Visit Ready':
    case 'Site Visit Scheduled':
    case 'Source Inventory':
      color = AppTheme.purple;
      bg = AppTheme.purpleContainer;
      break;

    // ORANGE / WARNING
    case 'Postponed Buying':
    case 'Postponed Buying Plan':
    case 'Rescheduled':
      color = AppTheme.warning;
      bg = AppTheme.warningContainer;
      break;

    // RED / ERROR
    case 'Not Interested':
    case 'Not Responding':
    case 'Wrong Number':
    case 'Low Budget':
    case 'Channel Partner':
    case 'Closed with Colleague':
    case 'Dropped Buying Plans':
    case 'Finalised Elsewhere':
    case 'Location Mismatch':
    case 'Location Mismatched':
    case 'Site Visit Missed':
      color = AppTheme.error;
      bg = AppTheme.errorContainer;
      break;

    // Status Log Accents
    case 'Status: New':
      color = AppTheme.statusNew;
      bg = AppTheme.statusNewBg;
      break;
    case 'Status: Called':
      color = AppTheme.statusCalled;
      bg = AppTheme.statusCalledBg;
      break;
    case 'Status: Follow-Up':
      color = AppTheme.statusFollowUp;
      bg = AppTheme.statusFollowUpBg;
      break;
    case 'Status: Won':
      color = AppTheme.statusWon;
      bg = AppTheme.statusWonBg;
      break;
    case 'Status: Lost/Dead':
      color = AppTheme.statusLost;
      bg = AppTheme.statusLostBg;
      break;
    case 'Status Changed':
      color = AppTheme.primary;
      bg = AppTheme.primaryContainer;
      break;

    // Temperature Changed Log Accents
    case 'Temp: Cold':
      color = const Color(0xFF7A6500);
      bg = const Color(0xFFFFFACC);
      break;
    case 'Temp: Warm':
      color = const Color(0xFF7D3C00);
      bg = const Color(0xFFFFE8CC);
      break;
    case 'Temp: Hot':
      color = const Color(0xFF155724);
      bg = const Color(0xFFD4EDDA);
      break;
    case 'Temp: Cleared':
      color = AppTheme.mutedText;
      bg = const Color(0xFFF3F4F6);
      break;

    default:
      color = AppTheme.mutedText;
      bg = const Color(0xFFF3F4F6);
  }

  return TagColor(
    textColor: color,
    bgColor: bg,
    borderColor: color.withAlpha(77),
  );
}
