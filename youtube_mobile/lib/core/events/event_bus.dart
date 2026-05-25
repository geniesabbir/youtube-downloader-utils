import 'dart:async';
import '../../models/video_job.dart';

class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final _streamController = StreamController<dynamic>.broadcast();

  Stream<T> on<T>() {
    if (T == dynamic) {
      return _streamController.stream as Stream<T>;
    } else {
      return _streamController.stream.where((event) => event is T).cast<T>();
    }
  }

  void fire(dynamic event) {
    _streamController.add(event);
  }
}

class PlaybackProgressEvent {
  final String jobId;
  final Duration position;
  final Duration duration;
  final double watchedPercent;

  PlaybackProgressEvent({
    required this.jobId,
    required this.position,
    required this.duration,
    required this.watchedPercent,
  });
}

class PlayMediaInWorkspaceEvent {
  final VideoJob job;
  PlayMediaInWorkspaceEvent(this.job);
}
