import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_job.dart';
import '../models/transcript.dart';
import '../models/note.dart';
import '../services/download_service.dart';
import '../services/playback_service.dart';
import '../services/transcript_service.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

class WorkspaceView extends StatefulWidget {
  const WorkspaceView({super.key});

  @override
  State<WorkspaceView> createState() => _WorkspaceViewState();
}

class _WorkspaceViewState extends State<WorkspaceView> with TickerProviderStateMixin {
  final DownloadService _download = DownloadService();
  final PlaybackService _playback = PlaybackService();
  final TranscriptService _transcriptService = TranscriptService();
  final AiService _aiService = AiService();

  VideoJob? _selectedJob;
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
    
    // Auto-select active playback job if there is one
    if (_playback.activeJob != null) {
      _selectedJob = _playback.activeJob;
      _loadJobWorkspaceData();
    } else {
      final completed = _download.queue.where((j) => j.localPath != null).toList();
      if (completed.isNotEmpty) {
        _selectedJob = completed.first;
        _loadJobWorkspaceData();
      }
    }
  }

  void _loadJobWorkspaceData() async {
    final job = _selectedJob;
    if (job == null) return;

    setState(() {
      _loadingTranscript = true;
      _summaryText = "";
      _keyPoints = [];
      _segments = [];
      _searchResults = [];
      _notes = [];
    });

    // 1. Fetch transcript segments
    final segs = await _transcriptService.getTranscript(job);
    
    // 2. Fetch persisted notes
    final loadedNotes = await _loadPersistedNotes(job.jobId);

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
    await prefs.setString('library_notes_${_selectedJob!.jobId}', raw);
  }

  void _generateAISummary() async {
    if (_selectedJob == null) return;
    setState(() {
      _generatingSummary = true;
    });

    final summary = await _aiService.summarize(_segments, _selectedJob!.title);
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
    final job = _selectedJob;
    if (job == null) return;
    final text = _noteInputController.text.trim();
    if (text.isEmpty) return;

    // Get current playback position if it's the active playing track, otherwise default to 00:00
    final currentPos = (_playback.activeJob?.jobId == job.jobId) ? _playback.position : Duration.zero;

    final newNote = MediaNote(
      noteId: DateTime.now().millisecondsSinceEpoch.toString(),
      jobId: job.jobId,
      timestamp: currentPos,
      content: text,
      createdAt: DateTime.now(),
    );

    _saveNote(newNote);
    _noteInputController.clear();
    FocusScope.of(context).unfocus();
  }

  void _jumpToTimestamp(Duration timestamp) {
    final job = _selectedJob;
    if (job == null) return;

    // Tapping a timestamp jumps the playback controller position immediately!
    if (_playback.activeJob?.jobId == job.jobId) {
      _playback.seek(timestamp);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Jumped to timestamp ${_formatDuration(timestamp)}", style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.cyan,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Prompt user to play track first
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Play '${job.title}' to enable dynamic seeks.", style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.amber,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: "PLAY",
            textColor: Colors.black,
            onPressed: () => _playback.play(job),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedJobs = _download.queue.where((j) => j.localPath != null).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header dropdown row
          Row(
            children: [
              const Text(
                "INTELLIGENT WORKSPACE",
                style: TextStyle(
                  color: AppColors.cyan,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 12),
              if (completedJobs.isNotEmpty)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: DropdownButton<VideoJob>(
                      value: _selectedJob,
                      isExpanded: true, // Dynamically fills remaining horizontal space
                      dropdownColor: const Color(0xff0b0f17),
                      style: const TextStyle(color: AppColors.mint, fontSize: 12, fontWeight: FontWeight.bold),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.mint),
                      onChanged: (VideoJob? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedJob = newValue;
                            _loadJobWorkspaceData();
                          });
                        }
                      },
                      items: completedJobs.map<DropdownMenuItem<VideoJob>>((VideoJob value) {
                        return DropdownMenuItem<VideoJob>(
                          value: value,
                          child: Text(
                            value.title, 
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (completedJobs.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.terminal_rounded, size: 48, color: Colors.white24),
                    const SizedBox(height: 12),
                    Text(
                      "No completed offline downloads available.\nFinish a download in your Queue to open Workspace.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13.0, height: 1.5),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Tab Selector Row
            Container(
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.stroke),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.mint,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.muted,
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: "Transcript"),
                  Tab(text: "Search"),
                  Tab(text: "Notes"),
                  Tab(text: "AI Summary"),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Main Tab Views
            Expanded(
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
            const SizedBox(height: 60), // absolute player padding
          ]
        ],
      ),
    );
  }

  // --- Tab 1: Scrollable Transcripts ---
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
              // Timestamp clickable link
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
                    style: const TextStyle(
                      color: AppColors.cyan,
                      fontSize: 10.5,
                      fontFamily: "monospace",
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Segment text content
              Expanded(
                child: Text(
                  seg.text,
                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Tab 2: Keyword Semantic/Interactive Search ---
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
                          title: Text(
                            match.text,
                            style: const TextStyle(color: Colors.white, fontSize: 12.5),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // --- Tab 3: Markdown Timestamp Notes ---
  Widget _buildNotesTab() {
    final activePlaying = _playback.activeJob?.jobId == _selectedJob?.jobId;
    final currentTimeStr = activePlaying ? _formatDuration(_playback.position) : "00:00";

    return Column(
      children: [
        // Note Input Form
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
                    hintText: "Add note at current playback...",
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

        // Notes List
        Expanded(
          child: _notes.isEmpty
              ? Center(
                  child: Text(
                    "No timestamp notes taken yet.\nType a note and hit enter to attach to second.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12.0, height: 1.4),
                  ),
                )
              : ListView.builder(
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return Card(
                      color: AppColors.panel,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.stroke),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        dense: true,
                        leading: ActionChip(
                          label: Text(_formatDuration(note.timestamp), style: const TextStyle(fontFamily: "monospace", fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.mint)),
                          backgroundColor: AppColors.mint.withOpacity(0.1),
                          onPressed: () => _jumpToTimestamp(note.timestamp),
                        ),
                        title: Text(
                          note.content,
                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Created at ${_formatDateTime(note.createdAt)}",
                          style: const TextStyle(color: Colors.white24, fontSize: 9.5),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          onPressed: () => _deleteNote(note.noteId),
                        ),
                      ),
                    );
                  },
                ),
        )
      ],
    );
  }

  // --- Tab 4: On-Device Gemini summaries ---
  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_summaryText.isEmpty && !_generatingSummary)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const Icon(Icons.psychology_rounded, size: 48, color: AppColors.cyan),
                  const SizedBox(height: 12),
                  const Text(
                    "ON-DEVICE AI COGNITIVE SUMMARIZATION",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Generate offline transcripts summaries and key points maps entirely locally using Gemini Nano (AICore) on-device.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12.0, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
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
                  SizedBox(height: 60),
                  CircularProgressIndicator(color: AppColors.cyan),
                  SizedBox(height: 16),
                  Text("Gemini Nano compiling offline summary...", style: TextStyle(color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else ...[
            // Summarized Output Panel
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.description, color: AppColors.cyan, size: 20),
                      SizedBox(width: 8),
                      Text("OFFLINE EXECUTIVE SUMMARY", style: TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 11.5)),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  Text(
                    _summaryText,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Key Points Panel
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.auto_awesome, color: AppColors.mint, size: 20),
                      SizedBox(width: 8),
                      Text("AI EXTRACTED KEY POINTS", style: TextStyle(color: AppColors.mint, fontWeight: FontWeight.bold, fontSize: 11.5)),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  ..._keyPoints.map((point) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("• ", style: TextStyle(color: AppColors.mint, fontWeight: FontWeight.bold, fontSize: 16)),
                            Expanded(
                              child: Text(
                                point,
                                style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
                              ),
                            ),
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
