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

  DownloaderApiService({required String baseUrl})
      : _baseUrl = _normalizeBaseUrl(baseUrl),
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 30),
        ));

  String get baseUrl => _baseUrl;

  static String _normalizeBaseUrl(String value) {
    var trimmed = value.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String _endpoint(String path) => '$_baseUrl$path';

  Future<void> checkHealth() async {
    try {
      final response = await _dio.get(_endpoint('/api/health'));
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true || data['status'] != 'ok') {
        throw DownloaderApiException('Local downloader server is not ready.');
      }
    } on DioException catch (e) {
      throw DownloaderApiException(_extractDioError(e));
    }
  }

  Future<SongInfo> fetchSongInfo(String url) async {
    try {
      final response = await _dio.post(
        _endpoint('/api/audio/info'),
        data: {'url': url.trim()},
      );

      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true && data['data'] != null) {
        return SongInfo.fromJson(Map<String, dynamic>.from(data['data'] as Map));
      }
      final error = data['error'] as Map<String, dynamic>?;
      throw DownloaderApiException(
        error?['message'] as String? ?? 'Failed to fetch song info',
        code: error?['code'] as String?,
      );
    } on DioException catch (e) {
      throw DownloaderApiException(_extractDioError(e));
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
      }
      final error = data['error'] as Map<String, dynamic>?;
      throw DownloaderApiException(
        error?['message'] as String? ?? 'Failed to start download job',
        code: error?['code'] as String?,
      );
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
      }
      final error = data['error'] as Map<String, dynamic>?;
      throw DownloaderApiException(
        error?['message'] as String? ?? 'Failed to check progress',
        code: error?['code'] as String?,
      );
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
      // Best effort cleanup.
    }
  }

  String _extractDioError(DioException e) {
    if (e.response?.data is Map) {
      final data = e.response!.data as Map;
      final error = data['error'] as Map?;
      if (error?['message'] != null) {
        return error!['message'] as String;
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Local downloader server timed out.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Could not connect to the local downloader server.';
    }
    return e.message ?? 'Network error occurred';
  }
}
