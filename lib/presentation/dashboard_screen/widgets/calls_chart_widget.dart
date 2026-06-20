import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';

class CallsChartWidget extends StatefulWidget {
  final List<Map<String, dynamic>> callLogs;

  const CallsChartWidget({super.key, required this.callLogs});

  @override
  State<CallsChartWidget> createState() => _CallsChartWidgetState();
}

class _CallsChartWidgetState extends State<CallsChartWidget> {
  int? _touchedIndex;

  DateTime? _dateFromValue(dynamic value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    if (value is String && value.trim().isNotEmpty) {
      try {
        return DateTime.parse(value.replaceFirst(' ', 'T')).toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<Map<String, dynamic>> _generateChartData() {
    final now = DateTime.now();
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    return List.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      final isToday = _isSameDay(date, now);
      final dayLabel = isToday ? 'Today' : weekdays[date.weekday - 1];

      final logsForDay = widget.callLogs.where((log) {
        final createdAt = _dateFromValue(log['createdAt']);
        return createdAt != null && _isSameDay(createdAt, date);
      }).toList();
      final connected = logsForDay.where((log) {
        final duration = log['durationSeconds'];
        return duration is num && duration > 0;
      }).length;

      return {
        'day': dayLabel,
        'calls': logsForDay.length,
        'connected': connected,
      };
    });
  }

  double _maxY(List<Map<String, dynamic>> data) {
    final highest = data.fold<int>(0, (max, item) {
      final calls = item['calls'] as int;
      final connected = item['connected'] as int;
      return [max, calls, connected].reduce((a, b) => a > b ? a : b);
    });
    if (highest <= 5) return 5;
    return ((highest + 4) ~/ 5 * 5).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final data = _generateChartData();
    final maxY = _maxY(data);

    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Calls This Week',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkText,
                ),
              ),
              Row(
                children: [
                  _LegendDot(color: AppTheme.primary, label: 'Total'),
                  const SizedBox(width: 12),
                  _LegendDot(color: AppTheme.success, label: 'Connected'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    setState(() {
                      if (response?.spot != null) {
                        _touchedIndex = response!.spot!.touchedBarGroupIndex;
                      } else {
                        _touchedIndex = null;
                      }
                    });
                  },
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final d = data[groupIndex];
                      return BarTooltipItem(
                        '${d['day']}\n',
                        GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        children: [
                          TextSpan(
                            text: rodIndex == 0
                                ? 'Total: ${d['calls']}'
                                : 'Connected: ${d['connected']}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withAlpha(230),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox();
                        }
                        final isToday = data[idx]['day'] == 'Today';
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            data[idx]['day'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isToday
                                  ? AppTheme.primary
                                  : AppTheme.mutedText,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 10,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox();
                        return Text(
                          value.toInt().toString(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppTheme.mutedText,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY <= 10 ? 2 : 10,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppTheme.borderColor,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: data.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final d = entry.value;
                  final isTouched = idx == _touchedIndex;
                  final isToday = d['day'] == 'Today';
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: (d['calls'] as int).toDouble(),
                        color: isToday
                            ? AppTheme.primary
                            : (isTouched
                                  ? AppTheme.primary
                                  : AppTheme.primary.withAlpha(89)),
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: (d['connected'] as int).toDouble(),
                        color: isToday
                            ? AppTheme.success
                            : (isTouched
                                  ? AppTheme.success
                                  : AppTheme.success.withAlpha(89)),
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                    barsSpace: 3,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText),
        ),
      ],
    );
  }
}
