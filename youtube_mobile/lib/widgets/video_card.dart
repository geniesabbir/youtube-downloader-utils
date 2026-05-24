import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/video_job.dart';
import '../services/download_service.dart';
import '../services/playback_service.dart';
import '../services/security_service.dart';
import 'metadata_editor.dart';
import 'video_player_view.dart';

class VideoCard extends StatelessWidget {
  final VideoJob job;
  final VoidCallback onVaultLocked;

  const VideoCard({
    super.key,
    required this.job,
    required this.onVaultLocked,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = job.status == "Completed" && job.localPath != null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: job.downloading
              ? const Color(0xff00d2ff).withOpacity(0.5)
              : Colors.blueGrey.withOpacity(0.2),
          width: job.downloading ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (job.downloading)
            BoxShadow(
              color: const Color(0xff00d2ff).withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: const Color(0xff121820).withOpacity(0.75),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Glowing cyber icon placeholder or thumbnail
                    Container(
                      width: (job.thumbnailUrl != null && job.thumbnailUrl!.isNotEmpty) ? 80 : 55,
                      height: 55,
                      decoration: BoxDecoration(
                        color: const Color(0xff0a0d14),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: isCompleted
                              ? const Color(0xff00ff88).withOpacity(0.3)
                              : const Color(0xff00d2ff).withOpacity(0.3),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7.0),
                        child: (job.thumbnailUrl != null && job.thumbnailUrl!.isNotEmpty)
                            ? Image.network(
                                job.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      job.isAudio ? Icons.music_note : Icons.play_arrow,
                                      color: isCompleted
                                          ? const Color(0xff00ff88)
                                          : const Color(0xff00d2ff),
                                      size: 28,
                                    ),
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xff00d2ff)),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Icon(
                                  job.isAudio ? Icons.music_note : Icons.play_arrow,
                                  color: isCompleted
                                      ? const Color(0xff00ff88)
                                      : const Color(0xff00d2ff),
                                  size: 28,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Channel: ${job.author} • Duration: ${job.duration}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress Bar
                if (job.downloading || job.progress > 0 && !isCompleted) ...[
                  LinearProgressIndicator(
                    value: job.progress,
                    backgroundColor: const Color(0xff0a0d14),
                    color: const Color(0xff00d2ff),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 6),
                ],
                // Chapters Horizontal Navigation List (If analyzed only and chapters exist)
                if (job.discovered && !job.downloadTriggered && job.localPath == null && job.chapters.isNotEmpty) ...[
                  const Text(
                    "DETECTED CHAPTERS INDEX",
                    style: TextStyle(
                      color: Color(0xff00d2ff),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 32,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: job.chapters.length,
                      itemBuilder: (context, cIdx) {
                        final ch = job.chapters[cIdx];
                        final startStr = _formatDuration(ch.start);
                        return Container(
                          margin: const EdgeInsets.only(right: 8.0),
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: const Color(0xff0a0d14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xff00d2ff).withOpacity(0.2),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            "[$startStr] ${ch.title}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // Format Selector Action Panel (If analyzed only)
                if (job.discovered && !job.downloadTriggered && job.localPath == null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => DownloadService().startDownload(job.jobId, isAudio: false),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xff00d2ff).withOpacity(0.15),
                                  const Color(0xff0088ff).withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xff00d2ff).withOpacity(0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xff00d2ff).withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.movie_creation_outlined, color: Color(0xff00d2ff), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  "VIDEO (MP4)",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => DownloadService().startDownload(job.jobId, isAudio: true),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xff00ff88).withOpacity(0.15),
                                  const Color(0xff00aa55).withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xff00ff88).withOpacity(0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xff00ff88).withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.music_note_outlined, color: Color(0xff00ff88), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  "AUDIO (MP3)",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                // Status / Metadata Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        job.status,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _getStatusColor(job),
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                          fontFamily: "monospace",
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        if (job.discoverFailed || job.downloadFailed)
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.amber),
                            tooltip: "Retry Download",
                            onPressed: () => DownloadService().retryJob(job.jobId),
                          ),
                        if (isCompleted) ...[
                          IconButton(
                            icon: const Icon(Icons.edit_note, color: Color(0xff00d2ff)),
                            tooltip: "Edit Tags",
                            onPressed: () => _openTagEditor(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.lock_outline, color: Colors.amber),
                            tooltip: "Lock in Secure Vault",
                            onPressed: () => _moveFileToVault(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.play_circle_fill, color: Color(0xff00ff88), size: 30),
                            tooltip: "Play",
                            onPressed: () {
                              if (job.isAudio) {
                                PlaybackService().play(job);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VideoPlayerView(job: job),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: "Remove Download",
                          onPressed: () => DownloadService().removeJob(job.jobId),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(VideoJob job) {
    if (job.status == "Completed") return const Color(0xff00ff88);
    if (job.discoverFailed || job.downloadFailed) return Colors.redAccent;
    if (job.downloading) return const Color(0xff00d2ff);
    if (job.status.startsWith("Paused")) return Colors.amber;
    if (job.discovered && !job.downloadTriggered) return const Color(0xff00d2ff);
    return Colors.white.withOpacity(0.5);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _openTagEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MetadataEditor(job: job),
    );
  }

  Future<void> _moveFileToVault(BuildContext context) async {
    final sec = SecurityService();
    final enabled = await sec.isLockEnabled;
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enable 'Biometric Lock' in settings to lock files in the vault."),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final authenticated = await sec.authenticate("Authenticate to lock file in Secure Vault");
    if (authenticated) {
      job.status = "Vault Locked";
      onVaultLocked();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("File locked securely in Biometric Enclave Vault."),
          backgroundColor: Color(0xff00ff88),
        ),
      );
    }
  }
}
