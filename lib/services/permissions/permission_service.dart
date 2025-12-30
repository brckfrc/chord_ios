import 'package:permission_handler/permission_handler.dart';
import '../logging/log_service.dart';

/// Microphone permission service
class PermissionService {
  final LogService _logger = LogService('PermissionService');

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    try {
      _logger.info('Requesting microphone permission');
      final status = await Permission.microphone.request();
      
      if (status.isGranted) {
        _logger.info('Microphone permission granted');
        return true;
      } else if (status.isDenied) {
        _logger.warn('Microphone permission denied');
        return false;
      } else if (status.isPermanentlyDenied) {
        _logger.warn('Microphone permission permanently denied');
        return false;
      }
      
      return false;
    } catch (e) {
      _logger.error('Failed to request microphone permission: $e');
      return false;
    }
  }

  /// Check microphone permission status
  Future<PermissionStatus> checkMicrophonePermission() async {
    try {
      return await Permission.microphone.status;
    } catch (e) {
      _logger.error('Failed to check microphone permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Open app settings if permission denied
  Future<void> openSettings() async {
    try {
      _logger.info('Opening app settings');
      await openAppSettings();
    } catch (e) {
      _logger.error('Failed to open app settings: $e');
    }
  }
  
  /// Check if microphone permission is granted
  Future<bool> isMicrophoneGranted() async {
    final status = await checkMicrophonePermission();
    return status.isGranted;
  }
}
