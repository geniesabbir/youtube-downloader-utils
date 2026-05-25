class MediaNote {
  final String noteId;
  final String jobId;
  final Duration timestamp;
  final String content; // Markdown content
  final DateTime createdAt;

  MediaNote({
    required this.noteId,
    required this.jobId,
    required this.timestamp,
    required this.content,
    required this.createdAt,
  });

  factory MediaNote.fromJson(Map<String, dynamic> json) {
    return MediaNote(
      noteId: json['noteId'] as String,
      jobId: json['jobId'] as String,
      timestamp: Duration(seconds: (json['timestamp'] as num).toInt()),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'noteId': noteId,
      'jobId': jobId,
      'timestamp': timestamp.inSeconds,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
