import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/update_info.dart';
import '../../services/update_service.dart';
import 'update_providers.dart';

Future<void> showUpdateDialog({
  required BuildContext context,
  required WidgetRef ref,
  required UpdateInfo updateInfo,
  required UpdateService updateService,
}) async {
  final shouldInstall = await showDialog<bool>(
    context: context,
    barrierDismissible: !updateInfo.forceUpdate,
    builder: (context) => AlertDialog(
      title: const Text('发现新版本'),
      content: Text(
        '版本 ${updateInfo.version}（构建 ${updateInfo.buildNumber}）\n\n'
        '${updateInfo.notes.isEmpty ? '已有新版本可用。' : updateInfo.notes}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('稍后再说'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('立即更新'),
        ),
      ],
    ),
  );

  if (shouldInstall != true || !context.mounted) {
    return;
  }

  final progress = ValueNotifier<double?>(null);
  final downloading = ValueNotifier<bool>(false);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ValueListenableBuilder<bool>(
      valueListenable: downloading,
      builder: (context, isDownloading, _) {
        return ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (context, value, _) {
            final percent = value == null ? null : (value * 100).clamp(0, 100);
            return AlertDialog(
              content: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      !isDownloading
                          ? '正在准备安装更新...'
                          : percent == null
                          ? '正在下载更新...'
                          : '正在下载更新... ${percent.toStringAsFixed(0)}%',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );

  try {
    downloading.value = true;
    final file = await updateService.downloadApk(
      updateInfo,
      onProgress: (value) => progress.value = value,
    );
    final digest = await updateService.computeFileSha256(file);
    if (digest.toLowerCase() != updateInfo.sha256.toLowerCase()) {
      throw UpdateServiceException('APK 校验失败');
    }
    if (!context.mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();

    final canInstall = await updateService.canInstallPackages();
    if (canInstall) {
      await updateService.installDownloadedApk(file.path);
      return;
    }

    ref.read(pendingUpdateInstallProvider.notifier).state =
        PendingUpdateInstall(updateInfo: updateInfo, apkPath: file.path);

    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要安装权限'),
        content: const Text('请先允许安装未知来源应用，返回后会继续安装更新。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await updateService.openInstallPermissionSettings();
            },
            child: const Text('去授权'),
          ),
        ],
      ),
    );
  } on UpdateServiceException catch (error) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  } finally {
    downloading.dispose();
    progress.dispose();
  }
}
