import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/download_manager_screen.dart';
import 'services/downloader_api.dart';
import 'services/download_manager_service.dart';
import 'services/local_server_service.dart';
import 'services/music_player_service.dart';
import 'services/background_audio_handler.dart';
import 'services/share_intent_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final musicHandler = await initBackgroundAudio();
  runApp(SongDownloaderApp(musicHandler: musicHandler));
}

class SongDownloaderApp extends StatefulWidget {
  final BackgroundAudioHandler musicHandler;
  const SongDownloaderApp({super.key, required this.musicHandler});
  @override State<SongDownloaderApp> createState() => _SongDownloaderAppState();
}

class _SongDownloaderAppState extends State<SongDownloaderApp> {
  final LocalServerService _localServer = LocalServerService();
  final ShareIntentService _shareIntent = ShareIntentService();
  late DownloaderApiService _apiService;
  late final MusicPlayerService _musicPlayer = MusicPlayerService(handler: widget.musicHandler);
  DownloadManagerService? _downloadManager;
  StreamSubscription<String>? _shareSubscription;
  String? _pendingSharedUrl;
  String? _startupError;
  bool _initialized = false;
  final GlobalKey<_MainShellState> _mainShellKey = GlobalKey<_MainShellState>();

  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) { _requestNotificationPermission(); _initShareHandling(); _initApp(); }); }
  Future<void> _initShareHandling() async { await _shareIntent.initialize(); _setSharedUrl(await _shareIntent.getInitialSharedText()); await _shareSubscription?.cancel(); _shareSubscription = _shareIntent.sharedTextStream.listen(_setSharedUrl); }
  void _setSharedUrl(String? text) { final url = _shareIntent.extractYouTubeUrl(text); if (url != null && mounted) setState(() => _pendingSharedUrl = url); }
  void _consumeSharedUrl() { if (mounted) setState(() => _pendingSharedUrl = null); }
  Future<void> _requestNotificationPermission() async { try { await Permission.notification.request(); } catch (_) {} }
  Future<void> _initApp() async {
    if (mounted) setState(() { _startupError = null; _initialized = false; });
    Object? lastError;
    for (var attempt = 1; attempt <= 4; attempt++) { try { final url = await _localServer.start(); final api = DownloaderApiService(baseUrl: url); await api.checkHealth(); final manager = DownloadManagerService(apiService: api)..start(); if (!mounted) { manager.dispose(); return; } _downloadManager?.dispose(); setState(() { _apiService = api; _downloadManager = manager; _initialized = true; _startupError = null; }); return; } catch (e) { lastError = e; if (attempt < 4) await Future<void>.delayed(Duration(milliseconds: 250 * attempt)); } }
    if (mounted) setState(() { _startupError = lastError?.toString() ?? 'Unable to start the local downloader server.'; _initialized = false; });
  }
  Future<void> _restartServer() async { final url = await _localServer.restart(); final api = DownloaderApiService(baseUrl: url); await api.checkHealth(); final manager = DownloadManagerService(apiService: api)..start(); if (!mounted) { manager.dispose(); return; } _downloadManager?.dispose(); setState(() { _apiService = api; _downloadManager = manager; _startupError = null; _initialized = true; }); }
  void _openLibrary() { if (mounted) _mainShellKey.currentState?.openLibrary(); }
  @override void dispose() { _shareSubscription?.cancel(); _shareIntent.dispose(); _downloadManager?.dispose(); _musicPlayer.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Song Downloader',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B0B0F),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B5CF6), brightness: Brightness.dark),
      useMaterial3: true,
      cardTheme: CardThemeData(color: const Color(0xFF111116), elevation: 0, margin: const EdgeInsets.symmetric(vertical: 7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFF111116), hintStyle: const TextStyle(color: Colors.white38), prefixIconColor: Colors.white54, border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: Colors.white.withValues(alpha: .035))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: Colors.white.withValues(alpha: .035))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.2))),
      navigationBarTheme: const NavigationBarThemeData(backgroundColor: Color(0xFF101015), elevation: 0, indicatorColor: Color(0xFF261B3D)),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, centerTitle: false),
    ),
    home: _initialized ? MainShell(key: _mainShellKey, apiService: _apiService, downloadManager: _downloadManager!, musicPlayer: _musicPlayer, onRestartServer: _restartServer, sharedUrl: _pendingSharedUrl, onSharedUrlConsumed: _consumeSharedUrl, onOpenLibrary: _openLibrary) : _StartupScreen(error: _startupError, onRetry: _initApp),
  );
}

class _StartupScreen extends StatelessWidget {
  final String? error; final VoidCallback onRetry;
  const _StartupScreen({this.error, required this.onRetry});
  @override Widget build(BuildContext context) { final hasError = error != null; return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.graphic_eq_rounded, size: 64, color: Color(0xFF8B5CF6)), const SizedBox(height: 20), Text(hasError ? 'Local server failed to start' : 'Starting Song Downloader…', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)), const SizedBox(height: 12), Text(hasError ? error! : 'Preparing your private downloader on this device.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)), if (hasError) ...[const SizedBox(height: 20), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'))] else ...[const SizedBox(height: 24), const CircularProgressIndicator()], ])))); }
}

class MainShell extends StatefulWidget {
  final DownloaderApiService apiService; final DownloadManagerService downloadManager; final MusicPlayerService musicPlayer; final Future<void> Function() onRestartServer; final String? sharedUrl; final VoidCallback onSharedUrlConsumed; final VoidCallback onOpenLibrary;
  const MainShell({super.key, required this.apiService, required this.downloadManager, required this.musicPlayer, required this.onRestartServer, this.sharedUrl, required this.onSharedUrlConsumed, required this.onOpenLibrary});
  @override State<MainShell> createState() => _MainShellState();
}
class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  void openLibrary() => setState(() => _currentIndex = 1);
  @override Widget build(BuildContext context) { final pages = [HomeScreen(apiService: widget.apiService, downloadManager: widget.downloadManager, sharedUrl: widget.sharedUrl, onSharedUrlConsumed: widget.onSharedUrlConsumed, onOpenLibrary: widget.onOpenLibrary), LibraryScreen(musicPlayer: widget.musicPlayer), DownloadManagerScreen(manager: widget.downloadManager), SettingsScreen(apiService: widget.apiService, onRestartServer: widget.onRestartServer)]; return Scaffold(body: IndexedStack(index: _currentIndex, children: pages), bottomNavigationBar: NavigationBar(selectedIndex: _currentIndex, onDestinationSelected: (i) => setState(() => _currentIndex = i), destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'), NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music_rounded), label: 'Library'), NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download_rounded), label: 'Downloads'), NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings')])); }
}
