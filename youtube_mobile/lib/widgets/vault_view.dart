import 'package:flutter/material.dart';
import '../models/video_job.dart';
import '../services/security_service.dart';
import '../services/playback_service.dart';
import '../services/download_service.dart';

class VaultView extends StatefulWidget {
  final VoidCallback onVaultChanged;
  const VaultView({super.key, required this.onVaultChanged});

  @override
  State<VaultView> createState() => _VaultViewState();
}

class _VaultViewState extends State<VaultView> {
  final SecurityService _security = SecurityService();
  bool _authenticated = false;
  List<VideoJob> _vaultJobs = [];

  @override
  void initState() {
    super.initState();
    _security.lockVault();
    _loadVaultJobs();
  }

  void _loadVaultJobs() {
    // Retrieve jobs that are locked in the vault
    setState(() {
      _vaultJobs = DownloadService()
          .queue
          .where((j) => j.status == "Vault Locked")
          .toList();
    });
  }

  Future<void> _authenticate() async {
    final success = await _security.authenticate("Access Secure Enclave Vault");
    if (success) {
      setState(() {
        _authenticated = true;
      });
      _loadVaultJobs();
    }
  }

  void _lockVault() {
    _security.lockVault();
    setState(() {
      _authenticated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xff121820),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xff00d2ff).withOpacity(0.5),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff00d2ff).withOpacity(0.2),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fingerprint,
                  color: Color(0xff00d2ff),
                  size: 50,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "ENCLAVE LOCKED",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Verify biometric credentials to access locked lectures.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13.0,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0a0d14),
                  foregroundColor: const Color(0xff00ff88),
                  side: const BorderSide(color: Color(0xff00ff88), width: 1.0),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.lock_open),
                label: const Text("UNLOAD SECURE VAULT"),
                onPressed: _authenticate,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "SECURE ARCHIVES VAULT",
                style: TextStyle(
                  color: Color(0xff00ff88),
                  fontWeight: FontWeight.bold,
                  fontSize: 13.0,
                  letterSpacing: 1.0,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.lock, color: Colors.amber, size: 16),
                label: const Text("LOCK", style: TextStyle(color: Colors.amber, fontSize: 12)),
                onPressed: _lockVault,
              ),
            ],
          ),
        ),
        Expanded(
          child: _vaultJobs.isEmpty
              ? Center(
                  child: Text(
                    "No items are locked in the vault.",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13.0,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _vaultJobs.length,
                  itemBuilder: (context, index) {
                    final job = _vaultJobs[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: const Color(0xff121820).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            job.isAudio ? Icons.music_note : Icons.play_arrow,
                            color: const Color(0xff00ff88),
                          ),
                          const SizedBox(width: 12),
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
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  job.author,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 11.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.lock_open, color: Colors.amber),
                            tooltip: "Unlock File",
                            onPressed: () {
                              setState(() {
                                job.status = "Completed";
                              });
                              _loadVaultJobs();
                              widget.onVaultChanged();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.play_circle_fill, color: Color(0xff00ff88)),
                            tooltip: "Play",
                            onPressed: () => PlaybackService().play(job),
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
