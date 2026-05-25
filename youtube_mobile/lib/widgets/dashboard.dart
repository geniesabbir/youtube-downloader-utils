import 'dart:async';
import 'package:flutter/material.dart';
import '../models/video_job.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';
import 'brand_mark.dart';
import 'video_card.dart';
import 'player_overlay.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _libraryTabController;
  final TextEditingController _urlInputController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final DownloadService _downloadService = DownloadService();

  bool _isAudioOnly = false;
  bool _isResolvingPlaylist = false;
  String _searchQuery = "";
  List<String> _stagedUrls = const [];
  StreamSubscription? _warningSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _libraryTabController = TabController(length: 2, vsync: this);

    // Listen to background service warnings and display high-fidelity floating warning toast
    _warningSub = _downloadService.warningStream.listen((message) {
      if (mounted) {
        _showPremiumWarningToast(message);
      }
    });
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
          bottom: 70,
          left: 16,
          right: 16,
        ), // float gracefully above player overlay
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          decoration: BoxDecoration(
            color: const Color(
              0xff1c1410,
            ).withOpacity(0.95), // deep warm spatial charcoal
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
    _tabController.dispose();
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
        appBar: AppBar(
          toolbarHeight: 82,
          titleSpacing: 18,
          title: const BrandLockup(
            compact: true,
            markSize: 38,
            showTagline: false,
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.mint,
            labelColor: AppColors.mint,
            unselectedLabelColor: AppColors.muted,
            tabs: const [
              Tab(icon: Icon(Icons.download), text: "Queue"),
              Tab(icon: Icon(Icons.library_books), text: "Library"),
              Tab(icon: Icon(Icons.tune), text: "Settings"),
            ],
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: [
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

  Widget _buildLibraryTab() {
    return StreamBuilder<List<VideoJob>>(
      stream: _downloadService.queueStream,
      builder: (context, snapshot) {
        final queue = snapshot.data ?? _downloadService.queue;
        final completedJobs = queue
            .where((j) => j.localPath != null)
            .where(
              (j) =>
                  _searchQuery.isEmpty ||
                  j.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  j.author.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();
        final videoJobs = completedJobs.where((j) => !j.isAudio).toList();
        final audioJobs = completedJobs.where((j) => j.isAudio).toList();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search Input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                decoration: BoxDecoration(
                  color: const Color(0xff121820),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    icon: const Icon(Icons.search, color: Color(0xff00d2ff)),
                    hintText: "Search offline archive library...",
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "COMPLETED OFFLINE ARCHIVES",
                      style: TextStyle(
                        color: Color(0xff00ff88),
                        fontWeight: FontWeight.bold,
                        fontSize: 12.0,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _rescanLibrary,
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text("Re-scan"),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildStatusPill(
                    'All ${completedJobs.length}',
                    AppColors.mint,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusPill(
                    'Videos ${videoJobs.length}',
                    AppColors.cyan,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusPill(
                    'Audio ${audioJobs.length}',
                    const Color(0xfff6c453),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: TabBar(
                  controller: _libraryTabController,
                  indicatorColor: AppColors.mint,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.muted,
                  tabs: const [
                    Tab(text: "Videos"),
                    Tab(text: "Audio"),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _libraryTabController,
                  children: [
                    _buildLibraryList(
                      videoJobs,
                      emptyLabel: "No saved videos yet.",
                    ),
                    _buildLibraryList(
                      audioJobs,
                      emptyLabel: "No saved audio files yet.",
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 60,
              ), // padding from absolute floating player
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "HARDWARE & CONSTRAINTS RULES",
            style: TextStyle(
              color: Color(0xff00d2ff),
              fontWeight: FontWeight.bold,
              fontSize: 12.0,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsToggleRow(
            title: "Wi-Fi Only Mode",
            subtitle: "Auto-pauses when switching to cellular",
            value: _downloadService.wifiOnly,
            onChanged: (val) async {
              await _downloadService.setWifiOnly(val);
              if (mounted) {
                setState(() {});
              }
            },
          ),
          const Divider(color: Colors.blueGrey, height: 1),
          _buildSettingsToggleRow(
            title: "Power Saver Mode",
            subtitle: "Halts active queues when battery is below 15%",
            value: _downloadService.powerSaver,
            onChanged: (val) async {
              await _downloadService.setPowerSaver(val);
              if (mounted) {
                setState(() {});
              }
            },
          ),
          const Divider(color: Colors.blueGrey, height: 1),
          _buildSettingsStepperRow(
            title: "Concurrent Downloads",
            subtitle: "Default is 3 to balance speed and stability.",
          ),
          const Divider(color: Colors.blueGrey, height: 1),
          const Spacer(),
          Center(
            child: Text(
              "YT Utils • Local-first media utility v1.0.0",
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 80), // padding from player
        ],
      ),
    );
  }

  Widget _buildSettingsToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
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
                      ? () => _updateConcurrentDownloads(
                          _downloadService.maxConcurrentDownloads - 1,
                        )
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
                      ? () => _updateConcurrentDownloads(
                          _downloadService.maxConcurrentDownloads + 1,
                        )
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

  Widget _buildLibraryList(List<VideoJob> jobs, {required String emptyLabel}) {
    if (jobs.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty ? "No matching files." : emptyLabel,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13.0,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        return VideoCard(job: jobs[index]);
      },
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
}
