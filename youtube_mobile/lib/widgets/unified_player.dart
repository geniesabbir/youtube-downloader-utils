import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video_job.dart';
import '../services/playback_service.dart';
import '../services/download_service.dart';
import 'video_player_view.dart';
import '../theme/app_theme.dart';

enum PlayerVariant { small, mid, full }

class UnifiedPlayer extends StatefulWidget {
  final VideoJob job;
  final PlayerVariant variant;
  final VoidCallback? onMinimize;
  final ValueChanged<bool>? onLockToggled;

  const UnifiedPlayer({
    super.key,
    required this.job,
    required this.variant,
    this.onMinimize,
    this.onLockToggled,
  });

  @override
  State<UnifiedPlayer> createState() => _UnifiedPlayerState();
}

class _UnifiedPlayerState extends State<UnifiedPlayer> with TickerProviderStateMixin {
  final PlaybackService _playback = PlaybackService();
  late AnimationController _cdRotationController;

  bool _isLocked = false;
  bool _showLockIndicatorActive = false;
  bool _showLeftSeekIndicator = false;
  bool _showRightSeekIndicator = false;
  bool _controlsVisible = true;

  Timer? _lockIndicatorTimer;
  Timer? _fadeControlsTimer;

  @override
  void initState() {
    super.initState();
    _cdRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    _resetControlsTimer();
  }

  @override
  void dispose() {
    _cdRotationController.dispose();
    _lockIndicatorTimer?.cancel();
    _fadeControlsTimer?.cancel();
    super.dispose();
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
    if (_isLocked) {
      _showLockOverlay();
      return;
    }
    final target = _playback.position + offset;
    final maxDuration = _playback.duration;
    Duration clamped = target;
    if (clamped < Duration.zero) {
      clamped = Duration.zero;
    } else if (clamped > maxDuration) {
      clamped = maxDuration;
    }
    _playback.seek(clamped);
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
    if (widget.onLockToggled != null) widget.onLockToggled!(_isLocked);
    _showLockOverlay();
    _resetControlsTimer();
  }

