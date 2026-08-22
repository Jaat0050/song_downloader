import 'package:flutter/material.dart';
import '../services/download_storage.dart';
import '../services/downloader_api.dart';

class SettingsScreen extends StatefulWidget {
  final DownloaderApiService apiService;
  final VoidCallback onUrlUpdated;

  const SettingsScreen({
    super.key,
    required this.apiService,
    required this.onUrlUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DownloadStorageService _storageService = DownloadStorageService();
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.apiService.baseUrl);
  }

  Future<void> _saveUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    await _storageService.setBackendUrl(trimmed);
    widget.apiService.updateBaseUrl(trimmed);
    widget.onUrlUpdated();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backend URL saved: $trimmed')),
      );
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

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
              'Backend API Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure the URL of your Python Flask backend server.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Backend Base URL',
                hintText: 'http://10.0.2.2:5000 or http://192.168.x.x:5000',
                prefixIcon: const Icon(Icons.dns_rounded),
                filled: true,
                fillColor: const Color(0xFF17171D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => _saveUrl(_urlController.text),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save Backend URL'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Presets for Quick Setup',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              leading: const Icon(Icons.phone_android_rounded, color: Color(0xFF8B5CF6)),
              title: const Text('Android Emulator'),
              subtitle: const Text('http://10.0.2.2:5000'),
              onTap: () {
                _urlController.text = 'http://10.0.2.2:5000';
                _saveUrl('http://10.0.2.2:5000');
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              leading: const Icon(Icons.computer_rounded, color: Color(0xFF8B5CF6)),
              title: const Text('Localhost / Desktop'),
              subtitle: const Text('http://127.0.0.1:5000'),
              onTap: () {
                _urlController.text = 'http://127.0.0.1:5000';
                _saveUrl('http://127.0.0.1:5000');
              },
            ),
            const SizedBox(height: 28),
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
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.white70),
                      SizedBox(width: 10),
                      Text('Physical Android Device Setup', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'For a physical phone connected to your Wi-Fi network, replace localhost/10.0.2.2 with your computer\'s local network IP address (e.g., http://192.168.1.15:5000).',
                    style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
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
