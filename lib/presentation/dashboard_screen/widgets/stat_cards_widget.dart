import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_icon_widget.dart';

class StatCardsWidget extends StatelessWidget {
  final int callsDoneToday;
  final int callsDoneYesterday;
  final int totalLeads;
  final int newLeadsToday;
  final int activeLeads;
  final int overdueLeads;
  final String avgCallTime;
  final bool hasCalls;

  const StatCardsWidget({
    super.key,
    required this.callsDoneToday,
    required this.callsDoneYesterday,
    required this.totalLeads,
    required this.newLeadsToday,
    required this.activeLeads,
    required this.overdueLeads,
    required this.avgCallTime,
    required this.hasCalls,
  });

  String get _callsTrend {
    final diff = callsDoneToday - callsDoneYesterday;
    if (diff == 0) return 'same as yesterday';
    if (diff > 0) return '+$diff vs yesterday';
    return '$diff vs yesterday';
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    final cards = [
      _StatCard(
        label: 'Calls Done Today',
        value: callsDoneToday.toString(),
        iconName: 'call_made',
        valueColor: AppTheme.accent,
        bgColor: AppTheme.accentContainer,
        iconColor: AppTheme.accent,
        trend: _callsTrend,
        trendPositive: callsDoneToday >= callsDoneYesterday,
      ),
      _StatCard(
        label: 'Total Leads',
        value: totalLeads.toString(),
        iconName: 'people',
        valueColor: AppTheme.primary,
        bgColor: AppTheme.primaryContainer,
        iconColor: AppTheme.primary,
        trend: '$newLeadsToday new today',
        trendPositive: true,
      ),
      _StatCard(
        label: 'Active Leads',
        value: activeLeads.toString(),
        iconName: 'trending_up',
        valueColor: AppTheme.success,
        bgColor: AppTheme.successContainer,
        iconColor: AppTheme.success,
        trend: '$overdueLeads overdue',
        trendPositive: overdueLeads == 0,
      ),
      _StatCard(
        label: 'Avg Call Time',
        value: avgCallTime,
        iconName: 'access_time',
        valueColor: AppTheme.purple,
        bgColor: AppTheme.purpleContainer,
        iconColor: AppTheme.purple,
        trend: hasCalls ? 'from call logs' : 'no calls yet',
        trendPositive: hasCalls,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Overview",
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkText,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.successContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Live',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 12) / 2;
            final cardHeight = isTablet ? (cardWidth / 1.6) : 122.0;
            final childAspectRatio = cardWidth / cardHeight;
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: childAspectRatio,
              children: cards,
            );
          },
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String iconName;
  final Color valueColor;
  final Color bgColor;
  final Color iconColor;
  final String trend;
  final bool trendPositive;

  const _StatCard({
    required this.label,
    required this.value,
    required this.iconName,
    required this.valueColor,
    required this.bgColor,
    required this.iconColor,
    required this.trend,
    required this.trendPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: CustomIconWidget(
                    iconName: iconName,
                    color: iconColor,
                    size: 18,
                  ),
                ),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: trendPositive
                        ? AppTheme.successContainer
                        : AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      trend,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: trendPositive ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
