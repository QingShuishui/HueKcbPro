import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/schedule.dart';

const _scheduleWeekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
const _scheduleWeekdayShortLabels = [
  'MON',
  'TUE',
  'WED',
  'THU',
  'FRI',
  'SAT',
  'SUN',
];
const _courseDisplayNameAliases = {
  '毛泽东思想和中国特色社会主义理论体系概论': '毛概',
  '习近平新时代中国特色社会主义思想概论': '习思想',
};

String _displayCourseName(String name) {
  return _courseDisplayNameAliases[name] ?? name;
}

class ScheduleGrid extends StatelessWidget {
  const ScheduleGrid({
    super.key,
    required this.schedule,
    required this.weekStartDate,
    this.borderRadius = 0,
  });

  final Schedule schedule;
  final DateTime weekStartDate;
  final double borderRadius;

  static const _lessonLabels = [
    '1-2节',
    '3-4节',
    '5-6节',
    '7-8节',
    '9-10节',
    '11-12节',
  ];
  static const _lessonTimeRanges = [
    '08:00-09:40',
    '10:00-11:40',
    '14:00-15:40',
    '16:00-17:40',
    '18:30-20:10',
    '20:20-21:05',
  ];
  static const _lessonPeriods = ['上午', '上午', '下午', '下午', '晚上', '晚上'];

  Color _cardColor(int index) {
    const palette = [
      Color(0xFFFEE2E2),
      Color(0xFFE0F2FE),
      Color(0xFFFEF3C7),
      Color(0xFFF3E8FF),
      Color(0xFFDCFCE7),
      Color(0xFFFFEDD5),
    ];
    return palette[index % palette.length];
  }

