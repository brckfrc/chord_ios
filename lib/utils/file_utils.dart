import 'dart:io';

/// File utility functions
class FileUtils {
  /// Get file type from MIME type
  /// Returns "image", "video", or "document"
  static String? getFileType(String? mimeType) {
    if (mimeType == null) return null;

    if (mimeType.startsWith('image/')) {
      return 'image';
    } else if (mimeType.startsWith('video/')) {
      return 'video';
    } else {
      return 'document';
    }
  }

  /// Format file size in bytes to human-readable string
  /// Example: 1024 -> "1.0 KB", 1048576 -> "1.0 MB"
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Validate file size (max 25MB)
  /// Returns true if file size is valid, false otherwise
  static bool validateFileSize(File file, {int maxSizeMB = 25}) {
    final fileSize = file.lengthSync();
    final maxSizeBytes = maxSizeMB * 1024 * 1024;
    return fileSize <= maxSizeBytes;
  }

  /// Get file extension from file name
  /// Example: "image.jpg" -> "jpg"
  static String? getFileExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) return null;
    return parts.last.toLowerCase();
  }

  /// Get MIME type from file extension
  /// Returns MIME type string or null
  static String? getMimeTypeFromExtension(String? extension) {
    if (extension == null) return null;

    final mimeTypes = {
      // Images
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      // Videos
      'mp4': 'video/mp4',
      'webm': 'video/webm',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      // Documents
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt': 'text/plain',
      'csv': 'text/csv',
      'zip': 'application/zip',
      'rar': 'application/x-rar-compressed',
    };

    return mimeTypes[extension.toLowerCase()];
  }
}
