import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:video_player/video_player.dart';
import '../models/video_job.dart';
import '../core/events/event_bus.dart';

enum PlaybackState { idle, loading, playing, paused, completed }

class PlaybackService {
  static final PlaybackService _instance = PlaybackService._internal();
  factory PlaybackService() => _instance;
  PlaybackService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoController;
  VideoPlayerController? get videoController => _videoController;
  VideoJob? _activeJob;
  PlaybackState _state = PlaybackState.idle;
  Timer? _sleepTimer;
  Duration? _sleepTimerDuration;
  DateTime _lastPositionSave = DateTime.fromMillisecondsSinceEpoch(0);

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
  
  Duration get position {
    if (_activeJob?.isAudio ?? true) {
      return _audioPlayer.position;
    } else {
      return _videoController?.value.position ?? Duration.zero;
    }
  }

  Duration get duration {
    if (_activeJob?.isAudio ?? true) {
      return _audioPlayer.duration ?? Duration.zero;
    } else {
      return _videoController?.value.duration ?? Duration.zero;
    }
  }

  double get speed {
    if (_activeJob?.isAudio ?? true) {
      return _audioPlayer.speed;
    } else {
      return _videoController?.value.playbackSpeed ?? 1.0;
    }
  }

  int? get sleepTimerSecondsLeft => _sleepTimerDuration?.inSeconds;

  void init() {
    _audioPlayer.playerStateStream.listen((playerState) {
      if (!(_activeJob?.isAudio ?? true)) return;
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

    _audioPlayer.positionStream.listen((pos) {
      if (!(_activeJob?.isAudio ?? true)) return;
      _positionController.add(pos);
      
      final job = _activeJob;
      if (job != null && _state == PlaybackState.playing) {
        final now = DateTime.now();
        if (now.difference(_lastPositionSave).inSeconds >= 5) {
          _lastPositionSave = now;
          _saveProgress();
        }
      }
    });
    
    _audioPlayer.bufferedPositionStream.listen((buf) {
      if (!(_activeJob?.isAudio ?? true)) return;
      _bufferedController.add(buf);
    });
    
    _audioPlayer.durationStream.listen((dur) {
      if (!(_activeJob?.isAudio ?? true)) return;
      if (dur != null) _durationController.add(dur);
    });
  }

  void _videoListener() {
    if (_activeJob?.isAudio ?? true) return;
    if (_videoController == null) return;
    
    final value = _videoController!.value;
    
    PlaybackState newState;
    if (!value.isInitialized) {
      newState = PlaybackState.loading;
    } else if (value.isCompleted) {
      newState = PlaybackState.completed;
    } else {
      newState = value.isPlaying ? PlaybackState.playing : PlaybackState.paused;
    }
    
    if (newState != _state) {
      _state = newState;
      _stateController.add(_state);
    }
    
    _positionController.add(value.position);
    _durationController.add(value.duration);
    _bufferedController.add(value.buffered.isNotEmpty ? value.buffered.last.end : Duration.zero);

    final job = _activeJob;
    if (job != null && _state == PlaybackState.playing) {
      final now = DateTime.now();
      if (now.difference(_lastPositionSave).inSeconds >= 5) {
        _lastPositionSave = now;
        _saveProgress();
      }
    }
  }

  void _saveProgress() {
    final job = _activeJob;
    if (job != null) {
      final pos = position;
      final dur = duration;
      if (dur.inSeconds > 0) {
        final watchedPercent = (pos.inSeconds / dur.inSeconds).clamp(0.0, 1.0);
        EventBus().fire(
          PlaybackProgressEvent(
            jobId: job.jobId,
            position: pos,
            duration: dur,
            watchedPercent: watchedPercent,
          ),
        );
      }
    }
  }

  Future<void> play(VideoJob job) async {
    if (job.localPath == null) return;
    
    // Stop any current video or audio
    await stop();
    
    _activeJob = job;

    if (job.isAudio) {
      try {
        final source = AudioSource.file(
          job.localPath!,
          tag: MediaItem(
            id: job.jobId,
            album: "YT Utils Audio",
            title: job.title,
            artist: job.author,
            artUri: null,
          ),
        );

        await _audioPlayer.setAudioSource(source);
        
        if (job.lastPositionSeconds > 0 && job.watchedPercent < 0.95) {
          await _audioPlayer.seek(Duration(seconds: job.lastPositionSeconds));
        } else {
          await _audioPlayer.seek(Duration.zero);
          final updatedJob = job.copyWith(
            lastPositionSeconds: 0,
            watchedPercent: 0.0,
          );
          _activeJob = updatedJob;
          EventBus().fire(
            PlaybackProgressEvent(
              jobId: job.jobId,
              position: Duration.zero,
              duration: Duration.zero,
              watchedPercent: 0.0,
            ),
          );
        }

        _audioPlayer.play();
      } catch (_) {
        _state = PlaybackState.idle;
        _stateController.add(_state);
      }
    } else {
      try {
        _state = PlaybackState.loading;
        _stateController.add(_state);
        
        _videoController = VideoPlayerController.file(File(job.localPath!));
        await _videoController!.initialize();
        _videoController!.addListener(_videoListener);
        
        if (job.lastPositionSeconds > 0 && job.watchedPercent < 0.95) {
          await _videoController!.seekTo(Duration(seconds: job.lastPositionSeconds));
        } else {
          await _videoController!.seekTo(Duration.zero);
          final updatedJob = job.copyWith(
            lastPositionSeconds: 0,
            watchedPercent: 0.0,
          );
          _activeJob = updatedJob;
          EventBus().fire(
            PlaybackProgressEvent(
              jobId: job.jobId,
              position: Duration.zero,
              duration: Duration.zero,
              watchedPercent: 0.0,
            ),
          );
        }
        
        _videoController!.play();
      } catch (_) {
        _state = PlaybackState.idle;
        _stateController.add(_state);
      }
    }
  }

  Future<void> pause() async {
    _saveProgress();
    if (_activeJob?.isAudio ?? true) {
      await _audioPlayer.pause();
    } else {
      await _videoController?.pause();
    }
  }

  Future<void> resume() async {
    if (_activeJob?.isAudio ?? true) {
      await _audioPlayer.play();
    } else {
      await _videoController?.play();
    }
  }

  Future<void> stop() async {
    _saveProgress();
    
    // Stop audio
    await _audioPlayer.stop();
    
    // Stop and dispose video
    if (_videoController != null) {
      _videoController!.removeListener(_videoListener);
      await _videoController!.pause();
      await _videoController!.dispose();
      _videoController = null;
    }
    
    _activeJob = null;
    _state = PlaybackState.idle;
    _stateController.add(_state);
    cancelSleepTimer();
  }

  Future<void> seek(Duration position) async {
    if (_activeJob?.isAudio ?? true) {
      await _audioPlayer.seek(position);
    } else {
      await _videoController?.seekTo(position);
    }
  }

  Future<void> setSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 3.0);
    if (_activeJob?.isAudio ?? true) {
      await _audioPlayer.setSpeed(clamped);
    } else {
      await _videoController?.setPlaybackSpeed(clamped);
    }
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
    if (_videoController != null) {
      _videoController!.dispose();
    }
    _stateController.close();
    _positionController.close();
    _bufferedController.close();
    _durationController.close();
    _sleepTimerController.close();
  }
}
