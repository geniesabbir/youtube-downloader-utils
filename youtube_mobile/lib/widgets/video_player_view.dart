import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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
import 'unified_player.dart';

class VideoPlayerView extends StatefulWidget {
  final VideoJob job;
  const VideoPlayerView({super.key, required this.job});

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> with TickerProviderStateMixin {
  late VideoJob _currentJob;
  StreamSubscription<PlaybackState>? _playbackStateSubscription;
  late VideoPlayerController _controller;
  bool _initialized = false;
  
  Timer? _progressTimer;

  // Workspace Study States
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
    _currentJob = widget.job;
    _tabController = TabController(length: 4, vsync: this);
    
    // Initialize Workspace Data
    _loadJobWorkspaceData();

    if (!_currentJob.isAudio) {
      if (_playback.activeJob?.jobId != _currentJob.jobId) {
        _playback.play(_currentJob).then((_) {
          if (mounted) {
            _initializeController();
          }
        });
      } else {
        _initializeController();
      }
    } else {
      if (_playback.activeJob?.jobId != _currentJob.jobId) {
        _playback.play(_currentJob);
      }
    }

    _playbackStateSubscription = _playback.stateStream.listen((state) {
      if (!mounted) return;
      
      final active = _playback.activeJob;
      if (active == null) {
        Navigator.of(context).pop();
        return;
      }
      
      if (active.jobId != _currentJob.jobId) {
        setState(() {
          _currentJob = active;
          _initialized = false;
        });
        _loadJobWorkspaceData();
        if (!_currentJob.isAudio) {
          _initializeController();
        }
      }
    });
  }

