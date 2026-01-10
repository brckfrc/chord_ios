import 'dart:io';
import 'package:dio/dio.dart';
import '../services/api/api_client.dart';
import '../models/upload/upload_response_dto.dart';
import '../utils/file_utils.dart';

/// Upload repository for file upload operations
class UploadRepository {
  final ApiClient _apiClient = ApiClient();

  /// Upload a file to the server
  /// Returns UploadResponseDto with file information
  /// Throws exception if upload fails
  Future<UploadResponseDto> uploadFile(
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    // Validate file size (25MB limit)
    if (!FileUtils.validateFileSize(file)) {
      throw Exception('File size exceeds 25MB limit');
    }

    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      final response = await _apiClient.dio.post(
        '/Upload',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
        onSendProgress: onProgress != null
            ? (sent, total) {
                onProgress(sent, total);
              }
            : null,
      );

      return UploadResponseDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMessage = e.response?.data['message'] ?? 'Upload failed';
        throw Exception(errorMessage);
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Upload failed: ${e.toString()}');
    }
  }

  /// Delete a file from the server
  /// Throws exception if deletion fails
  Future<void> deleteFile(String fileUrl) async {
    try {
      await _apiClient.delete(
        '/Upload',
        queryParameters: {'fileUrl': fileUrl},
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMessage = e.response?.data['message'] ?? 'Delete failed';
        throw Exception(errorMessage);
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Delete failed: ${e.toString()}');
    }
  }
}
