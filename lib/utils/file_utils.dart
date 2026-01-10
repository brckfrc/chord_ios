import 'dart:io';
import '../core/config/app_config.dart';

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
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt': 'text/plain',
      'csv': 'text/csv',
      'zip': 'application/zip',
      'rar': 'application/x-rar-compressed',
    };

    return mimeTypes[extension.toLowerCase()];
  }

  /// Transform MinIO URL for platform compatibility
  /// - Development mode on Android: replaces `minio:9000` with `10.0.2.2:9000` (emulator)
  /// - Production mode: uses reverse proxy path `/uploads` instead of direct port access
  ///
  /// Example:
  /// - Input: `http://minio:9000/chord-uploads/file.mp4`
  /// - Output (Android dev): `http://10.0.2.2:9000/chord-uploads/file.mp4`
  /// - Output (Production): `https://chord.borak.dev/uploads/chord-uploads/file.mp4`
  /// - Output (other): `http://minio:9000/chord-uploads/file.mp4` (unchanged)
  static String transformMinioUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Check if this is a MinIO URL
      if (uri.host == 'minio' && uri.port == 9000) {
        if (AppConfig.isDevelopment && Platform.isAndroid) {
          // Development mode on Android: use 10.0.2.2 for emulator
          final transformedUri = uri.replace(host: '10.0.2.2');
          final transformedUrl = transformedUri.toString();
          print('🔄 [FileUtils] URL transform (dev/Android): $url -> $transformedUrl');
          return transformedUrl;
        } else if (AppConfig.isProduction) {
          // Production mode: use reverse proxy path /uploads
          // http://minio:9000/chord-uploads/... -> https://chord.borak.dev/uploads/chord-uploads/...
          final transformedUri = Uri(
            scheme: 'https',
            host: 'chord.borak.dev',
            path: '/uploads${uri.path}',
            query: uri.query,
            fragment: uri.fragment,
          );
          final transformedUrl = transformedUri.toString();
          print('🔄 [FileUtils] URL transform (production): $url -> $transformedUrl');
          return transformedUrl;
        }
      }
      
      return url;
    } catch (e) {
      print('⚠️ [FileUtils] Failed to parse URL: $url, error: $e');
      return url;
    }
  }
}
