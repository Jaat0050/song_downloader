class AudioFormat {
  final String? formatId;
  final String? ext;
  final String? codec;
  final num? bitrate;
  final num? sampleRate;
  final num? size;

  const AudioFormat({
    this.formatId,
    this.ext,
    this.codec,
    this.bitrate,
    this.sampleRate,
    this.size,
  });

  factory AudioFormat.fromJson(Map<String, dynamic> json) {
    return AudioFormat(
      formatId: json['format_id'] as String?,
      ext: json['ext'] as String?,
      codec: json['codec'] as String?,
      bitrate: json['bitrate'] as num?,
      sampleRate: json['sample_rate'] as num?,
      size: json['size'] as num?,
    );
  }

  Map<String, dynamic> toJson() => {
        'format_id': formatId,
        'ext': ext,
        'codec': codec,
        'bitrate': bitrate,
        'sample_rate': sampleRate,
        'size': size,
      };
}

class SongInfo {
  final String id;
  final String title;
  final String artist;
  final String uploader;
  final int duration;
  final String thumbnail;
  final String webpageUrl;
  final List<AudioFormat> audioFormats;

  const SongInfo({
    required this.id,
    required this.title,
    required this.artist,
    required this.uploader,
    required this.duration,
    required this.thumbnail,
    required this.webpageUrl,
    required this.audioFormats,
  });

  factory SongInfo.fromJson(Map<String, dynamic> json) {
    final rawFormats = json['audio_formats'] as List<dynamic>? ?? [];
    return SongInfo(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Unknown song',
      artist: (json['artist'] as String?) ?? (json['uploader'] as String?) ?? 'Unknown artist',
      uploader: (json['uploader'] as String?) ?? '',
      duration: (json['duration'] as int?) ?? 0,
      thumbnail: (json['thumbnail'] as String?) ?? '',
      webpageUrl: (json['webpage_url'] as String?) ?? '',
      audioFormats: rawFormats.map((f) => AudioFormat.fromJson(Map<String, dynamic>.from(f as Map))).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'uploader': uploader,
        'duration': duration,
        'thumbnail': thumbnail,
        'webpage_url': webpageUrl,
        'audio_formats': audioFormats.map((f) => f.toJson()).toList(),
      };
}
