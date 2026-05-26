class StudyCard {
  final String cardId;
  final String jobId;
  final String question;
  final String answer;
  final Duration? timestamp; // associated jump-to video timestamp
  final DateTime createdAt;

  StudyCard({
    required this.cardId,
    required this.jobId,
    required this.question,
    required this.answer,
    this.timestamp,
    required this.createdAt,
  });

  factory StudyCard.fromJson(Map<String, dynamic> json) {
    return StudyCard(
      cardId: json['cardId'] as String,
      jobId: json['jobId'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      timestamp: json['timestampSeconds'] != null
          ? Duration(seconds: (json['timestampSeconds'] as num).toInt())
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cardId': cardId,
      'jobId': jobId,
      'question': question,
      'answer': answer,
      'timestampSeconds': timestamp?.inSeconds,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
