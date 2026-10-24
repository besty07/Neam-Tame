import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifevault/core/contracts/models.dart';
import 'package:lifevault/features/capture_ocr/offline_ocr_service_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('lifevault/ocr');
  late OfflineOcrServiceImpl ocrService;
  late Directory tempDir;
  late File sampleImageFile;

  setUp(() async {
    ocrService = OfflineOcrServiceImpl(channel: channel);
    tempDir = await Directory.systemTemp.createTemp('lifevault_ocr_test');
    sampleImageFile = File('${tempDir.path}/test_doc.jpg');
    await sampleImageFile.writeAsBytes(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00]);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('OfflineOcrServiceImpl', () {
    test('returns DECODE_FAILED when file does not exist', () async {
      final OcrOutput output = await ocrService.recognizeImage(
        '${tempDir.path}/non_existent.jpg',
      );

      expect(output.isSuccess, isFalse);
      expect(output.errorCode, 'DECODE_FAILED');
      expect(output.errorMessage, contains('does not exist'));
      expect(output.text, isEmpty);
    });

    test('returns DECODE_FAILED when path is empty', () async {
      final OcrOutput output = await ocrService.recognizeImage('   ');

      expect(output.isSuccess, isFalse);
      expect(output.errorCode, 'DECODE_FAILED');
      expect(output.text, isEmpty);
    });

    test('successfully parses native OCR response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        expect(methodCall.method, 'recognizeImage');
        expect(methodCall.arguments['path'], sampleImageFile.path);
        expect(methodCall.arguments['language'], 'eng');

        return <String, dynamic>{
          'text': 'POLICY EXPIRY DATE 24/11/2026\nPREMIUM PAID',
          'language': 'eng',
          'page': 1,
          'confidence': 89.5,
          'processingMs': 320,
          'errorCode': null,
          'errorMessage': null,
        };
      });

      final OcrOutput output =
          await ocrService.recognizeImage(sampleImageFile.path);

      expect(output.isSuccess, isTrue);
      expect(output.errorCode, isNull);
      expect(output.text, contains('POLICY EXPIRY DATE 24/11/2026'));
      expect(output.confidence, 89.5);
      expect(output.processingMs, 320);
      expect(output.page, 1);
      expect(output.language, 'eng');
    });

    test('maps MODEL_MISSING error code from native bridge', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return <String, dynamic>{
          'text': '',
          'language': 'eng',
          'page': 1,
          'confidence': null,
          'processingMs': 15,
          'errorCode': 'MODEL_MISSING',
          'errorMessage': 'Failed to unpack or verify OCR model',
        };
      });

      final OcrOutput output =
          await ocrService.recognizeImage(sampleImageFile.path);

      expect(output.isSuccess, isFalse);
      expect(output.errorCode, 'MODEL_MISSING');
      expect(output.errorMessage, contains('OCR model'));
      expect(output.text, isEmpty);
    });

    test('maps OCR_FAILED error code from native bridge', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return <String, dynamic>{
          'text': '',
          'language': 'eng',
          'page': 1,
          'confidence': null,
          'processingMs': 45,
          'errorCode': 'OCR_FAILED',
          'errorMessage': 'Native Tesseract init error',
        };
      });

      final OcrOutput output =
          await ocrService.recognizeImage(sampleImageFile.path);

      expect(output.isSuccess, isFalse);
      expect(output.errorCode, 'OCR_FAILED');
      expect(output.errorMessage, contains('Tesseract'));
    });

    test('gracefully handles PlatformException without throwing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'CHANNEL_CRASH',
          message: 'Android native exception occurred',
        );
      });

      final OcrOutput output =
          await ocrService.recognizeImage(sampleImageFile.path);

      expect(output.isSuccess, isFalse);
      expect(output.errorCode, 'CHANNEL_CRASH');
      expect(output.errorMessage, 'Android native exception occurred');
      expect(output.text, isEmpty);
    });

    test('handles null native response safely', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return null;
      });

      final OcrOutput output =
          await ocrService.recognizeImage(sampleImageFile.path);

      expect(output.isSuccess, isFalse);
      expect(output.errorCode, 'OCR_FAILED');
      expect(output.errorMessage, contains('null response'));
    });
  });
}
