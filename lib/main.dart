import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const SongDownloaderApp()); }

class SongDownloaderApp extends StatelessWidget {
  const SongDownloaderApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'Song Downloader',
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0B0B0F), colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B5CF6), brightness: Brightness.dark), useMaterial3: true),
    home: const HomePage(),
  );
}

class SongInfo { const SongInfo({required this.title, required this.author, required this.thumbnail}); final String title, author, thumbnail; }

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState() => _HomePageState(); }

class _HomePageState extends State<HomePage> {
  static const _channel = MethodChannel('song_downloader/native');
  final _urlController = TextEditingController();
  SongInfo? _song; double _progress = 0; bool _loadingInfo = false, _downloading = false; String _status = ''; String? _downloadedPath;

  @override void initState() { super.initState(); _channel.setMethodCallHandler(_handleNativeCall); }
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'downloadProgress') { final args = Map<String, dynamic>.from(call.arguments as Map); if (!mounted) return null; setState(() { _progress = (args['progress'] as num?)?.toDouble() ?? 0; _status = (args['line'] as String?) ?? 'Downloading…'; }); }
    return null;
  }

  Future<SongInfo?> _fetchInfo(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('https://www.youtube.com/oembed?url=${Uri.encodeComponent(url)}&format=json'));
      final response = await request.close(); if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join(); final json = jsonDecode(body) as Map<String, dynamic>;
      return SongInfo(title: (json['title'] as String?) ?? 'Unknown song', author: (json['author_name'] as String?) ?? 'Unknown artist', thumbnail: (json['thumbnail_url'] as String?) ?? '');
    } finally { client.close(force: true); }
  }

  bool _isSupportedUrl(String value) { final uri = Uri.tryParse(value.trim()); if (uri == null) return false; final host = uri.host.toLowerCase(); return host == 'youtube.com' || host == 'www.youtube.com' || host == 'm.youtube.com' || host == 'youtu.be' || host == 'www.youtube-nocookie.com'; }

  Future<void> _loadSong() async {
    FocusManager.instance.primaryFocus?.unfocus(); final url = _urlController.text.trim();
    if (!_isSupportedUrl(url)) { _showMessage('Please enter a valid YouTube URL.'); return; }
    setState(() { _loadingInfo = true; _song = null; _downloadedPath = null; _status = 'Fetching song information…'; });
    try { final info = await _fetchInfo(url); if (!mounted) return; if (info == null) { _showMessage('Could not read this YouTube URL.'); setState(() => _status = ''); return; } setState(() { _song = info; _status = 'Ready to download original best audio'; }); }
    catch (_) { if (mounted) _showMessage('Unable to fetch song information.'); }
    finally { if (mounted) setState(() => _loadingInfo = false); }
  }

  Future<void> _download() async {
    if (_downloading || _song == null) return; final url = _urlController.text.trim();
    setState(() { _downloading = true; _progress = 0; _downloadedPath = null; _status = 'Starting download…'; });
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('downloadAudio', {'url': url});
      if (!mounted) return; final success = result?['success'] == true;
      if (success) { setState(() { _progress = 100; _downloadedPath = result?['path'] as String?; _status = 'Download complete'; }); _showMessage('Song downloaded successfully.'); }
      else { setState(() => _status = 'Download failed'); _showMessage((result?['error'] as String?) ?? 'Download failed.'); }
    } on PlatformException catch (e) { if (mounted) { setState(() => _status = 'Download failed'); _showMessage(e.message ?? 'Download failed.'); } }
    finally { if (mounted) setState(() => _downloading = false); }
  }
  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  @override void dispose() { _urlController.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Song Downloader', style: TextStyle(fontWeight: FontWeight.w700)), backgroundColor: Colors.transparent, elevation: 0),
    body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
      const Text('High-quality audio', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.1)),
      const SizedBox(height: 8), Text('Download the best available original audio stream from a YouTube video you are authorized to save.', style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.45)),
      const SizedBox(height: 28),
      TextField(controller: _urlController, keyboardType: TextInputType.url, textInputAction: TextInputAction.done, onSubmitted: (_) => _loadSong(), decoration: InputDecoration(hintText: 'Paste YouTube URL', prefixIcon: const Icon(Icons.link_rounded), filled: true, fillColor: const Color(0xFF17171D), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none))),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _loadingInfo || _downloading ? null : _loadSong, icon: _loadingInfo ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search_rounded), label: Text(_loadingInfo ? 'Fetching…' : 'Fetch song'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))),
      if (_song != null) ...[
        const SizedBox(height: 28),
        Container(decoration: BoxDecoration(color: const Color(0xFF15151B), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withValues(alpha: .07))), padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: AspectRatio(aspectRatio: 16 / 9, child: Image.network(_song!.thumbnail, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF24242B), child: Icon(Icons.music_note_rounded, size: 64))))),
          const SizedBox(height: 16), Text(_song!.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(_song!.author, style: const TextStyle(color: Colors.white60)), const SizedBox(height: 18),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF211A31), borderRadius: BorderRadius.circular(16)), child: const Row(children: [Icon(Icons.high_quality_rounded), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Best available audio', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(height: 3), Text('Original source format • Audio only', style: TextStyle(fontSize: 12))]))])),
          const SizedBox(height: 14), FilledButton.icon(onPressed: _downloading ? null : _download, icon: const Icon(Icons.download_rounded), label: Text(_downloading ? 'Downloading…' : 'Download audio'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)))),
          if (_downloading || _downloadedPath != null) ...[const SizedBox(height: 18), LinearProgressIndicator(value: _downloading ? _progress / 100 : 1), const SizedBox(height: 8), Text(_downloading ? '${_progress.toStringAsFixed(0)}%  $_status' : _status, style: const TextStyle(color: Colors.white60, fontSize: 12))],
        ])),
      ],
      if (_status.isNotEmpty && _song == null) ...[const SizedBox(height: 18), Center(child: Text(_status, style: const TextStyle(color: Colors.white54)))],
    ])),
  );
}
