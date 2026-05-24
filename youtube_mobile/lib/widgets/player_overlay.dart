import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/playback_service.dart';

class PlayerOverlay extends StatefulWidget {
  const PlayerOverlay({super.key});

  @override
  State<PlayerOverlay> createState() => _PlayerOverlayState();
}

class _PlayerOverlayState extends State<PlayerOverlay> {
  final PlaybackService _playback = PlaybackService();
  bool _chaptersExpanded = false;

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

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _chaptersExpanded ? 500 : 220,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24.0),
              topRight: Radius.circular(24.0),
            ),
            border: Border.all(
              color: const Color(0xff00d2ff).withOpacity(0.3),
              width: 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24.0),
              topRight: Radius.circular(24.0),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: const Color(0xff080b0e).withOpacity(0.9),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  children: [
                    // Handle line
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Track Title & Author
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                              ),
                              Text(
                                job.author,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent),
                          onPressed: () => _playback.stop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Seek Bar Slider
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
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                    activeTrackColor: const Color(0xff00d2ff),
                                    inactiveTrackColor: Colors.blueGrey.withOpacity(0.3),
                                    thumbColor: const Color(0xff00ff88),
                                  ),
                                  child: Slider(
                                    value: maxVal > 0 ? currVal : 0.0,
                                    max: maxVal > 0 ? maxVal : 1.0,
                                    onChanged: (val) {
                                      _playback.seek(Duration(milliseconds: val.toInt()));
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(pos),
                                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontFamily: "monospace"),
                                      ),
                                      Text(
                                        _formatDuration(dur),
                                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontFamily: "monospace"),
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
                    const SizedBox(height: 8),
                    // Main audio player controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Chapters trigger
                        IconButton(
                          icon: Icon(
                            _chaptersExpanded ? Icons.menu_open : Icons.menu,
                            color: job.chapters.isNotEmpty ? const Color(0xff00d2ff) : Colors.blueGrey.withOpacity(0.4),
                          ),
                          tooltip: "Chapters List",
                          onPressed: job.chapters.isNotEmpty
                              ? () {
                                  setState(() {
                                    _chaptersExpanded = !_chaptersExpanded;
                                  });
                                }
                              : null,
                        ),
                        // Speed speed setting
                        IconButton(
                          icon: const Icon(Icons.speed, color: Color(0xff00d2ff)),
                          tooltip: "Playback Speed",
                          onPressed: () => _showSpeedSelector(context),
                        ),
                        // Main control button
                        IconButton(
                          iconSize: 42,
                          icon: Icon(
                            state == PlaybackState.playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            color: const Color(0xff00ff88),
                          ),
                          onPressed: () {
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
                                color: secondsLeft != null ? Colors.amber : const Color(0xff00d2ff),
                              ),
                              tooltip: secondsLeft != null ? "Sleep Timer: ${secondsLeft ~/ 60}m" : "Set Sleep Timer",
                              onPressed: () => _showSleepTimerSelector(context, secondsLeft),
                            );
                          },
                        ),
                      ],
                    ),
                    // Chapters Expanded view
                    if (_chaptersExpanded) ...[
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
                            fontSize: 12.0,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                                  leading: Icon(
                                    active ? Icons.play_arrow : Icons.radio_button_unchecked,
                                    color: active ? const Color(0xff00ff88) : Colors.blueGrey,
                                  ),
                                  title: Text(
                                    chap.title,
                                    style: TextStyle(
                                      color: active ? const Color(0xff00ff88) : Colors.white,
                                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: Text(
                                    _formatDuration(chap.start),
                                    style: TextStyle(
                                      color: active ? const Color(0xff00ff88) : Colors.white.withOpacity(0.5),
                                      fontFamily: "monospace",
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
            ),
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
                style: TextStyle(color: Color(0xff00d2ff), fontWeight: FontWeight.bold, fontSize: 14.0),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [0.5, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0].map((speedVal) {
                  final active = _playback.speed == speedVal;
                  return ChoiceChip(
                    label: Text("${speedVal}x"),
                    selected: active,
                    selectedColor: const Color(0xff00ff88),
                    labelStyle: TextStyle(color: active ? Colors.black : Colors.white),
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
              const SizedBox(height: 12),
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
                style: TextStyle(color: Color(0xff00d2ff), fontWeight: FontWeight.bold, fontSize: 14.0),
              ),
              const SizedBox(height: 16),
              if (secondsLeft != null) ...[
                Text(
                  "Active timer: ${secondsLeft ~/ 60}m ${secondsLeft % 60}s remaining",
                  style: const TextStyle(color: Colors.amber),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () {
                    _playback.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                  child: const Text("CANCEL SLEEP TIMER", style: TextStyle(color: Colors.white)),
                ),
              ] else ...[
                Wrap(
                  spacing: 12,
                  children: [5, 15, 30, 45, 60].map((mins) {
                    return ActionChip(
                      label: Text("$mins Minutes"),
                      backgroundColor: const Color(0xff0a0d14),
                      labelStyle: const TextStyle(color: Colors.white),
                      onPressed: () {
                        _playback.setSleepTimer(Duration(minutes: mins));
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
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
