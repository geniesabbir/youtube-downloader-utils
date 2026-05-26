import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../models/video_job.dart';
import '../core/events/event_bus.dart';
import 'download_service.dart';

enum PlaybackState { idle, loading, playing, paused, completed }
enum LoopModeState { off, one, all }

class PlaybackService with WidgetsBindingObserver {
  static final PlaybackService _instance = PlaybackService._internal();
  factory PlaybackService() => _instance;
  PlaybackService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoController;
  VideoPlayerController? get videoController => _videoController;
  VideoJob? _activeJob;
  PlaybackState _state = PlaybackState.idle;
  LoopModeState _loopMode = LoopModeState.off;
  bool _isSettingUp = false;
  Timer? _sleepTimer;
  Duration? _sleepTimerDuration;
  DateTime _lastPositionSave = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastDriftCorrection = DateTime.fromMillisecondsSinceEpoch(0);

  final StreamController<PlaybackState> _stateController = StreamController<PlaybackState>.broadcast();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _bufferedController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  final StreamController<int?> _sleepTimerController = StreamController<int?>.broadcast();
  final StreamController<LoopModeState> _loopModeController = StreamController<LoopModeState>.broadcast();

  Stream<PlaybackState> get stateStream => _stateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get bufferedStream => _bufferedController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<int?> get sleepTimerStream => _sleepTimerController.stream;
  Stream<LoopModeState> get loopModeStream => _loopModeController.stream;

  VideoJob? get activeJob => _activeJob;
  PlaybackState get state => _state;
  LoopModeState get loopMode => _loopMode;
  
  Duration get position {
    if (_activeJob?.isAudio ?? true) {
      return _audioPlayer.position;
    } else {
      if (_videoController != null && _videoController!.value.isInitialized && !_audioPlayer.playing) {
        return _videoController!.value.position;
      }
      return _audioPlayer.position;
    }
  }

  Duration get duration {
    if (_activeJob?.isAudio ?? true) {
      return _audioPlayer.duration ?? Duration.zero;
    } else {
      if (_videoController != null && _videoController!.value.isInitialized && !_audioPlayer.playing) {
        return _videoController!.value.duration;
      }
      return _audioPlayer.duration ?? Duration.zero;
    }
  }

  double get speed {
    if (_activeJob?.isAudio ?? true) {
      return _audioPlayer.speed;
    } else {
      if (_videoController != null && _videoController!.value.isInitialized && !_audioPlayer.playing) {
        return _videoController!.value.playbackSpeed;
      }
      return _audioPlayer.speed;
    }
  }

  int? get sleepTimerSecondsLeft => _sleepTimerDuration?.inSeconds;

