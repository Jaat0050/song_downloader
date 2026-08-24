import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/history_item.dart';
import '../services/download_storage.dart';
import '../services/library_service.dart';
import '../services/music_player_service.dart';
import '../theme/neumorphic_widgets.dart';
import 'playlists_screen.dart';
import 'now_playing_screen.dart';

class LibraryScreen extends StatefulWidget {
  final MusicPlayerService musicPlayer;
  const LibraryScreen({super.key, required this.musicPlayer});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _storage = DownloadStorageService();
  final _library = LibraryService();
  final _search = TextEditingController();
  List<HistoryItem> _items = [];
  bool _loading = true;
  bool _favorites = false;
  StreamSubscription<void>? _sub;
  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_changed);
    _sub = DownloadStorageService.historyChanges.listen((_) {
      if (mounted) _load();
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final items = await _library.load();
    if (mounted)
      setState(() {
        _items = items;
        _loading = false;
      });
  }

  List<HistoryItem> get _visible {
    final q = _search.text.trim().toLowerCase();
    return _items
        .where(
          (x) =>
              (!_favorites || x.favorite) &&
              (q.isEmpty ||
                  x.title.toLowerCase().contains(q) ||
                  x.artist.toLowerCase().contains(q)),
        )
        .toList();
  }

  Future<void> _play(HistoryItem i) async {
    if (!await File(i.localPath).exists()) {
      _snack('Audio file not found.');
      return;
    }
    await widget.musicPlayer.play(i, source: _visible);
  }

  Future<void> _favorite(HistoryItem i) async {
    await _library.toggleFavorite(i.id);
    await _load();
  }

  Future<void> _delete(HistoryItem i) async {
    if (widget.musicPlayer.current?.id == i.id)
      await widget.musicPlayer.clearQueue();
    await _storage.deleteHistoryItem(i.id);
    await _load();
  }

  Future<void> _rename(HistoryItem i) async {
    final c = TextEditingController(text: i.title);
    final v = await showDialog<String>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Rename song'),
            content: TextField(controller: c, autofocus: true),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, c.text),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    c.dispose();
    if (v != null) {
      try {
        await _library.rename(i, v);
        await _load();
      } catch (e) {
        _snack(e.toString());
      }
    }
  }

  void _snack(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  String _size(int b) =>
      b < 1048576
          ? '${(b / 1024).toStringAsFixed(1)} KB'
          : '${(b / 1048576).toStringAsFixed(1)} MB';
  @override
  void dispose() {
    _sub?.cancel();
    _search.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.musicPlayer,
    builder: (context, _) {
      final player = widget.musicPlayer;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Music Library'),
          actions: [
            NeuIconButton(
              icon: Icons.queue_music_rounded,
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => PlaylistsScreen(
                            library: _items,
                            musicPlayer: player,
                          ),
                    ),
                  ),
            ),
            const SizedBox(width: 7),
            NeuIconButton(icon: Icons.refresh_rounded, onPressed: _load),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        hintText: 'Search songs or artists',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  NeuIconButton(
                    icon: _favorites ? Icons.favorite : Icons.favorite_border,
                    active: _favorites,
                    onPressed: () => setState(() => _favorites = !_favorites),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _visible.isEmpty
                      ? Center(
                        child: NeuSurface(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.library_music_outlined,
                                size: 48,
                                color: NeuTheme.accent,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No songs found',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Downloaded songs will appear here.',
                                style: TextStyle(
                                  color: NeuTheme.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                        itemCount: _visible.length,
                        itemBuilder: (_, i) => _tile(_visible[i], player),
                      ),
            ),
            if (player.current != null) _playerBar(player),
          ],
        ),
      );
    },
  );
  Widget _tile(HistoryItem item, MusicPlayerService player) {
    final active = player.current?.id == item.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: NeuSurface(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 60,
                height: 60,
                child:
                    item.thumbnail.isEmpty
                        ? const ColoredBox(
                          color: NeuTheme.input,
                          child: Icon(Icons.music_note_rounded),
                        )
                        : Image.network(
                          item.thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => const ColoredBox(
                                color: NeuTheme.input,
                                child: Icon(Icons.music_note_rounded),
                              ),
                        ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.artist} • ${_size(item.fileSize)}',
                    style: const TextStyle(color: NeuTheme.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            NeuIconButton(
              icon: item.favorite ? Icons.favorite : Icons.favorite_border,
              active: item.favorite,
              onPressed: () => _favorite(item),
            ),
            const SizedBox(width: 8),
            NeuIconButton(
              icon:
                  active && player.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
              active: active,
              onPressed: () => _play(item),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'rename') _rename(item);
                if (v == 'share')
                  Share.shareXFiles([XFile(item.localPath)], text: item.title);
                if (v == 'delete') _delete(item);
              },
              itemBuilder:
                  (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'share', child: Text('Share')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerBar(MusicPlayerService player) {
    final d = player.duration;
    final p = player.position;
    final max = d.inMilliseconds > 0 ? d.inMilliseconds.toDouble() : 1.0;
    final value = p.inMilliseconds.clamp(0, d.inMilliseconds).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: NeuSurface(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: GestureDetector(
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NowPlayingScreen(player: player),
                ),
              ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      player.current!.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  NeuIconButton(
                    icon: Icons.skip_previous_rounded,
                    onPressed: player.previous,
                  ),
                  const SizedBox(width: 8),

                  NeuIconButton(
                    icon:
                        player.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                    active: true,
                    onPressed: player.playing ? player.pause : player.resume,
                  ),
                  const SizedBox(width: 8),

                  NeuIconButton(
                    icon: Icons.skip_next_rounded,
                    onPressed: player.next,
                  ),
                ],
              ),
              Slider(
                value: value,
                max: max,
                onChanged:
                    d.inMilliseconds == 0
                        ? null
                        : (v) => player.seek(Duration(milliseconds: v.toInt())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
