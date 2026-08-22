import 'dart:convert';

class HistoryItem {
  final String id;
  final String title;
  final String artist;
  final String thumbnail;
  final String filename;
  final String localPath;
  final DateTime downloadedAt;
  final int fileSize;

  const HistoryItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnail,
    required this.filename,
    required this.localPath,
    required this.downloadedAt,
    required this.fileSize,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Unknown song',
      artist: (json['artist'] as String?) ?? 'Unknown artist',
      thumbnail: (json['thumbnail'] as String?) ?? '',
      filename: (json['filename'] as String?) ?? '',
      localPath: (json['local_path'] as String?) ?? '',
      downloadedAt: DateTime.tryParse((json['downloaded_at'] as String?) ?? '') ?? DateTime.now(),
      fileSize: (json['file_size'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'thumbnail': thumbnail,
        'filename': filename,
        'local_path': localPath,
        'downloaded_at': downloadedAt.toIso8601String(),
        'file_size': fileSize,
      };

  String encode() => jsonEncode(toJson());

  factory HistoryItem.decode(String rawJson) => HistoryItem.fromJson(jsonDecode(rawJson) as Map<String, dynamic>);
}
