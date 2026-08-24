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
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
        children: [
          const Text(
            'Song Downloader',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Private • Fast • On-device',
            style: TextStyle(
              color: NeuTheme.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          NeuSurface(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: NeuTheme.accent.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.graphic_eq_rounded,
                        color: NeuTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'High-quality audio',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Download the best available original audio stream from YouTube for your personal collection.',
                  style: TextStyle(color: NeuTheme.muted, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Download a song',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          NeuSurface(
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _fetchSong(),
              onChanged: (_) => setState(() {}),
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
            ),
          ),
          const SizedBox(height: 25),
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
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            NeuSurface(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: NeuTheme.danger,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: NeuTheme.danger,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 30),
          NeuSurface(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: NeuTheme.success),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Downloads stay on this device. The embedded server listens locally.',
                    style: TextStyle(
                      color: NeuTheme.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
