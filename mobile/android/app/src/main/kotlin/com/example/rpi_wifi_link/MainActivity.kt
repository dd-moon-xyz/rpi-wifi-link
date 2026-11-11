package com.example.rpi_wifi_link

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rpi-wifi-link/permissions")
            .setMethodCallHandler { call, result ->
                if (call.method != "bluetooth") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val permissions = if (Build.VERSION.SDK_INT >= 31) {
                    arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
                } else {
                    arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
                }
                if (permissions.all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }) {
                    result.success(true)
                } else if (pendingPermission == null) {
                    pendingPermission = result
                    requestPermissions(permissions, 410)
                } else {
                    result.error("busy", "Permission request already pending", null)
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 410) {
            pendingPermission?.success(grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED })
            pendingPermission = null
        }
    }
}
