package cn.org.hue.kcb.kcb_pro_android

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kcb_pro_android/update"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallApk" -> {
                    result.success(canInstallPackages())
                }

                "openInstallPermissionSettings" -> {
                    openInstallPermissionSettings()
                    result.success(null)
                }

                "installDownloadedApk", "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("invalid_args", "Missing APK path", null)
                        return@setMethodCallHandler
                    }

                    runCatching {
                        installDownloadedApk(path)
                    }.onSuccess {
                        result.success(null)
                    }.onFailure { error ->
                        result.error("install_failed", error.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun canInstallPackages(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }

    private fun openInstallPermissionSettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName")
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun installDownloadedApk(path: String) {
        if (!canInstallPackages()) {
            throw IllegalStateException("请先允许安装未知来源应用")
        }

        val apkFile = File(path)
        if (!apkFile.exists()) {
            throw IllegalStateException("APK 文件不存在")
        }

        val apkUri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apkFile
        )

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        startActivity(intent)
    }
}
