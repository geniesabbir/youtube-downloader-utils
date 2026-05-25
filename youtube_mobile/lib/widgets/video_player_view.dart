import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video_job.dart';
import '../core/events/event_bus.dart';

class VideoPlayerView extends StatefulWidget {
  final VideoJob job;
  const VideoPlayerView({super.key, required this.job});

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _controlsVisible = true;
  
  // Phase 2 - Advanced Player Enhancements
  bool _isLocked = false;
  bool _showLockIndicatorActive = false;
  bool _showLeftSeekIndicator = false;
  bool _showRightSeekIndicator = false;
  
  Timer? _progressTimer;
  Timer? _lockIndicatorTimer;
  Timer? _fadeControlsTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.job.localPath!))
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        if (widget.job.lastPositionSeconds > 0) {
          _controller.seekTo(Duration(seconds: widget.job.lastPositionSeconds));
        }
        _controller.play();
        _startProgressSaving();
        _resetControlsTimer();
      });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _startProgressSaving() {
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });
  }

  void _saveProgress() {
    if (!_initialized) return;
    final pos = _controller.value.position;
    final dur = _controller.value.duration;
    if (dur.inSeconds > 0) {
      final watchedPercent = (pos.inSeconds / dur.inSeconds).clamp(0.0, 1.0);
      EventBus().fire(
        PlaybackProgressEvent(
          jobId: widget.job.jobId,
          position: pos,
          duration: dur,
          watchedPercent: watchedPercent,
        ),
      );
    }
  }

  void _resetControlsTimer() {
    _fadeControlsTimer?.cancel();
    if (_controlsVisible && !_isLocked) {
      _fadeControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _controlsVisible = false;
          });
        }
      });
    }
  }

  void _seekRelative(Duration offset) {
    if (_isLocked || !_initialized) return;
    final target = _controller.value.position + offset;
    final maxDuration = _controller.value.duration;
    Duration clamped = target;
    if (clamped < Duration.zero) {
      clamped = Duration.zero;
    } else if (clamped > maxDuration) {
      clamped = maxDuration;
    }
    _controller.seekTo(clamped);
    _saveProgress();
    _resetControlsTimer();

    setState(() {
      if (offset.inSeconds < 0) {
        _showLeftSeekIndicator = true;
      } else {
        _showRightSeekIndicator = true;
      }
    });

    Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          if (offset.inSeconds < 0) {
            _showLeftSeekIndicator = false;
          } else {
            _showRightSeekIndicator = false;
          }
        });
      }
    });
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
      if (_isLocked) {
        _controlsVisible = false;
      } else {
        _controlsVisible = true;
      }
    });
    _showLockIndicator();
    _resetControlsTimer();
  }

  void _showLockIndicator() {
    setState(() {
      _showLockIndicatorActive = true;
    });
    _lockIndicatorTimer?.cancel();
    _lockIndicatorTimer = Timer(const Duration(seconds: 1500), () {
      if (mounted) {
        setState(() {
          _showLockIndicatorActive = false;
        });
      }
    });
  }

  void _showSpeedSelector(BuildContext context) {
    _resetControlsTimer();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff121820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "SELECT PLAYBACK SPEED",
                style: TextStyle(
                  color: Color(0xff00d2ff),
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [0.5, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0].map((speedVal) {
                  final active = _controller.value.playbackSpeed == speedVal;
                  return ChoiceChip(
                    label: Text("${speedVal}x"),
                    selected: active,
                    selectedColor: const Color(0xff00ff88),
                    labelStyle: TextStyle(color: active ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                    backgroundColor: const Color(0xff0a0d14),
                    onSelected: (selected) {
                      if (selected) {
                        _controller.setPlaybackSpeed(speedVal);
                        Navigator.pop(context);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _lockIndicatorTimer?.cancel();
    _fadeControlsTimer?.cancel();
    _saveProgress();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _initialized
            ? Stack(
                alignment: Alignment.center,
                children: [
                  // Video Player element
                  AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),

                  // Gestures Overlays
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        return Stack(
                          children: [
                            // Main screen interaction
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () {
                                  if (_isLocked) {
                                    _showLockIndicator();
                                  } else {
                                    setState(() {
                                      _controlsVisible = !_controlsVisible;
                                    });
                                    _resetControlsTimer();
                                  }
                                },
                              ),
                            ),

                            // Double tap Left 35%
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: width * 0.35,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onDoubleTap: () => _seekRelative(const Duration(seconds: -10)),
                              ),
                            ),

                            // Double tap Right 35%
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              width: width * 0.35,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onDoubleTap: () => _seekRelative(const Duration(seconds: 10)),
                              ),
                            ),

                            // Center Double tap screen lock
                            Positioned(
                              left: width * 0.35,
                              right: width * 0.35,
                              top: 0,
                              bottom: 0,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onDoubleTap: _toggleLock,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Left Skip Visual Indicator
                  if (_showLeftSeekIndicator)
                    Positioned(
                      left: 48,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xff00d2ff).withOpacity(0.3)),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fast_rewind_rounded, color: Color(0xff00d2ff), size: 36),
                            SizedBox(height: 4),
                            Text("-10s", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),

                  // Right Skip Visual Indicator
                  if (_showRightSeekIndicator)
                    Positioned(
                      right: 48,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xff00d2ff).withOpacity(0.3)),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fast_forward_rounded, color: Color(0xff00d2ff), size: 36),
                            SizedBox(height: 4),
                            Text("+10s", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),

                  // Lock State Center Alert
                  if (_showLockIndicatorActive)
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _isLocked ? Colors.amber : const Color(0xff00ff88)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isLocked ? Icons.lock : Icons.lock_open,
                                color: _isLocked ? Colors.amber : const Color(0xff00ff88),
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isLocked ? "Controls Locked" : "Controls Unlocked",
                                style: TextStyle(
                                  color: _isLocked ? Colors.amber : const Color(0xff00ff88),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isLocked ? "Double-tap center to unlock" : "Accidental taps prevented",
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Persistent Lock Floating Indicator (when locked, so they can tap to see state or double tap to unlock)
                  if (_isLocked)
                    Positioned(
                      top: 40,
                      right: 20,
                      child: GestureDetector(
                        onTap: _showLockIndicator,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.amber.withOpacity(0.5)),
                          ),
                          child: const Icon(Icons.lock, color: Colors.amber, size: 24),
                        ),
                      ),
                    ),

                  // Control bars (AppBar & Bottom Playback UI)
                  if (_controlsVisible && !_isLocked) ...[
                    // Custom AppBar
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.only(top: 40, bottom: 20, left: 16, right: 16),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.job.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 14.0, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    widget.job.author,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11.0, fontFamily: "monospace"),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.speed_rounded, color: Color(0xff00d2ff)),
                              tooltip: "Playback Speed",
                              onPressed: () => _showSpeedSelector(context),
                            ),
                            IconButton(
                              icon: const Icon(Icons.lock_open, color: Colors.white70),
                              tooltip: "Lock Interface",
                              onPressed: _toggleLock,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Play/Pause button in center
                    Center(
                      child: IconButton(
                        iconSize: 72,
                        icon: Icon(
                          _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: const Color(0xff00ff88),
                        ),
                        onPressed: () {
                          setState(() {
                            if (_controller.value.isPlaying) {
                              _controller.pause();
                            } else {
                              _controller.play();
                            }
                          });
                          _resetControlsTimer();
                        },
                      ),
                    ),

                    // Seekbar overlay at bottom
                    Positioned(
                      bottom: 30,
                      left: 24,
                      right: 24,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Color(0xff00d2ff),
                              bufferedColor: Colors.white24,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_controller.value.position),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: "monospace"),
                              ),
                              Text(
                                _formatDuration(_controller.value.duration),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: "monospace"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              )
            : const CircularProgressIndicator(color: Color(0xff00d2ff)),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
