import '../models/transcript.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  Future<bool> isAiAvailable() async {
    return false;
  }

  List<TranscriptSegment> semanticSearch(String query, List<TranscriptSegment> segments) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return segments.where((segment) => segment.text.toLowerCase().contains(lowerQuery)).toList();
  }
}
