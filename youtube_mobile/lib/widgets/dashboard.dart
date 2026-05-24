import 'package:flutter/material.dart';
import '../models/video_job.dart';
import '../services/download_service.dart';
import '../services/security_service.dart';
import 'video_card.dart';
import 'vault_view.dart';
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
  final SecurityService _securityService = SecurityService();

  bool _isAudioOnly = false;
  String _searchQuery = "";
  bool _biometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final bioEnabled = await _securityService.isLockEnabled;
    setState(() {
      _biometricsEnabled = bioEnabled;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlInputController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff080b0e),
      appBar: AppBar(
        backgroundColor: const Color(0xff0a0d14),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xff00d2ff), width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "VOID",
                style: TextStyle(
                  color: Color(0xff00d2ff),
                  fontFamily: "monospace",
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "ARCHIVE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w300,
                fontSize: 16.0,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xff00ff88),
          labelColor: const Color(0xff00ff88),
          unselectedLabelColor: Colors.blueGrey,
          tabs: const [
            Tab(icon: Icon(Icons.download), text: "Queue"),
            Tab(icon: Icon(Icons.library_books), text: "Library"),
            Tab(icon: Icon(Icons.fingerprint), text: "Vault"),
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
                VaultView(
                  onVaultChanged: () {
                    setState(() {}); // refresh layouts
                  },
                ),
                _buildSettingsTab(),
              ],
            ),
            // Floating media player overlay
            const Align(
              alignment: Alignment.bottomCenter,
              child: PlayerOverlay(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueTab() {
    return StreamBuilder<List<VideoJob>>(
      stream: _downloadService.queueStream,
      builder: (context, snapshot) {
        final queue = snapshot.data ?? _downloadService.queue;
        final activeJobs = queue.where((j) => j.status != "Completed" && j.status != "Vault Locked").toList();

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
                            onVaultLocked: () => setState(() {}),
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
        // Exclude vault items or in-progress jobs
        final completedJobs = queue
            .where((j) => j.status == "Completed" && j.localPath != null)
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
                            onVaultLocked: () => setState(() {}),
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
          // Biometrics Enable
          SwitchListTile(
            title: const Text("Biometric Lock (TouchID/FaceID)", style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text("Enforces local authentication to unlock private vault", style: TextStyle(color: Colors.blueGrey, fontSize: 11)),
            value: _biometricsEnabled,
            activeColor: const Color(0xff00ff88),
            onChanged: (val) async {
              final sec = SecurityService();
              if (val) {
                final canAuth = await sec.canAuthenticate();
                if (!canAuth) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Biometrics not supported or setup on this device."),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
                final passed = await sec.authenticate("Setup secure biometrics");
                if (passed) {
                  await sec.setLockEnabled(true);
                  setState(() {
                    _biometricsEnabled = true;
                  });
                }
              } else {
                final passed = await sec.authenticate("Disable biometric vault");
                if (passed) {
                  await sec.setLockEnabled(false);
                  setState(() {
                    _biometricsEnabled = false;
                  });
                }
              }
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
