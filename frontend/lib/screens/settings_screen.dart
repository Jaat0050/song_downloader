import 'package:flutter/material.dart';
import '../services/downloader_api.dart';

class SettingsScreen extends StatelessWidget {
  final DownloaderApiService apiService;

  const SettingsScreen({
    super.key,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Local Downloader Server',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'The Python Flask server runs privately inside this Android app. No Render, VPS, or external backend URL is required.',
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF15151B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.dns_rounded, color: Color(0xFF8B5CF6)),
                      SizedBox(width: 10),
                      Text('Server status', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 18, color: Colors.greenAccent),
                      SizedBox(width: 8),
                      Text('Running on this device'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    apiService.baseUrl,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF15151B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How it works', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text(
                    '1. Flutter starts the embedded Python runtime.\n'
                    '2. Flask starts on a private localhost port.\n'
                    '3. yt-dlp performs extraction/download work on this device.\n'
                    '4. Downloaded files remain on this device.',
                    style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.55),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF211A31),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'The local server is bound to 127.0.0.1, so it is not exposed as a public API. The Python runtime and downloader must be included in the Android build.',
                      style: TextStyle(fontSize: 13, height: 1.4),
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
}
