class Chapter {
  final String title;
  final Duration start;
  final Duration end;

  Chapter({required this.title, required this.start, required this.end});

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      title: json['title'] as String,
      start: Duration(seconds: json['start'] as int),
      end: Duration(seconds: json['end'] as int),
    );
  }

  Map<String, dynamic> toJson() {
    return {'title': title, 'start': start.inSeconds, 'end': end.inSeconds};
  }
}

class VideoJob {
  final String jobId;
  final String sourceUrl;
  String targetUrl;
  String title;
  String author;
  String duration;
  String status;
  double progress;
  bool discovered;
  bool discoverFailed;
  bool downloadFailed;
  bool downloading;
  String? localPath;
  bool isAudio;
  bool downloadTriggered;
  String? thumbnailUrl;
  List<Chapter> chapters;

  VideoJob({
    required this.jobId,
    required this.sourceUrl,
    required this.targetUrl,
    this.title = "Pending discovery",
    this.author = "Unknown",
    this.duration = "N/A",
    this.status = "Queued for discovery",
    this.progress = 0.0,
    this.discovered = false,
    this.discoverFailed = false,
    this.downloadFailed = false,
    this.downloading = false,
    this.localPath,
    this.isAudio = false,
    this.downloadTriggered = false,
    this.thumbnailUrl = "",
    this.chapters = const [],
  });

  factory VideoJob.fromJson(Map<String, dynamic> json) {
    return VideoJob(
      jobId: json['jobId'] as String,
      sourceUrl: json['sourceUrl'] as String,
      targetUrl: json['targetUrl'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      duration: json['duration'] as String,
      status: json['status'] as String,
      progress: (json['progress'] as num).toDouble(),
      discovered: json['discovered'] as bool,
      discoverFailed: json['discoverFailed'] as bool,
      downloadFailed: json['downloadFailed'] as bool,
      downloading: json['downloading'] as bool,
      localPath: json['localPath'] as String?,
      isAudio: json['isAudio'] as bool? ?? false,
      downloadTriggered: json['downloadTriggered'] as bool? ?? false,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      chapters:
          (json['chapters'] as List<dynamic>?)
              ?.map((e) => Chapter.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jobId': jobId,
      'sourceUrl': sourceUrl,
      'targetUrl': targetUrl,
      'title': title,
      'author': author,
      'duration': duration,
      'status': status,
      'progress': progress,
      'discovered': discovered,
      'discoverFailed': discoverFailed,
      'downloadFailed': downloadFailed,
      'downloading': downloading,
      'localPath': localPath,
      'isAudio': isAudio,
      'downloadTriggered': downloadTriggered,
      'thumbnailUrl': thumbnailUrl,
      'chapters': chapters.map((e) => e.toJson()).toList(),
    };
  }

  VideoJob copyWith({
    String? title,
    String? author,
    String? duration,
    String? status,
    double? progress,
    bool? discovered,
    bool? discoverFailed,
    bool? downloadFailed,
    bool? downloading,
    String? localPath,
    bool? isAudio,
    bool? downloadTriggered,
    String? thumbnailUrl,
    List<Chapter>? chapters,
    bool clearLocalPath = false,
  }) {
    return VideoJob(
      jobId: jobId,
      sourceUrl: sourceUrl,
      targetUrl: targetUrl,
      title: title ?? this.title,
      author: author ?? this.author,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      discovered: discovered ?? this.discovered,
      discoverFailed: discoverFailed ?? this.discoverFailed,
      downloadFailed: downloadFailed ?? this.downloadFailed,
      downloading: downloading ?? this.downloading,
      localPath: clearLocalPath ? null : (localPath ?? this.localPath),
      isAudio: isAudio ?? this.isAudio,
      downloadTriggered: downloadTriggered ?? this.downloadTriggered,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      chapters: chapters ?? this.chapters,
    );
  }
}
