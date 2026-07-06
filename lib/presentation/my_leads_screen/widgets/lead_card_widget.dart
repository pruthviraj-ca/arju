import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_icon_widget.dart';
import '../../../widgets/status_badge_widget.dart';
import '../../../utils/tag_colors.dart';

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

  bool get _isWon {
    final status = (widget.lead['status'] as String? ?? '').toLowerCase();
    return status == 'won';
  }

  bool get _isLost {
    final status = (widget.lead['status'] as String? ?? '').toLowerCase();
    return status == 'lost/dead' || status == 'lost' || status == 'dead';
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F7),
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

  /// Circular green call button (38px), matching Dashboard style.
  Widget _buildCircularCallButton() {
    return GestureDetector(
      onTap: widget.onCallNow,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.success,
          borderRadius: BorderRadius.circular(19),
          boxShadow: [
            BoxShadow(
              color: AppTheme.success.withAlpha(60),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.call, size: 18, color: Colors.white),
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
    final callsCount = lead['callsCount'] as int? ?? 0;
    final statusColor = AppTheme.getStatusColor(status);

    // Determine left border color for won/lost
    Color? leftBorderColor;
    if (_isWon) {
      leftBorderColor = AppTheme.success;
    }

    // Muted opacity for lost leads
    final cardOpacity = _isLost ? 0.75 : 1.0;

    Widget cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Overdue top indicator bar
        if (isOverdueFlag)
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: AppTheme.error,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
          ),

        // ═══ TOP ZONE (Rows 1-3) ═══
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Name, Property+CallCount, Source
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ROW 1: Lead Name
                    Text(
                      lead['clientName'] as String? ?? 'Unknown',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkText,
                        height: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 8),

                    // ROW 2: Property + Call count badge
                    Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'apartment',
                          color: AppTheme.primary.withAlpha(179),
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            lead['property'] as String? ?? '—',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.darkText,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (callsCount > 0) ...[
                          const SizedBox(width: 8),
                          _buildCallCountBadge(callsCount),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),

                    // ROW 3: Lead Source
                    Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'campaign_outlined',
                          color: AppTheme.mutedText,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            (lead['leadSource'] as String? ?? '').isNotEmpty
                                ? (lead['leadSource'] as String? ?? '')
                                : 'Unknown',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.mutedText,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Right: Status + Temp badges, then Call button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // ROW 1-right: Status + Temperature side-by-side
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    children: [
                      StatusBadgeWidget(status: status, fontSize: 10),
                      if (lead['leadTemperature'] != null &&
                          (lead['leadTemperature'] as String? ?? '').isNotEmpty)
                        _buildTemperatureBadge(lead['leadTemperature'] as String? ?? ''),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ROW 2-right: Circular call button
                  _buildCircularCallButton(),
                ],
              ),
            ],
          ),
        ),

        // ═══ DIVIDER ═══
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Container(
            height: 1,
            color: Colors.black.withAlpha(15),
          ),
        ),

        // ═══ BOTTOM ZONE (Rows 4-5) ═══
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ROW 4: Tag + Follow-up date
              if (hasTag || followUpLabel.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: hasNote ? 8 : 0),
                  child: Row(
                    children: [
                      if (hasTag) ...[
                        _OutcomeTagChip(tag: lead['lastTag'] as String? ?? ''),
                        const SizedBox(width: 8),
                      ],
                      if (followUpLabel.isNotEmpty)
                        _buildFollowUpChip(followUpLabel, isOverdueFlag),
                      const Spacer(),
                      if (lead['callDuration'] != null &&
                          (lead['callDuration'] as String? ?? '—') != '—' &&
                          (lead['callDuration'] as String? ?? '').isNotEmpty)
                        Text(
                          lead['callDuration'] as String? ?? '—',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppTheme.mutedText,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),

              // ROW 5: Note preview (quote block style)
              if (hasNote)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border(
                      left: BorderSide(
                        color: statusColor.withAlpha(150),
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'notes',
                        color: AppTheme.mutedText.withAlpha(130),
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          lead['lastNote'] as String? ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFF666666),
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    // Won green left border accent
    if (leftBorderColor != null) {
      cardContent = Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: leftBorderColor, width: 4),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: cardContent,
        ),
      );
    }

    // Lost leads muted opacity
    if (_isLost) {
      cardContent = Opacity(opacity: cardOpacity, child: cardContent);
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: isOverdueFlag
                ? Border.all(color: AppTheme.error.withAlpha(102), width: 1.5)
                : Border.all(color: AppTheme.borderColor.withAlpha(180), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: widget.onView,
              borderRadius: BorderRadius.circular(14),
              splashColor: AppTheme.primary.withAlpha(20),
              highlightColor: AppTheme.primary.withAlpha(10),
              child: cardContent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowUpChip(String label, bool isOverdue) {
    if (isOverdue) {
      // Prominent overdue chip: red background, white text & icon
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 11),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Normal follow-up chip
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: label == 'Today'
            ? AppTheme.accentContainer
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomIconWidget(
            iconName: 'calendar_today',
            color: label == 'Today' ? AppTheme.warning : AppTheme.mutedText,
            size: 10,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: label == 'Today' ? AppTheme.warning : AppTheme.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomeTagChip extends StatelessWidget {
  final String tag;

  const _OutcomeTagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final colors = getOutcomeTagColor(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomIconWidget(iconName: 'label', color: colors.textColor, size: 10),
          const SizedBox(width: 4),
          Text(
            tag,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.textColor,
            ),
          ),
        ],
      ),
    );
  }
}
