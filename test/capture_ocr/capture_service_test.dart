import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lifevault/features/capture_ocr/capture_service.dart';

class FakeImagePicker implements ImagePicker {
  XFile? nextImage;
  LostDataResponse? nextLostData;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    return nextImage;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async {
    return nextLostData ?? LostDataResponse.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeImagePicker fakePicker;
  late CaptureService captureService;
  late Directory tempDir;
  late File validImage;

  setUp(() async {
    fakePicker = FakeImagePicker();
    captureService = CaptureService(picker: fakePicker);
    tempDir = await Directory.systemTemp.createTemp('lifevault_capture_test');

    validImage = File('${tempDir.path}/invoice.jpg');
    await validImage.writeAsBytes(<int>[0x12, 0x34, 0x56, 0x78]);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CaptureService', () {
    test('computeSha256 returns consistent hexadecimal digest', () async {
      final String hash1 = await captureService.computeSha256(validImage.path);
      final String hash2 = await captureService.computeSha256(validImage.path);

      expect(hash1, isNotEmpty);
      expect(hash1, equals(hash2));
      expect(hash1.length, 64);
    });

    test('captureFromCamera returns null when user cancels', () async {
      fakePicker.nextImage = null;
      final CapturedImageResult? result = await captureService.captureFromCamera();
      expect(result, isNull);
    });

    test('pickFromGallery returns null when user cancels', () async {
      fakePicker.nextImage = null;
      final CapturedImageResult? result = await captureService.pickFromGallery();
      expect(result, isNull);
    });

    test('captureFromCamera validates and returns CapturedImageResult on success', () async {
      fakePicker.nextImage = XFile(validImage.path);

      final CapturedImageResult? result = await captureService.captureFromCamera();

      expect(result, isNotNull);
      expect(result!.filePath, validImage.path);
      expect(result.fileSizeBytes, 4);
      expect(result.sha256Hash.length, 64);
      expect(result.wasRecoveredFromCrash, isFalse);
    });

    test('retrieveLostData returns null when no crash data is present', () async {
      fakePicker.nextLostData = LostDataResponse.empty();

      final CapturedImageResult? result = await captureService.retrieveLostData();
      expect(result, isNull);
    });

    test('retrieveLostData recovers image when crash data is present', () async {
      fakePicker.nextLostData = LostDataResponse(
        file: XFile(validImage.path),
      );

      final CapturedImageResult? result = await captureService.retrieveLostData();

      expect(result, isNotNull);
      expect(result!.filePath, validImage.path);
      expect(result.wasRecoveredFromCrash, isTrue);
    });

    test('throws FormatException for unsupported file extensions', () async {
      final File textFile = File('${tempDir.path}/test.txt');
      await textFile.writeAsString('hello');
      fakePicker.nextImage = XFile(textFile.path);

      expect(
        () => captureService.captureFromCamera(),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
