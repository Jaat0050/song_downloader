import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/download_job.dart';
import '../models/history_item.dart';
import '../models/song_info.dart';
import '../services/download_storage.dart';
import '../services/download_manager_service.dart';
import '../services/downloader_api.dart';

class ProgressScreen extends StatefulWidget {
  final String jobId;
  final SongInfo songInfo;
  final DownloaderApiService apiService;
  final DownloadManagerService downloadManager;
  final VoidCallback onOpenLibrary;
  const ProgressScreen({
    super.key,
    required this.jobId,
    required this.songInfo,
    required this.apiService,
    required this.downloadManager,
    required this.onOpenLibrary,
  });
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final DownloadStorageService _storageService = DownloadStorageService();
  Timer? _filePollTimer;
  DownloadProgress? _jobProgress;
  bool _isDownloadingFile = false;
  double _fileDownloadProgress = 0;
  String? _errorMessage;
  String? _savedLocalPath;
  bool _savingStarted = false;

  @override
  void initState() {
    super.initState();
    widget.downloadManager.addListener(_onManagerChanged);
    widget.downloadManager.refreshJob(widget.jobId);
  }

  void _onManagerChanged() {
    if (!mounted) return;
    final match = widget.downloadManager.jobs.where(
      (job) => job.jobId == widget.jobId,
    );
    if (match.isNotEmpty) {
      final progress = match.first;
      setState(() => _jobProgress = progress);
      if (progress.isCompleted) _saveCompletedFile(progress);
      if (progress.isFailed || progress.isCancelled) {
        setState(
          () =>
              _errorMessage =
                  progress.error ??
                  (progress.isCancelled
                      ? 'Download cancelled.'
                      : 'Download failed.'),
        );
      }
    }
  }

  Future<void> _saveCompletedFile(DownloadProgress progress) async {
    if (_savingStarted || _savedLocalPath != null) return;
    _savingStarted = true;
    setState(() {
      _isDownloadingFile = true;
      _errorMessage = null;
    });
    try {
      final downloadDir = await _storageService.getDownloadDirectory();
      final cleanFilename =
          progress.filename.isNotEmpty
              ? progress.filename
              : '${widget.songInfo.title.replaceAll(RegExp(r'[^\w\s\.-]'), '_')}.mp3';
      final savePath = '${downloadDir.path}/$cleanFilename';
      await widget.apiService.downloadFile(
        widget.jobId,
        savePath,
        onReceiveProgress: (received, total) {
          if (mounted && total > 0)
            setState(() => _fileDownloadProgress = received / total);
        },
      );
      final file = File(savePath);
      final fileSize = await file.exists() ? await file.length() : 0;
      await _storageService.addHistoryItem(
        HistoryItem(
          id: widget.jobId,
          title: widget.songInfo.title,
          artist: widget.songInfo.artist,
          thumbnail: widget.songInfo.thumbnail,
          filename: cleanFilename,
          localPath: savePath,
          downloadedAt: DateTime.now(),
          fileSize: fileSize,
        ),
      );
      if (!mounted) return;
      setState(() {
        _isDownloadingFile = false;
        _savedLocalPath = savePath;
      });
      await widget.apiService.deleteJob(widget.jobId);
    } catch (e) {
      _savingStarted = false;
      if (mounted)
        setState(() {
          _isDownloadingFile = false;
          _errorMessage = 'Failed saving file to device: $e';
        });
    }
  }

  Future<void> _cancel() async {
    try {
      await widget.downloadManager.cancel(widget.jobId);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _retry() async {
    try {
      setState(() {
        _errorMessage = null;
        _savingStarted = false;
      });
      await widget.downloadManager.retry(widget.jobId);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    }
  }

  void _goToLibrary() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onOpenLibrary();
  }

  @override
  void dispose() {
    widget.downloadManager.removeListener(_onManagerChanged);
    _filePollTimer?.cancel();
    super.dispose();
  }

  String _statusText(DownloadProgress job) {
    switch (job.status) {
      case 'queued':
        return 'Waiting in download queue…';
      case 'extracting':
        return 'Preparing audio…';
      case 'downloading':
        return 'Downloading audio…';
      case 'processing':
      case 'converting':
        return 'Converting to MP3…';
      case 'saving':
        return 'Saving audio…';
      case 'cancelled':
        return 'Download cancelled';
      case 'failed':
        return 'Download failed';
      default:
        return job.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.songInfo;
    final job =
        _jobProgress ??
        const DownloadProgress(
          jobId: '',
          status: 'queued',
          progress: 0,
          speed: '',
          eta: null,
          filename: '',
        );
    final isDone = _savedLocalPath != null;
    final failed = job.isFailed || job.isCancelled;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Status'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF15151B),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: .07)),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 70,
                          height: 70,
                          child:
                              song.thumbnail.isNotEmpty
                                  ? Image.network(
                                    song.thumbnail,
                                    fit: BoxFit.cover,
                                  )
                                  : const ColoredBox(
                                    color: Color(0xFF24242B),
                                    child: Icon(Icons.music_note),
                                  ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.artist,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (isDone) ...[
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.greenAccent,
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Download Complete!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saved to: $_savedLocalPath',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _goToLibrary,
                      icon: const Icon(Icons.library_music_rounded),
                      label: const Text('Go to Library'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ] else if (failed) ...[
                    Row(
                      children: [
                        Icon(
                          job.isCancelled
                              ? Icons.cancel_outlined
                              : Icons.error_outline_rounded,
                          color: Colors.redAccent,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage ?? 'Download failed.',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Back'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      _isDownloadingFile
                          ? 'Transferring audio file to device…'
                          : _statusText(job),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value:
                          _isDownloadingFile
                              ? _fileDownloadProgress
                              : (job.progress / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.white10,
                      minHeight: 8,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isDownloadingFile
                              ? '${(_fileDownloadProgress * 100).toStringAsFixed(0)}%'
                              : '${job.progress.toStringAsFixed(1)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (!_isDownloadingFile && job.speed.isNotEmpty)
                          Text(
                            job.speed,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: _cancel,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel Download'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
