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
  final bool favorite;

  const HistoryItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnail,
    required this.filename,
    required this.localPath,
    required this.downloadedAt,
    required this.fileSize,
    this.favorite = false,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? 'Unknown song',
    artist: json['artist'] as String? ?? 'Unknown artist',
    thumbnail: json['thumbnail'] as String? ?? '',
    filename: json['filename'] as String? ?? '',
    localPath: json['local_path'] as String? ?? '',
    downloadedAt:
        DateTime.tryParse(json['downloaded_at'] as String? ?? '') ??
        DateTime.now(),
    fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
    favorite: json['favorite'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'thumbnail': thumbnail,
    'filename': filename,
    'local_path': localPath,
    'downloaded_at': downloadedAt.toIso8601String(),
    'file_size': fileSize,
    'favorite': favorite,
  };

  String encode() => jsonEncode(toJson());
  factory HistoryItem.decode(String raw) =>
      HistoryItem.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  HistoryItem copyWith({bool? favorite}) => HistoryItem(
    id: id,
    title: title,
    artist: artist,
    thumbnail: thumbnail,
    filename: filename,
    localPath: localPath,
    downloadedAt: downloadedAt,
    fileSize: fileSize,
    favorite: favorite ?? this.favorite,
  );
}
