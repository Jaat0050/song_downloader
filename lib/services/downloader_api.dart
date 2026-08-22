import 'package:dio/dio.dart';
import '../models/download_job.dart';
import '../models/song_info.dart';

class DownloaderApiException implements Exception {
  final String message;
  final String? code;

  DownloaderApiException(this.message, {this.code});

  @override
  String toString() => message;
}

class DownloaderApiService {
  final Dio _dio;
  String _baseUrl;

  DownloaderApiService({String baseUrl = 'http://10.0.2.2:5000'})
      : _baseUrl = baseUrl,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
        ));

  String get baseUrl => _baseUrl;

  void updateBaseUrl(String newUrl) {
    var trimmed = newUrl.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    _baseUrl = trimmed;
  }

  String _endpoint(String path) => '$_baseUrl$path';

  Future<SongInfo> fetchSongInfo(String url) async {
    try {
      final response = await _dio.post(
        _endpoint('/api/audio/info'),
        data: {'url': url.trim()},
      );

      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true && data['data'] != null) {
        return SongInfo.fromJson(Map<String, dynamic>.from(data['data'] as Map));
      } else {
        final error = data['error'] as Map<String, dynamic>?;
        throw DownloaderApiException(
          error?['message'] as String? ?? 'Failed to fetch song info',
          code: error?['code'] as String?,
        );
      }
    } on DioException catch (e) {
      final errorMsg = _extractDioError(e);
      throw DownloaderApiException(errorMsg);
    }
  }

  Future<String> startDownload(String url) async {
    try {
      final response = await _dio.post(
        _endpoint('/api/audio/download'),
        data: {'url': url.trim()},
      );

      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true && data['job_id'] != null) {
        return data['job_id'] as String;
      } else {
        final error = data['error'] as Map<String, dynamic>?;
        throw DownloaderApiException(
          error?['message'] as String? ?? 'Failed to start download job',
          code: error?['code'] as String?,
        );
      }
    } on DioException catch (e) {
      throw DownloaderApiException(_extractDioError(e));
    }
  }

  Future<DownloadProgress> getJobProgress(String jobId) async {
    try {
      final response = await _dio.get(_endpoint('/api/audio/progress/$jobId'));
      final data = response.data as Map<String, dynamic>;

      if (data['success'] == true && data['data'] != null) {
        return DownloadProgress.fromJson(Map<String, dynamic>.from(data['data'] as Map));
      } else {
        final error = data['error'] as Map<String, dynamic>?;
        throw DownloaderApiException(
          error?['message'] as String? ?? 'Failed to check progress',
          code: error?['code'] as String?,
        );
      }
    } on DioException catch (e) {
      throw DownloaderApiException(_extractDioError(e));
    }
  }

  Future<void> downloadFile(
    String jobId,
    String savePath, {
    required void Function(int received, int total) onReceiveProgress,
  }) async {
    try {
      await _dio.download(
        _endpoint('/api/audio/file/$jobId'),
        savePath,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw DownloaderApiException(_extractDioError(e));
    }
  }

  Future<void> deleteJob(String jobId) async {
    try {
      await _dio.delete(_endpoint('/api/audio/job/$jobId'));
    } catch (_) {
      // Best effort deletion on backend
    }
  }

  String _extractDioError(DioException e) {
    if (e.response != null && e.response?.data is Map) {
      final data = e.response!.data as Map;
      final error = data['error'] as Map?;
      if (error != null && error['message'] != null) {
        return error['message'] as String;
      }
    }
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Check backend URL and server state.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Could not connect to backend at $_baseUrl. Verify the host address and server.';
    }
    return e.message ?? 'Network error occurred';
  }
}
