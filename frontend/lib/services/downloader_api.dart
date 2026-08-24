import 'dart:io';
import 'package:dio/dio.dart';
import '../models/download_job.dart';
import '../models/song_info.dart';

class DownloaderApiException implements Exception {
  final String message;
  final String? code;
  DownloaderApiException(this.message, {this.code});
  @override String toString() => message;
}

class ServerHealth {
  final bool healthy; final String status; final String server; final String host; final int? port;
  final int uptimeSeconds; final DateTime? startedAt; final String pythonVersion; final String ytDlpVersion;
  final String audioFormat; final String ffmpeg; final int storageBytes; final int diskFreeBytes;
  final int diskTotalBytes; final bool storageReady; final Map<String,int> jobs; final int workerCount; final String workerStatus;
  const ServerHealth({required this.healthy,required this.status,required this.server,required this.host,required this.port,required this.uptimeSeconds,required this.startedAt,required this.pythonVersion,required this.ytDlpVersion,required this.audioFormat,required this.ffmpeg,required this.storageBytes,required this.diskFreeBytes,required this.diskTotalBytes,required this.storageReady,required this.jobs,required this.workerCount,required this.workerStatus});
  factory ServerHealth.fromJson(Map<String,dynamic> json) {
    final rawJobs=Map<String,dynamic>.from(json['jobs'] as Map? ?? {}); final rawWorkers=Map<String,dynamic>.from(json['worker_pool'] as Map? ?? {});
    return ServerHealth(healthy:json['success']==true&&json['status']=='ok',status:json['status']?.toString()??'unknown',server:json['server']?.toString()??'unknown',host:json['host']?.toString()??'unknown',port:(json['port'] as num?)?.toInt(),uptimeSeconds:(json['uptime_seconds'] as num?)?.toInt()??0,startedAt:DateTime.tryParse(json['started_at']?.toString()??''),pythonVersion:json['python_version']?.toString()??'unknown',ytDlpVersion:json['yt_dlp']?.toString()??'unknown',audioFormat:json['audio_format']?.toString()??'unknown',ffmpeg:json['ffmpeg']?.toString()??'unknown',storageBytes:(json['download_storage_bytes'] as num?)?.toInt()??0,diskFreeBytes:(json['disk_free_bytes'] as num?)?.toInt()??0,diskTotalBytes:(json['disk_total_bytes'] as num?)?.toInt()??0,storageReady:json['storage_ready']!=false,jobs:rawJobs.map((k,v)=>MapEntry(k,(v as num?)?.toInt()??0)),workerCount:(rawWorkers['max_workers'] as num?)?.toInt()??0,workerStatus:rawWorkers['status']?.toString()??'unknown');
  }
}