  Future<void> _loadLoopMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt('playback_loop_mode');
      if (modeIndex != null && modeIndex >= 0 && modeIndex < LoopModeState.values.length) {
        _loopMode = LoopModeState.values[modeIndex];
        _loopModeController.add(_loopMode);
        _audioPlayer.setLoopMode(_loopMode == LoopModeState.one ? LoopMode.one : LoopMode.off);
        if (_videoController != null && !(_activeJob?.isAudio ?? true)) {
          _videoController?.setLooping(_loopMode == LoopModeState.one);
        }
      }
    } catch (_) {}
  }

  void init() {
    WidgetsBinding.instance.addObserver(this);
    _loadLoopMode();

    _audioPlayer.playerStateStream.listen((playerState) {
      if (_activeJob == null) return;
      if (_activeJob!.isAudio || (_videoController == null || !_videoController!.value.isInitialized)) {
        if (playerState.processingState == ProcessingState.idle) {
          _state = PlaybackState.idle;
        } else if (playerState.processingState == ProcessingState.loading ||
            playerState.processingState == ProcessingState.buffering) {
          _state = PlaybackState.loading;
        } else if (playerState.processingState == ProcessingState.completed) {
          _state = PlaybackState.completed;
          _stateController.add(_state);
          _handlePlaybackCompletion();
          return;
        } else {
          _state = playerState.playing ? PlaybackState.playing : PlaybackState.paused;
        }
        _stateController.add(_state);
      }
    });

    _audioPlayer.positionStream.listen((pos) {
      if (_activeJob == null) return;
      if (_activeJob!.isAudio || (_videoController == null || !_videoController!.value.isInitialized)) {
        _positionController.add(pos);
      }
      
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
      if (_activeJob == null) return;
      if (_activeJob!.isAudio || (_videoController == null || !_videoController!.value.isInitialized)) {
        _bufferedController.add(buf);
      }
    });
    
    _audioPlayer.durationStream.listen((dur) {
      if (_activeJob == null) return;
      if (_activeJob!.isAudio || (_videoController == null || !_videoController!.value.isInitialized)) {
        if (dur != null) _durationController.add(dur);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_activeJob == null || _activeJob!.isAudio) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App is backgrounded: Pause video controller and hand off to audio player for notifications
      if (_videoController != null && _videoController!.value.isPlaying && !_isSettingUp) {
        final pos = _videoController!.value.position;
        _isSettingUp = true;
        await _videoController!.pause();

        final source = AudioSource.file(
          _activeJob!.localPath!,
          tag: MediaItem(
            id: _activeJob!.jobId,
            album: "YT Utils Video",
            title: _activeJob!.title,
            artist: _activeJob!.author,
            artUri: null,
          ),
        );
        await _audioPlayer.setAudioSource(source);
        await _audioPlayer.seek(pos);
        _audioPlayer.play();
        _isSettingUp = false;
      }
    } else if (state == AppLifecycleState.resumed) {
      // App is resumed: Pause audio player and hand back control to video controller in sync
      if (_videoController != null && !_isSettingUp) {
        _isSettingUp = true;
        final pos = _audioPlayer.position;
        final wasPlaying = _audioPlayer.playing;

        await _audioPlayer.pause();
        await _audioPlayer.stop();

        await _videoController!.seekTo(pos);
        if (wasPlaying) {
          _videoController!.play();
        } else {
          _videoController!.pause();
        }
        _isSettingUp = false;
      }
    }
  }

  void _videoListener() {
    if (_activeJob == null || _activeJob!.isAudio) return;
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    if (_audioPlayer.playing || _isSettingUp) return;

    final value = _videoController!.value;
    
    PlaybackState newState;
    if (value.isCompleted) {
      newState = PlaybackState.completed;
      if (_state != PlaybackState.completed) {
        _state = newState;
        _stateController.add(_state);
        _handlePlaybackCompletion();
        return;
      }
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
  }

  void _handlePlaybackCompletion() {
    if (_loopMode == LoopModeState.one) {
      return;
    }
    
    final queue = DownloadService().queue;
    final libraryJobs = queue.where((j) => j.localPath != null).toList();
    if (libraryJobs.isEmpty) return;
    
    final currentIdx = libraryJobs.indexWhere((j) => j.jobId == _activeJob?.jobId);
    if (currentIdx != -1) {
      if (currentIdx + 1 < libraryJobs.length) {
        play(libraryJobs[currentIdx + 1]);
      } else if (_loopMode == LoopModeState.all) {
        play(libraryJobs[0]);
      } else {
        stop();
      }
    }
  }

  void toggleLoopMode() async {
    if (_loopMode == LoopModeState.off) {
      _loopMode = LoopModeState.one;
    } else if (_loopMode == LoopModeState.one) {
      _loopMode = LoopModeState.all;
    } else {
      _loopMode = LoopModeState.off;
    }
    _loopModeController.add(_loopMode);
    
    _audioPlayer.setLoopMode(_loopMode == LoopModeState.one ? LoopMode.one : LoopMode.off);
    if (!(_activeJob?.isAudio ?? true)) {
      _videoController?.setLooping(_loopMode == LoopModeState.one);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('playback_loop_mode', _loopMode.index);
    } catch (_) {}
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
    
    _isSettingUp = true;
    _state = PlaybackState.loading;
    _stateController.add(_state);
    
    _saveProgress();
    
    await _audioPlayer.stop();
    
    if (_videoController != null) {
      final oldController = _videoController!;
      _videoController = null;
      oldController.removeListener(_videoListener);
      await oldController.pause();
      await oldController.dispose();
    }
    cancelSleepTimer();
    
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
        _audioPlayer.setLoopMode(_loopMode == LoopModeState.one ? LoopMode.one : LoopMode.off);
        
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
        _isSettingUp = false;
      } catch (_) {
        _isSettingUp = false;
        _state = PlaybackState.idle;
        _stateController.add(_state);
      }
    } else {
      try {
        _state = PlaybackState.loading;
        _stateController.add(_state);
        
        // 1. Initialize Video Player Controller (Foreground with Standard volume)
        _videoController = VideoPlayerController.file(File(job.localPath!));
        await _videoController!.initialize();
        await _videoController!.setVolume(1.0); // Full audio volume in foreground
        _videoController!.addListener(_videoListener);
        _videoController!.setLooping(_loopMode == LoopModeState.one);
        
        // 2. Clear any active audio player source
        await _audioPlayer.stop();

        // 3. Handle seek to last position
        if (job.lastPositionSeconds > 0 && job.watchedPercent < 0.95) {
          final targetPos = Duration(seconds: job.lastPositionSeconds);
          await _videoController!.seekTo(targetPos);
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
        _isSettingUp = false;
        _state = PlaybackState.playing;
        _stateController.add(_state);
      } catch (_) {
        _isSettingUp = false;
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
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      } else {
        await _videoController?.pause();
      }
    }
  }

  Future<void> resume() async {
    if (_activeJob?.isAudio ?? true) {
      await _audioPlayer.play();
    } else {
      if (_videoController != null) {
        await _videoController!.play();
      }
    }
  }

  Future<void> stop() async {
    _saveProgress();
    
    await _audioPlayer.stop();
    
    if (_videoController != null) {
      final oldController = _videoController!;
      _videoController = null;
      oldController.removeListener(_videoListener);
      await oldController.pause();
      await oldController.dispose();
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
      if (_audioPlayer.playing) {
        await _audioPlayer.seek(position);
      } else {
        await _videoController?.seekTo(position);
      }
    }
  }

  Future<void> setSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 3.0);
    if (_activeJob?.isAudio ?? true) {
      await _audioPlayer.setSpeed(clamped);
    } else {
      if (_audioPlayer.playing) {
        await _audioPlayer.setSpeed(clamped);
      } else {
        await _videoController?.setPlaybackSpeed(clamped);
      }
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
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    if (_videoController != null) {
      _videoController!.dispose();
    }
    _stateController.close();
    _positionController.close();
    _bufferedController.close();
    _durationController.close();
    _sleepTimerController.close();
    _loopModeController.close();
  }
}
