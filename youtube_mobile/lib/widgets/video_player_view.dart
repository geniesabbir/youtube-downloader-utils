import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../models/video_job.dart';
import '../models/transcript.dart';
import '../models/note.dart';
import '../services/download_service.dart';
import '../services/playback_service.dart';
import '../services/transcript_service.dart';
import '../services/ai_service.dart';
import '../services/clip_service.dart';
import '../theme/app_theme.dart';
import '../core/events/event_bus.dart';
import 'brand_mark.dart';

class VideoPlayerView extends StatefulWidget {
  final VideoJob job;
  const VideoPlayerView({super.key, required this.job});

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> with TickerProviderStateMixin {
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

  // Workspace Study States
  final DownloadService _download = DownloadService();
  final PlaybackService _playback = PlaybackService();
  final TranscriptService _transcriptService = TranscriptService();
  final AiService _aiService = AiService();

  List<TranscriptSegment> _segments = [];
  List<MediaNote> _notes = [];
  bool _loadingTranscript = false;

  // AI Summary State
  String _summaryText = "";
  List<String> _keyPoints = [];
  bool _generatingSummary = false;

  // Search State
  String _searchQuery = "";
  List<TranscriptSegment> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();

  // Note Input State
  final TextEditingController _noteInputController = TextEditingController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Initialize Workspace Data
    _loadJobWorkspaceData();

    if (!widget.job.isAudio) {
      if (_playback.activeJob?.jobId != widget.job.jobId) {
        _playback.play(widget.job).then((_) {
          if (mounted) {
            _initializeController();
          }
        });
      } else {
        _initializeController();
      }
    } else {
      if (_playback.activeJob?.jobId != widget.job.jobId) {
        _playback.play(widget.job);
      }
    }
  }

  void _initializeController() {
    if (_playback.videoController != null) {
      _controller = _playback.videoController!;
      _controller.addListener(_onControllerUpdate);
      setState(() {
        _initialized = true;
      });
      _startProgressSaving();
      _resetControlsTimer();
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startProgressSaving() {
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });
  }

