import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/download_job.dart';
import '../models/history_item.dart';
import '../models/song_info.dart';
import '../services/download_storage.dart';
import '../services/downloader_api.dart';

class ProgressScreen extends StatefulWidget {
  final String jobId;
  final SongInfo songInfo;
  final DownloaderApiService apiService;

  const ProgressScreen({
    super.key,
    required this.jobId,
    required this.songInfo,
    required this.apiService,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final DownloadStorageService _storageService = DownloadStorageService();
  Timer? _pollTimer;
  
  DownloadProgress _jobProgress = const DownloadProgress(
    jobId: '',
    status: 'queued',
    progress: 0.0,
    speed: '0B/s',
    eta: 0,
    filename: '',
  );

  bool _isDownloadingFile = false;
  double _fileDownloadProgress = 0.0;
  String? _errorMessage;
  String? _savedLocalPath;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) => _checkProgress());
    _checkProgress();
  }

  Future<void> _checkProgress() async {
    try {
      final progress = await widget.apiService.getJobProgress(widget.jobId);
      if (!mounted) return;

      setState(() {
        _jobProgress = progress;
      });

      if (progress.isCompleted) {
        _pollTimer?.cancel();
        _fetchFileLocally(progress.filename);
      } else if (progress.isFailed) {
        _pollTimer?.cancel();
        setState(() {
          _errorMessage = progress.error ?? 'Download job failed on backend.';
        });
      }
    } catch (e) {
      // Keep polling unless explicit cancel
    }
  }

  Future<void> _fetchFileLocally(String serverFilename) async {
    if (_isDownloadingFile || _savedLocalPath != null) return;
    setState(() {
      _isDownloadingFile = true;
      _errorMessage = null;
    });

    try {
      final downloadDir = await _storageService.getDownloadDirectory();
      final cleanFilename = serverFilename.isNotEmpty
          ? serverFilename
          : '${widget.songInfo.title.replaceAll(RegExp(r'[^\w\s\.-]'), '_')}.m4a';
      
      final savePath = '${downloadDir.path}/$cleanFilename';

      await widget.apiService.downloadFile(
        widget.jobId,
        savePath,
        onReceiveProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() {
              _fileDownloadProgress = received / total;
            });
          }
        },
      );

      final file = File(savePath);
      final fileSize = await file.exists() ? await file.length() : 0;

      final historyItem = HistoryItem(
        id: widget.jobId,
        title: widget.songInfo.title,
        artist: widget.songInfo.artist,
        thumbnail: widget.songInfo.thumbnail,
        filename: cleanFilename,
        localPath: savePath,
        downloadedAt: DateTime.now(),
        fileSize: fileSize,
      );

      await _storageService.addHistoryItem(historyItem);

      if (mounted) {
        setState(() {
          _isDownloadingFile = false;
          _savedLocalPath = savePath;
        });
      }

      // Cleanup job on backend
      widget.apiService.deleteJob(widget.jobId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloadingFile = false;
          _errorMessage = 'Failed saving file to device: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.songInfo;
    final isDone = _savedLocalPath != null;

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
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
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
                          child: song.thumbnail.isNotEmpty
                              ? Image.network(song.thumbnail, fit: BoxFit.cover)
                              : const ColoredBox(color: Color(0xFF24242B), child: Icon(Icons.music_note)),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.artist,
                              style: const TextStyle(color: Colors.white60, fontSize: 13),
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
                        Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 28),
                        SizedBox(width: 10),
                        Text(
                          'Download Complete!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saved to: $_savedLocalPath',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.library_music_rounded),
                      label: const Text('Back to Home'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ] else if (_errorMessage != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Go Back'),
                    ),
                  ] else ...[
                    Text(
                      _isDownloadingFile
                          ? 'Transferring audio file to device…'
                          : 'Processing backend download (${_jobProgress.status})…',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _isDownloadingFile
                          ? _fileDownloadProgress
                          : (_jobProgress.progress / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.white10,
                      color: const Color(0xFF8B5CF6),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isDownloadingFile
                              ? '${(_fileDownloadProgress * 100).toStringAsFixed(0)}%'
                              : '${_jobProgress.progress.toStringAsFixed(1)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (!_isDownloadingFile && _jobProgress.speed.isNotEmpty)
                          Text(
                            _jobProgress.speed,
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                      ],
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
