class UpdateInfo {
  UpdateInfo({
    required this.platform,
    required this.version,
    required this.buildNumber,
    required this.forceUpdate,
    required this.notes,
    required this.apkUrl,
    required this.sha256,
    required this.publishedAt,
  });

  final String platform;
  final String version;
  final int buildNumber;
  final bool forceUpdate;
  final String notes;
  final String apkUrl;
  final String sha256;
  final DateTime publishedAt;

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      platform: json['platform'] as String,
      version: json['version'] as String,
      buildNumber: (json['build_number'] as num).toInt(),
      forceUpdate: json['force_update'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
      apkUrl: json['apk_url'] as String,
      sha256: json['sha256'] as String,
      publishedAt: DateTime.parse(json['published_at'] as String),
    );
  }

  bool isNewerThan({required int localBuildNumber}) {
    return buildNumber > localBuildNumber;
  }
}
