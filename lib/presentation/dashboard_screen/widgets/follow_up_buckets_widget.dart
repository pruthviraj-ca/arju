import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_icon_widget.dart';
import '../../../utils/lead_source_assets.dart';

class FollowUpBucketsWidget extends StatefulWidget {
  final List<Map<String, dynamic>> todayLeads;
  final List<Map<String, dynamic>> tomorrowLeads;
  final List<Map<String, dynamic>> dueLeads;
  final List<Map<String, dynamic>> overdueLeads;
  final void Function(Map<String, dynamic>, String) onCallNow;
  final String? initialBucket;

  const FollowUpBucketsWidget({
    super.key,
    required this.todayLeads,
    required this.tomorrowLeads,
    required this.dueLeads,
    required this.overdueLeads,
    required this.onCallNow,
    this.initialBucket,
  });

  @override
  State<FollowUpBucketsWidget> createState() => _FollowUpBucketsWidgetState();
}

class _FollowUpBucketsWidgetState extends State<FollowUpBucketsWidget> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _getBucketIndex(widget.initialBucket) ?? 2;
  }

  @override
  void didUpdateWidget(covariant FollowUpBucketsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialBucket != oldWidget.initialBucket && widget.initialBucket != null) {
      final index = _getBucketIndex(widget.initialBucket);
      if (index != null) {
        setState(() {
          _selectedIndex = index;
        });
      }
    }
  }

  int? _getBucketIndex(String? bucket) {
    if (bucket == null) return null;
    switch (bucket.toLowerCase()) {
      case 'overdue':
        return 0;
      case 'due':
        return 1;
      case 'today':
        return 2;
      case 'tomorrow':
        return 3;
      default:
        return null;
    }
  }

  List<_BucketData> get _buckets => [
    _BucketData(
      title: 'Overdue',
      subtitle: '2+ days past follow-up',
      leads: widget.overdueLeads,
      color: AppTheme.error,
      bgColor: AppTheme.errorContainer,
      borderColor: const Color(0xFFFCA5A5),
      iconName: 'warning_amber',
    ),
    _BucketData(
      title: 'Due',
      subtitle: "Yesterday's follow-up",
      leads: widget.dueLeads,
      color: AppTheme.warning,
      bgColor: AppTheme.warningContainer,
      borderColor: const Color(0xFFFCD34D),
      iconName: 'schedule',
    ),
    _BucketData(
      title: 'Today',
      subtitle: 'Scheduled for today',
      leads: widget.todayLeads,
      color: AppTheme.primary,
      bgColor: AppTheme.primaryContainer,
      borderColor: const Color(0xFF93C5FD),
      iconName: 'today',
    ),
    _BucketData(
      title: 'Tomorrow',
      subtitle: 'Upcoming follow-ups',
      leads: widget.tomorrowLeads,
      color: AppTheme.success,
      bgColor: AppTheme.successContainer,
      borderColor: const Color(0xFF6EE7B7),
      iconName: 'event',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final buckets = _buckets;
    final selected = buckets[_selectedIndex];
    final totalOpen = buckets.fold<int>(
      0,
      (sum, item) => sum + item.leads.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Follow-up Buckets',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkText,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: selected.bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selected.borderColor),
              ),
              child: Text(
                '$totalOpen open',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected.color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: buckets.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
          ),
          itemBuilder: (context, index) {
            final bucket = buckets[index];
            return _BucketTile(
              bucket: bucket,
              isSelected: index == _selectedIndex,
              onTap: () => setState(() => _selectedIndex = index),
            );
          },
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
            return Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          child: _BucketPanel(
            key: ValueKey(selected.title),
            bucket: selected,
            onCallNow: widget.onCallNow,
          ),
        ),
      ],
    );
  }
}

class _BucketData {
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> leads;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final String iconName;

  const _BucketData({
    required this.title,
    required this.subtitle,
    required this.leads,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.iconName,
  });
}

class _BucketTile extends StatelessWidget {
  final _BucketData bucket;
  final bool isSelected;
  final VoidCallback onTap;

