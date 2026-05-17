import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../updates/update_prompt.dart';
import '../../updates/update_providers.dart';
import '../../../services/update_service.dart';
import 'about_page.dart';

typedef DebugDateSelector =
    Future<DateTime?> Function(BuildContext context, DateTime initialDate);

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({
    super.key,
    required this.academicUsername,
    this.appVersionLabel,
    this.isDebugMode = false,
    this.debugEffectiveDate,
    this.debugConfiguredDate,
    this.debugDateSyncImmediately = true,
    this.debugCacheAge = Duration.zero,
    this.debugRefreshDuration = Duration.zero,
    this.onDebugDateSelected,
    this.onDebugDateSyncImmediatelyChanged,
    this.onDebugCacheAgeChanged,
    this.onDebugRefreshDurationChanged,
    this.debugDateSelector,
  });

  final String academicUsername;
  final String? appVersionLabel;
  final bool isDebugMode;
  final DateTime? debugEffectiveDate;
  final DateTime? debugConfiguredDate;
  final bool debugDateSyncImmediately;
  final Duration debugCacheAge;
  final Duration debugRefreshDuration;
  final ValueChanged<DateTime>? onDebugDateSelected;
  final ValueChanged<bool>? onDebugDateSyncImmediatelyChanged;
  final ValueChanged<Duration>? onDebugCacheAgeChanged;
  final ValueChanged<Duration>? onDebugRefreshDurationChanged;
  final DebugDateSelector? debugDateSelector;
  static final Uri _githubUri = Uri.parse(
    'https://github.com/QingShuishui/HueKcbPro',
  );

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final Future<String?> _appVersionFuture = widget.appVersionLabel == null
      ? _loadAppVersion()
      : Future<String?>.value(widget.appVersionLabel);
  late bool _debugDateSyncImmediately = widget.debugDateSyncImmediately;
  late DateTime? _debugEffectiveDate = widget.debugEffectiveDate;
  late DateTime? _debugConfiguredDate = widget.debugConfiguredDate;
  late Duration _debugCacheAge = widget.debugCacheAge;
  late Duration _debugRefreshDuration = widget.debugRefreshDuration;

  Future<String?> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.trim();
    if (build.isEmpty) {
      return info.version;
    }
    return '${info.version}+$build';
  }

  String _formatDebugDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatDebugDuration(Duration duration) {
    if (duration.inHours > 0) {
      final minutes = duration.inMinutes.remainder(60);
      return minutes == 0
          ? '${duration.inHours}小时'
          : '${duration.inHours}小时$minutes分钟';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}分钟';
    }
    return '${duration.inSeconds}秒';
  }

  void _changeDebugCacheAge(Duration delta) {
    final next = _debugCacheAge + delta;
    final clampedMinutes = next.inMinutes.clamp(0, 180);
    final clamped = Duration(minutes: clampedMinutes);
    setState(() {
      _debugCacheAge = clamped;
    });
    widget.onDebugCacheAgeChanged?.call(clamped);
  }

  void _changeDebugRefreshDuration(Duration delta) {
    final next = _debugRefreshDuration + delta;
    final clampedSeconds = next.inSeconds.clamp(0, 20);
    final clamped = Duration(seconds: clampedSeconds);
    setState(() {
      _debugRefreshDuration = clamped;
    });
    widget.onDebugRefreshDurationChanged?.call(clamped);
  }

  Future<void> _pickDebugDate(BuildContext context) async {
    final initialDate =
        _debugConfiguredDate ?? _debugEffectiveDate ?? DateTime.now();
    final selector = widget.debugDateSelector;
    final selected = selector == null
        ? await showDatePicker(
            context: context,
            initialDate: initialDate,
            firstDate: DateTime(2026, 3, 2),
            lastDate: DateTime(2026, 7, 26),
          )
        : await selector(context, initialDate);
    if (selected == null) {
      return;
    }
    final normalized = DateTime(selected.year, selected.month, selected.day);
    setState(() {
      _debugConfiguredDate = normalized;
      if (_debugDateSyncImmediately) {
        _debugEffectiveDate = normalized;
      }
    });
    widget.onDebugDateSelected?.call(normalized);
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    final updateService = ref.read(updateServiceProvider);
    try {
      final updateInfo = await updateService.getAvailableUpdate();
      if (!context.mounted) {
        return;
      }
      if (updateInfo == null) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('当前已是最新版本'),
            content: const Text('暂时没有检测到新的可用更新。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
        return;
      }
      await showUpdateDialog(
        context: context,
        ref: ref,
        updateInfo: updateInfo,
        updateService: updateService,
      );
    } on UpdateServiceException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF7FB), Color(0xFFFDFBF7)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionCard(
              title: '账号',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('当前学号'),
                  const SizedBox(height: 8),
                  Text(
                    widget.academicUsername,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('退出登录'),
                  ),
                ],
              ),
            ),
            if (widget.isDebugMode)
              _SectionCard(
                title: 'Debug 测试',
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _debugDateSyncImmediately,
                      onChanged: (value) {
                        setState(() {
                          _debugDateSyncImmediately = value;
                        });
                        widget.onDebugDateSyncImmediatelyChanged?.call(value);
                      },
                      title: const Text('立即刷新生效'),
                      subtitle: Text(
                        _debugDateSyncImmediately
                            ? '选择日期后立即同步当前周'
                            : '选择日期后等待课表刷新按钮同步',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.event_available_rounded,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                      title: '设置当前日期',
                      subtitle: [
                        if (_debugEffectiveDate != null)
                          '已生效：${_formatDebugDate(_debugEffectiveDate!)}',
                        if (_debugConfiguredDate != null &&
                            _debugEffectiveDate != null &&
                            !DateUtils.isSameDay(
                              _debugConfiguredDate,
                              _debugEffectiveDate,
                            ))
                          '待同步：${_formatDebugDate(_debugConfiguredDate!)}',
                      ].join('\n'),
                      onTap: () => _pickDebugDate(context),
                    ),
                    const SizedBox(height: 10),
                    _DebugDurationControl(
                      title: '缓存距今',
                      valueLabel: _formatDebugDuration(_debugCacheAge),
                      onDecrease: () =>
                          _changeDebugCacheAge(const Duration(minutes: -15)),
                      onIncrease: () =>
                          _changeDebugCacheAge(const Duration(minutes: 15)),
                    ),
                    const SizedBox(height: 10),
                    _DebugDurationControl(
                      title: '刷新耗时',
                      valueLabel: _formatDebugDuration(_debugRefreshDuration),
                      onDecrease: () => _changeDebugRefreshDuration(
                        const Duration(seconds: -1),
                      ),
                      onIncrease: () => _changeDebugRefreshDuration(
                        const Duration(seconds: 1),
                      ),
                    ),
                  ],
                ),
              ),
            _SectionCard(
              title: '项目',
              child: Column(
                children: [
                  FutureBuilder<String?>(
                    future: _appVersionFuture,
                    builder: (context, snapshot) {
                      final versionLabel = snapshot.data ?? '读取中...';
                      return _ActionTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.system_update_alt_rounded,
                            color: Color(0xFFBE185D),
                          ),
                        ),
                        title: '检查更新',
                        subtitle: '当前版本：$versionLabel',
                        onTap: () => _checkForUpdates(context),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    leading: const _GithubBadge(),
                    title: 'GitHub',
                    subtitle: '帮帮忙点下Star～感谢啦🙏',
                    onTap: () async {
                      final launched = await launchUrl(
                        SettingsPage._githubUri,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!launched && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('暂时无法打开 GitHub 链接')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        color: Color(0xFFBE185D),
                      ),
                    ),
                    title: '关于',
                    subtitle: '作者的一些碎碎念',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    this.title,
    this.titleFuture,
    this.titleBuilder,
    required this.child,
  });

  final String? title;
  final Future<String?>? titleFuture;
  final String Function(String?)? titleBuilder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF374151),
              ),
            )
          else
            FutureBuilder<String?>(
              future: titleFuture,
              builder: (context, snapshot) {
                final resolved = titleBuilder?.call(snapshot.data) ?? '';
                return Text(
                  resolved,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF374151),
                  ),
                );
              },
            ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DebugDurationControl extends StatelessWidget {
  const _DebugDurationControl({
    required this.title,
    required this.valueLabel,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String title;
  final String valueLabel;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFBF7),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    valueLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDecrease,
              tooltip: '减少',
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            IconButton(
              onPressed: onIncrease,
              tooltip: '增加',
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFBF7),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _GithubBadge extends StatelessWidget {
  const _GithubBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: const FaIcon(
        FontAwesomeIcons.github,
        color: Colors.white,
        size: 30,
      ),
    );
  }
}
