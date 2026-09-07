package it.partysync.partysync

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "it.partysync.partysync/apk_share"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getApkPath") {
                try {
                    val appInfo = applicationInfo
                    val srcFile = File(appInfo.sourceDir)
                    val cacheFile = File(cacheDir, "Lello.apk")
                    if (!cacheFile.exists() || cacheFile.length() != srcFile.length()) {
                        srcFile.inputStream().use { input ->
                            cacheFile.outputStream().use { output ->
                                input.copyTo(output)
                            }
                        }
                    }
                    result.success(cacheFile.absolutePath)
                } catch (e: Exception) {
                    result.error("APK_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

