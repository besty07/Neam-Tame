package com.lifevault.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

/**
 * Native Kotlin OCR platform channel for LifeVault v0.1.
 *
 * Owned exclusively by Developer 1 (Capture & OCR).
 * Implements the Flutter MethodChannel `lifevault/ocr` using Tesseract4Android
 * and bundled `eng.traineddata`.
 *
 * All OCR operations and asset copying run strictly on background worker threads
 * (`Dispatchers.IO`) and never block the Android main UI thread.
 */
class LifeVaultOcrChannel(
    private val context: Context
) : MethodChannel.MethodCallHandler {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        const val CHANNEL_NAME = "lifevault/ocr"
        private const val MAX_IMAGE_DIMENSION = 2400
        private const val ASSET_MODEL_PATH = "flutter_assets/assets/tessdata/eng.traineddata"
        private const val EXPECTED_MODEL_SIZE = 4113088L

        /**
         * Convenience registration method for Developer 4 to wire into `MainActivity.kt`:
         *
         * ```kotlin
         * LifeVaultOcrChannel.register(this, flutterEngine.dartExecutor.binaryMessenger)
         * ```
         */
        @JvmStatic
        fun register(context: Context, messenger: BinaryMessenger): LifeVaultOcrChannel {
            val channel = MethodChannel(messenger, CHANNEL_NAME)
            val instance = LifeVaultOcrChannel(context.applicationContext)
            channel.setMethodCallHandler(instance)
            return instance
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "recognizeImage" -> {
                val imagePath = call.argument<String>("path")
                val language = call.argument<String>("language") ?: "eng"

                if (imagePath.isNullOrBlank()) {
                    result.error(
                        "INVALID_ARGUMENT",
                        "Image path must be provided and not blank",
                        null
                    )
                    return
                }

                scope.launch {
                    val ocrResult = processOcr(imagePath, language)
                    withContext(Dispatchers.Main) {
                        result.success(ocrResult)
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Executes the complete OCR flow off the main thread:
     * 1. Ensure model assets exist in app-private storage.
     * 2. Safely decode and orient the bitmap without exceeding memory budget.
     * 3. Run Tesseract recognition and record duration only (no PII in logs).
     * 4. Free native resources.
     */
    private fun processOcr(imagePath: String, language: String): Map<String, Any?> {
        val startTime = SystemClock.elapsedRealtime()

        val file = File(imagePath)
        if (!file.exists() || !file.canRead()) {
            return mapOf(
                "text" to "",
                "language" to language,
                "page" to 1,
                "confidence" to null,
                "processingMs" to (SystemClock.elapsedRealtime() - startTime).toInt(),
                "errorCode" to "DECODE_FAILED",
                "errorMessage" to "Image file does not exist or is unreadable: $imagePath"
            )
        }

        // 1. Ensure traineddata exists in app-private storage
        val tessDataDir = File(context.filesDir, "tessdata")
        val modelFile = File(tessDataDir, "$language.traineddata")

        try {
            ensureModelAssetExists(tessDataDir, modelFile, language)
        } catch (e: Exception) {
            return mapOf(
                "text" to "",
                "language" to language,
                "page" to 1,
                "confidence" to null,
                "processingMs" to (SystemClock.elapsedRealtime() - startTime).toInt(),
                "errorCode" to "MODEL_MISSING",
                "errorMessage" to "Failed to unpack or verify OCR model: ${e.message}"
            )
        }

        // 2. Decode bitmap safely
        val bitmap = try {
            decodeSampledBitmapAndOrient(imagePath, MAX_IMAGE_DIMENSION)
        } catch (oom: OutOfMemoryError) {
            return mapOf(
                "text" to "",
                "language" to language,
                "page" to 1,
                "confidence" to null,
                "processingMs" to (SystemClock.elapsedRealtime() - startTime).toInt(),
                "errorCode" to "DECODE_FAILED",
                "errorMessage" to "Out of memory while decoding image"
            )
        } catch (e: Exception) {
            return mapOf(
                "text" to "",
                "language" to language,
                "page" to 1,
                "confidence" to null,
                "processingMs" to (SystemClock.elapsedRealtime() - startTime).toInt(),
                "errorCode" to "DECODE_FAILED",
                "errorMessage" to "Failed to decode image: ${e.message}"
            )
        }

        if (bitmap == null) {
            return mapOf(
                "text" to "",
                "language" to language,
                "page" to 1,
                "confidence" to null,
                "processingMs" to (SystemClock.elapsedRealtime() - startTime).toInt(),
                "errorCode" to "DECODE_FAILED",
                "errorMessage" to "Decoded bitmap was null"
            )
        }

        // 3. Run Tesseract recognition
        val tessBaseApi = TessBaseAPI()
        return try {
            val datapath = context.filesDir.absolutePath
            val initSuccess = tessBaseApi.init(datapath, language)
            if (!initSuccess) {
                return mapOf(
                    "text" to "",
                    "language" to language,
                    "page" to 1,
                    "confidence" to null,
                    "processingMs" to (SystemClock.elapsedRealtime() - startTime).toInt(),
                    "errorCode" to "OCR_FAILED",
                    "errorMessage" to "Tesseract engine failed to initialize with datapath=$datapath and lang=$language"
                )
            }

            tessBaseApi.setImage(bitmap)
            val recognizedText = tessBaseApi.utF8Text ?: ""
            val confidence = tessBaseApi.meanConfidence().toDouble()
            val durationMs = (SystemClock.elapsedRealtime() - startTime).toInt()

            mapOf(
                "text" to recognizedText,
                "language" to language,
                "page" to 1,
                "confidence" to confidence,
                "processingMs" to durationMs,
                "errorCode" to null,
                "errorMessage" to null
            )
        } catch (e: Exception) {
            mapOf(
                "text" to "",
                "language" to language,
                "page" to 1,
                "confidence" to null,
                "processingMs" to (SystemClock.elapsedRealtime() - startTime).toInt(),
                "errorCode" to "OCR_FAILED",
                "errorMessage" to "OCR recognition error: ${e.message}"
            )
        } finally {
            try {
                tessBaseApi.recycle()
            } catch (_: Exception) {
            }
            try {
                bitmap.recycle()
            } catch (_: Exception) {
            }
        }
    }

    private const val EXPECTED_ENG_HASH = "7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2"

    /**
     * Copies the bundled model asset into `<filesDir>/tessdata/<language>.traineddata`
     * with a one-time hash check per Section 7.1 of Master Implementation Plan.
     */
    @Synchronized
    private fun ensureModelAssetExists(tessDataDir: File, modelFile: File, language: String) {
        if (!tessDataDir.exists()) {
            tessDataDir.mkdirs()
        }

        // One-time verification: if model exists and hash matches, reuse directly.
        if (modelFile.exists() && modelFile.length() == EXPECTED_MODEL_SIZE) {
            if (language != "eng" || computeSha256(modelFile).equals(EXPECTED_ENG_HASH, ignoreCase = true)) {
                return
            }
        }

        val assetManager = context.assets
        val candidates = listOf(
            try { io.flutter.FlutterInjector.instance().flutterLoader().getLookupKeyForAsset("assets/tessdata/$language.traineddata") } catch (_: Exception) { null },
            ASSET_MODEL_PATH,
            "flutter_assets/assets/tessdata/$language.traineddata",
            "assets/tessdata/$language.traineddata"
        ).filterNotNull()

        var inputStream: java.io.InputStream? = null
        for (candidate in candidates) {
            try {
                inputStream = assetManager.open(candidate)
                if (inputStream != null) break
            } catch (_: IOException) {
            }
        }

        if (inputStream == null) {
            throw IOException("Could not locate asset for $language.traineddata in APK")
        }

        val tempFile = File(tessDataDir, "$language.traineddata.tmp")
        inputStream.use { input ->
            FileOutputStream(tempFile).use { output ->
                input.copyTo(output)
            }
        }

        if (language == "eng") {
            val hash = computeSha256(tempFile)
            if (!hash.equals(EXPECTED_ENG_HASH, ignoreCase = true)) {
                tempFile.delete()
                throw IllegalStateException("Copied model hash ($hash) does not match expected SHA-256 ($EXPECTED_ENG_HASH)")
            }
        }

        if (modelFile.exists()) {
            modelFile.delete()
        }
        if (!tempFile.renameTo(modelFile)) {
            tempFile.copyTo(modelFile, overwrite = true)
            tempFile.delete()
        }
    }

    private fun computeSha256(file: File): String {
        val digest = java.security.MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(8192)
            var bytesRead: Int
            while (input.read(buffer).also { bytesRead = it } != -1) {
                digest.update(buffer, 0, bytesRead)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    /**
     * Decodes the image at [imagePath] with inSampleSize sub-sampling if larger than [maxDimension],
     * and corrects any EXIF rotation.
     */
    private fun decodeSampledBitmapAndOrient(imagePath: String, maxDimension: Int): Bitmap? {
        val boundsOptions = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeFile(imagePath, boundsOptions)

        val origWidth = boundsOptions.outWidth
        val origHeight = boundsOptions.outHeight
        if (origWidth <= 0 || origHeight <= 0) {
            return null
        }

        var inSampleSize = 1
        if (origWidth > maxDimension || origHeight > maxDimension) {
            val halfWidth = origWidth / 2
            val halfHeight = origHeight / 2
            while ((halfWidth / inSampleSize) >= maxDimension || (halfHeight / inSampleSize) >= maxDimension) {
                inSampleSize *= 2
            }
        }

        val decodeOptions = BitmapFactory.Options().apply {
            this.inSampleSize = inSampleSize
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }

        val rawBitmap = BitmapFactory.decodeFile(imagePath, decodeOptions) ?: return null

        // Check EXIF orientation
        val orientation = try {
            val exif = ExifInterface(imagePath)
            exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        } catch (_: IOException) {
            ExifInterface.ORIENTATION_NORMAL
        }

        val rotationAngle = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }

        if (rotationAngle == 0f) {
            return rawBitmap
        }

        val matrix = Matrix().apply { postRotate(rotationAngle) }
        val rotated = Bitmap.createBitmap(
            rawBitmap,
            0,
            0,
            rawBitmap.width,
            rawBitmap.height,
            matrix,
            true
        )
        if (rotated != rawBitmap) {
            rawBitmap.recycle()
        }
        return rotated
    }
}
