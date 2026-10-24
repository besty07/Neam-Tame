import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Result of capturing or importing a document image.
class CapturedImageResult {
  const CapturedImageResult({
    required this.filePath,
    required this.sha256Hash,
    required this.fileSizeBytes,
    this.wasRecoveredFromCrash = false,
  });

  /// Path to the local image (cache/temp directory).
  final String filePath;

  /// SHA-256 digest for duplicate detection.
  final String sha256Hash;

  /// Size of the file in bytes.
  final int fileSizeBytes;

  /// True if recovered via [ImagePicker.retrieveLostData] after process death.
  final bool wasRecoveredFromCrash;
}

/// Service handling document capture from camera/gallery, lost data recovery,
/// image validation, and persistent storage copying.
///
/// Owned exclusively by Developer 1 (Capture & OCR).
class CaptureService {
  CaptureService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Maximum allowed image file size (12 MB per Section 5 of Master Plan).
  static const int maxFileSizeBytes = 12 * 1024 * 1024;

  /// Supported image extensions for decoding.
  static const Set<String> supportedExtensions = <String>{
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.bmp',
  };

  /// Captures a new document using the device camera.
  ///
  /// Returns `null` if the user cancels.
  Future<CapturedImageResult?> captureFromCamera({
    double? maxWidth = 2400,
    double? maxHeight = 2400,
    int? imageQuality = 90,
  }) async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    if (file == null) {
      return null;
    }
    return _validateAndWrap(file.path);
  }

  /// Imports an existing document image from the device gallery.
  ///
  /// Returns `null` if the user cancels.
  Future<CapturedImageResult?> pickFromGallery({
    double? maxWidth = 2400,
    double? maxHeight = 2400,
    int? imageQuality = 90,
  }) async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    if (file == null) {
      return null;
    }
    return _validateAndWrap(file.path);
  }

  /// Recovers lost capture data on Android startup if the Activity was
  /// destroyed while camera was open.
  Future<CapturedImageResult?> retrieveLostData() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null) {
        return null;
      }
      return _validateAndWrap(
        response.file!.path,
        wasRecoveredFromCrash: true,
      );
    } catch (_) {
      // In non-Android environments or if no lost data exists, fail safely.
      return null;
    }
  }

  /// Copies verified temporary image to app-private persistent directory
  /// under `<appDocDir>/vault_documents/<documentId>.<ext>`.
  Future<String> persistToAppStorage(
    String tempPath,
    String documentId,
  ) async {
    final File tempFile = File(tempPath);
    if (!tempFile.existsSync()) {
      throw StateError('Source temporary file does not exist: $tempPath');
    }

    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory vaultDir = Directory(p.join(appDir.path, 'vault_documents'));
    if (!vaultDir.existsSync()) {
      await vaultDir.create(recursive: true);
    }

    final String extension = p.extension(tempPath).toLowerCase();
    final String targetPath = p.join(vaultDir.path, '$documentId$extension');
    await tempFile.copy(targetPath);
    return targetPath;
  }

  /// Computes SHA-256 hash of a file at [filePath].
  Future<String> computeSha256(String filePath) async {
    final File file = File(filePath);
    final List<int> bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  /// Validates file existence, format, and size budget.
  Future<CapturedImageResult> _validateAndWrap(
    String filePath, {
    bool wasRecoveredFromCrash = false,
  }) async {
    final File file = File(filePath);
    if (!await file.exists()) {
      throw StateError('Captured image file not found at: $filePath');
    }

    final String ext = p.extension(filePath).toLowerCase();
    if (!supportedExtensions.contains(ext)) {
      throw FormatException(
        'Unsupported image extension: $ext. Allowed: $supportedExtensions',
      );
    }

    final int size = await file.length();
    if (size > maxFileSizeBytes) {
      throw StateError(
        'Image file size ($size bytes) exceeds maximum allowed ($maxFileSizeBytes bytes).',
      );
    }

    final String hash = await computeSha256(filePath);

    return CapturedImageResult(
      filePath: filePath,
      sha256Hash: hash,
      fileSizeBytes: size,
      wasRecoveredFromCrash: wasRecoveredFromCrash,
    );
  }
}