class DownloaderApiService {
  final Dio _dio; String _baseUrl;
  DownloaderApiService({required String baseUrl}):_baseUrl=_normalizeBaseUrl(baseUrl),_dio=Dio(BaseOptions(connectTimeout:const Duration(seconds:10),receiveTimeout:const Duration(seconds:120),sendTimeout:const Duration(seconds:30)));
  String get baseUrl=>_baseUrl;
  static String _normalizeBaseUrl(String value){var t=value.trim();while(t.endsWith('/'))t=t.substring(0,t.length-1);return t;}
  String _endpoint(String path)=>'$_baseUrl$path';
  Future<ServerHealth> fetchHealth() async {try{final r=await _dio.get(_endpoint('/api/health'));final h=ServerHealth.fromJson(Map<String,dynamic>.from(r.data as Map));if(!h.healthy)throw DownloaderApiException('Local downloader server is not ready.');return h;}on DioException catch(e){throw DownloaderApiException(_extractDioError(e));}}
  Future<void> checkHealth()=>fetchHealth();
  Future<SongInfo> fetchSongInfo(String url) async {try{final r=await _dio.post(_endpoint('/api/audio/info'),data:{'url':url.trim()});final d=r.data as Map<String,dynamic>;if(d['success']==true&&d['data']!=null)return SongInfo.fromJson(Map<String,dynamic>.from(d['data'] as Map));final e=d['error'] as Map<String,dynamic>?;throw DownloaderApiException(e?['message'] as String???'Failed to fetch song info',code:e?['code'] as String?);}on DioException catch(e){throw DownloaderApiException(_extractDioError(e));}}
  Future<String> startDownload(String url) async {try{final r=await _dio.post(_endpoint('/api/audio/download'),data:{'url':url.trim()});final d=r.data as Map<String,dynamic>;if(d['success']==true&&d['job_id']!=null)return d['job_id'] as String;final e=d['error'] as Map<String,dynamic>?;throw DownloaderApiException(e?['message'] as String???'Failed to start download job',code:e?['code'] as String?);}on DioException catch(e){throw DownloaderApiException(_extractDioError(e));}}
  Future<DownloadProgress> getJobProgress(String jobId) async {try{final r=await _dio.get(_endpoint('/api/audio/progress/$jobId'));final d=r.data as Map<String,dynamic>;if(d['success']==true&&d['data']!=null)return DownloadProgress.fromJson(Map<String,dynamic>.from(d['data'] as Map));final e=d['error'] as Map<String,dynamic>?;throw DownloaderApiException(e?['message'] as String???'Failed to check progress',code:e?['code'] as String?);}on DioException catch(e){throw DownloaderApiException(_extractDioError(e));}}
  Future<void> cancelDownload(String jobId) async {try{final r=await _dio.post(_endpoint('/api/audio/cancel/$jobId'));if(r.data is Map&&(r.data['success']!=true)){final e=r.data['error'] as Map?;throw DownloaderApiException(e?['message']?.toString()??'Unable to cancel download');}}on DioException catch(e){throw DownloaderApiException(_extractDioError(e));}}
  Future<DownloadProgress> retryDownload(String jobId) async {try{final r=await _dio.post(_endpoint('/api/audio/retry/$jobId'));final d=r.data as Map<String,dynamic>;if(d['success']==true&&d['data']!=null)return DownloadProgress.fromJson(Map<String,dynamic>.from(d['data'] as Map));final e=d['error'] as Map<String,dynamic>?;throw DownloaderApiException(e?['message'] as String???'Unable to retry download',code:e?['code'] as String?);}on DioException catch(e){throw DownloaderApiException(_extractDioError(e));}}
  Future<void> downloadFile(String jobId,String savePath,{required void Function(int received,int total) onReceiveProgress}) async {final tempPath='$savePath.part',tempFile=File(tempPath),destinationFile=File(savePath);try{if(await tempFile.exists())await tempFile.delete();await _dio.download(_endpoint('/api/audio/file/$jobId'),tempPath,deleteOnError:true,onReceiveProgress:onReceiveProgress);if(!await tempFile.exists())throw DownloaderApiException('Server returned the audio, but the temporary file was not created.');if(await destinationFile.exists())await destinationFile.delete();await tempFile.rename(savePath);}on DioException catch(e){try{if(await tempFile.exists())await tempFile.delete();}catch(_){}throw DownloaderApiException(_extractDioError(e));}on FileSystemException catch(e){try{if(await tempFile.exists())await tempFile.delete();}catch(_){}throw DownloaderApiException('Could not save the audio file: ${e.message}');}}
  Future<void> deleteJob(String jobId) async {try{await _dio.delete(_endpoint('/api/audio/job/$jobId'));}catch(_) {}}
  String _extractDioError(DioException e){if(e.response?.data is Map){final d=e.response!.data as Map;final err=d['error'] as Map?;if(err?['message']!=null)return err!['message'].toString();}if(e.response?.statusCode==507)return'Not enough free device storage. Please free some space and try again.';if(e.response?.statusCode==429)return'Too many downloads are queued. Please wait for one to finish.';if(e.type==DioExceptionType.connectionTimeout||e.type==DioExceptionType.receiveTimeout)return'Local downloader server timed out.';if(e.type==DioExceptionType.connectionError)return'Could not connect to the local downloader server.';return e.message??'Network error occurred';}
}