  const _BucketTile({
    required this.bucket,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? bucket.bgColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? bucket.borderColor : AppTheme.borderColor,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isSelected ? 16 : 8),
                blurRadius: isSelected ? 10 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bucket.bgColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: CustomIconWidget(
                    iconName: bucket.iconName,
                    color: bucket.color,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      bucket.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: bucket.color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      bucket.leads.length == 1
                          ? '1 lead'
                          : '${bucket.leads.length} leads',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected ? bucket.color : bucket.bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '${bucket.leads.length}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : bucket.color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BucketPanel extends StatelessWidget {
  final _BucketData bucket;
  final void Function(Map<String, dynamic>, String) onCallNow;

  const _BucketPanel({
    super.key,
    required this.bucket,
    required this.onCallNow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bucket.borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bucket.bgColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(190),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: CustomIconWidget(
                      iconName: bucket.iconName,
                      color: bucket.color,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bucket.title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bucket.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: bucket.color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${bucket.leads.length}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          bucket.leads.isEmpty
              ? _EmptyBucket(color: bucket.color)
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: bucket.leads.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppTheme.borderColor,
                  ),
                  itemBuilder: (context, index) {
                    final lead = bucket.leads[index];
                    return _LeadRow(
                      lead: lead,
                      color: bucket.color,
                      isToday: bucket.title == 'Today',
                      bucketTitle: bucket.title,
                      onCallNow: () => onCallNow(lead, bucket.title),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

class _LeadRow extends StatelessWidget {
  final Map<String, dynamic> lead;
  final Color color;
  final bool isToday;
  final String bucketTitle;
  final VoidCallback onCallNow;

  const _LeadRow({
    required this.lead,
    required this.color,
    required this.isToday,
    required this.bucketTitle,
    required this.onCallNow,
  });

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'New';
      case 'called':
        return 'Called';
      case 'follow-up':
        return 'Follow-Up';
      case 'site visit':
      case 'site visit scheduled':
      case 'site visit done':
        return 'Site Visit';
      case 'won':
        return 'Won';
      case 'lost/dead':
        return 'Lost/Dead';
      case 'lost':
        return 'Lost';
      case 'dead':
        return 'Dead';
      default:
        if (status.isEmpty) return 'New';
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return const Color(0xFF6B7280);
      case 'called':
        return const Color(0xFF185FA5);
      case 'follow-up':
        return const Color(0xFF7C3AED);
      case 'site visit':
      case 'site visit scheduled':
      case 'site visit done':
        return const Color(0xFF6A4FB5);
      case 'won':
        return const Color(0xFF28A745);
      case 'lost/dead':
      case 'lost':
      case 'dead':
        return const Color(0xFFE05252);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return const Color(0xFFF3F4F6);
      case 'called':
        return const Color(0xFFE8F1FA);
      case 'follow-up':
        return const Color(0xFFF3E8FF);
      case 'site visit':
      case 'site visit scheduled':
      case 'site visit done':
        return const Color(0xFFF0ECFC);
      case 'won':
        return const Color(0xFFE8F5E9);
      case 'lost/dead':
      case 'lost':
      case 'dead':
        return const Color(0xFFFFEBEE);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getStatusBorderColor(String status, Color textColor) {
    switch (status.toLowerCase()) {
      case 'new':
        return const Color(0xFFD1D5DB);
      default:
        return textColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = lead['clientName'] as String? ?? '';
    final property = lead['property'] as String? ?? '';
    final tag = lead['lastTag'] as String? ?? '';
    final leadSource = lead['leadSource'] as String? ?? '';

    Widget? leadSourceWidget;
    if (leadSource.isNotEmpty) {
      leadSourceWidget = LeadSourceIconBadge(leadSource: leadSource);
    }

    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.leadDetailScreen,
        arguments: {
          'leadId': lead['id'] as String,
          'returnTo': 'Dashboard',
          'returnBucket': bucketTitle,
        },
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkText,
                    ),
                  ),
                  if (property.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'apartment',
                          color: AppTheme.mutedText,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: AppTheme.mutedText,
                            ),
                          ),
                        ),
                        if (leadSourceWidget != null) ...[
                          const SizedBox(width: 6),
                          leadSourceWidget,
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final status = lead['status'] as String? ?? 'New';
                      final displayStatus = _formatStatus(status);
                      final statusColor = _getStatusTextColor(status);
                      final statusBg = _getStatusBgColor(status);
                      final statusBorder = _getStatusBorderColor(status, statusColor);

                      final statusWidget = Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: statusBorder, width: 1),
                        ),
                        child: Text(
                          displayStatus,
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      );

                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          statusWidget,
                          if (tag.isNotEmpty) _TagChip(tag: tag),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onCallNow,
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                fixedSize: const Size(38, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.call_rounded, size: 17),
              tooltip: 'Call',
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBucket extends StatelessWidget {
  final Color color;

  const _EmptyBucket({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withAlpha(22),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.check_rounded, color: color, size: 30),
            ),
            const SizedBox(height: 14),
            Text(
              'All clear',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No leads in this bucket',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;

  const _TagChip({required this.tag});

  Color get _color {
    switch (tag) {
      case 'Interested':
        return AppTheme.success;
      case 'Callback':
        return AppTheme.statusCalled;
      case 'Site Visit Ready':
        return AppTheme.purple;
      case 'Not Interested':
      case 'Wrong Number':
        return AppTheme.error;
      case 'Busy / Call Later':
        return AppTheme.warning;
      default:
        return AppTheme.mutedText;
    }
  }

  Color get _bg {
    switch (tag) {
      case 'Interested':
        return AppTheme.successContainer;
      case 'Callback':
        return AppTheme.statusCalledBg;
      case 'Site Visit Ready':
        return AppTheme.purpleContainer;
      case 'Not Interested':
      case 'Wrong Number':
        return AppTheme.errorContainer;
      case 'Busy / Call Later':
        return AppTheme.warningContainer;
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
      ),
      child: Text(
        tag,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _color,
        ),
      ),
    );
  }
}

class LeadSourceIconBadge extends StatelessWidget {
  final String leadSource;

  const LeadSourceIconBadge({
    super.key,
    required this.leadSource,
  });

  @override
  Widget build(BuildContext context) {
    if (leadSource.isEmpty) return const SizedBox.shrink();

    final sourceData = sourceIconMap[leadSource];
    if (sourceData == null) return const SizedBox.shrink();

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: sourceData.color.withAlpha(25),
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: Icon(
        sourceData.icon,
        color: sourceData.color,
        size: 11,
      ),
    );
  }
}
