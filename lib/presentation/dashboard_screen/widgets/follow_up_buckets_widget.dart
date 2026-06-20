import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_icon_widget.dart';

class FollowUpBucketsWidget extends StatefulWidget {
  final List<Map<String, dynamic>> todayLeads;
  final List<Map<String, dynamic>> tomorrowLeads;
  final List<Map<String, dynamic>> dueLeads;
  final List<Map<String, dynamic>> overdueLeads;
  final void Function(Map<String, dynamic>) onCallNow;

  const FollowUpBucketsWidget({
    super.key,
    required this.todayLeads,
    required this.tomorrowLeads,
    required this.dueLeads,
    required this.overdueLeads,
    required this.onCallNow,
  });

  @override
  State<FollowUpBucketsWidget> createState() => _FollowUpBucketsWidgetState();
}

class _FollowUpBucketsWidgetState extends State<FollowUpBucketsWidget> {
  int _selectedIndex = 2;

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
  final void Function(Map<String, dynamic>) onCallNow;

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
                      onCallNow: () => onCallNow(lead),
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
  final VoidCallback onCallNow;

  const _LeadRow({
    required this.lead,
    required this.color,
    required this.onCallNow,
  });

  @override
  Widget build(BuildContext context) {
    final name = lead['clientName'] as String? ?? '';
    final property = lead['property'] as String? ?? '';
    final tag = lead['lastTag'] as String? ?? '';

    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.leadDetailScreen,
        arguments: lead['id'] as String,
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
                      ],
                    ),
                  ],
                  if (tag.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _TagChip(tag: tag),
                  ],
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