  List<Course> _coursesForCell(int weekday, int lessonStart) {
    return schedule.courses
        .where(
          (course) =>
              course.weekday == weekday && course.lessonStart == lessonStart,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = _ResponsiveScheduleMetrics.fromConstraints(
              constraints.maxWidth,
              constraints.maxHeight,
            );

            return Column(
              children: [
                _HeaderRow(metrics: metrics, weekStartDate: weekStartDate),
                for (
                  var rowIndex = 0;
                  rowIndex < _lessonLabels.length;
                  rowIndex++
                )
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TimeCell(
                          label: _lessonLabels[rowIndex],
                          periodLabel: _lessonPeriods[rowIndex],
                          timeRange: _lessonTimeRanges[rowIndex],
                          metrics: metrics,
                        ),
                        for (var weekday = 1; weekday <= 7; weekday++)
                          Expanded(
                            child: _CourseCell(
                              courses: _coursesForCell(
                                weekday,
                                rowIndex * 2 + 1,
                              ),
                              cardColor: _cardColor(weekday + rowIndex),
                              metrics: metrics,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    super.key,
    required this.child,
    required this.height,
    this.backgroundColor = const Color(0xFFFFF1F2),
    this.borderSide = const BorderSide(color: Color(0xFFF3E5F5), width: 0.8),
  });

  final Widget child;
  final double height;
  final Color backgroundColor;
  final BorderSide borderSide;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(right: borderSide, bottom: borderSide),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: child,
        ),
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.label,
    required this.periodLabel,
    required this.timeRange,
    required this.metrics,
  });

  final String label;
  final String periodLabel;
  final String timeRange;
  final _ResponsiveScheduleMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final rangeParts = timeRange.split('-');
    return Container(
      width: metrics.timeColumnWidth,
      constraints: BoxConstraints(minHeight: metrics.minCellHeight),
      padding: EdgeInsets.symmetric(
        horizontal: metrics.innerPadding / 2,
        vertical: metrics.innerPadding,
      ),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBF7),
        border: Border(
          right: BorderSide(color: Color(0xFFF3E5F5), width: 0.8),
          bottom: BorderSide(color: Color(0xFFF3E5F5), width: 0.8),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF9CA3AF),
              fontSize: metrics.timeFontSize,
              height: 1.15,
            ),
          ),
          SizedBox(height: metrics.detailGap),
          Text(
            periodLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w700,
              fontSize: metrics.courseDetailSize,
              height: 1.05,
            ),
          ),
          SizedBox(height: metrics.detailGap),
          Text(
            rangeParts.join('\n'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w600,
              fontSize: metrics.courseDetailSize,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCell extends StatelessWidget {
  const _CourseCell({
    required this.courses,
    required this.cardColor,
    required this.metrics,
  });

  final List<Course> courses;
  final Color cardColor;
  final _ResponsiveScheduleMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cardMargin = metrics.gap / 2;

    if (courses.isEmpty) {
      return Container(
        constraints: BoxConstraints(minHeight: metrics.minCellHeight),
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: Color(0xFFF3E5F5), width: 0.8),
            bottom: BorderSide(color: Color(0xFFF3E5F5), width: 0.8),
          ),
        ),
        child: Container(
          margin: EdgeInsets.all(cardMargin),
          decoration: BoxDecoration(
            color: const Color(0xFFFCFCFD),
            borderRadius: BorderRadius.circular(metrics.cardRadius),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
        ),
      );
    }

    final combinedNames = courses
        .map((course) => _displayCourseName(course.name))
        .join(' / ');
    final combinedCodes = courses
        .map((course) => course.code)
        .where((code) => code.isNotEmpty)
        .join(' / ');
    final combinedRooms = courses
        .map((course) => course.room)
        .where((room) => room.isNotEmpty)
        .join(' / ');
    return Container(
      constraints: BoxConstraints(minHeight: metrics.minCellHeight),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Color(0xFFF3E5F5), width: 0.8),
          bottom: BorderSide(color: Color(0xFFF3E5F5), width: 0.8),
        ),
      ),
      child: Container(
        margin: EdgeInsets.all(cardMargin),
        padding: EdgeInsets.all(metrics.innerPadding),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(metrics.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              combinedNames,
              maxLines: null,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF374151),
                fontSize: courses.length > 1
                    ? metrics.courseTitleSize - 0.5
                    : metrics.courseTitleSize,
                height: 1.1,
              ),
            ),
            if (combinedCodes.isNotEmpty) ...[
              SizedBox(height: metrics.detailGap),
              Text(
                combinedCodes,
                maxLines: null,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF7C3AED),
                  fontWeight: FontWeight.w700,
                  fontSize: metrics.courseDetailSize,
                  height: 1.05,
                ),
              ),
            ],
            SizedBox(height: metrics.detailGap),
            Text(
              combinedRooms,
              maxLines: null,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
                fontSize: metrics.courseDetailSize,
                height: 1.05,
              ),
            ),
            if (courses.length == 1 &&
                courses.first.teacher.isNotEmpty &&
                metrics.showTeacherChip) ...[
              SizedBox(height: metrics.detailGap),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.teacherHorizontalPadding,
                    vertical: metrics.teacherVerticalPadding,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    courses.first.teacher,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                      fontSize: metrics.teacherSize,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.metrics, required this.weekStartDate});

  final _ResponsiveScheduleMetrics metrics;
  final DateTime weekStartDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();

    return Row(
      children: [
        SizedBox(
          width: metrics.timeColumnWidth,
          child: _HeaderCell(
            height: metrics.headerHeight,
            child: Text(
              '时间',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF6B7280),
                fontSize: metrics.headerTitleSize,
              ),
            ),
          ),
        ),
        for (var index = 0; index < _scheduleWeekdayLabels.length; index++)
          Expanded(
            child: Builder(
              builder: (context) {
                final date = weekStartDate.add(Duration(days: index));
                final isToday = DateUtils.isSameDay(date, today);
                final content = Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _scheduleWeekdayShortLabels[index],
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isToday
                            ? const Color(0xFFFFF7FB)
                            : const Color(0xFFF472B6),
                        fontSize: metrics.headerMetaSize,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _scheduleWeekdayLabels[index],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isToday
                            ? Colors.white
                            : const Color(0xFF4B5563),
                        fontSize: metrics.headerTitleSize,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${date.month}/${date.day}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isToday
                            ? const Color(0xFFFFE4F1)
                            : const Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w700,
                        fontSize: metrics.headerMetaSize,
                        height: 1,
                      ),
                    ),
                  ],
                );

                return _HeaderCell(
                  key: ValueKey('weekday-header-${index + 1}'),
                  height: metrics.headerHeight,
                  child: isToday
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: DecoratedBox(
                            key: ValueKey('weekday-highlight-${index + 1}'),
                            decoration: BoxDecoration(
                              color: const Color(0xFFBE185D),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22BE185D),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(child: content),
                          ),
                        )
                      : content,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ResponsiveScheduleMetrics {
  const _ResponsiveScheduleMetrics({
    required this.timeColumnWidth,
    required this.dayColumnWidth,
    required this.headerHeight,
    required this.minCellHeight,
    required this.cardRadius,
    required this.innerPadding,
    required this.gap,
    required this.headerMetaSize,
    required this.headerTitleSize,
    required this.timeFontSize,
    required this.courseTitleSize,
    required this.courseDetailSize,
    required this.teacherSize,
    required this.teacherHorizontalPadding,
    required this.teacherVerticalPadding,
    required this.detailGap,
    required this.showTeacherChip,
  });

  final double timeColumnWidth;
  final double dayColumnWidth;
  final double headerHeight;
  final double minCellHeight;
  final double cardRadius;
  final double innerPadding;
  final double gap;
  final double headerMetaSize;
  final double headerTitleSize;
  final double timeFontSize;
  final double courseTitleSize;
  final double courseDetailSize;
  final double teacherSize;
  final double teacherHorizontalPadding;
  final double teacherVerticalPadding;
  final double detailGap;
  final bool showTeacherChip;

  factory _ResponsiveScheduleMetrics.fromConstraints(
    double width,
    double maxHeight,
  ) {
    final clampedWidth = width.isFinite ? width.clamp(300.0, 720.0) : 360.0;
    final timeColumnWidth = (clampedWidth * 0.13).clamp(40.0, 58.0);
    final dayColumnWidth = (clampedWidth - timeColumnWidth) / 7;
    final compact = dayColumnWidth < 46;
    final extraCompact = dayColumnWidth < 42;
    final baseHeaderHeight = compact ? 50.0 : 56.0;
    final baseCellHeight = compact ? 82.0 : 92.0;
    final fittedMinCellHeight = maxHeight.isFinite
        ? ((maxHeight - baseHeaderHeight) / ScheduleGrid._lessonLabels.length)
              .clamp(70.0, baseCellHeight)
        : baseCellHeight;
    final fittedHeaderHeight = maxHeight.isFinite
        ? (maxHeight - fittedMinCellHeight * ScheduleGrid._lessonLabels.length)
              .clamp(40.0, baseHeaderHeight)
        : baseHeaderHeight;

    return _ResponsiveScheduleMetrics(
      timeColumnWidth: timeColumnWidth,
      dayColumnWidth: dayColumnWidth,
      headerHeight: fittedHeaderHeight,
      minCellHeight: fittedMinCellHeight,
      cardRadius: compact ? 12 : 16,
      innerPadding: compact ? 5 : 7,
      gap: compact ? 4 : 6,
      headerMetaSize: compact ? 8 : 9,
      headerTitleSize: compact ? 11 : 12,
      timeFontSize: compact ? 10 : 11,
      courseTitleSize: compact ? 10 : 11,
      courseDetailSize: compact ? 8 : 9,
      teacherSize: compact ? 7 : 8,
      teacherHorizontalPadding: compact ? 4 : 5,
      teacherVerticalPadding: compact ? 1 : 2,
      detailGap: compact ? 2 : 3,
      showTeacherChip: !extraCompact,
    );
  }
}
