import 'package:flutter/material.dart';
import '../services/downloader_api.dart';
import '../services/download_manager_service.dart';
import '../theme/neumorphic_widgets.dart';
import 'preview_screen.dart';

class HomeScreen extends StatefulWidget {
  final DownloaderApiService apiService;
  final DownloadManagerService downloadManager;
  final String? sharedUrl;
  final VoidCallback onSharedUrlConsumed;
  final VoidCallback onOpenLibrary;
  const HomeScreen({
    super.key,
    required this.apiService,
    required this.downloadManager,
    this.sharedUrl,
    required this.onSharedUrlConsumed,
    required this.onOpenLibrary,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;
  String? _lastHandledSharedUrl;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleSharedUrl());
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedUrl != oldWidget.sharedUrl)
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleSharedUrl());
  }

  void _handleSharedUrl() {
    final u = widget.sharedUrl;
    if (!mounted || u == null || u.isEmpty || u == _lastHandledSharedUrl)
      return;
    _lastHandledSharedUrl = u;
    _urlController.text = u;
    _fetchSong(sharedUrl: u);
    widget.onSharedUrlConsumed();
  }

  bool _isSupportedUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    final h = uri.host.toLowerCase();
    return h == 'youtube.com' ||
        h == 'www.youtube.com' ||
        h == 'm.youtube.com' ||
        h == 'youtu.be' ||
        h == 'www.youtube-nocookie.com';
  }

  Future<void> _fetchSong({String? sharedUrl}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final url = (sharedUrl ?? _urlController.text).trim();
    if (!_isSupportedUrl(url)) {
      if (mounted)
        setState(
          () => _errorMessage = 'Please enter a valid YouTube video URL.',
        );
      return;
    }
    if (mounted)
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    try {
      final info = await widget.apiService.fetchSongInfo(url);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => PreviewScreen(
                songInfo: info,
                apiService: widget.apiService,
                downloadManager: widget.downloadManager,
                onOpenLibrary: widget.onOpenLibrary,
              ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Song Downloader',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const SizedBox(height: 8),
          const Text(
            'High-quality audio',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Download the best available original audio stream from YouTube for your personal collection.',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: 28),
          NeuSurface(
            child: Column(
              children: [
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _fetchSong(),
                  decoration: InputDecoration(
                    hintText: 'Paste YouTube URL',
                    prefixIcon: const Icon(Icons.link_rounded),
                    suffixIcon:
                        _urlController.text.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _urlController.clear();
                                setState(() => _errorMessage = null);
                              },
                            )
                            : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                NeuButton(
                  onPressed: _loading ? null : _fetchSong,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _loading
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.search_rounded),
                      const SizedBox(width: 9),
                      Text(_loading ? 'Fetching info…' : 'Fetch song'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 20),
            NeuSurface(
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
