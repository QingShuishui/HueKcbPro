import 'package:flutter/material.dart';

import '../../models/update_info.dart';
import '../../services/update_service.dart';

Future<void> showUpdateDialog({
  required BuildContext context,
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
        if (!updateInfo.forceUpdate)
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

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AlertDialog(
      content: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('正在准备安装更新...')),
        ],
      ),
    ),
  );

  try {
    await updateService.downloadAndInstall(updateInfo);
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  } on UpdateServiceException catch (error) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
