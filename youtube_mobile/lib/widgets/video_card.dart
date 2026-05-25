import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/video_job.dart';
import '../services/download_service.dart';
import '../services/playback_service.dart';
import 'metadata_editor.dart';
import 'video_player_view.dart';

class VideoCard extends StatefulWidget {
  final VideoJob job;
  final bool showFavoriteOption;
  final VoidCallback? onFavoritePressed;

  const VideoCard({
    super.key,
    required this.job,
    this.showFavoriteOption = false,
    this.onFavoritePressed,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  VideoJob get job => widget.job;
  DismissDirection? _swipeDirection;

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = job.localPath != null;
    final bool isFailed = job.discoverFailed || job.downloadFailed;

    Color underlyingColor = const Color(0xff0f1520);
    if (_swipeDirection == DismissDirection.startToEnd) {
      underlyingColor = const Color(0xff00ff88).withOpacity(0.7);
    } else if (_swipeDirection == DismissDirection.endToStart) {
      underlyingColor = Colors.redAccent.withOpacity(0.7);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: underlyingColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: job.downloading
              ? const Color(0xff00d2ff).withOpacity(0.5)
              : job.isPaused
              ? Colors.amber.withOpacity(0.4)
              : isFailed
              ? Colors.redAccent.withOpacity(0.4)
              : Colors.blueGrey.withOpacity(0.2),
          width: (job.downloading || job.isPaused) ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (job.downloading)
            BoxShadow(
              color: const Color(0xff00d2ff).withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          if (job.isPaused)
            BoxShadow(
              color: Colors.amber.withOpacity(0.08),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Dismissible(
          key: ValueKey(job.jobId),
          direction: isCompleted
              ? DismissDirection.horizontal
              : DismissDirection.endToStart,
          onUpdate: (details) {
            if (details.progress == 0.0) {
              if (_swipeDirection != null) {
                setState(() {
                  _swipeDirection = null;
                });
              }
            } else {
              if (_swipeDirection != details.direction) {
                setState(() {
                  _swipeDirection = details.direction;
                });
              }
            }
          },
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd && isCompleted) {
              _playJob(context);
              return false;
            }
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xff121820),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'Remove item?',
                  style: TextStyle(color: Colors.white),
                ),
                content: Text(
                  'This will delete the file from storage.',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            );
          },
          onDismissed: (_) => DownloadService().removeJob(job.jobId),
          background: Container(
            color: const Color(0xff00ff88).withOpacity(0.15),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 24),
            child: const Row(
              children: [
                Icon(
                  Icons.play_circle_fill,
                  color: Color(0xff00ff88),
                  size: 28,
                ),
                SizedBox(width: 8),
                Text(
                  'Play',
                  style: TextStyle(
                    color: Color(0xff00ff88),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          secondaryBackground: Container(
            color: Colors.redAccent.withOpacity(0.15),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
              ],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xff0f1520),
              borderRadius: BorderRadius.circular(16.0),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: thumbnail + info ──────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildThumbnail(isCompleted),
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
                            '${job.author} • ${job.duration}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12.0,
                            ),
                          ),
                          if (isCompleted &&
                              job.fileSizeDisplay.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _buildSizeBadge(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Progress bar (downloading) ──────────────────────────
                if (job.downloading || (job.progress > 0 && !isCompleted)) ...[
                  const SizedBox(height: 12),
                  RepaintBoundary(
                    child: LinearProgressIndicator(
                      value: job.progress,
                      backgroundColor: const Color(0xff0a0d14),
                      color: const Color(0xff00d2ff),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],

                // ── Chapter chips (analyzed, not yet downloading) ──────
                if (job.discovered &&
                    !job.downloadTriggered &&
                    job.localPath == null &&
                    job.chapters.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    "DETECTED CHAPTERS",
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
                        return Container(
                          margin: const EdgeInsets.only(right: 8.0),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 6.0,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xff0a0d14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xff00d2ff).withOpacity(0.2),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            "[${_formatDuration(ch.start)}] ${ch.title}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // ── Format selector (analyzed, not triggered) ──────────
                if (job.discovered &&
                    !job.downloadTriggered &&
                    job.localPath == null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildFormatButton(context, false)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildFormatButton(context, true)),
                    ],
                  ),
                ],

                // ── Status row ─────────────────────────────────────────
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        job.status,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _getStatusColor(),
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                          fontFamily: "monospace",
                        ),
                      ),
                    ),
                    _buildActionButtons(context, isCompleted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Thumbnail with watched % ring ──────────────────────────────────────────
  Widget _buildThumbnail(bool isCompleted) {
    final hasThumbnail =
        job.thumbnailUrl != null && job.thumbnailUrl!.isNotEmpty;
    final size = hasThumbnail ? 80.0 : 55.0;
    final accentColor = isCompleted
        ? const Color(0xff00ff88)
        : const Color(0xff00d2ff);

    Widget imageContent = hasThumbnail
        ? Image.network(
            job.thumbnailUrl!,
            fit: BoxFit.cover,
            cacheWidth: 320,
            errorBuilder: (_, __, ___) => Center(
              child: Icon(
                job.isAudio ? Icons.music_note : Icons.play_arrow,
                color: accentColor,
                size: 28,
              ),
            ),
            loadingBuilder: (_, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xff00d2ff),
                    ),
                  ),
                ),
              );
            },
          )
        : Center(
            child: Icon(
              job.isAudio ? Icons.music_note : Icons.play_arrow,
              color: accentColor,
              size: 28,
            ),
          );

    return SizedBox(
      width: size,
      height: 55,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: size,
              height: 55,
              decoration: BoxDecoration(
                color: const Color(0xff0a0d14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: imageContent,
              ),
            ),
          ),
          // Watched % ring overlay
          if (isCompleted && job.watchedPercent > 0)
            Positioned.fill(
              child: CustomPaint(
                painter: _WatchProgressRingPainter(
                  progress: job.watchedPercent,
                  color: const Color(0xff00ff88),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSizeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xff00ff88).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xff00ff88).withOpacity(0.25)),
      ),
      child: Text(
        job.fileSizeDisplay,
        style: const TextStyle(
          color: Color(0xff00ff88),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildFormatButton(BuildContext context, bool isAudio) {
    final color = isAudio ? const Color(0xff00ff88) : const Color(0xff00d2ff);
    final label = isAudio ? "AUDIO (MP3)" : "VIDEO (MP4)";
    final icon = isAudio
        ? Icons.music_note_outlined
        : Icons.movie_creation_outlined;

    return InkWell(
      onTap: () => DownloadService().startDownload(job.jobId, isAudio: isAudio),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), color.withOpacity(0.04)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.0,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isCompleted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pause / Resume button (only while triggered and not complete)
        if (job.downloadTriggered && !isCompleted && !job.downloadFailed) ...[
          if (job.isPaused)
            IconButton(
              icon: const Icon(
                Icons.play_arrow_rounded,
                color: Color(0xff00ff88),
              ),
              tooltip: "Resume",
              visualDensity: VisualDensity.compact,
              onPressed: () => DownloadService().resumeJob(job.jobId),
            )
          else if (!job.downloading)
            const SizedBox.shrink()
          else
            IconButton(
              icon: const Icon(Icons.pause_rounded, color: Colors.amber),
              tooltip: "Pause",
              visualDensity: VisualDensity.compact,
              onPressed: () => DownloadService().pauseJob(job.jobId),
            ),
        ],
        // Retry on failure
        if (job.discoverFailed || job.downloadFailed)
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.amber),
            tooltip: "Retry",
            visualDensity: VisualDensity.compact,
            onPressed: () => DownloadService().retryJob(job.jobId),
          ),
        // Completed actions
        if (isCompleted) ...[
          if (widget.showFavoriteOption)
            IconButton(
              icon: Icon(
                job.isFavorited ? Icons.star_rounded : Icons.star_outline_rounded,
                color: job.isFavorited ? Colors.amber : Colors.white70,
              ),
              tooltip: job.isFavorited ? "Remove from Favorites" : "Add to Favorites",
              visualDensity: VisualDensity.compact,
              onPressed: widget.onFavoritePressed,
            ),
          IconButton(
            icon: const Icon(Icons.edit_note, color: Color(0xff00d2ff)),
            tooltip: "Edit Tags",
            visualDensity: VisualDensity.compact,
            onPressed: () => _openTagEditor(context),
          ),
          IconButton(
            icon: const Icon(
              Icons.play_circle_fill,
              color: Color(0xff00ff88),
              size: 28,
            ),
            tooltip: "Play",
            visualDensity: VisualDensity.compact,
            onPressed: () => _playJob(context),
          ),
        ],
        // Delete
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          tooltip: "Remove",
          visualDensity: VisualDensity.compact,
          onPressed: () => DownloadService().removeJob(job.jobId),
        ),
      ],
    );
  }

  void _playJob(BuildContext context) {
    if (job.isAudio) {
      PlaybackService().play(job);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoPlayerView(job: job)),
      );
    }
  }

  Color _getStatusColor() {
    if (job.localPath != null) return const Color(0xff00ff88);
    if (job.discoverFailed || job.downloadFailed) return Colors.redAccent;
    if (job.isPaused) return Colors.amber;
    if (job.downloading) return const Color(0xff00d2ff);
    if (job.status.startsWith("Paused")) return Colors.amber;
    if (job.discovered && !job.downloadTriggered)
      return const Color(0xff00d2ff);
    return Colors.white.withOpacity(0.5);
  }

  String _formatDuration(Duration duration) {
    String two(int n) => n.toString().padLeft(2, "0");
    if (duration.inHours > 0) {
      return "${two(duration.inHours)}:${two(duration.inMinutes.remainder(60))}:${two(duration.inSeconds.remainder(60))}";
    }
    return "${two(duration.inMinutes.remainder(60))}:${two(duration.inSeconds.remainder(60))}";
  }

  void _openTagEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MetadataEditor(job: job),
    );
  }
}

// ── Watched progress ring painter ─────────────────────────────────────────────
class _WatchProgressRingPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final Color color;

  _WatchProgressRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeW = 3.0;
    final rect = Rect.fromLTWH(
      strokeW / 2,
      strokeW / 2,
      size.width - strokeW,
      size.height - strokeW,
    );
    // Track
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = color.withOpacity(0.15)
        ..strokeWidth = strokeW
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    // Progress arc
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeW
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_WatchProgressRingPainter old) =>
      old.progress != progress || old.color != color;
}
