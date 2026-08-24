import 'package:flutter/material.dart';
import '../models/download_job.dart';
import '../services/download_manager_service.dart';

class DownloadManagerScreen extends StatelessWidget {
  final DownloadManagerService manager;
  const DownloadManagerScreen({super.key, required this.manager});

  String _statusText(DownloadProgress job) {
    switch (job.status) {
      case 'queued': return 'Queued';
      case 'extracting': return 'Preparing';
      case 'downloading': return 'Downloading';
      case 'processing':
      case 'converting': return 'Converting to MP3';
      case 'saving': return 'Saving';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      case 'failed': return 'Failed';
      default: return job.status;
    }
  }

  Color _statusColor(DownloadProgress job) {
    if (job.isCompleted) return Colors.greenAccent;
    if (job.isFailed || job.isCancelled) return Colors.redAccent;
    return const Color(0xFF8B5CF6);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: manager,
      builder: (context, _) {
        final jobs = manager.jobs;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Downloads', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            actions: [
              if (jobs.isNotEmpty)
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => Future.wait(jobs.map((job) => manager.refreshJob(job.jobId))),
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
          body: jobs.isEmpty
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.download_for_offline_rounded, size: 64, color: Colors.white24),
                    SizedBox(height: 14),
                    Text('No downloads yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text('Your active and recent downloads will appear here.', style: TextStyle(color: Colors.white54)),
                  ]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _JobCard(job: jobs[index], manager: manager, statusText: _statusText(jobs[index]), statusColor: _statusColor(jobs[index])),
                ),
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  final DownloadProgress job;
  final DownloadManagerService manager;
  final String statusText;
  final Color statusColor;
  const _JobCard({required this.job, required this.manager, required this.statusText, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    final progress = (job.progress / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF15151B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: statusColor.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)), child: Icon(job.isCompleted ? Icons.check_rounded : job.isFailed || job.isCancelled ? Icons.error_outline_rounded : Icons.music_note_rounded, color: statusColor)),
          const SizedBox(width: 12),
          Expanded(child: Text(job.filename.isNotEmpty ? job.filename : (job.url ?? 'Audio download'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'cancel') await manager.cancel(job.jobId);
              if (value == 'retry') await manager.retry(job.jobId);
              if (value == 'delete') await manager.remove(job.jobId);
            },
            itemBuilder: (_) => [
              if (job.isActive) const PopupMenuItem(value: 'cancel', child: Text('Cancel download')),
              if (job.isFailed || job.isCancelled) const PopupMenuItem(value: 'retry', child: Text('Retry download')),
              if (job.isFinished) const PopupMenuItem(value: 'delete', child: Text('Remove from list')),
            ],
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700)), const Spacer(), if (job.isActive) Text('${job.progress.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white70))]),
        if (job.isActive) ...[
          const SizedBox(height: 9),
          LinearProgressIndicator(value: progress, minHeight: 7, backgroundColor: Colors.white10),
          const SizedBox(height: 8),
          Row(children: [if (job.speed.isNotEmpty) Text(job.speed, style: const TextStyle(color: Colors.white54, fontSize: 12)), const Spacer(), if (job.eta != null && job.eta! > 0) Text('ETA ${job.eta}s', style: const TextStyle(color: Colors.white54, fontSize: 12))]),
        ],
        if (job.error != null && job.error!.isNotEmpty) ...[
          const SizedBox(height: 9),
          Text(job.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
        ],
        if (job.isFailed || job.isCancelled) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => manager.retry(job.jobId), icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Retry'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42))),
        ],
      ]),
    );
  }
}
