import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_item.dart';

class DownloadStorageService {
  static const String _historyKey = 'song_downloader_history_items';
  static const String _backendUrlKey = 'song_downloader_backend_url';
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
      final downloadDir = Directory('${extDir?.path ?? (await getApplicationDocumentsDirectory()).path}/Song Downloader');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    } else {
      final baseDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${baseDir.path}/Song Downloader');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    }
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
    final rawList = prefs.getStringList(_historyKey) ?? [];
    final items = <HistoryItem>[];
    for (final raw in rawList) {
      try {
        items.add(HistoryItem.decode(raw));
      } catch (_) {}
    }
    items.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return items;
  }

  Future<void> saveHistory(List<HistoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = items.map((item) => item.encode()).toList();
    await prefs.setStringList(_historyKey, rawList);
  }

  Future<void> addHistoryItem(HistoryItem item) async {
    final current = await loadHistory();
    current.removeWhere((x) => x.id == item.id);
    current.insert(0, item);
    await saveHistory(current);
  }

  Future<void> deleteHistoryItem(String id) async {
    final current = await loadHistory();
    final target = current.firstWhere((x) => x.id == id, orElse: () => HistoryItem(id: '', title: '', artist: '', thumbnail: '', filename: '', localPath: '', downloadedAt: DateTime.now(), fileSize: 0));
    
    if (target.id.isNotEmpty) {
      final file = File(target.localPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      current.removeWhere((x) => x.id == id);
      await saveHistory(current);
    }
  }
}
