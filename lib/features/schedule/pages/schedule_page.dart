import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/refresh_policy.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../settings/pages/settings_page.dart';
import '../controllers/schedule_controller.dart';
import '../models/schedule.dart';
import '../widgets/schedule_grid.dart';

final _semesterStartDate = DateTime(2026, 3, 2);
const _weekTileExtent = 132.0;
const _minWeek = 1;
const _maxWeek = 18;

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key, this.schedule, this.initialDate});

  final Schedule? schedule;
  final DateTime? initialDate;

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage>
    with WidgetsBindingObserver {
  late final DateTime _today = _normalizeDate(
    widget.initialDate ?? DateTime.now(),
  );
  late int _selectedWeek = _weekForDate(_today);
  late final ScrollController _weekStripController = ScrollController(
    initialScrollOffset: (_selectedWeek - 1) * _weekTileExtent,
  );
  late final PageController _pageController = PageController(
    initialPage: _selectedWeek - 1,
  );

  bool _isManualRefreshing = false;
  bool _showRefreshSuccess = false;
  bool _autoRefreshInFlight = false;
  DateTime? _lastAutoRefreshBaseline;
  int? _programmaticWeekTarget;
  ScheduleRefreshWarning? _visibleWarningPopup;
  Timer? _warningPopupTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.schedule == null) {
      Future.microtask(
        () => ref.read(scheduleControllerProvider.notifier).loadSchedule(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _warningPopupTimer?.cancel();
    _weekStripController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || widget.schedule != null) {
      return;
    }
    final currentSchedule = ref.read(scheduleControllerProvider).valueOrNull;
    if (currentSchedule != null) {
      unawaited(_maybeAutoRefresh(currentSchedule));
    }
  }

  Future<void> _refreshSchedule() async {
    setState(() {
      _isManualRefreshing = true;
      _showRefreshSuccess = false;
    });
    try {
      final didRefresh = await ref
          .read(scheduleControllerProvider.notifier)
          .manualRefresh();
      if (mounted && didRefresh) {
        setState(() {
          _isManualRefreshing = false;
          _showRefreshSuccess = true;
        });
        unawaited(_hideRefreshSuccessLater());
      }
    } finally {
      if (mounted && _isManualRefreshing) {
        setState(() {
          _isManualRefreshing = false;
        });
      }
    }
  }

  Future<void> _hideRefreshSuccessLater() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) {
      return;
    }
    setState(() {
      _showRefreshSuccess = false;
    });
  }

  DateTime _currentMoment() => widget.initialDate ?? DateTime.now();

  Future<void> _maybeAutoRefresh(Schedule schedule) async {
    if (widget.schedule != null ||
        _isManualRefreshing ||
        _autoRefreshInFlight) {
      return;
    }
    final baseline = schedule.lastSyncedAt ?? schedule.generatedAt;
    if (_lastAutoRefreshBaseline == baseline) {
      return;
    }
    if (!RefreshPolicy.shouldRefresh(
      now: _currentMoment(),
      lastRefreshAt: baseline,
    )) {
      return;
    }

    _lastAutoRefreshBaseline = baseline;
    _autoRefreshInFlight = true;
    try {
      await _refreshSchedule();
    } finally {
      _autoRefreshInFlight = false;
    }
  }

  Future<void> _jumpToToday() async {
    await _jumpToWeek(_weekForDate(_today));
  }

  Future<void> _jumpToWeek(int week) async {
    final clampedWeek = week.clamp(_minWeek, _maxWeek);
    if (clampedWeek == _selectedWeek) {
      return;
    }
    setState(() {
      _selectedWeek = clampedWeek;
      _programmaticWeekTarget = clampedWeek;
    });
    try {
      await Future.wait([
        if (_weekStripController.hasClients)
          _weekStripController.animateTo(
            (clampedWeek - 1) * _weekTileExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          ),
        if (_pageController.hasClients)
          _pageController.animateToPage(
            clampedWeek - 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          ),
      ]);
    } finally {
      if (mounted) {
        setState(() {
          _programmaticWeekTarget = null;
        });
      }
    }
  }

  Future<void> _handlePageChanged(int page) async {
    final week = page + 1;
    if (_programmaticWeekTarget != null && week != _programmaticWeekTarget) {
      return;
    }
    if (week == _selectedWeek) {
      return;
    }
    setState(() {
      _selectedWeek = week;
    });
    if (_weekStripController.hasClients) {
      await _weekStripController.animateTo(
        page * _weekTileExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    }
  }

  DateTime _weekStartForWeek(int week) {
    return _semesterStartDate.add(Duration(days: (week - 1) * 7));
  }

  int _weekForDate(DateTime date) {
    final normalized = _normalizeDate(date);
    final daysDiff = normalized.difference(_semesterStartDate).inDays;
    if (daysDiff < 0) {
      return _minWeek;
    }
    return ((daysDiff ~/ 7) + 1).clamp(_minWeek, _maxWeek);
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

  ScheduleRefreshWarning _warningForPinnedSchedule(Schedule? schedule) {
    if (schedule?.isStale ?? false) {
      return ScheduleRefreshWarning.staleCache;
    }
    return ScheduleRefreshWarning.none;
  }

  String _warningMessage(ScheduleRefreshWarning warning) {
    switch (warning) {
      case ScheduleRefreshWarning.offlineCache:
        return '当前处于离线状态，正在显示缓存课表';
      case ScheduleRefreshWarning.staleCache:
        return '当前显示的是缓存课表，可能不是最新数据';
      case ScheduleRefreshWarning.none:
        return '';
    }
  }

  void _showRefreshWarning(ScheduleRefreshWarning warning) {
    _warningPopupTimer?.cancel();
    setState(() {
      _visibleWarningPopup = warning;
    });
    _warningPopupTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _visibleWarningPopup = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheduleState = widget.schedule == null
        ? ref.watch(scheduleControllerProvider)
        : const AsyncValue<Schedule?>.data(null);
    final authState = ref.watch(authControllerProvider);
    final currentSchedule = widget.schedule ?? scheduleState.valueOrNull;
    final refreshWarning = widget.schedule == null
        ? ref.watch(scheduleRefreshWarningProvider)
        : _warningForPinnedSchedule(widget.schedule);
    final isLoading = widget.schedule == null && scheduleState.isLoading;
    final currentWeek = _weekForDate(_today);
    final refreshLabel = currentSchedule == null
        ? null
        : _formatRefreshTime(currentSchedule);

    if (widget.schedule == null && currentSchedule != null) {
      unawaited(_maybeAutoRefresh(currentSchedule));
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '第$_selectedWeek周',
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
          if (refreshWarning != ScheduleRefreshWarning.none)
            _ScheduleWarningButton(
              onPressed: () => _showRefreshWarning(refreshWarning),
            ),
          IconButton(
            key: const ValueKey('schedule-refresh-button'),
            onPressed: _isManualRefreshing ? null : _refreshSchedule,
            icon: AnimatedRotation(
              turns: _isManualRefreshing ? 1 : 0,
              duration: _isManualRefreshing
                  ? const Duration(milliseconds: 700)
                  : Duration.zero,
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
          : Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFF7FB), Color(0xFFFDFBF7)],
                    ),
                  ),
                  child: RefreshIndicator(
                    onRefresh: _refreshSchedule,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
                      children: [
                        _CompactTopBar(
                          selectedWeek: _selectedWeek,
                          currentWeek: currentWeek,
                          controller: _weekStripController,
                          onWeekTap: _jumpToWeek,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                        SizedBox(
                          key: const ValueKey('schedule-swipe-area'),
                          height: 720,
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              unawaited(_handlePageChanged(index));
                            },
                            itemCount: _maxWeek,
                            itemBuilder: (context, index) {
                              final week = index + 1;
                              final weekSchedule = currentSchedule.filterByWeek(
                                week,
                              );
                              return AnimatedBuilder(
                                animation: _pageController,
                                builder: (context, child) {
                                  final currentPage = _pageController.hasClients
                                      ? (_pageController.page ??
                                            _pageController.initialPage
                                                .toDouble())
                                      : _pageController.initialPage.toDouble();
                                  final distance = (currentPage - index)
                                      .abs()
                                      .clamp(0.0, 1.0);
                                  final opacity = lerpDouble(
                                    0.94,
                                    1.0,
                                    1 - distance,
                                  )!;
                                  final borderRadius = lerpDouble(
                                    16,
                                    0,
                                    1 - distance,
                                  )!;

                                  return Opacity(
                                    opacity: opacity,
                                    child: ScheduleGrid(
                                      key: ValueKey('schedule-week-$week'),
                                      schedule: weekSchedule,
                                      weekStartDate: _weekStartForWeek(week),
                                      borderRadius: borderRadius,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
                    ignoring: _visibleWarningPopup == null,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -0.08),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: _visibleWarningPopup == null
                          ? const SizedBox.shrink()
                          : _ScheduleWarningPopup(
                              key: const ValueKey('schedule-warning-popup'),
                              message: _warningMessage(_visibleWarningPopup!),
                            ),
                    ),
                  ),
                ),
                if (_selectedWeek != currentWeek)
                  const Positioned(
                    right: 0,
                    bottom: 110,
                    child: SizedBox.shrink(),
                  ),
                if (_selectedWeek != currentWeek)
                  Positioned(
                    right: 0,
                    bottom: 110,
                    child: _ReturnToCurrentWeekButton(onPressed: _jumpToToday),
                  ),
              ],
            ),
    );
  }
}

class _ScheduleWarningButton extends StatelessWidget {
  const _ScheduleWarningButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('schedule-warning-button'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            key: const ValueKey('schedule-warning-surface'),
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xCCFFF3C4), Color(0xB3FFE1A3)],
              ),
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: Color(0x33D97706)),
              ),
            ),
            child: const Icon(
              key: ValueKey('schedule-warning-icon'),
              Icons.priority_high_rounded,
              color: Color(0xFFB45309),
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleWarningPopup extends StatelessWidget {
  const _ScheduleWarningPopup({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBF0),
            borderRadius: BorderRadius.all(Radius.circular(20)),
            border: Border.fromBorderSide(BorderSide(color: Color(0x26F59E0B))),
            boxShadow: [
              BoxShadow(
                color: Color(0x1692400E),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE7AE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.priority_high_rounded,
                    color: Color(0xFFB45309),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF7C2D12),
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReturnToCurrentWeekButton extends StatelessWidget {
  const _ReturnToCurrentWeekButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 12),
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(begin: const Offset(1, 0), end: Offset.zero),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, offset, child) {
          return FractionalTranslation(translation: offset, child: child);
        },
        child: Material(
          color: const Color(0xFFF97316),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(999),
            bottomLeft: Radius.circular(999),
          ),
          elevation: 6,
          child: InkWell(
            onTap: onPressed,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(999),
              bottomLeft: Radius.circular(999),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                '回到本周',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar({
    required this.selectedWeek,
    required this.currentWeek,
    required this.controller,
    required this.onWeekTap,
  });

  final int selectedWeek;
  final int currentWeek;
  final ScrollController controller;
  final ValueChanged<int> onWeekTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        key: const ValueKey('infinite-week-strip'),
        controller: controller,
        scrollDirection: Axis.horizontal,
        itemExtent: _weekTileExtent,
        itemCount: _maxWeek,
        itemBuilder: (context, index) {
          final week = index + 1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _WeekTile(
              key: ValueKey('week-tile-$week'),
              week: week,
              isCurrentWeek: week == currentWeek,
              isSelected: week == selectedWeek,
              onTap: () => onWeekTap(week),
            ),
          );
        },
      ),
    );
  }
}

class _WeekTile extends StatelessWidget {
  const _WeekTile({
    super.key,
    required this.week,
    required this.isCurrentWeek,
    required this.isSelected,
    required this.onTap,
  });

  final int week;
  final bool isCurrentWeek;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = _semesterStartDate.add(Duration(days: (week - 1) * 7));
    final end = start.add(const Duration(days: 6));
    final backgroundColor = isSelected
        ? const Color(0xFFFCE7F3)
        : isCurrentWeek
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFFFFBF7);
    final borderColor = isSelected
        ? const Color(0xFFF472B6)
        : isCurrentWeek
        ? const Color(0xFFFDA4AF)
        : const Color(0xFFF3E5F5);
    final titleColor = isSelected || isCurrentWeek
        ? const Color(0xFF9D174D)
        : const Color(0xFF6B7280);
    final valueColor = isSelected || isCurrentWeek
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
          boxShadow: isSelected || isCurrentWeek
              ? const [
                  BoxShadow(
                    color: Color(0x22F472B6),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${start.month}.${start.day}-${end.month}.${end.day}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '第$week周',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    height: 1,
                  ),
                ),
                if (isCurrentWeek) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '本周',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFBE185D),
                        fontWeight: FontWeight.w800,
                        fontSize: 8,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
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
