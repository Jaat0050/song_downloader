import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/history_item.dart';
import '../services/download_storage.dart';
import '../services/library_service.dart';
import '../services/music_player_service.dart';
import 'playlists_screen.dart';
import 'now_playing_screen.dart';

class LibraryScreen extends StatefulWidget {
  final MusicPlayerService musicPlayer;
  const LibraryScreen({super.key, required this.musicPlayer});
  @override State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _storage = DownloadStorageService();
  final _library = LibraryService();
  final _search = TextEditingController();
  List<HistoryItem> _items = [];
  bool _loading = true;
  bool _favoritesOnly = false;
  StreamSubscription<void>? _historySubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_searchChanged);
    _historySubscription = DownloadStorageService.historyChanges.listen((_) {
      if (mounted) _load();
    });
  }

  void _searchChanged() { if (mounted) setState(() {}); }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final items = await _library.load();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  List<HistoryItem> get _visible {
    final q = _search.text.trim().toLowerCase();
    return _items.where((x) =>
      (!_favoritesOnly || x.favorite) &&
      (q.isEmpty || x.title.toLowerCase().contains(q) || x.artist.toLowerCase().contains(q))
    ).toList();
  }

  Future<void> _play(HistoryItem item) async {
    if (!await File(item.localPath).exists()) { _snack('Audio file not found.'); return; }
    await widget.musicPlayer.play(item, source: _visible);
  }

  Future<void> _favorite(HistoryItem item) async { await _library.toggleFavorite(item.id); await _load(); }

  Future<void> _delete(HistoryItem item) async {
    if (widget.musicPlayer.current?.id == item.id) await widget.musicPlayer.clearQueue();
    await _storage.deleteHistoryItem(item.id);
    await _load();
  }

  Future<void> _rename(HistoryItem item) async {
    final controller = TextEditingController(text: item.title);
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename song'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      try { await _library.rename(item, value); await _load(); }
      catch (e) { _snack(e.toString()); }
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  String _size(int bytes) => bytes < 1048576 ? '${(bytes / 1024).toStringAsFixed(1)} KB' : '${(bytes / 1048576).toStringAsFixed(1)} MB';

  @override
  void dispose() {
    _historySubscription?.cancel();
    _search.removeListener(_searchChanged);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.musicPlayer,
      builder: (context, _) {
        final player = widget.musicPlayer;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Music Library'),
            actions: [
              IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistsScreen(library: _items, musicPlayer: player))), icon: const Icon(Icons.queue_music_rounded)),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: TextField(controller: _search, decoration: const InputDecoration(hintText: 'Search songs or artists', prefixIcon: Icon(Icons.search), filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none)))),
                IconButton(onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly), icon: Icon(_favoritesOnly ? Icons.favorite : Icons.favorite_border)),
              ]),
            ),
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _visible.isEmpty
                  ? const Center(child: Text('No songs found'))
                  : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 0, 12, 110), itemCount: _visible.length, itemBuilder: (_, i) => _tile(_visible[i], player)),
            ),
            if (player.current != null) _playerBar(player),
          ]),
        );
      },
    );
  }

  Widget _tile(HistoryItem item, MusicPlayerService player) {
    final active = player.current?.id == item.id;
    return Card(
      child: ListTile(
        leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 52, height: 52, child: item.thumbnail.isEmpty ? const Icon(Icons.music_note) : Image.network(item.thumbnail, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note)))),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${item.artist} • ${_size(item.fileSize)}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(onPressed: () => _favorite(item), icon: Icon(item.favorite ? Icons.favorite : Icons.favorite_border)),
          IconButton(onPressed: () => _play(item), icon: Icon(active && player.playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 32)),
          PopupMenuButton<String>(
            onSelected: (value) { if (value == 'rename') _rename(item); if (value == 'share') Share.shareXFiles([XFile(item.localPath)], text: item.title); if (value == 'delete') _delete(item); },
            itemBuilder: (_) => const [PopupMenuItem(value: 'rename', child: Text('Rename')), PopupMenuItem(value: 'share', child: Text('Share')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
          ),
        ]),
      ),
    );
  }

  Widget _playerBar(MusicPlayerService player) {
    final duration = player.duration;
    final position = player.position;
    final max = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
    final value = position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NowPlayingScreen(player: player))),
      child: Container(
        color: const Color(0xFF211B32), padding: const EdgeInsets.all(8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Text(player.current!.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
            IconButton(onPressed: player.previous, icon: const Icon(Icons.skip_previous)),
            IconButton(onPressed: player.playing ? player.pause : player.resume, icon: Icon(player.playing ? Icons.pause : Icons.play_arrow)),
            IconButton(onPressed: player.next, icon: const Icon(Icons.skip_next)),
            IconButton(onPressed: () => player.setShuffle(!player.shuffle), icon: Icon(Icons.shuffle, color: player.shuffle ? const Color(0xFF8B5CF6) : null)),
            IconButton(onPressed: () => player.setRepeat(!player.repeat), icon: Icon(Icons.repeat, color: player.repeat ? const Color(0xFF8B5CF6) : null)),
          ]),
          Slider(value: value, max: max, onChanged: duration.inMilliseconds == 0 ? null : (v) => player.seek(Duration(milliseconds: v.toInt()))),
        ]),
      ),
    );
  }
}
