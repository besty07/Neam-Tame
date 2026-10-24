package com.lifevault.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * MainActivity owned by Developer 4 (Integration Lead).
 *
 * Registers:
 * - Developer 1's [LifeVaultOcrChannel] on channel `lifevault/ocr`
 * - Qwen-0.6B [LifeVaultLlmChannel] on channel `lifevault/llm`
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        LifeVaultOcrChannel.register(this, messenger)
        LifeVaultLlmChannel.register(this, messenger)
    }
}
