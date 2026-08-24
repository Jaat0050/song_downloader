import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/download_job.dart';
import '../models/history_item.dart';
import '../models/song_info.dart';
import '../services/download_storage.dart';
import '../services/download_manager_service.dart';
import '../services/downloader_api.dart';
import '../theme/neumorphic_widgets.dart';

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
  final _storage = DownloadStorageService();
  DownloadProgress? _job;
  bool _saving = false;
  double _fileProgress = 0;
  String? _error;
  String? _savedPath;
  @override
  void initState() {
    super.initState();
    widget.downloadManager.addListener(_changed);
    widget.downloadManager.refreshJob(widget.jobId);
  }

  void _changed() {
    if (!mounted) return;
    final matches = widget.downloadManager.jobs.where(
      (j) => j.jobId == widget.jobId,
    );
    if (matches.isEmpty) return;
    final p = matches.first;
    setState(() => _job = p);
    if (p.isCompleted) _save(p);
    if (p.isFailed || p.isCancelled)
      setState(
        () =>
            _error =
                p.error ??
                (p.isCancelled ? 'Download cancelled.' : 'Download failed.'),
      );
  }

  Future<void> _save(DownloadProgress p) async {
    if (_saving || _savedPath != null) return;
    _saving = true;
    setState(() {
      _error = null;
    });
    try {
      final dir = await _storage.getDownloadDirectory();
      final name =
          p.filename.isNotEmpty
              ? p.filename
              : '${widget.songInfo.title.replaceAll(RegExp(r'[^\w\s\.-]'), '_')}.mp3';
      final path = '${dir.path}/$name';
      await widget.apiService.downloadFile(
        widget.jobId,
        path,
        onReceiveProgress: (r, t) {
          if (mounted && t > 0) setState(() => _fileProgress = r / t);
        },
      );
      final file = File(path);
      final size = await file.exists() ? await file.length() : 0;
      await _storage.addHistoryItem(
        HistoryItem(
          id: widget.jobId,
          title: widget.songInfo.title,
          artist: widget.songInfo.artist,
          thumbnail: widget.songInfo.thumbnail,
          filename: name,
          localPath: path,
          downloadedAt: DateTime.now(),
          fileSize: size,
        ),
      );
      if (!mounted) return;
      setState(() => _savedPath = path);
      await widget.apiService.deleteJob(widget.jobId);
    } catch (e) {
      _saving = false;
      if (mounted) setState(() => _error = 'Failed saving file to device: $e');
    }
  }

  Future<void> _cancel() async {
    try {
      await widget.downloadManager.cancel(widget.jobId);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _retry() async {
    try {
      setState(() => _error = null);
      await widget.downloadManager.retry(widget.jobId);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _library() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.onOpenLibrary();
  }

  @override
  void dispose() {
    widget.downloadManager.removeListener(_changed);
    super.dispose();
  }

  String _status(String s) {
    switch (s) {
      case 'queued':
        return 'Waiting in queue…';
      case 'extracting':
        return 'Preparing audio…';
      case 'downloading':
        return 'Downloading audio…';
      case 'processing':
      case 'converting':
        return 'Converting to MP3…';
      case 'saving':
        return 'Saving audio…';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.songInfo;
    final j =
        _job ??
        const DownloadProgress(
          jobId: '',
          status: 'queued',
          progress: 0,
          speed: '',
          eta: null,
          filename: '',
        );
    final done = _savedPath != null;
    final failed = j.isFailed || j.isCancelled;
    final progress =
        _saving ? _fileProgress : (j.progress / 100).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Download Status')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          children: [
            NeuSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 66,
                          height: 66,
                          child:
                              s.thumbnail.isEmpty
                                  ? const ColoredBox(
                                    color: NeuTheme.input,
                                    child: Icon(Icons.music_note_rounded),
                                  )
                                  : Image.network(
                                    s.thumbnail,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) => const ColoredBox(
                                          color: NeuTheme.input,
                                          child: Icon(Icons.music_note_rounded),
                                        ),
                                  ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.artist,
                              style: const TextStyle(
                                color: NeuTheme.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (done) ...[
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: NeuTheme.success,
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Download Complete',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: NeuTheme.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saved to device',
                      style: const TextStyle(color: NeuTheme.muted),
                    ),
                    const SizedBox(height: 16),
                    NeuButton(
                      onPressed: _library,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.library_music_rounded),
                          SizedBox(width: 8),
                          Text('Go to Library'),
                        ],
                      ),
                    ),
                  ] else if (failed) ...[
                    Row(
                      children: [
                        Icon(
                          j.isCancelled
                              ? Icons.cancel_outlined
                              : Icons.error_outline_rounded,
                          color: NeuTheme.danger,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error ?? 'Download failed.',
                            style: const TextStyle(color: NeuTheme.danger),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    NeuButton(
                      onPressed: _retry,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh_rounded),
                          SizedBox(width: 8),
                          Text('Retry'),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      _saving ? 'Saving audio to device…' : _status(j.status),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 13),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 9,
                        backgroundColor: NeuTheme.input,
                        color: NeuTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        if (!_saving && j.speed.isNotEmpty)
                          Text(
                            j.speed,
                            style: const TextStyle(
                              color: NeuTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    NeuButton(
                      onPressed: _cancel,
                      // primary:false,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close_rounded),
                          SizedBox(width: 8),
                          Text('Cancel Download'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_error != null && !failed) ...[
              const SizedBox(height: 12),
              NeuSurface(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: NeuTheme.danger, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
