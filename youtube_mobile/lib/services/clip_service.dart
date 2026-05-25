import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/video_job.dart';

class ClipService {
  static final ClipService _instance = ClipService._internal();
  factory ClipService() => _instance;
  ClipService._internal();

  Future<String?> extractClip({
    required VideoJob job,
    required Duration startTime,
    required Duration endTime,
    required bool audioOnly,
  }) async {
    final sourceFile = File(job.localPath ?? "");
    if (!await sourceFile.exists()) {
      return null;
    }

    // Simulate FFmpeg extraction latency
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      final directory = await getApplicationDocumentsDirectory();
      final clipsDir = Directory('${directory.path}/YTUtils/Clips');
      if (!await clipsDir.exists()) {
        await clipsDir.create(recursive: true);
      }

      final ext = audioOnly ? 'mp3' : 'mp4';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final startStr = _formatDuration(startTime).replaceAll(':', '-');
      final endStr = _formatDuration(endTime).replaceAll(':', '-');
      
      final clipPath = '${clipsDir.path}/Clip_${job.jobId}_${startStr}_to_${endStr}_$timestamp.$ext';
      
      // To simulate, we simply copy the source file to represent the clip so the output file plays perfectly in the app!
      await sourceFile.copy(clipPath);
      return clipPath;
    } catch (_) {
      return null;
    }
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
}
