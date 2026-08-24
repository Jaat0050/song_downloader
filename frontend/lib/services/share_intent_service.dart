import 'dart:async';
import 'package:flutter/services.dart';

class ShareIntentService {
  static const MethodChannel _channel = MethodChannel('song_downloader/local_server');

  final StreamController<String> _sharedTextController = StreamController<String>.broadcast();
  bool _initialized = false;

  Stream<String> get sharedTextStream => _sharedTextController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedText') {
        final text = call.arguments?.toString().trim();
        if (text != null && text.isNotEmpty) {
          _sharedTextController.add(text);
        }
      }
      return null;
    });
  }

  Future<String?> getInitialSharedText() async {
    await initialize();
    try {
      final value = await _channel.invokeMethod<String>('getInitialSharedText');
      final text = value?.trim();
      return text == null || text.isEmpty ? null : text;
    } on PlatformException {
      return null;
    }
  }

  String? extractYouTubeUrl(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = text.trim();

    final uri = Uri.tryParse(value);
    if (uri != null && _isYouTubeHost(uri.host)) {
      return value;
    }

    final match = RegExp(
      r'https?://(?:www\.|m\.)?(?:youtube\.com|youtu\.be|youtube-nocookie\.com)\S*',
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(0)?.replaceAll(RegExp(r'[\s\]\)>.,]+$'), '');
  }

  bool _isYouTubeHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'youtube.com' ||
        normalized == 'www.youtube.com' ||
        normalized == 'm.youtube.com' ||
        normalized == 'youtu.be' ||
        normalized == 'www.youtu.be' ||
        normalized == 'youtube-nocookie.com' ||
        normalized == 'www.youtube-nocookie.com';
  }

  void dispose() {
    _sharedTextController.close();
  }
}
