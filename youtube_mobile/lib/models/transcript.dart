class TranscriptSegment {
  final Duration start;
  final Duration end;
  final String text;

  TranscriptSegment({required this.start, required this.end, required this.text});

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      start: Duration(seconds: (json['start'] as num).toInt()),
      end: Duration(seconds: (json['end'] as num).toInt()),
      text: json['text'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start.inSeconds,
      'end': end.inSeconds,
      'text': text,
    };
  }
}
