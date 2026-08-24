import 'package:flutter/material.dart';
import '../models/history_item.dart';
import '../services/download_storage.dart';
import '../services/music_player_service.dart';

class PlaylistsScreen extends StatefulWidget {
  final List<HistoryItem> library;
  final MusicPlayerService musicPlayer;
  const PlaylistsScreen({super.key, required this.library, required this.musicPlayer});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  final _storage = DownloadStorageService();
  Map<String, List<String>> _playlists = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final playlists = await _storage.loadPlaylists();
    if (!mounted) return;
    setState(() => _playlists = playlists);
  }

  Future<void> _create() async {
    final name = await _showPlaylistNameDialog();
    if (!mounted || name == null || name.isEmpty) return;

    if (_playlists.containsKey(name)) {
      _snack('Playlist already exists.');
      return;
    }

    final updated = <String, List<String>>{
      ..._playlists,
      name: <String>[],
    };

    await _storage.savePlaylists(updated);
    if (!mounted) return;
    setState(() => _playlists = updated);
  }

  Future<String?> _showPlaylistNameDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => const _CreatePlaylistDialog(),
    );
  }

  Future<void> _delete(String name) async {
    final updated = Map<String, List<String>>.from(_playlists)..remove(name);
    await _storage.savePlaylists(updated);
    if (!mounted) return;
    setState(() => _playlists = updated);
  }

  Future<void> _edit(String name) async {
    final selected = <String>{...(_playlists[name] ?? const <String>[])};
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _EditPlaylistDialog(
        name: name,
        library: widget.library,
        selected: selected,
      ),
    );

    if (!mounted || saved != true) return;

    final updated = <String, List<String>>{
      ..._playlists,
      name: selected.toList(),
    };
    await _storage.savePlaylists(updated);
    if (!mounted) return;
    setState(() => _playlists = updated);
  }

  Future<void> _play(String name) async {
    final ids = _playlists[name] ?? const <String>[];
    final songs = <HistoryItem>[];
    for (final id in ids) {
      for (final song in widget.library) {
        if (song.id == id) {
          songs.add(song);
          break;
        }
      }
    }

    if (songs.isEmpty) {
      _snack('This playlist has no available songs.');
      return;
    }
    await widget.musicPlayer.play(songs.first, source: songs);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      body: _playlists.isEmpty
          ? const Center(child: Text('No playlists yet'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _playlists.entries.map((entry) {
                return Card(
                  key: ValueKey(entry.key),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.queue_music),
                    ),
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${entry.value.length} songs'),
                    onTap: () => _play(entry.key),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'play') _play(entry.key);
                        if (value == 'edit') _edit(entry.key);
                        if (value == 'delete') _delete(entry.key);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'play',
                          child: Text('Play playlist'),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Add / edit songs'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete playlist'),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog();

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    Navigator.of(context).pop(name.isEmpty ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New playlist'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(hintText: 'Playlist name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _EditPlaylistDialog extends StatefulWidget {
  final String name;
  final List<HistoryItem> library;
  final Set<String> selected;

  const _EditPlaylistDialog({
    required this.name,
    required this.library,
    required this.selected,
  });

  @override
  State<_EditPlaylistDialog> createState() => _EditPlaylistDialogState();
}

class _EditPlaylistDialogState extends State<_EditPlaylistDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = <String>{...widget.selected};
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Songs in ${widget.name}'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: widget.library.isEmpty
            ? const Center(child: Text('No downloaded songs available.'))
            : ListView(
                children: widget.library.map((song) {
                  return CheckboxListTile(
                    value: _selected.contains(song.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selected.add(song.id);
                        } else {
                          _selected.remove(song.id);
                        }
                      });
                    },
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(song.artist),
                  );
                }).toList(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.selected
              ..clear()
              ..addAll(_selected);
            Navigator.of(context).pop(true);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
