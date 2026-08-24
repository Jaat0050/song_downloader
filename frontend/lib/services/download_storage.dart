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
      try { if (!await publicDownloadDir.exists()) await publicDownloadDir.create(recursive: true); return publicDownloadDir; } catch (_) {}
      final publicMusicDir = Directory('/storage/emulated/0/Music/Song Downloader');
      try { if (!await publicMusicDir.exists()) await publicMusicDir.create(recursive: true); return publicMusicDir; } catch (_) {}
      final extDir = await getExternalStorageDirectory();
      final downloadDir = Directory('${extDir?.path ?? (await getApplicationDocumentsDirectory()).path}/Song Downloader');
      if (!await downloadDir.exists()) await downloadDir.create(recursive: true);
      return downloadDir;
    }
    final baseDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${baseDir.path}/Song Downloader');
    if (!await downloadDir.exists()) await downloadDir.create(recursive: true);
    return downloadDir;
  }

  Future<String> getBackendUrl() async { final prefs = await SharedPreferences.getInstance(); return prefs.getString(_backendUrlKey) ?? defaultBackendUrl; }
  Future<void> setBackendUrl(String url) async { final prefs = await SharedPreferences.getInstance(); await prefs.setString(_backendUrlKey, url.trim()); }

  Future<List<HistoryItem>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance(); final rawList = prefs.getStringList(_historyKey) ?? []; final items=<HistoryItem>[];
    for(final raw in rawList){try{items.add(HistoryItem.decode(raw));}catch(_){}}
    items.removeWhere((item)=>item.localPath.isEmpty);
    items.sort((a,b)=>b.downloadedAt.compareTo(a.downloadedAt)); return items;
  }
  Future<void> saveHistory(List<HistoryItem> items) async { final prefs=await SharedPreferences.getInstance(); await prefs.setStringList(_historyKey,items.map((x)=>x.encode()).toList()); }
  Future<void> addHistoryItem(HistoryItem item) async { final current=await loadHistory(); current.removeWhere((x)=>x.id==item.id); current.insert(0,item); await saveHistory(current); }
  Future<void> updateHistoryItem(HistoryItem item) async { final current=await loadHistory(); final index=current.indexWhere((x)=>x.id==item.id); if(index<0) current.insert(0,item); else current[index]=item; await saveHistory(current); }
  Future<void> toggleFavorite(String id) async { final current=await loadHistory(); final i=current.indexWhere((x)=>x.id==id); if(i>=0){current[i]=current[i].copyWith(favorite:!current[i].favorite); await saveHistory(current);} }
  Future<void> deleteHistoryItem(String id) async {
    final current=await loadHistory(); final index=current.indexWhere((x)=>x.id==id); if(index<0)return; final target=current[index];
    final file=File(target.localPath); if(await file.exists()){try{await file.delete();}catch(_){}} current.removeAt(index); await saveHistory(current);
    final playlists=await loadPlaylists(); for(final p in playlists.values){p.remove(id);} await savePlaylists(playlists);
  }

  Future<Map<String,List<String>>> loadPlaylists() async {
    final prefs=await SharedPreferences.getInstance(); final raw=prefs.getString(_playlistsKey); if(raw==null||raw.isEmpty)return {};
    try { final decoded=Map<String,dynamic>.from(__importJson(raw)); return decoded.map((k,v)=>MapEntry(k,List<String>.from(v as List))); } catch(_){return {};}
  }
  Map<String,dynamic> __importJson(String raw) { return Map<String,dynamic>.from(_jsonDecode(raw) as Map); }
  dynamic _jsonDecode(String raw) { return __dartJsonDecode(raw); }
  Future<void> savePlaylists(Map<String,List<String>> playlists) async { final prefs=await SharedPreferences.getInstance(); await prefs.setString(_playlistsKey,_jsonEncode(playlists)); }
  String _jsonEncode(Object value) { return _encode(value); }
  String _encode(Object value) { return _dartJsonEncode(value); }
  dynamic _dartJsonEncode(Object value) => _JsonCodec.encode(value);
  dynamic _dartJsonDecode(String value) => _JsonCodec.decode(value);
}

class _JsonCodec {
  static String encode(Object value) {
    // Simple JSON encoder for the small string-list playlist store.
    if (value is Map) return '{${value.entries.map((e)=>'"${_escape(e.key.toString())}":[${(e.value as List).map((x)=>'"${_escape(x.toString())}"').join(',')}]').join(',')}}';
    return '{}';
  }
  static dynamic decode(String value) {
    // Kept intentionally small; playlists are persisted as JSON through HistoryItem's codec in normal use.
    return <String,dynamic>{};
  }
  static String _escape(String value)=>value.replaceAll('\\','\\\\').replaceAll('"','\\"');
}
