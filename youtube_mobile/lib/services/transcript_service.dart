import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/video_job.dart';
import '../models/transcript.dart';

class TranscriptService {
  static final TranscriptService _instance = TranscriptService._internal();
  factory TranscriptService() => _instance;
  TranscriptService._internal();

  static const String _transcriptsPrefsPrefix = 'library_transcripts_';
  final YoutubeExplode _yt = YoutubeExplode();

  Future<List<TranscriptSegment>> getTranscript(VideoJob job) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_transcriptsPrefsPrefix${job.jobId}';
    final cached = prefs.getString(cacheKey);

    if (cached != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cached);
        final list = decoded.map((e) => TranscriptSegment.fromJson(e)).toList();
        
        // Self-healing check: Discard pre-existing mockup cached data
        final hasMockData = list.any((seg) =>
          seg.text.contains("comprehensive overview about") ||
          seg.text.contains("foundational concepts shared by") ||
          seg.text.contains("Many developers and researchers have discussed")
        );
        
        if (hasMockData) {
          await prefs.remove(cacheKey);
        } else {
          return list;
        }
      } catch (_) {}
    }

    // Try to fetch captions from YouTube
    List<TranscriptSegment> segments = [];
    final videoId = job.videoId;
    if (videoId != null) {
      try {
        final manifest = await _yt.videos.closedCaptions.getManifest(videoId);
        if (manifest.tracks.isNotEmpty) {
          final trackInfo = manifest.getByLanguage('en').firstOrNull ?? manifest.tracks.first;
          final track = await _yt.videos.closedCaptions.get(trackInfo);
          
          segments = track.captions.map((caption) => TranscriptSegment(
            start: caption.offset,
            end: caption.offset + caption.duration,
            text: caption.text,
          )).toList();
        }
      } catch (_) {
        // Safe fail
      }
    }

    // If empty, return empty list (do not generate mockups)
    if (segments.isEmpty) {
      return [];
    }

    // Persist
    await prefs.setString(cacheKey, jsonEncode(segments.map((e) => e.toJson()).toList()));
    return segments;
  }

  Future<void> saveTranscript(String jobId, List<TranscriptSegment> segments) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_transcriptsPrefsPrefix$jobId';
    await prefs.setString(cacheKey, jsonEncode(segments.map((e) => e.toJson()).toList()));
  }
}
