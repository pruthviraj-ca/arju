import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_icon_widget.dart';
import '../../../widgets/status_badge_widget.dart';

class LeadCardWidget extends StatefulWidget {
  final Map<String, dynamic> lead;
  final int index;
  final VoidCallback onView;
  final VoidCallback onCallNow;

  const LeadCardWidget({
    super.key,
    required this.lead,
    required this.index,
    required this.onView,
    required this.onCallNow,
  });

  @override
  State<LeadCardWidget> createState() => _LeadCardWidgetState();
}

class _LeadCardWidgetState extends State<LeadCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
    // Staggered entrance: delay = index * 50ms, max 400ms
    final delay = Duration(milliseconds: (widget.index * 50).clamp(0, 400));
    Future.delayed(delay, () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  bool get _isClosed {
    final status = (widget.lead['status'] as String? ?? '').toLowerCase();
    final isActive = widget.lead['isActive'] as bool? ?? true;
    return !isActive || status == 'lost/dead' || status == 'lost' || status == 'dead' || status == 'won';
  }

  bool get _isOverdue {
    if (_isClosed) return false;
    final fu = widget.lead['followUpDate'] as String?;
    if (fu == null || fu == 'none' || fu.isEmpty) return false;
    try {
      final date = DateTime.parse(fu);
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      return date.isBefore(todayDate);
    } catch (_) {
      return false;
    }
  }

  String get _followUpLabel {
    if (_isClosed) return '';
    final fu = widget.lead['followUpDate'] as String?;
    if (fu == null || fu == 'none' || fu.isEmpty) return '';
    try {
      final date = DateTime.parse(fu);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = date.difference(today).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Tomorrow';
      if (diff == -1) return 'Yesterday';
      if (diff < 0) return '${diff.abs()}d overdue';
      return _shortDate(date);
    } catch (_) {
      return fu;
    }
  }

  String _shortDate(DateTime dt) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month]} ${dt.day}';
  }

  Widget _buildCallCountBadge(int callsCount) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomIconWidget(
            iconName: 'call_made',
            color: AppTheme.primary,
            size: 10,
          ),
          const SizedBox(width: 3),
          Text(
            '$callsCount calls',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureBadge(String temp) {
    String label;
    Color bg;
    Color text;
    Color border;

    switch (temp) {
      case 'Hot':
        label = '🔥 HOT';
        bg = const Color(0xFFD4EDDA);
        text = const Color(0xFF155724);
        border = const Color(0xFF28A745);
        break;
      case 'Warm':
        label = '🌤 WARM';
        bg = const Color(0xFFFFE8CC);
        text = const Color(0xFF7D3C00);
        border = const Color(0xFFFD7E14);
        break;
      case 'Cold':
        label = '❄️ COLD';
        bg = const Color(0xFFFFFACC);
        text = const Color(0xFF7A6500);
        border = const Color(0xFFFFC107);
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final status = lead['status'] as String? ?? 'new';
    final hasNote = (lead['lastNote'] as String? ?? '').isNotEmpty;
    final hasTag = (lead['lastTag'] as String? ?? '').isNotEmpty;
    final followUpLabel = _followUpLabel;
    final isOverdueFlag = _isOverdue;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isOverdueFlag
                ? Border.all(color: AppTheme.error.withAlpha(102), width: 1.5)
                : Border.all(color: AppTheme.borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overdue indicator bar
              if (isOverdueFlag)
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left side (avatar, name, phone, property)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lead['clientName'] as String? ?? 'Unknown',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.darkText,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Property row
                              Row(
                                children: [
                                  CustomIconWidget(
                                    iconName: 'apartment',
                                    color: AppTheme.primary.withAlpha(179),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      lead['property'] as String? ?? '—',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.darkText,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Right side (status, temperature, call count)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StatusBadgeWidget(status: status),
                            if (lead['leadTemperature'] != null && (lead['leadTemperature'] as String? ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _buildTemperatureBadge(lead['leadTemperature'] as String? ?? ''),
                            ],
                            if (lead['callsCount'] != null && (lead['callsCount'] as int? ?? 0) > 0) ...[
                              const SizedBox(height: 4),
                              _buildCallCountBadge(lead['callsCount'] as int? ?? 0),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Row 3: Tag + Follow-up date
                    Row(
                      children: [
                        if (hasTag) ...[
                          _OutcomeTagChip(tag: lead['lastTag'] as String? ?? ''),
                          const SizedBox(width: 8),
                        ],
                        if (followUpLabel.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isOverdueFlag
                                  ? AppTheme.errorContainer
                                  : followUpLabel == 'Today'
                                      ? AppTheme.accentContainer
                                      : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CustomIconWidget(
                                  iconName: 'calendar_today',
                                  color: isOverdueFlag
                                      ? AppTheme.error
                                      : followUpLabel == 'Today'
                                          ? AppTheme.warning
                                          : AppTheme.mutedText,
                                  size: 10,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  followUpLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isOverdueFlag
                                        ? AppTheme.error
                                        : followUpLabel == 'Today'
                                            ? AppTheme.warning
                                            : AppTheme.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (lead['callDuration'] != null &&
                            (lead['callDuration'] as String? ?? '—') != '—' &&
                            (lead['callDuration'] as String? ?? '').isNotEmpty)
                          Text(
                            lead['callDuration'] as String? ?? '—',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppTheme.mutedText,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (hasNote) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomIconWidget(
                              iconName: 'notes',
                              color: AppTheme.mutedText,
                              size: 13,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(
                              lead['lastNote'] as String? ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.mutedText,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Row 5: Action buttons
                    Row(
                      children: [
                        // Call Now button
                        Expanded(
                          child: GestureDetector(
                            onTap: widget.onCallNow,
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.success,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CustomIconWidget(
                                    iconName: 'call',
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Call Now',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // View button
                        Expanded(
                          child: GestureDetector(
                            onTap: widget.onView,
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.primary.withAlpha(77),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CustomIconWidget(
                                    iconName: 'arrow_forward',
                                    color: AppTheme.primary,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'View Lead',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutcomeTagChip extends StatelessWidget {
  final String tag;

  const _OutcomeTagChip({required this.tag});

  Color get _color {
    switch (tag) {
      case 'Interested':
        return AppTheme.success;
      case 'Callback':
        return AppTheme.accent;
      case 'Site Visit Ready':
        return AppTheme.purple;
      case 'Not Answering':
        return AppTheme.mutedText;
      case 'Not Interested':
        return AppTheme.error;
      case 'Wrong Number':
        return AppTheme.error;
      case 'Busy / Call Later':
        return AppTheme.warning;
      case 'Postponed Buying':
        return AppTheme.warning;
      case 'Source Inventory':
        return AppTheme.purple;
      case 'Low Budget':
        return AppTheme.error;
      default:
        return AppTheme.mutedText;
    }
  }

  Color get _bg {
    switch (tag) {
      case 'Interested':
        return AppTheme.successContainer;
      case 'Callback':
        return AppTheme.accentContainer;
      case 'Site Visit Ready':
        return AppTheme.purpleContainer;
      case 'Not Answering':
        return const Color(0xFFF3F4F6);
      case 'Not Interested':
        return AppTheme.errorContainer;
      case 'Wrong Number':
        return AppTheme.errorContainer;
      case 'Busy / Call Later':
        return AppTheme.warningContainer;
      case 'Postponed Buying':
        return AppTheme.warningContainer;
      case 'Source Inventory':
        return AppTheme.purpleContainer;
      case 'Low Budget':
        return AppTheme.errorContainer;
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withAlpha(77), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomIconWidget(iconName: 'label', color: _color, size: 10),
          const SizedBox(width: 4),
          Text(
            tag,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
