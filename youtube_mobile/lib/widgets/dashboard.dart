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

class _DashboardState extends State<Dashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _urlInputController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final DownloadService _downloadService = DownloadService();

  bool _isAudioOnly = false;
  String _searchQuery = "";
  StreamSubscription? _warningSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

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
        margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16), // float gracefully above player overlay
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
    _tabController.dispose();
    _urlInputController.dispose();
    _searchController.dispose();
    super.dispose();
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

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
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
                        hintText: "Enter YouTube Video URLs (space or comma separated)...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text("Audio Only", style: TextStyle(color: Colors.white, fontSize: 12)),
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
                            side: const BorderSide(color: Color(0xff00d2ff), width: 1.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.analytics_outlined),
                          label: const Text("ANALYZE"),
                          onPressed: () {
                            if (_urlInputController.text.trim().isNotEmpty) {
                              _downloadService.analyzeUrls(
                                _urlInputController.text.trim(),
                                isAudio: _isAudioOnly,
                              );
                              _urlInputController.clear();
                              FocusScope.of(context).unfocus();
                            }
                          },
                        ),
                      ],
                    ),
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
              Expanded(
                child: activeJobs.isEmpty
                    ? Center(
                        child: Text(
                          "Queue is currently empty.",
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13.0),
                        ),
                      )
                    : ListView.builder(
                        itemCount: activeJobs.length,
                        itemBuilder: (context, index) {
                          return VideoCard(
                            job: activeJobs[index],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 60), // padding from absolute floating player
            ],
          ),
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
            .where((j) =>
                _searchQuery.isEmpty ||
                j.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                j.author.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

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
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
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
              const SizedBox(height: 10),
              Expanded(
                child: completedJobs.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty ? "No matching files." : "No downloaded files in library.",
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13.0),
                        ),
                      )
                    : ListView.builder(
                        itemCount: completedJobs.length,
                        itemBuilder: (context, index) {
                          return VideoCard(
                            job: completedJobs[index],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 60), // padding from absolute floating player
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
          // Wi-Fi Only Toggle
          SwitchListTile(
            title: const Text("Wi-Fi Only Mode", style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text("Auto-pauses when switching to cellular", style: TextStyle(color: Colors.blueGrey, fontSize: 11)),
            value: _downloadService.wifiOnly,
            activeColor: const Color(0xff00ff88),
            onChanged: (val) {
              setState(() {
                _downloadService.setWifiOnly(val);
              });
            },
          ),
          const Divider(color: Colors.blueGrey, height: 1),
          // Power Saver Mode
          SwitchListTile(
            title: const Text("Power Saver Mode", style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text("Halts active queues when battery is below 15%", style: TextStyle(color: Colors.blueGrey, fontSize: 11)),
            value: _downloadService.powerSaver,
            activeColor: const Color(0xff00ff88),
            onChanged: (val) {
              setState(() {
                _downloadService.setPowerSaver(val);
              });
            },
          ),
          const Divider(color: Colors.blueGrey, height: 1),
          const Spacer(),
          Center(
            child: Text(
              "Local-first • Serverless Archive Utility v1.0.0",
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
            ),
          ),
          const SizedBox(height: 80), // padding from player
        ],
      ),
    );
  }
}
