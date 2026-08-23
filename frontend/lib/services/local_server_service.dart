import 'package:flutter/services.dart';

class LocalServerException implements Exception {
  final String message;
  LocalServerException(this.message);
  @override
  String toString() => message;
}

class LocalServerService {
  static const MethodChannel _channel = MethodChannel('song_downloader/local_server');

  String? _baseUrl;

  String? get baseUrl => _baseUrl;

  Future<String> start() async {
    try {
      final url = await _channel.invokeMethod<String>('startServer');
      if (url == null || url.isEmpty) {
        throw LocalServerException('Local server returned an empty URL.');
      }
      _baseUrl = url;
      return url;
    } on PlatformException catch (e) {
      throw LocalServerException(e.message ?? 'Unable to start local server.');
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopServer');
    } finally {
      _baseUrl = null;
    }
  }

  Future<String> restart() async {
    await stop();
    return start();
  }
}
