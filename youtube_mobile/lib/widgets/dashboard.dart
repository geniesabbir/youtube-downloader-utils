import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_job.dart';
import '../services/download_service.dart';
import '../services/playback_service.dart';
import '../theme/app_theme.dart';
import '../core/events/event_bus.dart';
import 'brand_mark.dart';
import 'video_card.dart';
import 'player_overlay.dart';
import 'continue_watching_row.dart';
import 'library_view.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  late TabController _libraryTabController;
  final TextEditingController _urlInputController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final DownloadService _downloadService = DownloadService();

  int _currentBottomNavIndex = 0;
  bool _isAudioOnly = false;
  bool _isResolvingPlaylist = false;
  String _searchQuery = "";
  List<String> _stagedUrls = const [];
  StreamSubscription? _warningSub;
  StreamSubscription? _playMediaInWorkspaceSub;
  bool _workspacePlaybackMode = false;

  @override
  void initState() {
    super.initState();
    _libraryTabController = TabController(length: 2, vsync: this);
    _loadSettings();

    // Listen to background service warnings and display high-fidelity floating warning toast
    _warningSub = _downloadService.warningStream.listen((message) {
      if (mounted) {
        _showPremiumWarningToast(message);
      }
    });

    // Listen to workspace play routing triggers
    _playMediaInWorkspaceSub = EventBus().on<PlayMediaInWorkspaceEvent>().listen((event) {
      if (mounted) {
        setState(() {
          _currentBottomNavIndex = 3; // Switch to Workspace tab
        });
      }
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _workspacePlaybackMode = prefs.getBool('prefs_workspace_playback_mode') ?? false;
      });
    }
  }

  void _showPremiumWarningToast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 6),
        margin: const EdgeInsets.only(
          bottom: 120, // float gracefully above player overlay + bottom nav
          left: 16,
          right: 16,
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          decoration: BoxDecoration(
            color: const Color(0xff1c1410).withOpacity(0.95), // deep warm spatial charcoal
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.amber.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "NETWORK FILTER ENCOUNTERED",
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _warningSub?.cancel();
    _playMediaInWorkspaceSub?.cancel();
    _libraryTabController.dispose();
    _urlInputController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _reviewBatch() async {
    final rawText = _urlInputController.text.trim();
    final stagedRaw = _downloadService.extractSupportedUrls(rawText);
    if (stagedRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste at least one valid YouTube URL to build a batch.'),
        ),
      );
      return;
    }

    // Check if any URL is a playlist
    final hasPlaylist = stagedRaw.any((url) => _downloadService.isPlaylistUrl(url));
    if (hasPlaylist) {
      setState(() {
        _isResolvingPlaylist = true;
      });

      final resolved = <String>[];
      try {
        for (final url in stagedRaw) {
          if (_downloadService.isPlaylistUrl(url)) {
            final playlistVideos = await _downloadService.resolvePlaylist(url);
            resolved.addAll(playlistVideos);
          } else {
            resolved.add(url);
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _stagedUrls = resolved.toSet().toList(); // Deduplicate
        _isResolvingPlaylist = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playlist resolved! Found ${resolved.length} videos.'),
        ),
      );
    } else {
      setState(() {
        _stagedUrls = stagedRaw;
      });
    }
    FocusScope.of(context).unfocus();
  }

  Future<void> _startBatch() async {
    if (_stagedUrls.isEmpty) return;
    final insertedCount = await _downloadService.addJobs(
      _stagedUrls,
      isAudio: _isAudioOnly,
    );
    if (!mounted) return;
    if (insertedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No queueable videos were found in that batch.'),
        ),
      );
      return;
    }
    setState(() {
      _stagedUrls = const [];
      _urlInputController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          insertedCount == 1
              ? '1 item added to the queue.'
              : '$insertedCount items added to the queue.',
        ),
      ),
    );
    FocusScope.of(context).unfocus();
  }

  void _clearBatch() {
    setState(() {
      _stagedUrls = const [];
    });
  }

  void _removeStagedUrl(String url) {
    setState(() {
      _stagedUrls = _stagedUrls
          .where((item) => item != url)
          .toList(growable: false);
    });
  }

  Future<void> _updateConcurrentDownloads(int value) async {
    await _downloadService.setMaxConcurrentDownloads(value);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _rescanLibrary() async {
    await _downloadService.rescanStorage();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Library scan finished.')));
  }

  @override
  Widget build(BuildContext context) {
    return BrandBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              IndexedStack(
                index: _currentBottomNavIndex,
                children: [
                  _buildHomeTab(),
                  _buildQueueTab(),
                  _buildLibraryTab(),
                  _buildSettingsTab(),
                ],
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: PlayerOverlay(),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xff080b0e).withOpacity(0.95),
        border: const Border(
          top: BorderSide(color: AppColors.stroke, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_filled, "Home"),
            _buildNavItem(1, Icons.download_rounded, "Queue"),
            _buildNavItem(2, Icons.library_books_rounded, "Library"),
            _buildNavItem(3, Icons.settings_rounded, "Settings"),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool active = _currentBottomNavIndex == index;
    final color = active ? AppColors.mint : AppColors.muted;

    return InkWell(
      onTap: () {
        setState(() {
          _currentBottomNavIndex = index;
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: active ? AppColors.mint.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return StreamBuilder<List<VideoJob>>(
      stream: _downloadService.queueStream,
      builder: (context, snapshot) {
        final queue = snapshot.data ?? _downloadService.queue;

        // Fetch Continue Watching jobs
        final continueWatching = queue
            .where((j) => j.localPath != null && j.watchedPercent > 0.0 && j.watchedPercent < 0.95)
            .toList();
        continueWatching.sort((a, b) => (b.lastWatchedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.lastWatchedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

        // Fetch recent downloads (last 3 completed)
        final completed = queue.where((j) => j.localPath != null).toList();
        completed.sort((a, b) => (b.lastWatchedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.lastWatchedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
        final recentDownloads = completed.take(3).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: [
            // Welcome Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.mint.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.mint.withOpacity(0.2)),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.mint,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "WELCOME BACK",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Workspace User",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Capture Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "QUICK CAPTURE",
                      style: TextStyle(
                        color: AppColors.cyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _urlInputController,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      maxLines: 1,
                      decoration: InputDecoration(
                        hintText: "Paste single video or playlist YouTube URL...",
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.25),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.download_rounded, color: AppColors.mint),
                          onPressed: () {
                            final text = _urlInputController.text.trim();
                            if (text.isNotEmpty) {
                              _downloadService.addJob(text, isAudio: _isAudioOnly);
                              _urlInputController.clear();
                              FocusScope.of(context).unfocus();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Staged in Queue tab for analysis.')),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Continue Watching shelf
            if (continueWatching.isNotEmpty) ...[
              ContinueWatchingRow(inProgressJobs: continueWatching),
              const SizedBox(height: 24),
            ],

            // Storage insights
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildStorageUsageBar(queue),
            ),
            const SizedBox(height: 24),

            // Recent Downloads
            if (recentDownloads.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "RECENT OFFLINE DOWNLOADS",
                  style: TextStyle(
                    color: AppColors.mint,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentDownloads.length,
                    separatorBuilder: (c, i) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final job = recentDownloads[index];
                      return ListTile(
                        dense: true,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 50,
                            height: 30,
                            child: job.thumbnailUrl != null && job.thumbnailUrl!.isNotEmpty
                                ? Image.network(job.thumbnailUrl!, fit: BoxFit.cover)
                                : const Icon(Icons.movie, color: Colors.white24),
                          ),
                        ),
                        title: Text(
                          job.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          job.author,
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                        ),
                        trailing: Icon(
                          job.isAudio ? Icons.music_note_outlined : Icons.movie_creation_outlined,
                          color: job.isAudio ? AppColors.mint : AppColors.cyan,
                          size: 16,
                        ),
                        onTap: () {
                          PlaybackService().play(job);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 80), // padding from absolute floating player
          ],
        );
      },
    );
  }

  Widget _buildStorageUsageBar(List<VideoJob> queue) {
    final completed = queue.where((j) => j.localPath != null).toList();
    final totalBytes = completed.fold<int>(0, (sum, j) => sum + (j.fileSizeBytes ?? 0));
    final audioBytes = completed.where((j) => j.isAudio).fold<int>(0, (sum, j) => sum + (j.fileSizeBytes ?? 0));
    final videoBytes = completed.where((j) => !j.isAudio).fold<int>(0, (sum, j) => sum + (j.fileSizeBytes ?? 0));

    final totalDisplay = _formatBytes(totalBytes);
    final audioDisplay = _formatBytes(audioBytes);
    final videoDisplay = _formatBytes(videoBytes);

    final double audioRatio = totalBytes > 0 ? audioBytes / totalBytes : 0.0;
    final double videoRatio = totalBytes > 0 ? videoBytes / totalBytes : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "STORAGE INSIGHTS",
                style: TextStyle(
                  color: AppColors.cyan,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                "$totalDisplay Used",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Dual progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              color: Colors.white10,
              child: Row(
                children: [
                  if (audioRatio > 0)
                    Expanded(
                      flex: (audioRatio * 100).toInt(),
                      child: Container(color: AppColors.mint),
                    ),
                  if (videoRatio > 0)
                    Expanded(
                      flex: (videoRatio * 100).toInt(),
                      child: Container(color: AppColors.cyan),
                    ),
                  if (totalBytes == 0)
                    Expanded(
                      child: Container(color: Colors.transparent),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text("Audio: $audioDisplay", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              const SizedBox(width: 16),
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.cyan, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text("Video: $videoDisplay", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "CONSTRAINTS & RULES",
            style: TextStyle(
              color: AppColors.cyan,
              fontWeight: FontWeight.w800,
              fontSize: 12.0,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Column(
              children: [
                _buildSettingsToggleRow(
                  title: "Wi-Fi Only Mode",
                  subtitle: "Auto-pauses when switching to cellular data",
                  value: _downloadService.wifiOnly,
                  onChanged: (val) async {
                    await _downloadService.setWifiOnly(val);
                    setState(() {});
                  },
                ),
                const Divider(color: Colors.white10, height: 28),
                _buildSettingsToggleRow(
                  title: "Power Saver Mode",
                  subtitle: "Halts active queues when battery drops below 15%",
                  value: _downloadService.powerSaver,
                  onChanged: (val) async {
                    await _downloadService.setPowerSaver(val);
                    setState(() {});
                  },
                ),
                const Divider(color: Colors.white10, height: 28),
                _buildSettingsStepperRow(
                  title: "Concurrent Downloads",
                  subtitle: "Throttles total parallel downloads to maintain speed stability.",
                  setModalState: (fn) {
                    setState(fn);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "SYSTEM AUTOMATION RULES",
            style: TextStyle(
              color: AppColors.mint,
              fontWeight: FontWeight.w800,
              fontSize: 12.0,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Subscriptions Rule Polling Monitor",
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Scans subscribed channels in the background and auto-queues new uploads on Wi-Fi connection.",
                  style: TextStyle(color: Colors.blueGrey, fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Subscription rules polling triggered...", style: TextStyle(fontWeight: FontWeight.bold))),
                    );
                  },
                  icon: const Icon(Icons.sync_rounded, color: Colors.black, size: 18),
                  label: const Text("FORCE POLL CHANNELS NOW", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Center(
            child: Text(
              "YT Utils • Local-first media utility v1.0.0",
              style: TextStyle(
                color: Colors.white.withOpacity(0.15),
                fontSize: 10.5,
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff0b0f17),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "CONSTRAINTS & RULES",
                    style: TextStyle(
                      color: AppColors.cyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.0,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSettingsToggleRow(
                    title: "Wi-Fi Only Mode",
                    subtitle: "Auto-pauses when switching to cellular",
                    value: _downloadService.wifiOnly,
                    onChanged: (val) async {
                      await _downloadService.setWifiOnly(val);
                      setModalState(() {});
                      setState(() {});
                    },
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  _buildSettingsToggleRow(
                    title: "Workspace Playback Mode",
                    subtitle: "Automatically play and study inside the Workspace tab",
                    value: _workspacePlaybackMode,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('prefs_workspace_playback_mode', val);
                      setModalState(() {
                        _workspacePlaybackMode = val;
                      });
                      setState(() {
                        _workspacePlaybackMode = val;
                      });
                    },
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  _buildSettingsToggleRow(
                    title: "Power Saver Mode",
                    subtitle: "Halts active queues when battery is below 15%",
                    value: _downloadService.powerSaver,
                    onChanged: (val) async {
                      await _downloadService.setPowerSaver(val);
                      setModalState(() {});
                      setState(() {});
                    },
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  _buildSettingsStepperRow(
                    title: "Concurrent Downloads",
                    subtitle: "Default is 3 to balance speed and stability.",
                    setModalState: setModalState,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      "YT Utils • Local-first media utility v1.0.0",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            activeColor: const Color(0xff00ff88),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsStepperRow({
    required String title,
    required String subtitle,
    required StateSetter setModalState,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _downloadService.maxConcurrentDownloads > 1
                      ? () async {
                          await _updateConcurrentDownloads(_downloadService.maxConcurrentDownloads - 1);
                          setModalState(() {});
                        }
                      : null,
                  icon: const Icon(Icons.remove, size: 18),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    _downloadService.maxConcurrentDownloads.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _downloadService.maxConcurrentDownloads < 5
                      ? () async {
                          await _updateConcurrentDownloads(_downloadService.maxConcurrentDownloads + 1);
                          setModalState(() {});
                        }
                      : null,
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueTab() {
    return StreamBuilder<List<VideoJob>>(
      stream: _downloadService.queueStream,
      builder: (context, snapshot) {
        final queue = snapshot.data ?? _downloadService.queue;
        final activeJobs = queue.where((j) => j.localPath == null).toList();
        final activeDownloads = activeJobs.where((j) => j.downloading).length;
        final waitingDownloads = activeJobs
            .where((j) => j.status == 'Waiting for slot')
            .length;
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        final isKeyboardVisible = keyboardInset > 0;

        Widget queueContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Batch Paste Input Panel
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xff121820).withOpacity(0.5),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _urlInputController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText:
                          "Paste single, batch, or playlist YouTube URLs...",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Audio Only",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Switch(
                            value: _isAudioOnly,
                            activeColor: const Color(0xff00ff88),
                            onChanged: (val) {
                              setState(() {
                                _isAudioOnly = val;
                              });
                            },
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff0a0d14),
                          foregroundColor: const Color(0xff00d2ff),
                          side: const BorderSide(
                            color: Color(0xff00d2ff),
                            width: 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: _isResolvingPlaylist
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xff00d2ff)),
                                ),
                              )
                            : Icon(
                                _stagedUrls.isEmpty
                                    ? Icons.playlist_add_check_circle_outlined
                                    : Icons.rocket_launch_outlined,
                              ),
                        label: Text(
                          _isResolvingPlaylist
                              ? "RESOLVING PLAYLIST..."
                              : (_stagedUrls.isEmpty ? "REVIEW BATCH" : "START BATCH"),
                        ),
                        onPressed: _isResolvingPlaylist
                            ? null
                            : (_stagedUrls.isEmpty ? _reviewBatch : _startBatch),
                      ),
                    ],
                  ),
                  if (_stagedUrls.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.panelAlt.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.stroke),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "BATCH READY • ${_stagedUrls.length} URL${_stagedUrls.length == 1 ? '' : 'S'}",
                                  style: const TextStyle(
                                    color: AppColors.mint,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _clearBatch,
                                child: const Text("Clear"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Review before queueing. This keeps large paste sets deliberate instead of instantly flooding the queue.",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.66),
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._stagedUrls
                              .take(3)
                              .map(
                                (url) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xff0d131b),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            url,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.cloud,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _removeStagedUrl(url),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: Icon(
                                            Icons.close_rounded,
                                            color: Colors.white.withOpacity(
                                              0.55,
                                            ),
                                            size: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          if (_stagedUrls.length > 3)
                            Text(
                              "+ ${_stagedUrls.length - 3} more URLs in this batch",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "ACTIVE EXTRACTIONS QUEUE",
                style: TextStyle(
                  color: Color(0xff00d2ff),
                  fontWeight: FontWeight.bold,
                  fontSize: 12.0,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatusPill('Active $activeDownloads', AppColors.mint),
                const SizedBox(width: 8),
                _buildStatusPill('Waiting $waitingDownloads', AppColors.cyan),
                const Spacer(),
                Text(
                  '${activeJobs.length} in queue',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Queue action bar ────────────────────────────────────
            if (activeJobs.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQueueAction(
                      icon: Icons.pause_circle_outline,
                      label: 'Pause All',
                      color: Colors.amber,
                      onTap: () => _downloadService.pauseAll(),
                    ),
                    const SizedBox(width: 8),
                    _buildQueueAction(
                      icon: Icons.play_circle_outline,
                      label: 'Resume All',
                      color: AppColors.mint,
                      onTap: () => _downloadService.resumeAll(),
                    ),
                    if (activeJobs.any((j) => j.discoverFailed || j.downloadFailed)) ...[
                      const SizedBox(width: 8),
                      _buildQueueAction(
                        icon: Icons.refresh_rounded,
                        label: 'Retry Failed',
                        color: Colors.orangeAccent,
                        onTap: () => _downloadService.retryAllFailed(),
                      ),
                    ],
                    if (queue.any((j) => j.localPath != null)) ...[
                      const SizedBox(width: 8),
                      _buildQueueAction(
                        icon: Icons.playlist_remove,
                        label: 'Clear Done',
                        color: Colors.blueGrey,
                        onTap: () => _downloadService.clearCompleted(),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 10),
          ],
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final bottomPadding = isKeyboardVisible
                ? keyboardInset + 24.0
                : 76.0;
            final minContentHeight = constraints.maxHeight - bottomPadding - 16;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: minContentHeight > 0 ? minContentHeight : 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    queueContent,
                    if (activeJobs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Center(
                          child: Text(
                            _stagedUrls.isNotEmpty
                                ? "Batch is staged. Start it when you're ready."
                                : "Queue is currently empty.",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 13.0,
                            ),
                          ),
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        itemCount: activeJobs.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        onReorder: (oldIndex, newIndex) {
                          _downloadService.moveJob(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final job = activeJobs[index];
                          return VideoCard(
                            key: ValueKey(job.jobId),
                            job: job,
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQueueAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildLibraryTab() {
    return const LibraryView();
  }
}
