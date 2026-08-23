import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'services/downloader_api.dart';
import 'services/local_server_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SongDownloaderApp());
}

class SongDownloaderApp extends StatefulWidget {
  const SongDownloaderApp({super.key});

  @override
  State<SongDownloaderApp> createState() => _SongDownloaderAppState();
}

class _SongDownloaderAppState extends State<SongDownloaderApp> {
  final LocalServerService _localServer = LocalServerService();
  late DownloaderApiService _apiService;
  String? _startupError;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      final backendUrl = await _localServer.start();
      _apiService = DownloaderApiService(baseUrl: backendUrl);
      await _apiService.checkHealth();
      if (mounted) {
        setState(() {
          _initialized = true;
          _startupError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _startupError = e.toString();
          _initialized = false;
        });
      }
    }
  }

  Future<void> _restartServer() async {
    final backendUrl = await _localServer.restart();
    final api = DownloaderApiService(baseUrl: backendUrl);
    await api.checkHealth();
    if (mounted) {
      setState(() {
        _apiService = api;
        _startupError = null;
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Song Downloader',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0B0F),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B5CF6), brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: _initialized
          ? MainShell(apiService: _apiService, onRestartServer: _restartServer)
          : _StartupScreen(error: _startupError, onRetry: _initApp),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;

  const _StartupScreen({this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.dns_rounded, size: 64, color: Color(0xFF8B5CF6)),
              const SizedBox(height: 20),
              Text(hasError ? 'Local server failed to start' : 'Starting local server…', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(hasError ? error! : 'Preparing the private downloader on this device.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.4)),
              if (hasError) ...[
                const SizedBox(height: 20),
                FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
              ] else ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final DownloaderApiService apiService;
  final Future<void> Function() onRestartServer;

  const MainShell({super.key, required this.apiService, required this.onRestartServer});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(apiService: widget.apiService),
      const LibraryScreen(),
      SettingsScreen(apiService: widget.apiService, onRestartServer: widget.onRestartServer),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: const Color(0xFF13131A),
        indicatorColor: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF8B5CF6)), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music_rounded, color: Color(0xFF8B5CF6)), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFF8B5CF6)), label: 'Settings'),
        ],
      ),
    );
  }
}
