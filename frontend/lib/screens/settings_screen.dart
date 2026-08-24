import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/downloader_api.dart';
import '../services/download_storage.dart';

class SettingsScreen extends StatefulWidget {
  final DownloaderApiService apiService;
  final Future<void> Function() onRestartServer;

  const SettingsScreen({
    super.key,
    required this.apiService,
    required this.onRestartServer,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = DownloadStorageService();
  ServerHealth? _health;
  String? _error;
  bool _loading = true;
  bool _restarting = false;
  bool _actionBusy = false;
  Timer? _timer;
  int _librarySongs = 0;
  int _libraryBytes = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loading = true);
    }

    try {
      final health = await widget.apiService.fetchHealth();
      final history = await _storage.loadHistory();
      final size = await _storage.getLibrarySizeBytes();

      if (mounted) {
        setState(() {
          _health = health;
          _librarySongs = history.length;
          _libraryBytes = size;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _restart() async {
    if (mounted) setState(() => _restarting = true);

    try {
      await widget.onRestartServer();
      await _refresh();
      if (mounted) {
        _snack('Local server restarted successfully.');
      }
    } catch (e) {
      if (mounted) {
        _snack('Restart failed: $e');
      }
    } finally {
      if (mounted) setState(() => _restarting = false);
    }
  }

  Future<void> _clearTemp() async {
    if (mounted) setState(() => _actionBusy = true);

    try {
      final count = await _storage.clearTemporaryFiles();
      if (mounted) {
        _snack(
          count == 0
              ? 'No temporary files found.'
              : 'Removed $count temporary file${count == 1 ? '' : 's'}.',
        );
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Clear history?'),
            content: const Text(
              'This removes library history only. Your MP3 files are kept.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Clear'),
              ),
            ],
          ),
    );

    if (ok == true) {
      await _storage.clearHistoryOnly();
      await _refresh();
    }
  }

  Future<void> _resetData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Reset app data?'),
            content: const Text(
              'Favorites, playlists and library history will be removed. Downloaded MP3 files will remain.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reset'),
              ),
            ],
          ),
    );

    if (ok == true) {
      await _storage.resetLocalData();
      await _refresh();
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _bytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  }

  String _uptime(int seconds) {
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (days > 0) return '${days}d ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${secs}s';
    return '${secs}s';
  }

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF15151B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: child,
    );
  }

  Widget _row(String label, String value, {bool good = true, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            icon ?? (good ? Icons.check_circle_rounded : Icons.error_rounded),
            size: 18,
            color: good ? Colors.greenAccent : Colors.redAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final health = _health;
    final online = health?.healthy == true && _error == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          children: [
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: online ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        online ? 'Backend Online' : 'Backend Offline',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_loading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    online
                        ? 'Embedded Python server is healthy and responding.'
                        : (_error ?? 'Checking local backend…'),
                    style: const TextStyle(color: Colors.white60, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _restarting ? null : _restart,
                      icon:
                          _restarting
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.restart_alt_rounded),
                      label: Text(
                        _restarting
                            ? 'Restarting Server…'
                            : 'Restart Local Server',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Server Health',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _row(
                    'HTTP health',
                    online ? 'OK' : 'Failed',
                    good: online,
                    icon: Icons.monitor_heart_rounded,
                  ),
                  _row(
                    'Server',
                    health?.server ?? '—',
                    icon: Icons.dns_rounded,
                  ),
                  _row(
                    'Address',
                    health == null
                        ? '—'
                        : '${health.host}:${health.port ?? '—'}',
                    icon: Icons.lan_rounded,
                  ),
                  _row(
                    'Uptime',
                    health == null ? '—' : _uptime(health.uptimeSeconds),
                    icon: Icons.timer_outlined,
                  ),
                  _row(
                    'Workers',
                    health == null
                        ? '—'
                        : '${health.workerCount} • ${health.workerStatus}',
                    good: health?.workerStatus == 'ready',
                    icon: Icons.account_tree_rounded,
                  ),
                  _row(
                    'Python',
                    health?.pythonVersion ?? '—',
                    icon: Icons.code_rounded,
                  ),
                  _row(
                    'yt-dlp',
                    health?.ytDlpVersion ?? '—',
                    icon: Icons.download_rounded,
                  ),
                  _row(
                    'FFmpeg',
                    health?.ffmpeg ?? '—',
                    icon: Icons.movie_creation_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Download Engine',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final entry in <MapEntry<String, int>>[
                    MapEntry('Total', health?.jobs['total'] ?? 0),
                    MapEntry('Queued', health?.jobs['queued'] ?? 0),
                    MapEntry('Extracting', health?.jobs['extracting'] ?? 0),
                    MapEntry('Downloading', health?.jobs['downloading'] ?? 0),
                    MapEntry('Processing', health?.jobs['processing'] ?? 0),
                    MapEntry('Completed', health?.jobs['completed'] ?? 0),
                    MapEntry('Failed', health?.jobs['failed'] ?? 0),
                    MapEntry('Cancelled', health?.jobs['cancelled'] ?? 0),
                  ])
                    _row(
                      entry.key,
                      '${entry.value}',
                      good:
                          !['Failed', 'Cancelled'].contains(entry.key) ||
                          entry.value == 0,
                      icon: Icons.queue_music_rounded,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Library & Storage',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _row(
                    'Songs',
                    '$_librarySongs',
                    icon: Icons.music_note_rounded,
                  ),
                  _row(
                    'Library size',
                    _bytes(_libraryBytes),
                    icon: Icons.folder_rounded,
                  ),
                  _row(
                    'Backend storage',
                    health == null ? '—' : _bytes(health.storageBytes),
                    icon: Icons.storage_rounded,
                  ),
                  _row(
                    'Free device space',
                    health == null ? '—' : _bytes(health.diskFreeBytes),
                    good: (health?.diskFreeBytes ?? 1) > 100 * 1024 * 1024,
                    icon: Icons.sd_storage_rounded,
                  ),
                  _row(
                    'Total device space',
                    health == null ? '—' : _bytes(health.diskTotalBytes),
                    icon: Icons.storage_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Maintenance',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: const Text('Clear temporary files'),
                    subtitle: const Text(
                      'Remove leftover WebM/part audio files',
                    ),
                    trailing:
                        _actionBusy
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.chevron_right),
                    onTap: _actionBusy ? null : _clearTemp,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history),
                    title: const Text('Clear library history'),
                    subtitle: const Text(
                      'Keep MP3 files, remove library records',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _clearHistory,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restart_alt),
                    title: const Text('Reset local app data'),
                    subtitle: const Text(
                      'Remove favorites, playlists and history',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _resetData,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'App Status',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _row(
                    'App version',
                    '1.0.0 (Build 1)',
                    icon: Icons.apps_rounded,
                  ),
                  _row(
                    'Platform',
                    Platform.operatingSystem,
                    icon: Icons.phone_android_rounded,
                  ),
                  _row(
                    'Backend',
                    'Embedded / Offline',
                    icon: Icons.phonelink_rounded,
                  ),
                  _row(
                    'Network exposure',
                    '127.0.0.1 only',
                    icon: Icons.lock_outline_rounded,
                  ),
                  _row(
                    'External API',
                    'Not required',
                    icon: Icons.cloud_off_rounded,
                  ),
                  _row('Audio output', 'MP3', icon: Icons.music_note_rounded),
                  const SizedBox(height: 8),
                  SelectableText(
                    widget.apiService.baseUrl,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Health refreshes automatically every 5 seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
