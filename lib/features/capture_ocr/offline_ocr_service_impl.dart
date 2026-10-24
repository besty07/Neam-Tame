import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../core/contracts/models.dart';
import '../../core/contracts/services.dart';

/// Concrete implementation of [OfflineOcrService].
///
/// On production mobile devices (Android / iOS), text recognition is performed
/// on-device using Google ML Kit (`google_mlkit_text_recognition`) with zero network calls.
/// For unit tests or custom platform bridges, an optional [MethodChannel] or [TextRecognizer]
/// can be injected.
class OfflineOcrServiceImpl implements OfflineOcrService {
  OfflineOcrServiceImpl({
    MethodChannel? channel,
    TextRecognizer? recognizer,
  })  : _channel = channel,
        _recognizer = recognizer;

  final MethodChannel? _channel;
  TextRecognizer? _recognizer;

  TextRecognizer get _effectiveRecognizer =>
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<OcrOutput> recognizeImage(
    String localImagePath, {
    String language = 'eng',
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    if (localImagePath.trim().isEmpty) {
      return OcrOutput(
        text: '',
        language: language,
        errorCode: 'DECODE_FAILED',
        errorMessage: 'Image path must not be empty',
        processingMs: stopwatch.elapsedMilliseconds,
      );
    }

    final File file = File(localImagePath);
    if (!await file.exists()) {
      return OcrOutput(
        text: '',
        language: language,
        errorCode: 'DECODE_FAILED',
        errorMessage: 'Image file does not exist: $localImagePath',
        processingMs: stopwatch.elapsedMilliseconds,
      );
    }

    // If a MethodChannel was explicitly supplied (e.g. in test suites), delegate to it.
    if (_channel != null) {
      return _recognizeViaChannel(
        localImagePath: localImagePath,
        language: language,
        stopwatch: stopwatch,
      );
    }

    // Otherwise, perform high-accuracy on-device recognition using Google ML Kit.
    try {
      final InputImage inputImage = InputImage.fromFilePath(localImagePath);
      final RecognizedText recognizedText =
          await _effectiveRecognizer.processImage(inputImage);

      stopwatch.stop();

      return OcrOutput(
        text: recognizedText.text,
        language: language,
        page: 1,
        confidence: 100.0,
        processingMs: stopwatch.elapsedMilliseconds,
      );
    } on PlatformException catch (e) {
      stopwatch.stop();
      return OcrOutput(
        text: '',
        language: language,
        errorCode: e.code.isNotEmpty ? e.code : 'OCR_FAILED',
        errorMessage: e.message ?? e.details?.toString(),
        processingMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return OcrOutput(
        text: '',
        language: language,
        errorCode: 'OCR_FAILED',
        errorMessage: e.toString(),
        processingMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<OcrOutput> _recognizeViaChannel({
    required String localImagePath,
    required String language,
    required Stopwatch stopwatch,
  }) async {
    try {
      final Map<dynamic, dynamic>? rawResult =
          await _channel!.invokeMapMethod<dynamic, dynamic>(
        'recognizeImage',
        <String, Object?>{
          'path': localImagePath,
          'language': language,
        },
      );

      stopwatch.stop();

      if (rawResult == null) {
        return OcrOutput(
          text: '',
          language: language,
          errorCode: 'OCR_FAILED',
          errorMessage: 'Native OCR bridge returned null response',
          processingMs: stopwatch.elapsedMilliseconds,
        );
      }

      final Map<String, dynamic> result = rawResult.cast<String, dynamic>();

      final String? errorCode = result['errorCode'] as String?;
      final String? errorMessage = result['errorMessage'] as String?;
      final String text = (result['text'] as String?) ?? '';
      final double? confidence = (result['confidence'] as num?)?.toDouble();
      final int processingMs = (result['processingMs'] as num?)?.toInt() ??
          stopwatch.elapsedMilliseconds;
      final int page = (result['page'] as num?)?.toInt() ?? 1;

      return OcrOutput(
        text: text,
        language: (result['language'] as String?) ?? language,
        page: page,
        confidence: confidence,
        processingMs: processingMs,
        errorCode: errorCode,
        errorMessage: errorMessage,
      );
    } on PlatformException catch (e) {
      stopwatch.stop();
      return OcrOutput(
        text: '',
        language: language,
        errorCode: e.code.isNotEmpty ? e.code : 'OCR_FAILED',
        errorMessage: e.message ?? e.details?.toString(),
        processingMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return OcrOutput(
        text: '',
        language: language,
        errorCode: 'OCR_FAILED',
        errorMessage: e.toString(),
        processingMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Disposes resources held by the ML Kit text recognizer.
  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
