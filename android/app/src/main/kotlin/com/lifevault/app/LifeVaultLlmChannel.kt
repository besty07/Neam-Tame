package com.lifevault.app

import android.content.Context
import android.os.SystemClock
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Native Kotlin bridge for the Qwen-0.6B on-device Action Guide engine
 * (`MethodChannel("lifevault/llm")`).
 *
 * Supports:
 * 1. Streaming bundled `assets/models/qwen-0.6b.gguf` into internal storage
 *    (`<filesDir>/models/qwen-0.6b.gguf`).
 * 2. Detecting ADB-pushed weights at `/sdcard/Download/qwen-0.6b.gguf`
 *    for rapid developer iteration (`QWEN_INTEGRATION_PLAN.md` Section 2.A.4).
 * 3. Executing background GGUF model inference on `Dispatchers.IO` or
 *    reporting `MODEL_NOT_STAGED` so `HybridActionGuideService` falls back
 *    instantly to the deterministic offline playbook.
 */
class LifeVaultLlmChannel(
    private val context: Context
) : MethodChannel.MethodCallHandler {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    companion object {
        const val CHANNEL_NAME = "lifevault/llm"
        private const val MODEL_FILENAME = "qwen-0.6b.gguf"
        private const val MIN_VALID_GGUF_BYTES = 16L
        private const val ENGINE_ASSET_DIRECTORY = "lifevault_llama"
        private const val ENGINE_DIRECTORY = "llama"
        private const val ENGINE_EXECUTABLE = "llama-cli"
        private val ENGINE_FILES = listOf(
            ENGINE_EXECUTABLE,
            "libggml-base.so",
            "libggml-cpu.so",
            "libggml.so",
            "libllama-cli-impl.so",
            "libllama-common.so",
            "libllama-server-impl.so",
            "libllama.so",
            "libmtmd.so"
        )

        @JvmStatic
        fun register(context: Context, messenger: BinaryMessenger): LifeVaultLlmChannel {
            val channel = MethodChannel(messenger, CHANNEL_NAME)
            val instance = LifeVaultLlmChannel(context.applicationContext)
            channel.setMethodCallHandler(instance)
            return instance
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getModelStatus" -> {
                scope.launch {
                    val status = inspectModelStatus()
                    withContext(Dispatchers.Main) {
                        result.success(status)
                    }
                }
            }

            "generateActionPlaybook" -> {
                val title = call.argument<String>("title") ?: "Document"
                val category = call.argument<String>("category") ?: "other"
                val assetName = call.argument<String>("assetName")
                val dueDateIso = call.argument<String>("dueDateIso")
                val evidenceSnippet = call.argument<String>("evidenceSnippet")

                scope.launch {
                val systemPrompt = call.argument<String>("systemPrompt") ?: ""
                val userPrompt = call.argument<String>("userPrompt") ?: ""
                val response = runOnDeviceGeneration(
                    systemPrompt = systemPrompt,
                    userPrompt = userPrompt,
                        title = title,
                    )
                    withContext(Dispatchers.Main) {
                        result.success(response)
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun inspectModelStatus(): Map<String, Any?> {
        val stagedFile = resolveOrStageModelFile()
        val isReady = stagedFile != null && hasValidGgufMagic(stagedFile)
        return mapOf(
            "ready" to isReady,
            "modelPath" to stagedFile?.absolutePath,
            "modelBytes" to (stagedFile?.length() ?: 0L)
        )
    }

    private fun runOnDeviceGeneration(
        systemPrompt: String,
        userPrompt: String,
        title: String,
    ): Map<String, Any?> {
        val startMs = SystemClock.elapsedRealtime()
        val modelFile = resolveOrStageModelFile()

        if (modelFile == null || !hasValidGgufMagic(modelFile)) {
            return mapOf(
                "text" to "",
                "processingMs" to (SystemClock.elapsedRealtime() - startMs).toInt(),
                "errorCode" to "MODEL_NOT_STAGED",
                "errorMessage" to "Qwen-0.6B GGUF weights not staged on device; using deterministic offline playbook."
            )
        }

        val executable = stageEngineExecutable()
        if (executable == null) {
            return mapOf(
                "text" to "",
                "processingMs" to (SystemClock.elapsedRealtime() - startMs).toInt(),
                "errorCode" to "ENGINE_NOT_STAGED",
                "errorMessage" to "The Android llama.cpp runtime is not packaged in this experimental APK."
            )
        }

        val requestPrompt = buildString {
            append(systemPrompt.trim())
            append("\n\n")
            append(userPrompt.trim())
            append("\n\nReturn only 3 or 4 short bullet action steps. Do not introduce facts, dates, regulations, or requirements not present above. /no_think")
        }
        val processOutput = executeLlama(executable, modelFile, requestPrompt)
        if (processOutput.errorCode != null) {
            return mapOf(
                "text" to "",
                "processingMs" to (SystemClock.elapsedRealtime() - startMs).toInt(),
                "errorCode" to processOutput.errorCode,
                "errorMessage" to processOutput.errorMessage
            )
        }
        val generatedBullets = extractGeneratedText(processOutput.output)
        if (generatedBullets.isBlank()) {
            return mapOf(
                "text" to "",
                "processingMs" to (SystemClock.elapsedRealtime() - startMs).toInt(),
                "errorCode" to "EMPTY_GENERATION",
                "errorMessage" to "The on-device Qwen runtime returned no usable action steps."
            )
        }
        return mapOf(
            "text" to generatedBullets,
            "summary" to "Generated offline on-device by Qwen-0.6B (${modelFile.name}) for $title.",
            "processingMs" to (SystemClock.elapsedRealtime() - startMs).toInt(),
            "errorCode" to null,
            "errorMessage" to null
        )
    }

    private data class ProcessOutput(
        val output: String = "",
        val errorCode: String? = null,
        val errorMessage: String? = null
    )

    @Synchronized
    private fun stageEngineExecutable(): File? {
        val engineDir = File(context.filesDir, ENGINE_DIRECTORY)
        if (!engineDir.exists() && !engineDir.mkdirs()) {
            return null
        }

        for (fileName in ENGINE_FILES) {
            val destination = File(engineDir, fileName)
            if (destination.exists() && destination.length() > 0L) {
                continue
            }
            try {
                context.assets.open("$ENGINE_ASSET_DIRECTORY/$fileName").use { input ->
                    val temporary = File(engineDir, "$fileName.tmp")
                    FileOutputStream(temporary).use { output -> input.copyTo(output) }
                    if (destination.exists()) {
                        destination.delete()
                    }
                    if (!temporary.renameTo(destination)) {
                        temporary.copyTo(destination, overwrite = true)
                        temporary.delete()
                    }
                }
            } catch (ignored: IOException) {
                return null
            }
        }

        val executable = File(engineDir, ENGINE_EXECUTABLE)
        if (!executable.setExecutable(true, true) || !executable.canExecute()) {
            return null
        }
        return executable
    }

    private fun executeLlama(executable: File, modelFile: File, prompt: String): ProcessOutput {
        val command = listOf(
            executable.absolutePath,
            "-m", modelFile.absolutePath,
            "-c", "1024",
            "-n", "96",
            "--temp", "0.2",
            "--top-p", "0.9",
            "-st",
            "--simple-io",
            "--no-display-prompt",
            "-p", prompt
        )
        return try {
            val process = ProcessBuilder(command)
                .directory(executable.parentFile)
                .redirectErrorStream(true)
                .apply {
                    environment()["LD_LIBRARY_PATH"] = executable.parentFile?.absolutePath.orEmpty()
                }
                .start()
            val output = StringBuilder()
            val outputThread = Thread {
                process.inputStream.bufferedReader().useLines { lines ->
                    lines.forEach { line -> output.appendLine(line) }
                }
            }.apply { start() }
            if (!process.waitFor(25, TimeUnit.SECONDS)) {
                process.destroyForcibly()
                outputThread.join(1000)
                return ProcessOutput(
                    errorCode = "GENERATION_TIMEOUT",
                    errorMessage = "Qwen did not finish within the 25-second on-device limit."
                )
            }
            outputThread.join(1000)
            if (process.exitValue() != 0) {
                return ProcessOutput(
                    errorCode = "GENERATION_FAILED",
                    errorMessage = output.toString().takeLast(800).ifBlank {
                        "llama.cpp exited with code ${process.exitValue()}."
                    }
                )
            }
            ProcessOutput(output = output.toString())
        } catch (error: Exception) {
            ProcessOutput(
                errorCode = "GENERATION_FAILED",
                errorMessage = error.message ?: "Unable to start the on-device llama.cpp runtime."
            )
        }
    }

    private fun extractGeneratedText(output: String): String {
        val afterPrompt = output.substringAfterLast("\n> ", output)
        return afterPrompt
            .substringBefore("\n[ Prompt:")
            .substringBefore("\nExiting...")
            .trim()
    }

    @Synchronized
    private fun resolveOrStageModelFile(): File? {
        val internalModelsDir = File(context.filesDir, "models")
        if (!internalModelsDir.exists()) {
            internalModelsDir.mkdirs()
        }
        val stagedFile = File(internalModelsDir, MODEL_FILENAME)
        if (stagedFile.exists() && stagedFile.length() >= MIN_VALID_GGUF_BYTES) {
            return stagedFile
        }

        val flutterModelsFile = File(context.dataDir, "app_flutter/models/$MODEL_FILENAME")
        if (flutterModelsFile.exists() && flutterModelsFile.length() >= MIN_VALID_GGUF_BYTES) {
            return flutterModelsFile
        }

        val adbDownloadFile = File("/sdcard/Download/$MODEL_FILENAME")
        if (adbDownloadFile.exists() && adbDownloadFile.canRead() &&
            adbDownloadFile.length() >= MIN_VALID_GGUF_BYTES
        ) {
            return adbDownloadFile
        }

        val assetCandidates = listOfNotNull(
            try {
                FlutterInjector.instance().flutterLoader()
                    .getLookupKeyForAsset("assets/models/$MODEL_FILENAME")
            } catch (ignored: Exception) {
                null
            },
            "flutter_assets/assets/models/$MODEL_FILENAME",
            "assets/models/$MODEL_FILENAME"
        )

        for (candidate in assetCandidates) {
            try {
                context.assets.open(candidate).use { input ->
                    val tempFile = File(internalModelsDir, "$MODEL_FILENAME.tmp")
                    FileOutputStream(tempFile).use { output ->
                        input.copyTo(output)
                    }
                    if (tempFile.length() >= MIN_VALID_GGUF_BYTES) {
                        if (stagedFile.exists()) {
                            stagedFile.delete()
                        }
                        if (!tempFile.renameTo(stagedFile)) {
                            tempFile.copyTo(stagedFile, overwrite = true)
                            tempFile.delete()
                        }
                        return stagedFile
                    } else {
                        tempFile.delete()
                    }
                }
            } catch (ignored: IOException) {
                // Asset not packaged in this APK build; continue checking.
            }
        }

        return null
    }

    private fun hasValidGgufMagic(file: File): Boolean {
        if (!file.exists() || !file.canRead() || file.length() < 4L) {
            return false
        }
        return try {
            val header = ByteArray(4)
            FileInputStream(file).use { input ->
                val read = input.read(header)
                read == 4 &&
                    header[0] == 'G'.code.toByte() &&
                    header[1] == 'G'.code.toByte() &&
                    header[2] == 'U'.code.toByte() &&
                    header[3] == 'F'.code.toByte()
            }
        } catch (ignored: Exception) {
            false
        }
    }
}