  void _showLockOverlay() {
    setState(() {
      _showLockIndicatorActive = true;
    });
    _lockIndicatorTimer?.cancel();
    _lockIndicatorTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showLockIndicatorActive = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: _playback.stateStream,
      builder: (context, snapshot) {
        final state = snapshot.data ?? _playback.state;
        if (state == PlaybackState.idle) {
          return const SizedBox.shrink();
        }

        switch (widget.variant) {
          case PlayerVariant.small:
            return _buildSmallPlayer(context, state);
          case PlayerVariant.mid:
            return _buildMidPlayer(context, state);
          case PlayerVariant.full:
            return _buildFullPlayer(context, state);
        }
      },
    );
  }

  // ==========================================
  // VARIANT 1: SMALL PLAYER (MINI PLAYER)
  // ==========================================
  Widget _buildSmallPlayer(BuildContext context, PlaybackState state) {
    final isPlaying = state == PlaybackState.playing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mini player Top Progress Indicator Line
        StreamBuilder<Duration>(
          stream: _playback.positionStream,
          builder: (context, posSnapshot) {
            final pos = posSnapshot.data ?? _playback.position;
            return StreamBuilder<Duration>(
              stream: _playback.durationStream,
              builder: (context, durSnapshot) {
                final dur = durSnapshot.data ?? _playback.duration;
                final double progressVal = dur.inSeconds > 0
                    ? (pos.inSeconds / dur.inSeconds).clamp(0.0, 1.0)
                    : 0.0;
                return SizedBox(
                  height: 2.5,
                  width: double.infinity,
                  child: LinearProgressIndicator(
                    value: progressVal,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.mint),
                  ),
                );
              },
            );
          },
        ),
        // Mini Player Contents
        Container(
          height: 65.5,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            children: [
              // Mini Rounded CD or Video Player
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: widget.job.isAudio
                      ? _buildSpinningAudioCdDeck(isPlaying, size: 42)
                      : (_playback.videoController != null && _playback.videoController!.value.isInitialized
                          ? FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _playback.videoController!.value.size.width,
                                height: _playback.videoController!.value.size.height,
                                child: VideoPlayer(_playback.videoController!),
                              ),
                            )
                          : _buildDefaultCdCenter(isPlaying, iconSize: 18)),
                ),
              ),
              // Scrolling Title and Author
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.job.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.job.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10.5,
                          fontFamily: "monospace",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Controls actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10_rounded, color: Color(0xff00d2ff), size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _playback.seek(_playback.position - const Duration(seconds: 10)),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                      color: AppColors.mint,
                      size: 32,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => isPlaying ? _playback.pause() : _playback.resume(),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.forward_10_rounded, color: Color(0xff00d2ff), size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _playback.seek(_playback.position + const Duration(seconds: 10)),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _playback.stop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // VARIANT 2: MEDIUM PLAYER (MID OVERLAY)
  // ==========================================
  Widget _buildMidPlayer(BuildContext context, PlaybackState state) {
    final isPlaying = state == PlaybackState.playing;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              // Swipe Drag handle
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onMinimize,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2.2),
                    ),
                  ),
                ),
              ),

              // Title Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xff00d2ff), size: 28),
                    onPressed: widget.onMinimize,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.job.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15.0,
                          ),
                        ),
                        Text(
                          widget.job.author,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11.0,
                            fontFamily: "monospace",
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.open_in_full_rounded,
                      color: Color(0xff00d2ff),
                      size: 22,
                    ),
                    onPressed: () {
                      if (widget.onMinimize != null) widget.onMinimize!();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerView(job: widget.job),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Media playback block
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = (constraints.maxHeight * 0.9).clamp(90.0, 140.0);
                      final double width = widget.job.isAudio ? size : (size * 16 / 9).clamp(160.0, constraints.maxWidth - 32);
                      final double height = widget.job.isAudio ? size : width * 9 / 16;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: width,
                            height: height,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xff00d2ff).withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: widget.job.isAudio
                                  ? _buildSpinningAudioCdDeck(isPlaying, size: size)
                                  : (_playback.videoController != null && _playback.videoController!.value.isInitialized
                                      ? FittedBox(
                                          fit: BoxFit.cover,
                                          child: SizedBox(
                                            width: _playback.videoController!.value.size.width,
                                            height: _playback.videoController!.value.size.height,
                                            child: VideoPlayer(_playback.videoController!),
                                          ),
                                        )
                                      : _buildDefaultCdCenter(isPlaying, iconSize: 40)),
                            ),
                          ),

                          // Double tap seek gestures
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 140,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onDoubleTap: () => _seekRelative(const Duration(seconds: -10)),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            width: 140,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onDoubleTap: () => _seekRelative(const Duration(seconds: 10)),
                            ),
                          ),
                          Positioned(
                            left: 60,
                            right: 60,
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
              ),
              const SizedBox(height: 12),

              // Glowing scrubbers timeline
              _buildAudioScrubbers(isPlaying),
              const SizedBox(height: 10),

              // Actions controls
              _buildActionsControlsRow(state),
            ],
          ),
        ),

        // Seek indicators
        if (_showLeftSeekIndicator)
          Positioned(
            left: 24,
            top: 100,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fast_rewind_rounded, color: Color(0xff00d2ff), size: 24),
                    Text("-10s", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        if (_showRightSeekIndicator)
          Positioned(
            right: 24,
            top: 100,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fast_forward_rounded, color: Color(0xff00d2ff), size: 24),
                    Text("+10s", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),

        // Locked HUD
        if (_showLockIndicatorActive)
          IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _isLocked ? Colors.amber : const Color(0xff00ff88)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isLocked ? Icons.lock : Icons.lock_open,
                      color: _isLocked ? Colors.amber : const Color(0xff00ff88),
                      size: 32,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLocked ? "Controls Locked" : "Controls Unlocked",
                      style: TextStyle(
                        color: _isLocked ? Colors.amber : const Color(0xff00ff88),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLocked ? "Double-tap center to unlock" : "Accidental taps prevented",
                      style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // VARIANT 3: FULLSCREEN PLAYER (FULL VIEW)
  // ==========================================
  Widget _buildFullPlayer(BuildContext context, PlaybackState state) {
    final isPlaying = state == PlaybackState.playing;
    
    if (widget.job.isAudio) {
      return Container(
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: _buildSpinningAudioCdDeck(isPlaying, size: 160),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAudioScrubbers(isPlaying),
                  const SizedBox(height: 16),
                  _buildActionsControlsRow(state),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Video Fullscreen Widescreen Layout
    return Container(
      color: Colors.black,
      child: _playback.videoController != null && _playback.videoController!.value.isInitialized
          ? Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    if (_isLocked) {
                      _showLockOverlay();
                    } else {
                      setState(() {
                        _controlsVisible = !_controlsVisible;
                      });
                      _resetControlsTimer();
                    }
                  },
                  child: AspectRatio(
                    aspectRatio: _playback.videoController!.value.aspectRatio,
                    child: VideoPlayer(_playback.videoController!),
                  ),
                ),
                
                // Double tap zone layers
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      return Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: width * 0.3,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onDoubleTap: () => _seekRelative(const Duration(seconds: -10)),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            width: width * 0.3,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onDoubleTap: () => _seekRelative(const Duration(seconds: 10)),
                            ),
                          ),
                          Positioned(
                            left: width * 0.3,
                            right: width * 0.3,
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

                // Double tap visualizers
                if (_showLeftSeekIndicator)
                  const Positioned(
                    left: 48,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.fast_rewind, color: AppColors.cyan),
                    ),
                  ),
                if (_showRightSeekIndicator)
                  const Positioned(
                    right: 48,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.fast_forward, color: AppColors.cyan),
                    ),
                  ),

                if (_controlsVisible && !_isLocked) _buildVideoControlsOverlay(),
                
                if (_isLocked && _showLockIndicatorActive)
                  IconButton(
                    icon: const Icon(Icons.lock, color: Colors.amber, size: 40),
                    onPressed: _toggleLock,
                  ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: AppColors.cyan)),
    );
  }

  // ==========================================
  // SHARED RENDERING UTILS & BLOCKS
  // ==========================================
  Widget _buildSpinningAudioCdDeck(bool isPlaying, {required double size}) {
    if (isPlaying) {
      _cdRotationController.repeat();
    } else {
      _cdRotationController.stop();
    }

    Widget cdChild;
    final hasThumbnail = widget.job.thumbnailUrl != null && widget.job.thumbnailUrl!.isNotEmpty;
    
    if (hasThumbnail) {
      cdChild = Image.network(
        widget.job.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultCdCenter(isPlaying, iconSize: size * 0.3),
      );
    } else {
      cdChild = _buildDefaultCdCenter(isPlaying, iconSize: size * 0.3);
    }

    return AspectRatio(
      aspectRatio: 1.0,
      child: RotationTransition(
        turns: _cdRotationController,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xff06080c),
            border: Border.all(color: isPlaying ? AppColors.mint : AppColors.stroke, width: size > 50 ? 4 : 2),
            boxShadow: [
              if (isPlaying && size > 50)
                BoxShadow(
                  color: AppColors.mint.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: cdChild),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.2),
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.6),
                        ],
                        stops: const [0.0, 0.45, 0.48, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),
  
                // Spindle pin
                Container(
                  width: size * 0.18,
                  height: size * 0.18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xff090c12),
                    border: Border.all(color: isPlaying ? AppColors.mint.withValues(alpha: 0.4) : Colors.white24, width: size > 50 ? 2 : 1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultCdCenter(bool isPlaying, {required double iconSize}) {
    return Container(
      color: const Color(0xff0f141f),
      child: Center(
        child: Icon(
          Icons.music_note,
          color: isPlaying ? AppColors.mint : Colors.white24,
          size: iconSize,
        ),
      ),
    );
  }

  Widget _buildAudioScrubbers(bool isPlaying) {
    return StreamBuilder<Duration>(
      stream: _playback.positionStream,
      builder: (context, posSnapshot) {
        final pos = posSnapshot.data ?? _playback.position;
        return StreamBuilder<Duration>(
          stream: _playback.durationStream,
          builder: (context, durSnapshot) {
            final dur = durSnapshot.data ?? _playback.duration;
            final double maxVal = dur.inMilliseconds.toDouble();
            final double currVal = pos.inMilliseconds.toDouble().clamp(0.0, maxVal);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: _isLocked ? 0.0 : 7.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: widget.job.isAudio ? AppColors.mint : AppColors.cyan,
                    inactiveTrackColor: Colors.blueGrey.withValues(alpha: 0.3),
                    thumbColor: widget.job.isAudio ? AppColors.mint : AppColors.cyan,
                  ),
                  child: Slider(
                    value: maxVal > 0 ? currVal : 0.0,
                    max: maxVal > 0 ? maxVal : 1.0,
                    onChanged: _isLocked
                        ? null
                        : (val) {
                            _playback.seek(Duration(milliseconds: val.toInt()));
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(pos),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 10.5,
                          fontFamily: "monospace",
                        ),
                      ),
                      Text(
                        _formatDuration(dur),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 10.5,
                          fontFamily: "monospace",
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildActionsControlsRow(PlaybackState state) {
    final isPlaying = state == PlaybackState.playing;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          icon: Icon(
            Icons.queue_music_rounded,
            color: _isLocked ? Colors.blueGrey.withValues(alpha: 0.2) : const Color(0xff00d2ff),
          ),
          tooltip: "Playback Queue",
          onPressed: _isLocked ? null : () => _showQueueSelector(context),
        ),
        IconButton(
          icon: Icon(
            Icons.speed,
            color: _isLocked ? Colors.blueGrey.withValues(alpha: 0.2) : const Color(0xff00d2ff),
          ),
          tooltip: "Playback Speed",
          onPressed: _isLocked ? null : () => _showSpeedSelector(context),
        ),
        IconButton(
          iconSize: 48,
          icon: Icon(
            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: _isLocked ? Colors.amber : AppColors.mint,
          ),
          onPressed: _isLocked
              ? () => _showLockOverlay()
              : () => isPlaying ? _playback.pause() : _playback.resume(),
        ),
        StreamBuilder<int?>(
          stream: _playback.sleepTimerStream,
          builder: (context, sleepSnapshot) {
            final secondsLeft = sleepSnapshot.data ?? _playback.sleepTimerSecondsLeft;
            return IconButton(
              icon: Icon(
                Icons.snooze,
                color: _isLocked
                    ? Colors.blueGrey.withValues(alpha: 0.2)
                    : (secondsLeft != null ? Colors.amber : const Color(0xff00d2ff)),
              ),
              tooltip: secondsLeft != null ? "Sleep Timer: ${secondsLeft ~/ 60}m" : "Set Sleep Timer",
              onPressed: _isLocked ? null : () => _showSleepTimerSelector(context, secondsLeft),
            );
          },
        ),
        StreamBuilder<LoopModeState>(
          stream: _playback.loopModeStream,
          builder: (context, loopSnapshot) {
            final mode = loopSnapshot.data ?? _playback.loopMode;
            IconData loopIcon;
            Color loopColor;
            String loopTooltip;
            if (mode == LoopModeState.one) {
              loopIcon = Icons.repeat_one_rounded;
              loopColor = AppColors.mint;
              loopTooltip = "Loop: One";
            } else if (mode == LoopModeState.all) {
              loopIcon = Icons.repeat_rounded;
              loopColor = const Color(0xff00d2ff);
              loopTooltip = "Loop: All";
            } else {
              loopIcon = Icons.repeat_rounded;
              loopColor = Colors.blueGrey.withValues(alpha: 0.4);
              loopTooltip = "Loop: Off (Autoplay)";
            }
            
            return IconButton(
              icon: Icon(loopIcon, color: _isLocked ? Colors.blueGrey.withValues(alpha: 0.2) : loopColor),
              tooltip: loopTooltip,
              onPressed: _isLocked ? null : () {
                _playback.toggleLoopMode();
                setState(() {});
              },
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent),
          tooltip: "Stop Playback",
          onPressed: _isLocked ? () => _showLockOverlay() : () => _playback.stop(),
        ),
      ],
    );
  }

  Widget _buildVideoControlsOverlay() {
    if (_playback.videoController == null) return const SizedBox.shrink();
    final duration = _playback.videoController!.value.duration;
    final position = _playback.videoController!.value.position;
    final isPlaying = _playback.videoController!.value.isPlaying;

    return Positioned.fill(
      child: Container(
        color: Colors.black45,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    _isLocked ? Icons.lock : Icons.lock_open_rounded,
                    color: _isLocked ? Colors.amber : Colors.white70,
                    size: 20,
                  ),
                  onPressed: _toggleLock,
                ),
                const SizedBox.shrink(),
              ],
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 32),
                  onPressed: () => _seekRelative(const Duration(seconds: -10)),
                ),
                const SizedBox(width: 32),
                
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isPlaying ? _playback.videoController!.pause() : _playback.videoController!.play();
                    });
                    _resetControlsTimer();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyan.withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                      color: AppColors.cyan,
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(width: 32),

                IconButton(
                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 32),
                  onPressed: () => _seekRelative(const Duration(seconds: 10)),
                ),
              ],
            ),

            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: VideoProgressIndicator(
                    _playback.videoController!,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: AppColors.cyan,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white10,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${_formatDuration(position)} / ${_formatDuration(duration)}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontFamily: "monospace",
                      ),
                    ),
                    
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StreamBuilder<LoopModeState>(
                          stream: _playback.loopModeStream,
                          builder: (context, loopSnapshot) {
                            final mode = loopSnapshot.data ?? _playback.loopMode;
                            IconData loopIcon;
                            Color loopColor;
                            if (mode == LoopModeState.one) {
                              loopIcon = Icons.repeat_one_rounded;
                              loopColor = AppColors.mint;
                            } else if (mode == LoopModeState.all) {
                              loopIcon = Icons.repeat_rounded;
                              loopColor = AppColors.cyan;
                            } else {
                              loopIcon = Icons.repeat_rounded;
                              loopColor = Colors.white54;
                            }
                            return IconButton(
                              icon: Icon(loopIcon, color: loopColor, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _playback.toggleLoopMode();
                                setState(() {});
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 14),

                        IconButton(
                          icon: const Icon(Icons.speed_rounded, color: Colors.white70, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showSpeedSelector(context),
                        ),
                        const SizedBox(width: 14),

                        const Icon(Icons.fullscreen_rounded, color: Colors.white54, size: 20),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQueueSelector(BuildContext context) {
    final queue = DownloadService().queue;
    final libraryJobs = queue.where((j) => j.localPath != null).toList();

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.queue_music_rounded, color: Color(0xff00d2ff), size: 22),
                  SizedBox(width: 8),
                  Text(
                    "PLAYBACK QUEUE",
                    style: TextStyle(
                      color: Color(0xff00d2ff),
                      fontWeight: FontWeight.bold,
                      fontSize: 14.0,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (libraryJobs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      "No other tracks in queue",
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: libraryJobs.length,
                    itemBuilder: (context, index) {
                      final item = libraryJobs[index];
                      final bool isCurrent = item.jobId == widget.job.jobId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty
                                ? DecorationImage(image: NetworkImage(item.thumbnailUrl!), fit: BoxFit.cover)
                                : null,
                            color: const Color(0xff0a0d14),
                          ),
                          child: item.thumbnailUrl == null || item.thumbnailUrl!.isEmpty
                              ? const Icon(Icons.music_note, color: Colors.white24, size: 20)
                              : null,
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent ? const Color(0xff00ff88) : Colors.white,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13.0,
                          ),
                        ),
                        subtitle: Text(
                          item.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent ? const Color(0xff00ff88).withValues(alpha: 0.7) : Colors.white54,
                            fontSize: 11.0,
                          ),
                        ),
                        trailing: isCurrent
                            ? const Icon(Icons.volume_up_rounded, color: Color(0xff00ff88), size: 18)
                            : const Icon(Icons.play_arrow_rounded, color: Colors.white38, size: 18),
                        onTap: () {
                          Navigator.pop(context);
                          _playback.play(item);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showSpeedSelector(BuildContext context) {
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
                  final active = _playback.speed == speedVal;
                  return ChoiceChip(
                    label: Text("${speedVal}x"),
                    selected: active,
                    selectedColor: const Color(0xff00ff88),
                    labelStyle: TextStyle(color: active ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                    backgroundColor: const Color(0xff0a0d14),
                    onSelected: (selected) {
                      if (selected) {
                        _playback.setSpeed(speedVal);
                        Navigator.pop(context);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showSleepTimerSelector(BuildContext context, int? secondsLeft) {
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
                "CONFIGURE SLEEP TIMER",
                style: TextStyle(
                  color: Color(0xff00d2ff),
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              if (secondsLeft != null) ...[
                Text(
                  "Active timer: ${secondsLeft ~/ 60}m ${secondsLeft % 60}s remaining",
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    _playback.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                  child: const Text("CANCEL SLEEP TIMER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [5, 15, 30, 45, 60].map((mins) {
                    return ActionChip(
                      label: Text("$mins Minutes"),
                      backgroundColor: const Color(0xff0a0d14),
                      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      onPressed: () {
                        _playback.setSleepTimer(Duration(minutes: mins));
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
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
