package com.lifevault.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * MainActivity owned by Developer 4 (Integration Lead).
 *
 * Registers Developer 1's `LifeVaultOcrChannel` on channel `lifevault/ocr`
 * inside [configureFlutterEngine].
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        LifeVaultOcrChannel.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
