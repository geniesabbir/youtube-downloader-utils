import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/video_job.dart';

enum PlaybackState { idle, loading, playing, paused, completed }

class PlaybackService {
  static final PlaybackService _instance = PlaybackService._internal();
  factory PlaybackService() => _instance;
  PlaybackService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoJob? _activeJob;
  PlaybackState _state = PlaybackState.idle;
  Timer? _sleepTimer;
  Duration? _sleepTimerDuration;

  final StreamController<PlaybackState> _stateController = StreamController<PlaybackState>.broadcast();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _bufferedController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  final StreamController<int?> _sleepTimerController = StreamController<int?>.broadcast();

  Stream<PlaybackState> get stateStream => _stateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get bufferedStream => _bufferedController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<int?> get sleepTimerStream => _sleepTimerController.stream;

  VideoJob? get activeJob => _activeJob;
  PlaybackState get state => _state;
  Duration get position => _audioPlayer.position;
  Duration get duration => _audioPlayer.duration ?? Duration.zero;
  double get speed => _audioPlayer.speed;
  int? get sleepTimerSecondsLeft => _sleepTimerDuration?.inSeconds;

  void init() {
    _audioPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.idle) {
        _state = PlaybackState.idle;
      } else if (playerState.processingState == ProcessingState.loading ||
          playerState.processingState == ProcessingState.buffering) {
        _state = PlaybackState.loading;
      } else if (playerState.processingState == ProcessingState.completed) {
        _state = PlaybackState.completed;
      } else {
        _state = playerState.playing ? PlaybackState.playing : PlaybackState.paused;
      }
      _stateController.add(_state);
    });

    _audioPlayer.positionStream.listen((pos) => _positionController.add(pos));
    _audioPlayer.bufferedPositionStream.listen((buf) => _bufferedController.add(buf));
    _audioPlayer.durationStream.listen((dur) {
      if (dur != null) _durationController.add(dur);
    });
  }

  Future<void> play(VideoJob job) async {
    if (job.localPath == null) return;
    _activeJob = job;

    try {
      _audioPlayer.stop();
      
      // Load file with background audio lock screen metadata
      final source = AudioSource.file(
        job.localPath!,
        tag: MediaItem(
          id: job.jobId,
          album: job.isAudio ? "YT Utils Audio" : "YT Utils Video",
          title: job.title,
          artist: job.author,
          artUri: null, // Optionally parse thumbnail locally
        ),
      );

      await _audioPlayer.setAudioSource(source);
      _audioPlayer.play();
    } catch (_) {
      _state = PlaybackState.idle;
      _stateController.add(_state);
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _activeJob = null;
    _state = PlaybackState.idle;
    _stateController.add(_state);
    cancelSleepTimer();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    await _audioPlayer.setSpeed(speed.clamp(0.5, 3.0));
  }

  void setSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepTimerDuration = duration;
    _sleepTimerController.add(_sleepTimerDuration?.inSeconds);

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTimerDuration == null) {
        timer.cancel();
        return;
      }

      if (_sleepTimerDuration!.inSeconds <= 1) {
        pause();
        cancelSleepTimer();
      } else {
        _sleepTimerDuration = _sleepTimerDuration! - const Duration(seconds: 1);
        _sleepTimerController.add(_sleepTimerDuration!.inSeconds);
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerDuration = null;
    _sleepTimerController.add(null);
  }

  void dispose() {
    _audioPlayer.dispose();
    _stateController.close();
    _positionController.close();
    _bufferedController.close();
    _durationController.close();
    _sleepTimerController.close();
  }
}
