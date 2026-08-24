import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_item.dart';

class DownloadStorageService {
  static const String _historyKey = 'song_downloader_history_items';
  static const String _backendUrlKey = 'song_downloader_backend_url';
  static const String _playlistsKey = 'song_downloader_playlists';
  static const String defaultBackendUrl = 'http://10.0.2.2:5000';

  Future<Directory> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final publicDownloadDir = Directory('/storage/emulated/0/Download/Song Downloader');
      try {
        if (!await publicDownloadDir.exists()) {
          await publicDownloadDir.create(recursive: true);
        }
        return publicDownloadDir;
      } catch (_) {}

      final publicMusicDir = Directory('/storage/emulated/0/Music/Song Downloader');
      try {
        if (!await publicMusicDir.exists()) {
          await publicMusicDir.create(recursive: true);
        }
        return publicMusicDir;
      } catch (_) {}

      final extDir = await getExternalStorageDirectory();
      final downloadDir = Directory(
        '${extDir?.path ?? (await getApplicationDocumentsDirectory()).path}/Song Downloader',
      );
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    }

    final baseDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${baseDir.path}/Song Downloader');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  Future<String> getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backendUrlKey) ?? defaultBackendUrl;
  }

  Future<void> setBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendUrlKey, url.trim());
  }

  Future<List<HistoryItem>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    final items = <HistoryItem>[];
    for (final value in raw) {
      try {
        items.add(HistoryItem.decode(value));
      } catch (_) {}
    }
    items.removeWhere((item) => item.localPath.isEmpty);
    items.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return items;
  }

  Future<void> saveHistory(List<HistoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, items.map((x) => x.encode()).toList());
  }

  Future<void> addHistoryItem(HistoryItem item) async {
    final current = await loadHistory();
    current.removeWhere((x) => x.id == item.id);
    current.insert(0, item);
    await saveHistory(current);
  }

  Future<void> updateHistoryItem(HistoryItem item) async {
    final current = await loadHistory();
    final i = current.indexWhere((x) => x.id == item.id);
    if (i < 0) {
      current.insert(0, item);
    } else {
      current[i] = item;
    }
    await saveHistory(current);
  }

  Future<void> toggleFavorite(String id) async {
    final current = await loadHistory();
    final i = current.indexWhere((x) => x.id == id);
    if (i >= 0) {
      current[i] = current[i].copyWith(favorite: !current[i].favorite);
      await saveHistory(current);
    }
  }

  Future<void> deleteHistoryItem(String id) async {
    final current = await loadHistory();
    final i = current.indexWhere((x) => x.id == id);
    if (i < 0) return;

    final target = current[i];
    final file = File(target.localPath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }

    current.removeAt(i);
    await saveHistory(current);

    final playlists = await loadPlaylists();
    for (final songs in playlists.values) {
      songs.remove(id);
    }
    await savePlaylists(playlists);
  }

  Future<List<File>> listAudioFiles() async {
    final dir = await getDownloadDirectory();
    if (!await dir.exists()) return [];

    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.mp3')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return files;
  }

  Future<int> getLibrarySizeBytes() async {
    var total = 0;
    for (final file in await listAudioFiles()) {
      try {
        total += await file.length();
      } catch (_) {}
    }
    return total;
  }

  Future<int> clearTemporaryFiles() async {
    final dir = await getDownloadDirectory();
    var removed = 0;
    if (!await dir.exists()) return 0;

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File &&
          RegExp(r'\.(part|webm|m4a|opus)$', caseSensitive: false).hasMatch(entity.path)) {
        try {
          await entity.delete();
          removed++;
        } catch (_) {}
      }
    }
    return removed;
  }

  Future<void> clearHistoryOnly() async {
    await saveHistory([]);
  }

  Future<void> resetLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    await prefs.remove(_playlistsKey);
  }

  Future<Map<String, List<String>>> loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_playlistsKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map<String, List<String>>(
        (k, v) => MapEntry(k.toString(), List<String>.from(v as List)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> savePlaylists(Map<String, List<String>> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playlistsKey, jsonEncode(playlists));
  }
}
