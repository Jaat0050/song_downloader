import 'package:flutter/material.dart';
import '../models/history_item.dart';
import '../services/download_storage.dart';
import '../services/music_player_service.dart';
import '../theme/neumorphic_widgets.dart';

class PlaylistsScreen extends StatefulWidget {
  final List<HistoryItem> library;
  final MusicPlayerService musicPlayer;
  const PlaylistsScreen({
    super.key,
    required this.library,
    required this.musicPlayer,
  });
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
    final p = await _storage.loadPlaylists();
    if (mounted) setState(() => _playlists = p);
  }

  Future<String?> _name() =>
      showDialog<String>(context: context, builder: (_) => const _NameDialog());
  Future<void> _create() async {
    final n = await _name();
    if (!mounted || n == null || n.isEmpty) return;
    if (_playlists.containsKey(n)) {
      _snack('Playlist already exists.');
      return;
    }
    final u = <String, List<String>>{..._playlists, n: <String>[]};
    await _storage.savePlaylists(u);
    if (mounted) setState(() => _playlists = u);
  }

  Future<void> _delete(String n) async {
    final u = <String, List<String>>{..._playlists}..remove(n);
    await _storage.savePlaylists(u);
    if (mounted) setState(() => _playlists = u);
  }

  Future<void> _edit(String n) async {
    final selected = <String>{...(_playlists[n] ?? const <String>[])};
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) =>
              _EditDialog(name: n, library: widget.library, selected: selected),
    );
    if (!mounted || ok != true) return;
    final u = <String, List<String>>{..._playlists, n: selected.toList()};
    await _storage.savePlaylists(u);
    if (mounted) setState(() => _playlists = u);
  }

  Future<void> _play(String n) async {
    final ids = _playlists[n] ?? const <String>[];
    final songs = widget.library.where((s) => ids.contains(s.id)).toList();
    if (songs.isEmpty) {
      _snack('This playlist has no available songs.');
      return;
    }
    await widget.musicPlayer.play(songs.first, source: songs);
  }

  void _snack(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Playlists')),
    floatingActionButton: FloatingActionButton(
      onPressed: _create,
      backgroundColor: NeuTheme.accent,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add_rounded),
    ),
    body:
        _playlists.isEmpty
            ? Center(
              child: NeuSurface(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.queue_music_rounded,
                      size: 48,
                      color: NeuTheme.accent,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No playlists yet',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Create a playlist for your downloaded songs.',
                      style: TextStyle(color: NeuTheme.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
            : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children:
                  _playlists.entries
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 11),
                          child: NeuSurface(
                            child: Row(
                              children: [
                                NeuIconButton(
                                  icon: Icons.play_arrow_rounded,
                                  active: true,
                                  onPressed: () => _play(e.key),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.key,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${e.value.length} songs',
                                        style: const TextStyle(
                                          color: NeuTheme.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'play') _play(e.key);
                                    if (v == 'edit') _edit(e.key);
                                    if (v == 'delete') _delete(e.key);
                                  },
                                  itemBuilder:
                                      (_) => const [
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
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final c = TextEditingController();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New playlist'),
    content: TextField(
      controller: c,
      autofocus: true,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => Navigator.pop(context, c.text.trim()),
      decoration: const InputDecoration(hintText: 'Playlist name'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, c.text.trim()),
        child: const Text('Create'),
      ),
    ],
  );
}

class _EditDialog extends StatefulWidget {
  final String name;
  final List<HistoryItem> library;
  final Set<String> selected;
  const _EditDialog({
    required this.name,
    required this.library,
    required this.selected,
  });
  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late Set<String> selected;
  @override
  void initState() {
    super.initState();
    selected = {...widget.selected};
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Songs in ${widget.name}'),
    content: SizedBox(
      width: double.maxFinite,
      height: 400,
      child:
          widget.library.isEmpty
              ? const Center(child: Text('No downloaded songs available.'))
              : ListView(
                children:
                    widget.library
                        .map(
                          (s) => CheckboxListTile(
                            value: selected.contains(s.id),
                            onChanged:
                                (v) => setState(
                                  () =>
                                      v == true
                                          ? selected.add(s.id)
                                          : selected.remove(s.id),
                                ),
                            title: Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(s.artist),
                          ),
                        )
                        .toList(),
              ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          widget.selected
            ..clear()
            ..addAll(selected);
          Navigator.pop(context, true);
        },
        child: const Text('Save'),
      ),
    ],
  );
}
