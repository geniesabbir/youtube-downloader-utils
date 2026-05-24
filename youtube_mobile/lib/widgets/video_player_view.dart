import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video_job.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.job.localPath!))
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
      });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        title: Text(widget.job.title, style: const TextStyle(fontSize: 13.0, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: _initialized
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _controlsVisible = !_controlsVisible;
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    if (_controlsVisible) ...[
                      // Gradient shadow
                      Container(color: Colors.black.withOpacity(0.4)),
                      // Play/Pause button
                      IconButton(
                        iconSize: 64,
                        icon: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
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
                        },
                      ),
                      // Video Seek bar
                      Positioned(
                        bottom: 30,
                        left: 20,
                        right: 20,
                        child: Column(
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
                            const SizedBox(height: 8),
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
                ),
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
