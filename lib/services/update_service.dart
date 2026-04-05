import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../core/network/api_base_url.dart';
import '../models/update_info.dart';

class UpdateServiceException implements Exception {
  UpdateServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpdateService {
  UpdateService({
    HttpClient? httpClient,
    String? updateMetadataUrl,
  }) : updateMetadataUrl =
           updateMetadataUrl ??
           ApiBaseUrl.resolveAndroidUpdateMetadataUrl(isAndroid: true),
       _httpClient = httpClient ?? HttpClient();

  static const MethodChannel _channel = MethodChannel(
    'kcb_pro_android/update',
  );

  final HttpClient _httpClient;
  final String updateMetadataUrl;

  Future<UpdateInfo?> getAvailableUpdate() async {
    if (!Platform.isAndroid) {
      return null;
    }

    final updateInfo = await fetchLatestUpdate();
    if (updateInfo == null) {
      return null;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final localBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
    if (!updateInfo.isNewerThan(localBuildNumber: localBuildNumber)) {
      return null;
    }

    return updateInfo;
  }

  Future<UpdateInfo?> fetchLatestUpdate() async {
    final uri = Uri.parse(updateMetadataUrl);
    final request = await _httpClient.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      return null;
    }

    final payload = await utf8.decoder.bind(response).join();
    final jsonMap = jsonDecode(payload) as Map<String, dynamic>;
    return UpdateInfo.fromJson(jsonMap);
  }

  Future<void> downloadAndInstall(UpdateInfo updateInfo) async {
    final file = await _downloadApk(updateInfo);
    final digest = await computeFileSha256(file);
    if (digest.toLowerCase() != updateInfo.sha256.toLowerCase()) {
      if (await file.exists()) {
        await file.delete();
      }
      throw UpdateServiceException('APK 校验失败');
    }

    try {
      await _channel.invokeMethod<void>('installApk', {
        'path': file.path,
      });
    } on PlatformException catch (error) {
      throw UpdateServiceException(error.message ?? '无法启动安装程序');
    }
  }

  Future<String> computeFileSha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<File> _downloadApk(UpdateInfo updateInfo) async {
    final uri = Uri.parse(updateInfo.apkUrl);
    final request = await _httpClient.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw UpdateServiceException('下载更新失败');
    }

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/kcb-update-${updateInfo.version}+${updateInfo.buildNumber}.apk',
    );
    final output = file.openWrite();
    await response.forEach(output.add);
    await output.close();
    return file;
  }
}