  void _initializeController() {
    if (_initialized) {
      try {
        _controller.removeListener(_onControllerUpdate);
      } catch (_) {}
      _initialized = false;
    }
    if (_playback.videoController != null) {
      _controller = _playback.videoController!;
      _controller.addListener(_onControllerUpdate);
      setState(() {
        _initialized = true;
      });
      _startProgressSaving();
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
    if (_currentJob.isAudio) return;
    if (!_initialized) return;
    
    final pos = _controller.value.position;
    final dur = _controller.value.duration;
    if (dur.inSeconds > 0) {
      final watchedPercent = (pos.inSeconds / dur.inSeconds).clamp(0.0, 1.0);
      EventBus().fire(
        PlaybackProgressEvent(
          jobId: _currentJob.jobId,
          position: pos,
          duration: dur,
          watchedPercent: watchedPercent,
        ),
      );
    }
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

    final segs = await _transcriptService.getTranscript(_currentJob);
    final loadedNotes = await _loadPersistedNotes(_currentJob.jobId);

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
    await prefs.setString('library_notes_${_currentJob.jobId}', raw);
  }

  void _generateAISummary() async {
    setState(() {
      _generatingSummary = true;
    });

    final summary = await _aiService.summarize(_segments, _currentJob.title);
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

    final currentPos = _currentJob.isAudio 
        ? _playback.position 
        : (_initialized ? _controller.value.position : Duration.zero);

    final newNote = MediaNote(
      noteId: DateTime.now().millisecondsSinceEpoch.toString(),
      jobId: _currentJob.jobId,
      timestamp: currentPos,
      content: text,
      createdAt: DateTime.now(),
    );

    _saveNote(newNote);
    _noteInputController.clear();
    FocusScope.of(context).unfocus();
  }

  void _jumpToTimestamp(Duration timestamp) {
    if (!_currentJob.isAudio && _initialized) {
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
    _playbackStateSubscription?.cancel();
    
    if (!_currentJob.isAudio) {
      _saveProgress();
      if (_initialized) {
        try {
          _controller.removeListener(_onControllerUpdate);
        } catch (_) {}
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
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white70),
          title: Text(
            _currentJob.isAudio ? "OFFLINE STUDY AUDIO" : "OFFLINE STUDY LECTURE",
            style: const TextStyle(color: AppColors.cyan, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // ── 1. Top Pinned Media Player Block ─────────────────────────────
            _buildPlayerBlock(),

            // ── 2. Coordinated Scrolling Detail & Workspace Area ─────────────
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                  return <Widget>[
                    // Details Header
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailsHeader(),
                          const Divider(color: Colors.white10, height: 1, thickness: 1),
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
                        ],
                      ),
                    ),
                    // Pinned Tab Bar
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverTabBarDelegate(
                        child: _buildTabBarSelectors(),
                      ),
                    ),
                  ];
                },
                body: Padding(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerBlock() {
    if (_currentJob.isAudio) {
      return SizedBox(
        height: 350.0,
        child: UnifiedPlayer(
          job: _currentJob,
          variant: PlayerVariant.full,
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: UnifiedPlayer(
        job: _currentJob,
        variant: PlayerVariant.full,
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
            _currentJob.title,
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
                "Offline study • ${_currentJob.fileSizeDisplay} • ",
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
                    final isFav = _currentJob.isFavorited;
                    return InkWell(
                      onTap: () async {
                        _currentJob.isFavorited = !_currentJob.isFavorited;
                        final downloadService = DownloadService();
                        await downloadService.updateJobStateDirectly(_currentJob.jobId, _currentJob);
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







  void _showClipExtractorBottomSheet() {
    final currentPos = _currentJob.isAudio 
        ? _playback.position 
        : (_initialized ? _controller.value.position : Duration.zero);
    
    // Default duration to 30 seconds
    final maxDur = _currentJob.isAudio
        ? const Duration(minutes: 60) // Simple limit for audio
        : (_initialized ? _controller.value.duration : const Duration(minutes: 60));
    
    Duration startTime = currentPos;
    Duration endTime = currentPos + const Duration(seconds: 30);
    if (endTime > maxDur) {
      endTime = maxDur;
    }
    
    bool audioOnly = _currentJob.isAudio;
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
                    
                    if (!_currentJob.isAudio) ...[
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
                            job: _currentJob,
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
    return _InteractiveTranscriptView(
      segments: _segments,
      playback: _playback,
      onJumpToTimestamp: _jumpToTimestamp,
      onExportPressed: _showTranscriptExportBottomSheet,
      formatDuration: _formatDuration,
    );
  }

  void _showTranscriptExportBottomSheet() {
    bool includeTimestamps = true;
    String selectedFormat = 'MARKDOWN';
    bool exporting = false;

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
            final isMediaFormat = selectedFormat == 'SUBRIP' || selectedFormat == 'JSON';
            return Container(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "📂 TRANSCRIPT EXPORT & SHARE HUB",
                    style: TextStyle(
                      color: AppColors.cyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.0,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Format, copy, or export the active interactive lecture timeline for student note-taking.",
                    style: TextStyle(color: Colors.white54, fontSize: 11.5),
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  
                  const Text(
                    "SELECT FORMAT",
                    style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 10),
                  
                  Row(
                    children: [
                      _buildFormatCard(
                        title: "Markdown",
                        ext: ".md",
                        isSelected: selectedFormat == 'MARKDOWN',
                        onTap: () => setSheetState(() => selectedFormat = 'MARKDOWN'),
                      ),
                      const SizedBox(width: 8),
                      _buildFormatCard(
                        title: "Plain Text",
                        ext: ".txt",
                        isSelected: selectedFormat == 'TEXT',
                        onTap: () => setSheetState(() => selectedFormat = 'TEXT'),
                      ),
                      const SizedBox(width: 8),
                      _buildFormatCard(
                        title: "Subtitle",
                        ext: ".srt",
                        isSelected: selectedFormat == 'SUBRIP',
                        onTap: () => setSheetState(() => selectedFormat = 'SUBRIP'),
                      ),
                      const SizedBox(width: 8),
                      _buildFormatCard(
                        title: "JSON Data",
                        ext: ".json",
                        isSelected: selectedFormat == 'JSON',
                        onTap: () => setSheetState(() => selectedFormat = 'JSON'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (!isMediaFormat) ...[
                    Row(
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Include Timestamps", style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text("Prepend [MM:SS] to segment text", style: TextStyle(color: Colors.white38, fontSize: 10.5)),
                          ],
                        ),
                        const Spacer(),
                        Switch(
                          value: includeTimestamps,
                          activeColor: AppColors.cyan,
                          onChanged: (val) {
                            setSheetState(() {
                              includeTimestamps = val;
                            });
                          },
                        )
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 20),
                  ],

                  if (exporting) ...[
                    const Center(
                      child: Column(
                        children: [
                          SizedBox(height: 10),
                          CircularProgressIndicator(color: AppColors.mint),
                          SizedBox(height: 12),
                          Text("Compiling export files...", style: TextStyle(color: AppColors.mint, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.panel,
                              side: const BorderSide(color: AppColors.stroke),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              final text = _generateFormattedTranscript(
                                includeTimestamps: includeTimestamps,
                                format: selectedFormat,
                              );
                              await Clipboard.setData(ClipboardData(text: text));
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Transcript copied to clipboard!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                                  backgroundColor: AppColors.mint,
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                            label: const Text("COPY TEXT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.cyan,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              setSheetState(() => exporting = true);
                              try {
                                final text = _generateFormattedTranscript(
                                  includeTimestamps: includeTimestamps,
                                  format: selectedFormat,
                                );
                                final ext = selectedFormat == 'MARKDOWN' ? 'md' : (selectedFormat == 'TEXT' ? 'txt' : (selectedFormat == 'SUBRIP' ? 'srt' : 'json'));
                                
                                final cleanTitle = _currentJob.title.replaceAll(RegExp(r'[^\w\s\-\.]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
                                final fileName = 'transcript_${cleanTitle}_${DateTime.now().millisecondsSinceEpoch}.$ext';
                                
                                final directory = await getApplicationDocumentsDirectory();
                                final transcriptsDir = Directory('${directory.path}/Transcripts');
                                if (!await transcriptsDir.exists()) {
                                  await transcriptsDir.create(recursive: true);
                                }
                                final file = File('${transcriptsDir.path}/$fileName');
                                await file.writeAsString(text);
                                
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Exported to Documents/Transcripts/$fileName", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    backgroundColor: AppColors.cyan,
                                    duration: const Duration(seconds: 4),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } catch (e) {
                                setSheetState(() => exporting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Failed to export: $e", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.save_alt_rounded, color: Colors.black, size: 18),
                            label: const Text("EXPORT FILE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ),
                      ],
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

  Widget _buildFormatCard({
    required String title,
    required String ext,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.cyan.withOpacity(0.08) : AppColors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.cyan : AppColors.stroke,
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                ext,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? AppColors.cyan : Colors.white30,
                  fontSize: 9.5,
                  fontFamily: "monospace",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _generateFormattedTranscript({required bool includeTimestamps, required String format}) {
    final buffer = StringBuffer();
    if (format == 'JSON') {
      final List<Map<String, dynamic>> jsonList = _segments.map((seg) {
        return {
          'start_seconds': seg.start.inSeconds,
          'start_display': _formatDuration(seg.start),
          'end_seconds': seg.end.inSeconds,
          'end_display': _formatDuration(seg.end),
          'text': seg.text,
        };
      }).toList();
      return const JsonEncoder.withIndent('  ').convert(jsonList);
    }

    if (format == 'SUBRIP') {
      for (int i = 0; i < _segments.length; i++) {
        final seg = _segments[i];
        buffer.writeln('${i + 1}');
        buffer.writeln('${_formatSrtTimestamp(seg.start)} --> ${_formatSrtTimestamp(seg.end)}');
        buffer.writeln(seg.text);
        buffer.writeln();
      }
      return buffer.toString();
    }

    for (final seg in _segments) {
      if (includeTimestamps) {
        if (format == 'MARKDOWN') {
          buffer.writeln('**[${_formatDuration(seg.start)}]** ${seg.text}\n');
        } else {
          buffer.writeln('[${_formatDuration(seg.start)}] ${seg.text}');
        }
      } else {
        if (format == 'MARKDOWN') {
          buffer.writeln('${seg.text}\n');
        } else {
          buffer.writeln(seg.text);
        }
      }
    }
    return buffer.toString();
  }

  String _formatSrtTimestamp(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds = duration.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$milliseconds';
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
    final currentTimeStr = _currentJob.isAudio 
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

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverTabBarDelegate({required this.child});

  @override
  double get minExtent => 72.0;

  @override
  double get maxExtent => 72.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xff090c10), // solid background matching details header
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _InteractiveTranscriptView extends StatefulWidget {
  final List<TranscriptSegment> segments;
  final PlaybackService playback;
  final Function(Duration) onJumpToTimestamp;
  final VoidCallback onExportPressed;
  final String Function(Duration) formatDuration;

  const _InteractiveTranscriptView({
    required this.segments,
    required this.playback,
    required this.onJumpToTimestamp,
    required this.onExportPressed,
    required this.formatDuration,
  });

  @override
  State<_InteractiveTranscriptView> createState() => _InteractiveTranscriptViewState();
}

class _InteractiveTranscriptViewState extends State<_InteractiveTranscriptView> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Duration>? _positionSubscription;
  int _activeIndex = -1;
  bool _autoScrollEnabled = true;
  List<GlobalKey> _itemKeys = [];

  @override
  void initState() {
    super.initState();
    _itemKeys = List.generate(widget.segments.length, (_) => GlobalKey());
    _positionSubscription = widget.playback.positionStream.listen((currentPos) {
      if (!mounted) return;
      
      int newActiveIndex = -1;
      for (int i = 0; i < widget.segments.length; i++) {
        final seg = widget.segments[i];
        if (currentPos >= seg.start && currentPos <= seg.end) {
          newActiveIndex = i;
          break;
        }
      }

      if (newActiveIndex != _activeIndex) {
        setState(() {
          _activeIndex = newActiveIndex;
        });

        if (_autoScrollEnabled && newActiveIndex != -1 && newActiveIndex < _itemKeys.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final key = _itemKeys[newActiveIndex];
            final context = key.currentContext;
            if (context != null) {
              final renderObject = context.findRenderObject();
              if (renderObject != null && _scrollController.hasClients) {
                _scrollController.position.ensureVisible(
                  renderObject,
                  duration: const Duration(milliseconds: 350),
                  alignment: 0.5, // Centers the item exactly in the transcript list
                  curve: Curves.easeInOutCubic,
                );
              }
            }
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _InteractiveTranscriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.segments.length != oldWidget.segments.length) {
      _itemKeys = List.generate(widget.segments.length, (_) => GlobalKey());
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Tools Bar: Interactive Timeline Header & Export options
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
          child: Row(
            children: [
              const Icon(Icons.analytics_outlined, color: AppColors.cyan, size: 14),
              const SizedBox(width: 6),
              Text(
                "TIMELINE",
                style: TextStyle(color: AppColors.cyan.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const Spacer(),
              // Auto-Scroll Sync Toggle with state styling
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: _autoScrollEnabled ? AppColors.mint : AppColors.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  _autoScrollEnabled ? Icons.sync_rounded : Icons.sync_disabled_rounded,
                  size: 13,
                ),
                label: const Text(
                  "SYNC",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  setState(() {
                    _autoScrollEnabled = !_autoScrollEnabled;
                  });
                },
              ),
              const SizedBox(width: 8),
              // Export Hub Button
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.mint,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.share_rounded, size: 13),
                label: const Text("EXPORT", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                onPressed: widget.onExportPressed,
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1, thickness: 1),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            cacheExtent: 9999.0, // Keeps all GlobalKeys built so context is always available
            itemCount: widget.segments.length,
            itemBuilder: (context, index) {
              final seg = widget.segments[index];
              final isActive = _activeIndex == index;

              return AnimatedContainer(
                key: _itemKeys[index], // Key assigned here!
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                margin: const EdgeInsets.symmetric(vertical: 2.0),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.panelAlt.withOpacity(0.4) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isActive
                      ? const Border(left: BorderSide(color: AppColors.mint, width: 3.0))
                      : const Border(left: BorderSide(color: Colors.transparent, width: 3.0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => widget.onJumpToTimestamp(seg.start),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.mint.withOpacity(0.2) : AppColors.cyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isActive ? AppColors.mint.withOpacity(0.5) : AppColors.cyan.withOpacity(0.25)),
                        ),
                        child: Text(
                          widget.formatDuration(seg.start),
                          style: TextStyle(
                            color: isActive ? AppColors.mint : AppColors.cyan,
                            fontSize: 10.5,
                            fontFamily: "monospace",
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        seg.text,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white70,
                          fontSize: isActive ? 13.5 : 13,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


