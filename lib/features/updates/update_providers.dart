import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});
