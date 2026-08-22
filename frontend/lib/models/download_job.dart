class DownloadProgress {
  final String jobId;
  final String status; // queued | downloading | processing | completed | failed
  final double progress;
  final String speed;
  final int eta;
  final String filename;
  final String? error;

  const DownloadProgress({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.speed,
    required this.eta,
    required this.filename,
    this.error,
  });

  factory DownloadProgress.fromJson(Map<String, dynamic> json) {
    return DownloadProgress(
      jobId: (json['job_id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'queued',
      progress: ((json['progress'] as num?) ?? 0.0).toDouble(),
      speed: (json['speed'] as String?) ?? '0B/s',
      eta: (json['eta'] as int?) ?? 0,
      filename: (json['filename'] as String?) ?? '',
      error: json['error'] as String?,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isFinished => isCompleted || isFailed;
}
