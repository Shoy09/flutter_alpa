package com.example.i_miner

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    private var laborVoice: LaborVoice? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        laborVoice = LaborVoice(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "i_miner/labor_voz")
            .setMethodCallHandler { call, result -> laborVoice!!.handle(call.method, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "i_miner/local_transfer")
            .setMethodCallHandler { call, result ->
                if (call.method == "keepAwake") {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == LaborVoice.PERMISSION) {
            laborVoice?.permission(grantResults.firstOrNull() == android.content.pm.PackageManager.PERMISSION_GRANTED)
        }
    }

    override fun onStop() {
        laborVoice?.cancel()
        super.onStop()
    }

    override fun onDestroy() {
        laborVoice?.close()
        super.onDestroy()
    }
}