  void _saveProgress() {
    if (widget.job.isAudio) return;
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
    if (widget.job.isAudio) {
      final target = _playback.position + offset;
      _playback.seek(target);
      return;
    }

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
    _lockIndicatorTimer = Timer(const Duration(seconds: 2), () {
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
                  final active = widget.job.isAudio 
                      ? _playback.speed == speedVal
                      : _controller.value.playbackSpeed == speedVal;
                  return ChoiceChip(
                    label: Text("${speedVal}x"),
                    selected: active,
                    selectedColor: const Color(0xff00ff88),
                    labelStyle: TextStyle(color: active ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                    backgroundColor: const Color(0xff0a0d14),
                    onSelected: (selected) {
                      if (selected) {
                        if (widget.job.isAudio) {
                          _playback.setSpeed(speedVal);
                        } else {
                          _controller.setPlaybackSpeed(speedVal);
                        }
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

  // ── Study Workspace Logic ──────────────────────────────────────────────────
  void _loadJobWorkspaceData() async {
    setState(() {
      _loadingTranscript = true;
      _summaryText = "";
      _keyPoints = [];
      _segments = [];
      _searchResults = [];
      _notes = [];
    });

    final segs = await _transcriptService.getTranscript(widget.job);
    final loadedNotes = await _loadPersistedNotes(widget.job.jobId);

    if (mounted) {
      setState(() {
        _segments = segs;
        _notes = loadedNotes;
        _loadingTranscript = false;
      });
    }
  }

  Future<List<MediaNote>> _loadPersistedNotes(String jobId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('library_notes_$jobId');
    if (raw != null) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        return decoded.map((e) => MediaNote.fromJson(e)).toList();
      } catch (_) {}
    }
    return [];
  }

  Future<void> _saveNote(MediaNote note) async {
    setState(() {
      _notes.add(note);
    });
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_notes.map((e) => e.toJson()).toList());
    await prefs.setString('library_notes_${note.jobId}', raw);
  }

  Future<void> _deleteNote(String noteId) async {
    setState(() {
      _notes.removeWhere((n) => n.noteId == noteId);
    });
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_notes.map((e) => e.toJson()).toList());
    await prefs.setString('library_notes_${widget.job.jobId}', raw);
  }

  void _generateAISummary() async {
    setState(() {
      _generatingSummary = true;
    });

    final summary = await _aiService.summarize(_segments, widget.job.title);
    final keyPointsList = await _aiService.extractKeyPoints(_segments);

    if (mounted) {
      setState(() {
        _summaryText = summary;
        _keyPoints = keyPointsList;
        _generatingSummary = false;
      });
    }
  }

  void _triggerSearch(String query) {
    setState(() {
      _searchQuery = query;
      _searchResults = _aiService.semanticSearch(query, _segments);
    });
  }

  void _addNewNoteAtCurrentTime() {
    final text = _noteInputController.text.trim();
    if (text.isEmpty) return;

    final currentPos = widget.job.isAudio 
        ? _playback.position 
        : (_initialized ? _controller.value.position : Duration.zero);

    final newNote = MediaNote(
      noteId: DateTime.now().millisecondsSinceEpoch.toString(),
      jobId: widget.job.jobId,
      timestamp: currentPos,
      content: text,
      createdAt: DateTime.now(),
    );

    _saveNote(newNote);
    _noteInputController.clear();
    FocusScope.of(context).unfocus();
  }

  void _jumpToTimestamp(Duration timestamp) {
    if (!widget.job.isAudio && _initialized) {
      _controller.seekTo(timestamp);
      _saveProgress();
    } else {
      _playback.seek(timestamp);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Jumped to timestamp ${_formatDuration(timestamp)}", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.cyan,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _lockIndicatorTimer?.cancel();
    _fadeControlsTimer?.cancel();
    
    if (!widget.job.isAudio) {
      _saveProgress();
      if (_initialized) {
        _controller.removeListener(_onControllerUpdate);
      }
    }
    
    _tabController.dispose();
    _searchController.dispose();
    _noteInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrandBackdrop(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white70),
          title: Text(
            widget.job.isAudio ? "OFFLINE STUDY AUDIO" : "OFFLINE STUDY LECTURE",
            style: const TextStyle(color: AppColors.cyan, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // ── 1. Top Pinned Media Player Block ─────────────────────────────
            _buildPlayerBlock(),

            // ── 2. Scrollable Detail, Comments & Workspace Area ──────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailsHeader(),
                    const Divider(color: Colors.white10, height: 1, thickness: 1),
                    _buildCognitiveWorkspace(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerBlock() {
    if (widget.job.isAudio) {
      return StreamBuilder<PlaybackState>(
        stream: _playback.stateStream,
        builder: (context, snapshot) {
          final isPlaying = _playback.state == PlaybackState.playing;
          return AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: const Color(0xff090c12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Spinning CD
                  _buildSpinningAudioCdDeck(isPlaying),
                  Positioned(
                    bottom: 12,
                    left: 16,
                    right: 16,
                    child: _buildAudioScrubbers(isPlaying),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: _initialized
            ? Stack(
                alignment: Alignment.center,
                children: [
                  GestureDetector(
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
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                  
                  // Gestures seeks zones
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

                  // Overlays and controls
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
      ),
    );
  }

  Widget _buildSpinningAudioCdDeck(bool isPlaying) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xff06080c),
        border: Border.all(color: isPlaying ? AppColors.mint : AppColors.stroke, width: 3),
        boxShadow: [
          if (isPlaying)
            BoxShadow(
              color: AppColors.mint.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xff0b0f17),
          ),
          child: Center(
            child: Icon(
              Icons.music_note,
              color: isPlaying ? AppColors.mint : Colors.white24,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioScrubbers(bool isPlaying) {
    return StreamBuilder<Duration>(
      stream: _playback.positionStream,
      builder: (context, snapshot) {
        final pos = _playback.position;
        final dur = _playback.duration;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(pos), style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: "monospace")),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10, color: AppColors.mint, size: 20),
                  onPressed: () => _playback.seek(pos - const Duration(seconds: 10)),
                ),
                IconButton(
                  icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle, color: AppColors.mint, size: 28),
                  onPressed: () => isPlaying ? _playback.pause() : _playback.resume(),
                ),
                IconButton(
                  icon: const Icon(Icons.forward_10, color: AppColors.mint, size: 20),
                  onPressed: () => _playback.seek(pos + const Duration(seconds: 10)),
                ),
                IconButton(
                  icon: const Icon(Icons.speed, color: AppColors.mint, size: 18),
                  onPressed: () => _showSpeedSelector(context),
                ),
              ],
            ),
            Text(_formatDuration(dur), style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: "monospace")),
          ],
        );
      },
    );
  }

  Widget _buildVideoControlsOverlay() {
    final duration = _controller.value.duration;
    final position = _controller.value.position;
    final isPlaying = _controller.value.isPlaying;

    return Positioned.fill(
      child: Container(
        color: Colors.black38,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(_isLocked ? Icons.lock : Icons.lock_open, color: Colors.white70, size: 20),
                  onPressed: _toggleLock,
                ),
                IconButton(
                  icon: const Icon(Icons.speed, color: Colors.white70, size: 20),
                  onPressed: () => _showSpeedSelector(context),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10, color: Colors.white, size: 28),
                  onPressed: () => _seekRelative(const Duration(seconds: -10)),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: 48),
                  onPressed: () {
                    setState(() {
                      isPlaying ? _controller.pause() : _controller.play();
                    });
                    _resetControlsTimer();
                  },
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(Icons.forward_10, color: Colors.white, size: 28),
                  onPressed: () => _seekRelative(const Duration(seconds: 10)),
                ),
              ],
            ),
            Column(
              children: [
                VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: AppColors.cyan,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white10,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${_formatDuration(position)} / ${_formatDuration(duration)}",
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: "monospace"),
                    ),
                    const Icon(Icons.fullscreen, color: Colors.white70, size: 20),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color: const Color(0xff090c10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.job.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          
          // Stats / views line
          Row(
            children: [
              Text(
                "Offline study • ${widget.job.fileSizeDisplay} • ",
                style: const TextStyle(color: Colors.blueGrey, fontSize: 11.5),
              ),
              const Icon(Icons.offline_pin_rounded, color: AppColors.mint, size: 12),
              const SizedBox(width: 4),
              const Text(
                "Downloaded",
                style: TextStyle(color: AppColors.mint, fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          
          // YouTube-style Horizontal Actions Row
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // 1. Star / Favorite Button
                StatefulBuilder(
                  builder: (context, setFavState) {
                    final isFav = widget.job.isFavorited;
                    return InkWell(
                      onTap: () async {
                        widget.job.isFavorited = !widget.job.isFavorited;
                        final downloadService = DownloadService();
                        await downloadService.updateJobStateDirectly(widget.job.jobId, widget.job);
                        setFavState(() {});
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isFav ? AppColors.cyan.withOpacity(0.1) : Colors.white10,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isFav ? AppColors.cyan.withOpacity(0.3) : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isFav ? Icons.star_rounded : Icons.star_border_rounded,
                              color: isFav ? Colors.amber : Colors.white70,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isFav ? "Favorited" : "Favorite",
                              style: TextStyle(
                                color: isFav ? AppColors.cyan : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                
                // 2. FFmpeg timeline clip extractor Button
                InkWell(
                  onTap: _showClipExtractorBottomSheet,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cut, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "Extract Clip",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Share Collection Button
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Collection shared successfully!", style: TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: AppColors.cyan,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.share, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "Share",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 4. Download Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_done, color: Colors.white60, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "100% Offline",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }




  Widget _buildCognitiveWorkspace() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              const Icon(Icons.psychology, color: AppColors.cyan, size: 20),
              const SizedBox(width: 8),
              Text(
                "COGNITIVE STUDY WORKSPACE",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        // The Tab Bar Selectors
        _buildTabBarSelectors(),
        // Bounded Study View Panel
        SizedBox(
          height: 420.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _loadingTranscript
                ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTranscriptTab(),
                      _buildSearchTab(),
                      _buildNotesTab(),
                      _buildSummaryTab(),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }




  void _showClipExtractorBottomSheet() {
    _resetControlsTimer();
    final currentPos = widget.job.isAudio 
        ? _playback.position 
        : (_initialized ? _controller.value.position : Duration.zero);
    
    // Default duration to 30 seconds
    final maxDur = widget.job.isAudio
        ? const Duration(minutes: 60) // Simple limit for audio
        : (_initialized ? _controller.value.duration : const Duration(minutes: 60));
    
    Duration startTime = currentPos;
    Duration endTime = currentPos + const Duration(seconds: 30);
    if (endTime > maxDur) {
      endTime = maxDur;
    }
    
    bool audioOnly = widget.job.isAudio;
    bool extracting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff090c12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "🧠 FFmpeg TIMELINE CLIP EXTRACTOR",
                    style: TextStyle(
                      color: AppColors.cyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.0,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Extract any segment of your offline lecture timeline to a separate media file.",
                    style: TextStyle(color: Colors.white54, fontSize: 11.5),
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  
                  if (extracting) ...[
                    const Center(
                      child: Column(
                        children: [
                          SizedBox(height: 20),
                          CircularProgressIndicator(color: AppColors.mint),
                          SizedBox(height: 16),
                          Text("Extracting segment via FFmpeg...", style: TextStyle(color: AppColors.mint, fontSize: 12, fontWeight: FontWeight.bold)),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Start time picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Start Time Offset", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: Text(_formatDuration(startTime), style: const TextStyle(color: AppColors.cyan, fontFamily: "monospace", fontSize: 14, fontWeight: FontWeight.bold)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.white54),
                            onPressed: () {
                              setSheetState(() {
                                if (startTime.inSeconds >= 5) {
                                  startTime -= const Duration(seconds: 5);
                                }
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
                            onPressed: () {
                              setSheetState(() {
                                if (startTime + const Duration(seconds: 5) < endTime) {
                                  startTime += const Duration(seconds: 5);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // End time picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("End Time Offset", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: Text(_formatDuration(endTime), style: const TextStyle(color: AppColors.mint, fontFamily: "monospace", fontSize: 14, fontWeight: FontWeight.bold)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.white54),
                            onPressed: () {
                              setSheetState(() {
                                if (endTime - const Duration(seconds: 5) > startTime) {
                                  endTime -= const Duration(seconds: 5);
                                }
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
                            onPressed: () {
                              setSheetState(() {
                                if (endTime + const Duration(seconds: 5) <= maxDur) {
                                  endTime += const Duration(seconds: 5);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    if (!widget.job.isAudio) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text("Audio Only Mode", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const Spacer(),
                          Switch(
                            value: audioOnly,
                            activeColor: AppColors.cyan,
                            onChanged: (val) {
                              setSheetState(() {
                                audioOnly = val;
                              });
                            },
                          )
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mint,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          setSheetState(() {
                            extracting = true;
                          });
                          final clipService = ClipService();
                          final path = await clipService.extractClip(
                            job: widget.job,
                            startTime: startTime,
                            endTime: endTime,
                            audioOnly: audioOnly,
                          );
                          Navigator.pop(context);
                          
                          if (path != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Clip extracted successfully to: ...${path.substring(path.length > 30 ? path.length - 30 : 0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                                backgroundColor: AppColors.mint,
                                duration: const Duration(seconds: 4),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Failed to extract clip. Please try again.", style: TextStyle(fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.bolt, color: Colors.black),
                        label: const Text("EXTRACT TIMELINE SEGMENT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTabBarSelectors() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.stroke),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.mint,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.muted,
        labelStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: "Transcript"),
          Tab(text: "Search"),
          Tab(text: "Notes"),
          Tab(text: "AI Summary"),
        ],
      ),
    );
  }

  // ── Tab Render Builders ────────────────────────────────────────────────────
  Widget _buildTranscriptTab() {
    if (_segments.isEmpty) {
      return const Center(child: Text("No transcript segments found.", style: TextStyle(color: Colors.white24)));
    }
    return ListView.builder(
      itemCount: _segments.length,
      itemBuilder: (context, index) {
        final seg = _segments[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _jumpToTimestamp(seg.start),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.cyan.withOpacity(0.25)),
                  ),
                  child: Text(
                    _formatDuration(seg.start),
                    style: const TextStyle(color: AppColors.cyan, fontSize: 10.5, fontFamily: "monospace", fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  seg.text,
                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: const Color(0xff121820),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 13.0),
            onChanged: _triggerSearch,
            decoration: InputDecoration(
              icon: const Icon(Icons.search, color: AppColors.mint, size: 18),
              hintText: "Search keyword in this transcript...",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12.5),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _searchQuery.isEmpty
              ? Center(child: Text("Type a word above to search transcript timestamps.", style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12.0)))
              : _searchResults.isEmpty
                  ? const Center(child: Text("No matches found in transcript.", style: TextStyle(color: Colors.white24)))
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final match = _searchResults[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: ActionChip(
                            label: Text(_formatDuration(match.start), style: const TextStyle(fontFamily: "monospace", fontSize: 10, fontWeight: FontWeight.bold)),
                            backgroundColor: AppColors.cyan.withOpacity(0.12),
                            onPressed: () => _jumpToTimestamp(match.start),
                          ),
                          title: Text(match.text, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildNotesTab() {
    final currentTimeStr = widget.job.isAudio 
        ? _formatDuration(_playback.position)
        : (_initialized ? _formatDuration(_controller.value.position) : "00:00");

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                decoration: BoxDecoration(
                  color: const Color(0xff121820),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
                ),
                child: TextField(
                  controller: _noteInputController,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  decoration: InputDecoration(
                    prefixIcon: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.mint.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(currentTimeStr, style: const TextStyle(color: AppColors.mint, fontSize: 10.5, fontFamily: "monospace", fontWeight: FontWeight.bold)),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    hintText: "Add markdown note at position...",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _addNewNoteAtCurrentTime(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.mint, size: 28),
              onPressed: _addNewNoteAtCurrentTime,
            )
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _notes.isEmpty
              ? Center(child: Text("No timestamp notes taken yet.\nType a note and hit enter to attach.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12.0, height: 1.4)))
              : ListView.builder(
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return Card(
                      color: AppColors.panel,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.stroke)),
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        dense: true,
                        leading: ActionChip(
                          label: Text(_formatDuration(note.timestamp), style: const TextStyle(fontFamily: "monospace", fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.mint)),
                          backgroundColor: AppColors.mint.withOpacity(0.1),
                          onPressed: () => _jumpToTimestamp(note.timestamp),
                        ),
                        title: Text(note.content, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                        subtitle: Text("Created at ${_formatDateTime(note.createdAt)}", style: const TextStyle(color: Colors.white24, fontSize: 9.5)),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _deleteNote(note.noteId)),
                      ),
                    );
                  },
                ),
        )
      ],
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_summaryText.isEmpty && !_generatingSummary)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  const Icon(Icons.psychology_rounded, size: 48, color: AppColors.cyan),
                  const SizedBox(height: 12),
                  const Text("ON-DEVICE AI SUMMARIZATION", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0)),
                  const SizedBox(height: 6),
                  Text("Generate study summaries and key points entirely offline using local AI models.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12.0, height: 1.4)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                    onPressed: _generateAISummary,
                    icon: const Icon(Icons.bolt_rounded, color: Colors.black),
                    label: const Text("GENERATE COGNITIVE SUMMARY", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            )
          else if (_generatingSummary)
            const Center(
              child: Column(
                children: [
                  SizedBox(height: 40),
                  CircularProgressIndicator(color: AppColors.cyan),
                  SizedBox(height: 16),
                  Text("Gemini Nano compiling offline summary...", style: TextStyle(color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.stroke)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.description, color: AppColors.cyan, size: 20), SizedBox(width: 8), Text("OFFLINE EXECUTIVE SUMMARY", style: TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 11.5))]),
                  const Divider(color: Colors.white12, height: 20),
                  Text(_summaryText, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.45)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.stroke)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.auto_awesome, color: AppColors.mint, size: 20), SizedBox(width: 8), Text("AI EXTRACTED KEY POINTS", style: TextStyle(color: AppColors.mint, fontWeight: FontWeight.bold, fontSize: 11.5))]),
                  const Divider(color: Colors.white12, height: 20),
                  ..._keyPoints.map((point) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("• ", style: TextStyle(color: AppColors.mint, fontWeight: FontWeight.bold, fontSize: 16)),
                            Expanded(child: Text(point, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4))),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ]
        ],
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

  String _formatDateTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
