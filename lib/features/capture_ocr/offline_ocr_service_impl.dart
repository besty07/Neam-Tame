import 'dart:io';
import 'package:flutter/services.dart';

import '../../core/contracts/models.dart';
import '../../core/contracts/services.dart';

/// Concrete implementation of [OfflineOcrService] connecting Flutter to the
/// native Kotlin Tesseract bridge (`LifeVaultOcrChannel`).
///
/// Owned exclusively by Developer 1 (Capture & OCR).
class OfflineOcrServiceImpl implements OfflineOcrService {
  OfflineOcrServiceImpl({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('lifevault/ocr');

  final MethodChannel _channel;

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

    try {
      final Map<dynamic, dynamic>? rawResult =
          await _channel.invokeMapMethod<dynamic, dynamic>(
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
      final int? processingMs = (result['processingMs'] as num?)?.toInt() ??
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
}
