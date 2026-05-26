import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/playback_service.dart';
import '../models/video_job.dart';
import '../theme/app_theme.dart';
import 'unified_player.dart';

class PlayerOverlay extends StatefulWidget {
  const PlayerOverlay({super.key});

  @override
  State<PlayerOverlay> createState() => _PlayerOverlayState();
}

class _PlayerOverlayState extends State<PlayerOverlay> {
  final PlaybackService _playback = PlaybackService();
  
  bool _isExpanded = false;
  bool _isLocked = false;

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
        double panelHeight = 72.0; // Mini player height (accounts for border and prevents overflows)
        if (_isExpanded) {
          panelHeight = 380.0;
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
                  ? Colors.amber.withValues(alpha: 0.4)
                  : const Color(0xff00d2ff).withValues(alpha: 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
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
                color: const Color(0xff080b0e).withValues(alpha: 0.85),
                child: _isExpanded
                    ? SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          height: 380.0,
                          child: UnifiedPlayer(
                            job: job,
                            variant: PlayerVariant.mid,
                            onMinimize: () {
                              setState(() {
                                _isExpanded = false;
                              });
                            },
                            onLockToggled: (locked) {
                              setState(() {
                                _isLocked = locked;
                              });
                            },
                          ),
                        ),
                      )
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _isExpanded = true;
                          });
                        },
                        child: UnifiedPlayer(
                          job: job,
                          variant: PlayerVariant.small,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
