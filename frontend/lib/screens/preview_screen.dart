import 'package:flutter/material.dart';
import '../models/song_info.dart';
import '../services/downloader_api.dart';
import '../services/download_manager_service.dart';
import 'progress_screen.dart';

class PreviewScreen extends StatefulWidget {
  final SongInfo songInfo;
  final DownloaderApiService apiService;
  final DownloadManagerService downloadManager;
  final VoidCallback onOpenLibrary;
  const PreviewScreen({super.key, required this.songInfo, required this.apiService, required this.downloadManager, required this.onOpenLibrary});
  @override State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _starting = false;
  String? _error;

  String _formatDuration(int seconds) {
    if (seconds <= 0) return 'Unknown duration';
    final mins = seconds ~/ 60;
    return '$mins:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _startDownload() async {
    setState(() { _starting = true; _error = null; });
    try {
      final jobId = await widget.downloadManager.enqueue(widget.songInfo.webpageUrl);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProgressScreen(jobId: jobId, songInfo: widget.songInfo, apiService: widget.apiService, downloadManager: widget.downloadManager, onOpenLibrary: widget.onOpenLibrary)));
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _starting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.songInfo;
    return Scaffold(
      appBar: AppBar(title: const Text('Song Preview'), elevation: 0, backgroundColor: Colors.transparent),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        Container(decoration: BoxDecoration(color: const Color(0xFF15151B), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withValues(alpha: .07))), padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: AspectRatio(aspectRatio: 16 / 9, child: song.thumbnail.isNotEmpty ? Image.network(song.thumbnail, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF24242B), child: Icon(Icons.music_note_rounded, size: 64))) : const ColoredBox(color: Color(0xFF24242B), child: Icon(Icons.music_note_rounded, size: 64)))),
          const SizedBox(height: 16),
          Text(song.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(song.artist, style: const TextStyle(color: Colors.white60, fontSize: 15)),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.timer_outlined, size: 16, color: Colors.white54), const SizedBox(width: 6), Text(_formatDuration(song.duration), style: const TextStyle(color: Colors.white54, fontSize: 13))]),
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF211A31), borderRadius: BorderRadius.circular(16)), child: const Row(children: [Icon(Icons.high_quality_rounded, color: Color(0xFF8B5CF6)), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Best Available Audio', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(height: 3), Text('Original source stream • Converted safely to MP3', style: TextStyle(fontSize: 12, color: Colors.white60))]))])),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: _starting ? null : _startDownload, icon: _starting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.download_rounded), label: Text(_starting ? 'Adding to downloads…' : 'Download Audio'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)))),
          if (_error != null) ...[const SizedBox(height: 14), Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))],
        ])),
      ])),
    );
  }
}
