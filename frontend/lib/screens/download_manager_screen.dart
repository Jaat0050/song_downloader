import 'package:flutter/material.dart';
import '../models/download_job.dart';
import '../services/download_manager_service.dart';
import '../theme/neumorphic_widgets.dart';

class DownloadManagerScreen extends StatelessWidget {
  final DownloadManagerService manager;
  const DownloadManagerScreen({super.key, required this.manager});
  String _statusText(DownloadProgress j) {
    switch (j.status) {
      case 'queued':
        return 'Queued';
      case 'extracting':
        return 'Preparing';
      case 'downloading':
        return 'Downloading';
      case 'processing':
      case 'converting':
        return 'Converting to MP3';
      case 'saving':
        return 'Saving';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'failed':
        return 'Failed';
      default:
        return j.status;
    }
  }

  Color _statusColor(DownloadProgress j) {
    if (j.isCompleted) return Colors.greenAccent;
    if (j.isFailed || j.isCancelled) return Colors.redAccent;
    return const Color(0xFF8B5CF6);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: manager,
    builder: (context, _) {
      final jobs = manager.jobs;
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Downloads',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            if (jobs.isNotEmpty)
              NeuIconButton(
                icon: Icons.refresh_rounded,
                onPressed:
                    () => Future.wait(
                      jobs.map((j) => manager.refreshJob(j.jobId)),
                    ),
              ),
            const SizedBox(width: 12),
          ],
        ),
        body:
            jobs.isEmpty
                ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download_for_offline_rounded,
                        size: 64,
                        color: Colors.white24,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'No downloads yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Your active and recent downloads will appear here.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                )
                : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder:
                      (context, i) => _JobCard(
                        job: jobs[i],
                        manager: manager,
                        statusText: _statusText(jobs[i]),
                        statusColor: _statusColor(jobs[i]),
                      ),
                ),
      );
    },
  );
}

class _JobCard extends StatelessWidget {
  final DownloadProgress job;
  final DownloadManagerService manager;
  final String statusText;
  final Color statusColor;
  const _JobCard({
    required this.job,
    required this.manager,
    required this.statusText,
    required this.statusColor,
  });
  @override
  Widget build(BuildContext context) {
    final p = (job.progress / 100).clamp(0.0, 1.0);
    return NeuSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeuIconButton(
                icon:
                    job.isCompleted
                        ? Icons.check_rounded
                        : job.isFailed || job.isCancelled
                        ? Icons.error_outline_rounded
                        : Icons.music_note_rounded,
                active: job.isCompleted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  job.filename.isNotEmpty
                      ? job.filename
                      : (job.url ?? 'Audio download'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'cancel') await manager.cancel(job.jobId);
                  if (v == 'retry') await manager.retry(job.jobId);
                  if (v == 'delete') await manager.remove(job.jobId);
                },
                itemBuilder:
                    (_) => [
                      if (job.isActive)
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Text('Cancel download'),
                        ),
                      if (job.isFailed || job.isCancelled)
                        const PopupMenuItem(
                          value: 'retry',
                          child: Text('Retry download'),
                        ),
                      if (job.isFinished)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Remove from list'),
                        ),
                    ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (job.isActive)
                Text(
                  '${job.progress.toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white70),
                ),
            ],
          ),
          if (job.isActive) ...[
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: p,
                minHeight: 8,
                backgroundColor: Colors.white10,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (job.speed.isNotEmpty)
                  Text(
                    job.speed,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                const Spacer(),
                if (job.eta != null && job.eta! > 0)
                  Text(
                    'ETA ${job.eta}s',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
          ],
          if (job.error != null && job.error!.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              job.error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          if (job.isFailed || job.isCancelled) ...[
            const SizedBox(height: 12),
            NeuButton(
              onPressed: () => manager.retry(job.jobId),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh_rounded),
                  SizedBox(width: 7),
                  Text('Retry'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
