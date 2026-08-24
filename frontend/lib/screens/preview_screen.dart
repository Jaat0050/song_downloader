import 'package:flutter/material.dart';
import '../models/song_info.dart';
import '../services/downloader_api.dart';
import '../services/download_manager_service.dart';
import '../theme/neumorphic_widgets.dart';
import 'progress_screen.dart';

class PreviewScreen extends StatefulWidget {
  final SongInfo songInfo;
  final DownloaderApiService apiService;
  final DownloadManagerService downloadManager;
  final VoidCallback onOpenLibrary;
  const PreviewScreen({
    super.key,
    required this.songInfo,
    required this.apiService,
    required this.downloadManager,
    required this.onOpenLibrary,
  });
  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _starting = false;
  String? _error;
  String _duration(int s) =>
      s <= 0
          ? 'Unknown duration'
          : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  Future<void> _download() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final id = await widget.downloadManager.enqueue(
        widget.songInfo.webpageUrl,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => ProgressScreen(
                jobId: id,
                songInfo: widget.songInfo,
                apiService: widget.apiService,
                downloadManager: widget.downloadManager,
                onOpenLibrary: widget.onOpenLibrary,
              ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _starting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.songInfo;
    return Scaffold(
      appBar: AppBar(title: const Text('Song Preview')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          children: [
            NeuSurface(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child:
                      s.thumbnail.isNotEmpty
                          ? Image.network(
                            s.thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => Image.asset(
                                  'assets/images/app_icon.png',
                                  fit: BoxFit.cover,
                                ),
                          )
                          : Image.asset(
                            'assets/images/app_icon.png',
                            fit: BoxFit.cover,
                          ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              s.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.artist,
              style: const TextStyle(color: NeuTheme.muted, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: NeuTheme.subtle,
                ),
                const SizedBox(width: 6),
                Text(
                  _duration(s.duration),
                  style: const TextStyle(color: NeuTheme.subtle, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 18),
            NeuSurface(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: NeuTheme.accent.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.high_quality_rounded,
                      color: NeuTheme.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Best Available Audio',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Original source stream • Converted safely to MP3',
                          style: TextStyle(fontSize: 11, color: NeuTheme.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            NeuButton(
              onPressed: _starting ? null : _download,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _starting
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.download_rounded),
                  const SizedBox(width: 8),
                  Text(_starting ? 'Adding to downloads…' : 'Download Audio'),
                ],
              ),
            ),
            if (_error != null) ...[
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
