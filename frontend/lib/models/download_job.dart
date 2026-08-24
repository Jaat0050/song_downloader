class DownloadProgress {
  final String jobId;
  final String status; // queued | extracting | downloading | converting | saving | completed | failed | cancelled
  final double progress;
  final String speed;
  final int? eta;
  final String filename;
  final String? error;
  final String? url;
  final bool cancelRequested;

  const DownloadProgress({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.speed,
    required this.eta,
    required this.filename,
    this.error,
    this.url,
    this.cancelRequested = false,
  });

  factory DownloadProgress.fromJson(Map<String, dynamic> json) {
    return DownloadProgress(
      jobId: (json['job_id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'queued',
      progress: ((json['progress'] as num?) ?? 0.0).toDouble(),
      speed: (json['speed'] as String?) ?? '',
      eta: (json['eta'] as num?)?.toInt(),
      filename: (json['filename'] as String?) ?? '',
      error: json['error'] as String?,
      url: json['url'] as String?,
      cancelRequested: json['cancel_requested'] == true,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';
  bool get isFinished => isCompleted || isFailed || isCancelled;
  bool get isActive => !isFinished;
}
