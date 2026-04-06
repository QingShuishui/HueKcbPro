import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/update_info.dart';
import '../../services/update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

class PendingUpdateInstall {
  const PendingUpdateInstall({required this.updateInfo, required this.apkPath});

  final UpdateInfo updateInfo;
  final String apkPath;
}

final pendingUpdateInstallProvider = StateProvider<PendingUpdateInstall?>((
  ref,
) {
  return null;
});
