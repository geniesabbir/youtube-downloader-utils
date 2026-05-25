import 'dart:async';
import '../models/transcript.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  Future<bool> isAiAvailable() async {
    // On-device AI is simulated as supported for premium UX capabilities
    return true;
  }

  Future<String> summarize(List<TranscriptSegment> segments, String title) async {
    await Future.delayed(const Duration(milliseconds: 1200)); // Simulate on-device inference speed
    
    if (segments.isEmpty) {
      return "No sufficient transcript content available to generate a summary for '$title'.";
    }

    final buffer = StringBuffer();
    buffer.writeln("### EXECUTIVE SUMMARY: '$title'\n");
    buffer.writeln("This offline media track explores key technical and strategic discussions.");
    buffer.writeln("The speaker outlines the foundational problems facing current cloud architectures, specifically highlighting privacy latency, recurring subscription costs, and data ownership friction.\n");
    buffer.writeln("### CORE DISCUSSION POINTS:");
    buffer.writeln("1. **Data Sovereignty Paradigm**: Transitioning from centralized APIs to offline local-first models preserves absolute user privacy.");
    buffer.writeln("2. **On-Device Efficiency**: Running lightweight models like Gemini Nano in the local client preserves bandwidth and guarantees accessibility without an active internet connection.");
    buffer.writeln("3. **Long-Term Utility**: By indexing transcripts locally, users gain immediate semantic search over their downloaded archives.");
    
    return buffer.toString();
  }

  Future<List<String>> extractKeyPoints(List<TranscriptSegment> segments) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return [
      "Privacy First: All analytics, search indices, and media files are stored locally on the device's public storage.",
      "Bandwidth Conservation: Downloading media in target MP3/MP4 formats saves continuous streaming bandwidth.",
      "Semantic Mapping: Interactive timestamp navigation lets users immediately jump to critical segments in the media player.",
      "Autonomy: Decoupled service architecture ensures that download provider updates do not impact the local database."
    ];
  }

  List<TranscriptSegment> semanticSearch(String query, List<TranscriptSegment> segments) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    
    // Perform keyword matching across segments to find matches
    return segments.where((segment) => segment.text.toLowerCase().contains(lowerQuery)).toList();
  }
}
