// lib/features/vault/data/models/vault_exceptions.dart
// Owner: Developer 3
//
// D3-private exception types. These are NOT part of the shared contracts;
// they are thrown internally and caught at service/repository boundaries.

/// Base exception for all vault storage failures.
class VaultException implements Exception {
  final String message;
  final Object? cause;

  const VaultException(this.message, {this.cause});

  @override
  String toString() => cause == null
      ? 'VaultException: $message'
      : 'VaultException: $message (caused by: $cause)';
}

/// Thrown when a document with the same SHA-256 hash already exists.
/// The caller can open the existing document or save a labeled copy.
class DuplicateDocumentException extends VaultException {
  final String existingId;
  final String sha256;

  const DuplicateDocumentException({
    required this.existingId,
    required this.sha256,
  }) : super(
            'Duplicate document: a record with the same content already exists.');
}

/// Thrown when a required file is missing (e.g., source image gone before copy).
class FileNotFoundException extends VaultException {
  final String path;

  const FileNotFoundException(this.path)
      : super('Required file not found: $path');
}

/// Thrown when the SQLite transaction fails part-way through.
/// The repository should have rolled back file copies before throwing this.
class VaultTransactionException extends VaultException {
  const VaultTransactionException(super.message, {super.cause});
}

/// Thrown when a notification cannot be scheduled (e.g., permission denied).
class NotificationScheduleException extends VaultException {
  final String documentId;

  const NotificationScheduleException({
    required this.documentId,
    required String reason,
  }) : super('Could not schedule notification for $documentId: $reason');
}
