import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/history_item.dart';
import '../services/download_storage.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final DownloadStorageService _storageService = DownloadStorageService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<HistoryItem> _items = [];
  bool _loading = true;

  HistoryItem? _currentlyPlaying;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadLibrary();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _loadLibrary() async {
    setState(() => _loading = true);
    final history = await _storageService.loadHistory();
    if (mounted) {
      setState(() {
        _items = history;
        _loading = false;
      });
    }
  }

  Future<void> _playSong(HistoryItem item) async {
    if (_currentlyPlaying?.id == item.id && _isPlaying) {
      await _audioPlayer.pause();
      return;
    }

    final file = File(item.localPath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File not found on device storage.')),
        );
      }
      return;
    }

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(item.localPath));
      setState(() {
        _currentlyPlaying = item;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteSong(HistoryItem item) async {
    if (_currentlyPlaying?.id == item.id) {
      await _audioPlayer.stop();
      setState(() {
        _currentlyPlaying = null;
        _isPlaying = false;
      });
    }
    await _storageService.deleteHistoryItem(item.id);
    _loadLibrary();
  }

  Future<void> _shareSong(HistoryItem item) async {
    final file = File(item.localPath);
    if (await file.exists()) {
      await Share.shareXFiles([XFile(item.localPath)], text: item.title);
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes > 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Library', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadLibrary,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.library_music_outlined, size: 64, color: Colors.white24),
                              SizedBox(height: 14),
                              Text('No downloaded songs yet.', style: TextStyle(color: Colors.white54, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final isPlayingThis = _currentlyPlaying?.id == item.id && _isPlaying;

                            return Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF15151B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPlayingThis
                                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.5)
                                      : Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: item.thumbnail.isNotEmpty
                                        ? Image.network(item.thumbnail, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF24242B), child: Icon(Icons.music_note)))
                                        : const ColoredBox(color: Color(0xFF24242B), child: Icon(Icons.music_note)),
                                  ),
                                ),
                                title: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                                subtitle: Text(
                                  '${item.artist} • ${_formatSize(item.fileSize)} • ${dateFormat.format(item.downloadedAt)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isPlayingThis ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                        color: const Color(0xFF8B5CF6),
                                        size: 32,
                                      ),
                                      onPressed: () => _playSong(item),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
                                      onSelected: (val) {
                                        if (val == 'share') _shareSong(item);
                                        if (val == 'delete') _deleteSong(item);
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'share',
                                          child: Row(
                                            children: [Icon(Icons.share_rounded, size: 18), SizedBox(width: 10), Text('Share')],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18), SizedBox(width: 10), Text('Delete', style: TextStyle(color: Colors.redAccent))],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            if (_currentlyPlaying != null) _buildPlayerBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerBar() {
    final item = _currentlyPlaying!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1B2C),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: item.thumbnail.isNotEmpty
                      ? Image.network(item.thumbnail, fit: BoxFit.cover)
                      : const ColoredBox(color: Color(0xFF24242B), child: Icon(Icons.music_note, size: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      item.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30),
                onPressed: () => _playSong(item),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white54),
                onPressed: () {
                  _audioPlayer.stop();
                  setState(() {
                    _currentlyPlaying = null;
                    _isPlaying = false;
                  });
                },
              ),
            ],
          ),
          if (_duration.inSeconds > 0)
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              ),
              child: Slider(
                value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()),
                max: _duration.inSeconds.toDouble(),
                activeColor: const Color(0xFF8B5CF6),
                inactiveColor: Colors.white10,
                onChanged: (val) {
                  _audioPlayer.seek(Duration(seconds: val.toInt()));
                },
              ),
            ),
        ],
      ),
    );
  }
}
