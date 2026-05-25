import 'package:flutter/material.dart';
import '../models/video_job.dart';
import '../services/playback_service.dart';
import '../theme/app_theme.dart';

class ContinueWatchingRow extends StatelessWidget {
  final List<VideoJob> inProgressJobs;

  const ContinueWatchingRow({super.key, required this.inProgressJobs});

  @override
  Widget build(BuildContext context) {
    if (inProgressJobs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            "CONTINUE WATCHING",
            style: TextStyle(
              color: AppColors.mint,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 155,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            scrollDirection: Axis.horizontal,
            itemCount: inProgressJobs.length,
            itemBuilder: (context, index) {
              final job = inProgressJobs[index];
              return _buildProgressCard(context, job);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(BuildContext context, VideoJob job) {
    final double cardWidth = 145;
    final progressVal = job.watchedPercent.clamp(0.0, 1.0);

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.symmetric(horizontal: 6.0),
      child: GestureDetector(
        onTap: () {
          PlaybackService().play(job);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with progress indicator overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: const Color(0xff121820),
                      child: job.thumbnailUrl != null && job.thumbnailUrl!.isNotEmpty
                          ? Image.network(
                              job.thumbnailUrl!,
                              fit: BoxFit.cover,
                              cacheWidth: 320, // Binds decoded image RAM size limit
                              errorBuilder: (c, e, s) => const Center(
                                child: Icon(Icons.movie_outlined, color: Colors.white24, size: 28),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.movie_outlined, color: Colors.white24, size: 28),
                            ),
                    ),
                  ),
                ),
                // Premium frosted play button overlay
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                // Watched percent indicator line at the bottom of the thumbnail
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3.5,
                    color: Colors.white24,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progressVal,
                        child: Container(
                          color: AppColors.mint,
                        ),
                      ),
                    ),
                  ),
                ),
                // Circular watched progress badge
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        value: progressVal,
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.mint),
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Title & Channel
            Text(
              job.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.cloud,
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              job.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 10.5,
                fontFamily: "monospace",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
