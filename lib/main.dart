import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'services/download_storage.dart';
import 'services/downloader_api.dart';

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
  final DownloadStorageService _storageService = DownloadStorageService();
  late DownloaderApiService _apiService;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initStorage();
  }

  Future<void> _initStorage() async {
    final backendUrl = await _storageService.getBackendUrl();
    _apiService = DownloaderApiService(baseUrl: backendUrl);
    if (mounted) {
      setState(() {
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B5CF6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: _initialized
          ? MainShell(
              apiService: _apiService,
              onUrlUpdated: () => setState(() {}),
            )
          : const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
    );
  }
}

class MainShell extends StatefulWidget {
  final DownloaderApiService apiService;
  final VoidCallback onUrlUpdated;

  const MainShell({
    super.key,
    required this.apiService,
    required this.onUrlUpdated,
  });

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
      SettingsScreen(
        apiService: widget.apiService,
        onUrlUpdated: widget.onUrlUpdated,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: const Color(0xFF13131A),
        indicatorColor: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF8B5CF6)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music_rounded, color: Color(0xFF8B5CF6)),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFF8B5CF6)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
