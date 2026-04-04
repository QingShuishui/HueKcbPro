import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../settings/pages/settings_page.dart';
import '../controllers/schedule_controller.dart';
import '../models/schedule.dart';
import '../widgets/schedule_grid.dart';

final _semesterStartDate = DateTime(2026, 3, 2);
const _dateStripCenterIndex = 1000000;
const _dateTileExtent = 86.0;

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key, this.schedule, this.initialDate});

  final Schedule? schedule;
  final DateTime? initialDate;

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  late final DateTime _today = _normalizeDate(
    widget.initialDate ?? DateTime.now(),
  );
  late DateTime _selectedDate = _today;
  late final ScrollController _dateStripController = ScrollController(
    initialScrollOffset: _dateStripCenterIndex * _dateTileExtent,
  );

  bool _isManualRefreshing = false;
  bool _showRefreshSuccess = false;

  @override
  void initState() {
    super.initState();
    if (widget.schedule == null) {
      Future.microtask(
        () => ref.read(scheduleControllerProvider.notifier).loadSchedule(),
      );
    }
  }

  @override
  void dispose() {
    _dateStripController.dispose();
    super.dispose();
  }

  Future<void> _refreshSchedule() async {
    setState(() {
      _isManualRefreshing = true;
      _showRefreshSuccess = false;
    });
    try {
      await ref.read(scheduleControllerProvider.notifier).manualRefresh();
      if (mounted) {
        setState(() {
          _isManualRefreshing = false;
          _showRefreshSuccess = true;
        });
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          setState(() {
            _showRefreshSuccess = false;
          });
        }
      }
    } finally {
      if (mounted && _isManualRefreshing) {
        setState(() {
          _isManualRefreshing = false;
        });
      }
    }
  }

  Future<void> _jumpToToday() async {
    setState(() {
      _selectedDate = _today;
    });
    if (!_dateStripController.hasClients) {
      return;
    }
    await _dateStripController.animateTo(
      _dateStripCenterIndex * _dateTileExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  int _weekForDate(DateTime date) {
    final normalized = _normalizeDate(date);
    final daysDiff = normalized.difference(_semesterStartDate).inDays;
    if (daysDiff < 0) {
      return 1;
    }
    return (daysDiff ~/ 7) + 1;
  }

  DateTime _dateFromIndex(int index) {
    return _today.add(Duration(days: index - _dateStripCenterIndex));
  }

  static DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _formatRefreshTime(Schedule schedule) {
    final target = schedule.lastSyncedAt ?? schedule.generatedAt;
    final local = target.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '课程表获取时间：$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final scheduleState = widget.schedule == null
        ? ref.watch(scheduleControllerProvider)
        : const AsyncValue<Schedule?>.data(null);
    final authState = ref.watch(authControllerProvider);
    final currentSchedule = widget.schedule ?? scheduleState.valueOrNull;
    final isLoading = widget.schedule == null && scheduleState.isLoading;
    final selectedWeek = _weekForDate(_selectedDate);
    final visibleSchedule = currentSchedule?.filterByWeek(selectedWeek);
    final refreshLabel = currentSchedule == null
        ? null
        : _formatRefreshTime(currentSchedule);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '第$selectedWeek周',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFFF472B6),
              ),
            ),
            if (refreshLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  refreshLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          if (!DateUtils.isSameDay(_selectedDate, _today))
            TextButton(
              onPressed: _jumpToToday,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF9D174D),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('回到今日'),
            ),
          IconButton(
            onPressed: _isManualRefreshing ? null : _refreshSchedule,
            icon: AnimatedRotation(
              turns: _isManualRefreshing ? 1 : 0,
              duration: const Duration(milliseconds: 700),
              child: const Icon(Icons.refresh_rounded),
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    academicUsername: authState.user?.academicUsername ?? '未绑定',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: scheduleState.hasError && currentSchedule == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('课表加载失败'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      ref
                          .read(scheduleControllerProvider.notifier)
                          .loadSchedule();
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : isLoading || currentSchedule == null
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF7FB), Color(0xFFFDFBF7)],
                ),
              ),
              child: RefreshIndicator(
                onRefresh: () => ref
                    .read(scheduleControllerProvider.notifier)
                    .loadSchedule(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
                  children: [
                    _CompactTopBar(
                      selectedDate: _selectedDate,
                      today: _today,
                      controller: _dateStripController,
                      dateAtIndex: _dateFromIndex,
                      onDateTap: (date) {
                        setState(() {
                          _selectedDate = _normalizeDate(date);
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    if (_isManualRefreshing)
                      _InfoBanner(
                        backgroundColor: const Color(0xFFE0F2FE),
                        textColor: const Color(0xFF075985),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '正在同步课表...',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xFF075985),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    if (_showRefreshSuccess)
                      _InfoBanner(
                        backgroundColor: const Color(0xFFDCFCE7),
                        textColor: const Color(0xFF166534),
                        child: Text(
                          '课表已更新',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xFF166534),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ScheduleGrid(schedule: visibleSchedule ?? currentSchedule),
                  ],
                ),
              ),
            ),
    );
  }
}

class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar({
    required this.selectedDate,
    required this.today,
    required this.controller,
    required this.dateAtIndex,
    required this.onDateTap,
  });

  final DateTime selectedDate;
  final DateTime today;
  final ScrollController controller;
  final DateTime Function(int index) dateAtIndex;
  final ValueChanged<DateTime> onDateTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.builder(
        key: const ValueKey('infinite-date-strip'),
        controller: controller,
        scrollDirection: Axis.horizontal,
        itemExtent: _dateTileExtent,
        itemBuilder: (context, index) {
          final date = dateAtIndex(index);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _DateTile(
              key: ValueKey('date-tile-${_formatDateKey(date)}'),
              date: date,
              isToday: DateUtils.isSameDay(date, today),
              isSelected: DateUtils.isSameDay(date, selectedDate),
              onTap: () => onDateTap(date),
            ),
          );
        },
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    super.key,
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected
        ? const Color(0xFFFCE7F3)
        : isToday
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFFFFBF7);
    final borderColor = isSelected
        ? const Color(0xFFF472B6)
        : isToday
        ? const Color(0xFFFDA4AF)
        : const Color(0xFFF3E5F5);
    final titleColor = isSelected || isToday
        ? const Color(0xFF9D174D)
        : const Color(0xFF6B7280);
    final valueColor = isSelected || isToday
        ? const Color(0xFF9D174D)
        : const Color(0xFF374151);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1),
          boxShadow: isSelected || isToday
              ? const [
                  BoxShadow(
                    color: Color(0x22F472B6),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _weekdayLabel(date.weekday),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.month}/${date.day}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                height: 1,
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 18,
              child: isToday
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '今天',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFFBE185D),
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                          height: 1,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

String _weekdayLabel(int weekday) {
  return const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][weekday - 1];
}

String _formatDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.backgroundColor,
    required this.textColor,
    required this.child,
  });

  final Color backgroundColor;
  final Color textColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: textColor),
        child: child,
      ),
    );
  }
}
