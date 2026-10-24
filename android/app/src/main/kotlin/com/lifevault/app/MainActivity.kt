package com.lifevault.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * MainActivity owned by Developer 4 (Integration Lead).
 *
 * Developer 1 provides a registration snippet for `LifeVaultOcrChannel`
 * on channel `lifevault/ocr` to be wired inside [configureFlutterEngine].
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // D4 integration hook: register LifeVaultOcrChannel(context, flutterEngine)
        // when D1's feat/d1-capture-ocr branch merges.
    }
}
