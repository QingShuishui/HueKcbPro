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

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({
    super.key,
    required this.academicUsername,
    this.appVersionLabel,
  });

  final String academicUsername;
  final String? appVersionLabel;
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

  Future<String?> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.trim();
    if (build.isEmpty) {
      return info.version;
    }
    return '${info.version}+$build';
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
