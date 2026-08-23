import 'dart:async';
import 'package:flutter/material.dart';
import '../services/downloader_api.dart';

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
  ServerHealth? _health;
  String? _error;
  bool _loading = true;
  bool _restarting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final health = await widget.apiService.fetchHealth();
      if (mounted) setState(() {
        _health = health;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _restart() async {
    setState(() => _restarting = true);
    try {
      await widget.onRestartServer();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local server restarted successfully')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restart failed: $e')));
    } finally {
      if (mounted) setState(() => _restarting = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatUptime(int seconds) {
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (d > 0) return '${d}d ${h}h ${m}m';
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF15151B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: child,
      );

  Widget _statusRow(String label, String value, {bool good = true, IconData? icon}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon ?? (good ? Icons.check_circle_rounded : Icons.error_rounded), size: 18, color: good ? Colors.greenAccent : Colors.redAccent),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
            Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final health = _health;
    final online = health?.healthy == true && _error == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(onPressed: _loading ? null : () => _refresh(), icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh status'),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          children: [
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? Colors.greenAccent : Colors.redAccent)),
                    const SizedBox(width: 10),
                    Text(online ? 'Backend Online' : 'Backend Offline', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ]),
                  const SizedBox(height: 8),
                  Text(online ? 'Embedded Python server is healthy and responding.' : (_error ?? 'Checking local backend…'), style: const TextStyle(color: Colors.white60, height: 1.4)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _restarting ? null : _restart,
                      icon: _restarting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.restart_alt_rounded),
                      label: Text(_restarting ? 'Restarting Server…' : 'Restart Local Server'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Server Health', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _statusRow('HTTP health', online ? 'OK' : 'Failed', good: online, icon: Icons.monitor_heart_rounded),
                _statusRow('Server', health?.server ?? '—', icon: Icons.dns_rounded),
                _statusRow('Address', health == null ? '—' : '${health.host}:${health.port ?? '—'}', icon: Icons.lan_rounded),
                _statusRow('Uptime', health == null ? '—' : _formatUptime(health.uptimeSeconds), icon: Icons.timer_outlined),
                _statusRow('Workers', health == null ? '—' : '${health.workerCount} • ${health.workerStatus}', good: health?.workerStatus == 'ready', icon: Icons.account_tree_rounded),
                _statusRow('yt-dlp', health?.ytDlpVersion ?? '—', icon: Icons.download_rounded),
                _statusRow('FFmpeg', health?.ffmpeg ?? '—', icon: Icons.movie_creation_outlined),
                _statusRow('Python', health?.pythonVersion ?? '—', icon: Icons.code_rounded),
                _statusRow('Output', health?.audioFormat.toUpperCase() ?? '—', icon: Icons.audiotrack_rounded),
              ]),
            ),
            const SizedBox(height: 14),
            _card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Download Engine', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _statusRow('Total jobs', '${health?.jobs['total'] ?? 0}', icon: Icons.queue_music_rounded),
                _statusRow('Queued', '${health?.jobs['queued'] ?? 0}', icon: Icons.hourglass_top_rounded),
                _statusRow('Downloading', '${health?.jobs['downloading'] ?? 0}', icon: Icons.downloading_rounded),
                _statusRow('Processing', '${health?.jobs['processing'] ?? 0}', icon: Icons.sync_rounded),
                _statusRow('Completed', '${health?.jobs['completed'] ?? 0}', good: true, icon: Icons.check_circle_outline_rounded),
                _statusRow('Failed', '${health?.jobs['failed'] ?? 0}', good: (health?.jobs['failed'] ?? 0) == 0, icon: Icons.error_outline_rounded),
              ]),
            ),
            const SizedBox(height: 14),
            _card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Storage', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _statusRow('Downloaded files', health == null ? '—' : _formatBytes(health.storageBytes), icon: Icons.folder_rounded),
                _statusRow('Free device space', health == null ? '—' : _formatBytes(health.diskFreeBytes), good: (health?.diskFreeBytes ?? 1) > 100 * 1024 * 1024, icon: Icons.storage_rounded),
                _statusRow('Total device space', health == null ? '—' : _formatBytes(health.diskTotalBytes), icon: Icons.sd_storage_rounded),
              ]),
            ),
            const SizedBox(height: 14),
            _card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('App Configuration', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _statusRow('Backend type', 'Embedded / Offline', icon: Icons.phonelink_rounded),
                _statusRow('Network exposure', '127.0.0.1 only', icon: Icons.lock_outline_rounded),
                _statusRow('External API', 'Not required', icon: Icons.cloud_off_rounded),
                _statusRow('Audio output', 'MP3', icon: Icons.music_note_rounded),
                const SizedBox(height: 8),
                SelectableText(widget.apiService.baseUrl, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 14),
            const Text('Status refreshes automatically every 5 seconds.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
