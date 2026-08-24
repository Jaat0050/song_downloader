import 'package:flutter_test/flutter_test.dart';
import 'package:song_downloder/services/downloader_api.dart';

void main() {
  test('ServerHealth parses a healthy local backend response', () {
    final health = ServerHealth.fromJson({
      'success': true,
      'status': 'ok',
      'server': 'Flask',
      'host': '127.0.0.1',
      'port': 5000,
      'uptime_seconds': 42,
      'started_at': '2026-08-24T00:00:00Z',
      'python_version': '3.11.16',
      'yt_dlp': '2026.08.19',
      'audio_format': 'mp3',
      'ffmpeg': 'available',
      'download_storage_bytes': 1024,
      'disk_free_bytes': 4096,
      'disk_total_bytes': 8192,
      'storage_ready': true,
      'jobs': {'queued': 1, 'downloading': 2, 'completed': 3},
      'worker_pool': {'max_workers': 2, 'status': 'running'},
    });

    expect(health.healthy, isTrue);
    expect(health.host, '127.0.0.1');
    expect(health.port, 5000);
    expect(health.pythonVersion, '3.11.16');
    expect(health.ytDlpVersion, '2026.08.19');
    expect(health.audioFormat, 'mp3');
    expect(health.storageReady, isTrue);
    expect(health.jobs['completed'], 3);
    expect(health.workerCount, 2);
    expect(health.workerStatus, 'running');
  });
}
