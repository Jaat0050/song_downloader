import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/download_job.dart';
import 'downloader_api.dart';

class DownloadManagerService extends ChangeNotifier {
  final DownloaderApiService apiService;
  final Map<String, DownloadProgress> _jobs = {};
  Timer? _pollTimer;
  bool _running = false;

  DownloadManagerService({required this.apiService});

  List<DownloadProgress> get jobs {
    final values = _jobs.values.toList();
    values.sort((a, b) => a.status == 'completed' ? 1 : -1);
    return List.unmodifiable(values);
  }

  List<DownloadProgress> get activeJobs =>
      jobs.where((job) => job.isActive).toList();
  List<DownloadProgress> get failedJobs =>
      jobs.where((job) => job.isFailed || job.isCancelled).toList();

  void start() {
    if (_running) return;
    _running = true;
    _refreshAll();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshAll(),
    );
  }

  Future<String> enqueue(String url) async {
    final jobId = await apiService.startDownload(url);
    try {
      final progress = await apiService.getJobProgress(jobId);
      _jobs[jobId] = progress;
    } catch (_) {
      _jobs[jobId] = DownloadProgress(
        jobId: jobId,
        status: 'queued',
        progress: 0,
        speed: '',
        eta: null,
        filename: '',
        url: url,
      );
    }
    notifyListeners();
    start();
    return jobId;
  }

  Future<void> refreshJob(String jobId) async {
    try {
      final progress = await apiService.getJobProgress(jobId);
      _jobs[jobId] = progress;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> cancel(String jobId) async {
    await apiService.cancelDownload(jobId);
    await refreshJob(jobId);
  }

  Future<void> retry(String jobId) async {
    final progress = await apiService.retryDownload(jobId);
    _jobs[jobId] = progress;
    notifyListeners();
    start();
  }

  Future<void> remove(String jobId) async {
    await apiService.deleteJob(jobId);
    _jobs.remove(jobId);
    notifyListeners();
  }

  Future<void> _refreshAll() async {
    if (!_running) return;
    try {
      final serverJobs = await apiService.listJobs();
      for (final job in serverJobs) {
        _jobs[job.jobId] = job;
      }
      notifyListeners();
    } catch (_) {
      // A temporary server restart should not destroy the local UI state.
    }
  }

  @override
  void dispose() {
    _running = false;
    _pollTimer?.cancel();
    super.dispose();
  }
}
