import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/playback_service.dart';
import '../models/video_job.dart';
import '../theme/app_theme.dart';

class PlayerOverlay extends StatefulWidget {
  const PlayerOverlay({super.key});

  @override
  State<PlayerOverlay> createState() => _PlayerOverlayState();
}

class _PlayerOverlayState extends State<PlayerOverlay> {
  final PlaybackService _playback = PlaybackService();
  
  // Phase 2 State management
  bool _isExpanded = false;
  bool _chaptersExpanded = false;
  bool _isLocked = false;
  bool _showLockIndicatorActive = false;
  bool _showLeftSeekIndicator = false;
  bool _showRightSeekIndicator = false;

  Timer? _lockIndicatorTimer;

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
        _chaptersExpanded = false;
      }
    });
    _showLockOverlay();
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
  void dispose() {
    _lockIndicatorTimer?.cancel();
    super.dispose();
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

        final job = _playback.activeJob;
        if (job == null) return const SizedBox.shrink();

        // Dynamically compute the panel height based on state
        double panelHeight = 68.0; // Mini player height
        if (_isExpanded) {
          panelHeight = _chaptersExpanded ? 540.0 : 380.0;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastOutSlowIn,
          height: panelHeight,
          width: double.infinity,
          margin: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isLocked
                  ? Colors.amber.withOpacity(0.4)
                  : const Color(0xff00d2ff).withOpacity(0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: const Color(0xff080b0e).withOpacity(0.85),
                child: _isExpanded ? _buildFullPlayer(context, state, job) : _buildMiniPlayer(context, state, job),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- 1. Mini Player View ---
  Widget _buildMiniPlayer(BuildContext context, PlaybackState state, VideoJob job) {
    return Column(
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
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _isExpanded = true;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  // Mini Rounded Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: job.thumbnailUrl != null && job.thumbnailUrl!.isNotEmpty
                          ? Image.network(
                              job.thumbnailUrl!,
                              fit: BoxFit.cover,
                              cacheWidth: 320, // Binds decoded image RAM size limit
                              errorBuilder: (c, e, s) => Container(
                                color: Colors.white10,
                                child: const Icon(Icons.music_note_rounded, color: AppColors.mint, size: 20),
                              ),
                            )
                          : Container(
                              color: Colors.white10,
                              child: const Icon(Icons.music_note_rounded, color: AppColors.mint, size: 20),
                            ),
                    ),
                  ),
                  // scrolling Title and Author
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            job.title,
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
                            job.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
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
                          state == PlaybackState.playing
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          color: AppColors.mint,
                          size: 32,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (state == PlaybackState.playing) {
                            _playback.pause();
                          } else {
                            _playback.resume();
                          }
                        },
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
          ),
        ),
      ],
    );
  }

  // --- 2. Full Player View ---
  Widget _buildFullPlayer(BuildContext context, PlaybackState state, VideoJob job) {
    return Stack(
      children: [
        // Main full player content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              // Tap Drag Handle to Minimize
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _isExpanded = false;
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2.2),
                    ),
                  ),
                ),
              ),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xff00d2ff), size: 28),
                    onPressed: () {
                      setState(() {
                        _isExpanded = false;
                      });
                    },
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          job.title,
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
                          job.author,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11.0,
                            fontFamily: "monospace",
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isLocked ? Icons.lock : Icons.lock_open,
                      color: _isLocked ? Colors.amber : Colors.white70,
                      size: 20,
                    ),
                    onPressed: _toggleLock,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Middle: Large rounded thumbnail with seek/lock gesture zones
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = (constraints.maxHeight * 0.9).clamp(90.0, 140.0);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Thumbnail itself
                          Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xff00d2ff).withOpacity(0.15),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: job.thumbnailUrl != null && job.thumbnailUrl!.isNotEmpty
                                  ? Image.network(
                                      job.thumbnailUrl!,
                                      fit: BoxFit.cover,
                                      cacheWidth: 320, // Binds decoded image RAM size limit
                                      errorBuilder: (c, e, s) => Container(
                                        color: Colors.white10,
                                        child: const Icon(Icons.music_note, color: AppColors.mint, size: 40),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.white10,
                                      child: const Icon(Icons.music_note, color: AppColors.mint, size: 40),
                                    ),
                            ),
                          ),

                          // Double tap Left Seek Zone
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

                          // Double tap Right Seek Zone
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

                          // Double tap Center Lock Gesture
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

              // Slider seeking bar
              StreamBuilder<Duration>(
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
                              activeTrackColor: _isLocked ? Colors.amber : const Color(0xff00d2ff),
                              inactiveTrackColor: Colors.blueGrey.withOpacity(0.3),
                              thumbColor: AppColors.mint,
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
                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(pos),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 10.5,
                                    fontFamily: "monospace",
                                  ),
                                ),
                                Text(
                                  _formatDuration(dur),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
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
              ),
              const SizedBox(height: 10),

              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Chapters trigger
                  IconButton(
                    icon: Icon(
                      _chaptersExpanded ? Icons.menu_open : Icons.menu,
                      color: _isLocked
                          ? Colors.blueGrey.withOpacity(0.2)
                          : (job.chapters.isNotEmpty ? const Color(0xff00d2ff) : Colors.blueGrey.withOpacity(0.4)),
                    ),
                    tooltip: "Chapters List",
                    onPressed: (_isLocked || job.chapters.isEmpty)
                        ? null
                        : () {
                            setState(() {
                              _chaptersExpanded = !_chaptersExpanded;
                            });
                          },
                  ),

                  // Playback speed
                  IconButton(
                    icon: Icon(
                      Icons.speed,
                      color: _isLocked ? Colors.blueGrey.withOpacity(0.2) : const Color(0xff00d2ff),
                    ),
                    tooltip: "Playback Speed",
                    onPressed: _isLocked ? null : () => _showSpeedSelector(context),
                  ),

                  // Primary Play / Pause
                  IconButton(
                    iconSize: 48,
                    icon: Icon(
                      state == PlaybackState.playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: _isLocked ? Colors.amber : AppColors.mint,
                    ),
                    onPressed: _isLocked
                        ? () => _showLockOverlay()
                        : () {
                            if (state == PlaybackState.playing) {
                              _playback.pause();
                            } else {
                              _playback.resume();
                            }
                          },
                  ),

                  // Sleep Timer
                  StreamBuilder<int?>(
                    stream: _playback.sleepTimerStream,
                    builder: (context, sleepSnapshot) {
                      final secondsLeft = sleepSnapshot.data ?? _playback.sleepTimerSecondsLeft;
                      return IconButton(
                        icon: Icon(
                          Icons.snooze,
                          color: _isLocked
                              ? Colors.blueGrey.withOpacity(0.2)
                              : (secondsLeft != null ? Colors.amber : const Color(0xff00d2ff)),
                        ),
                        tooltip: secondsLeft != null ? "Sleep Timer: ${secondsLeft ~/ 60}m" : "Set Sleep Timer",
                        onPressed: _isLocked ? null : () => _showSleepTimerSelector(context, secondsLeft),
                      );
                    },
                  ),

                  // Stop player close button
                  IconButton(
                    icon: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent),
                    tooltip: "Stop Playback",
                    onPressed: _isLocked ? () => _showLockOverlay() : () => _playback.stop(),
                  ),
                ],
              ),

              // Chapters List View (expanded)
              if (_chaptersExpanded && !_isLocked) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.blueGrey, height: 1),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "LECTURE CHAPTERS",
                    style: TextStyle(
                      color: Color(0xff00d2ff),
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: StreamBuilder<Duration>(
                    stream: _playback.positionStream,
                    builder: (context, posSnapshot) {
                      final pos = posSnapshot.data ?? _playback.position;
                      return ListView.builder(
                        itemCount: job.chapters.length,
                        itemBuilder: (context, index) {
                          final chap = job.chapters[index];
                          final bool active = pos >= chap.start && pos < chap.end;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            leading: Icon(
                              active ? Icons.play_arrow : Icons.radio_button_unchecked,
                              color: active ? const Color(0xff00ff88) : Colors.blueGrey,
                              size: 16,
                            ),
                            title: Text(
                              chap.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: active ? const Color(0xff00ff88) : Colors.white,
                                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12.0,
                              ),
                            ),
                            trailing: Text(
                              _formatDuration(chap.start),
                              style: TextStyle(
                                color: active ? const Color(0xff00ff88) : Colors.white.withOpacity(0.5),
                                fontFamily: "monospace",
                                fontSize: 11.0,
                              ),
                            ),
                            onTap: () {
                              _playback.seek(chap.start);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),

        // Double-Tap Seek left side notification Overlay
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

        // Double-Tap Seek right side notification Overlay
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

        // Full Screen Lock Center Alert
        if (_showLockIndicatorActive)
          IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.9),
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
