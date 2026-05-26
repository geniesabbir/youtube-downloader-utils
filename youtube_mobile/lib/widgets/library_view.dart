import 'package:flutter/material.dart';
import '../models/collection.dart';
import '../models/video_job.dart';
import '../services/download_service.dart';
import '../services/library_service.dart';
import '../services/playback_service.dart';
import '../theme/app_theme.dart';
import 'collection_view.dart';
import 'video_card.dart';

class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  final LibraryService _library = LibraryService();
  final DownloadService _download = DownloadService();
  
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  
  bool _multiSelectMode = false;
  final Set<String> _selectedJobIds = <String>{};
  
  String _sortBy = "recent"; // recent, title, size

  @override
  void initState() {
    super.initState();
    _library.init();
  }

  void _rescanLibrary() async {
    await _download.rescanStorage();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Offline library rescan completed.", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.mint,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleFavorite(VideoJob job) async {
    final index = _download.queue.indexWhere((j) => j.jobId == job.jobId);
    if (index != -1) {
      final updated = _download.queue[index].copyWith(isFavorited: !job.isFavorited);
      // We can trigger an update by updating queue and saving
      _download.updateJobStateDirectly(job.jobId, updated);
      setState(() {});
    }
  }

  void _deleteSelected() async {
    for (final id in _selectedJobIds) {
      await _download.removeJob(id);
    }
    setState(() {
      _selectedJobIds.clear();
      _multiSelectMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Bulk delete completed.", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<VideoJob> _getSortedAndFilteredJobs(List<VideoJob> allJobs) {
    // Filter completed downloaded jobs matching search query
    List<VideoJob> completed = allJobs
        .where((j) => j.localPath != null)
        .where((j) =>
            _searchQuery.isEmpty ||
            j.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            j.author.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    // Sort
    if (_sortBy == "title") {
      completed.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_sortBy == "size") {
      completed.sort((a, b) => (b.fileSizeBytes ?? 0).compareTo(a.fileSizeBytes ?? 0));
    } else {
      // default: recent
      completed.sort((a, b) {
        final dateA = a.lastWatchedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.lastWatchedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
    }
    return completed;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VideoJob>>(
      stream: _download.queueStream,
      builder: (context, queueSnapshot) {
        final rawJobs = queueSnapshot.data ?? _download.queue;
        final jobs = _getSortedAndFilteredJobs(rawJobs);

        // Compute total storage size used
        int totalBytes = 0;
        for (final j in rawJobs) {
          if (j.localPath != null) {
            totalBytes += j.fileSizeBytes ?? 0;
          }
        }
        final double totalGb = totalBytes / (1024 * 1024 * 1024);

        return StreamBuilder<List<MediaCollection>>(
          stream: _library.collectionsStream,
          builder: (context, collectionsSnapshot) {
            final collections = collectionsSnapshot.data ?? _library.collections;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                children: [
                  // Storage Insights Bar
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "OFFLINE STORAGE INSIGHTS",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              "${totalGb.toStringAsFixed(2)} GB OFFLINE",
                              style: const TextStyle(
                                color: AppColors.mint,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 4,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (totalGb / 64.0).clamp(0.0, 1.0), // Mock 64GB max
                              backgroundColor: Colors.white10,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.mint),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 13.0),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, color: Color(0xff00d2ff), size: 18),
                            hintText: "Search title, author, tags...",
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12.5,
                            ),
                            filled: true,
                            fillColor: const Color(0xff121820),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(color: Colors.blueGrey.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(color: AppColors.cyan),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.sync, color: AppColors.cyan, size: 20),
                        tooltip: "Re-scan Public storage",
                        onPressed: _rescanLibrary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Smart Collections List row (Spotify chips style)
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: collections.length,
                      itemBuilder: (context, index) {
                        final c = collections[index];
                        final matchedCount = _library.filterJobsForCollection(c, rawJobs).length;
                        return _buildCollectionChip(c, matchedCount, rawJobs);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Sorting & Bulk Mode control row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text("Sort:", style: TextStyle(color: Colors.white60, fontSize: 12)),
                          const SizedBox(width: 6),
                          DropdownButton<String>(
                            value: _sortBy,
                            dropdownColor: const Color(0xff0b0f17),
                            style: const TextStyle(color: AppColors.mint, fontSize: 12, fontWeight: FontWeight.bold),
                            underline: const SizedBox(),
                            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.mint, size: 16),
                            items: const [
                              DropdownMenuItem(value: "recent", child: Text("Recent")),
                              DropdownMenuItem(value: "title", child: Text("Title")),
                              DropdownMenuItem(value: "size", child: Text("Size")),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _sortBy = val;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (_multiSelectMode) ...[
                            IconButton(
                              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                              tooltip: "Delete Selected",
                              onPressed: _selectedJobIds.isEmpty ? null : _deleteSelected,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70),
                              onPressed: () {
                                setState(() {
                                  _multiSelectMode = false;
                                  _selectedJobIds.clear();
                                });
                              },
                            ),
                          ] else ...[
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _multiSelectMode = true;
                                });
                              },
                              icon: const Icon(Icons.checklist_rtl_rounded, size: 16, color: AppColors.cyan),
                              label: const Text("Bulk Edit", style: TextStyle(color: AppColors.cyan, fontSize: 11.5, fontWeight: FontWeight.bold)),
                            ),
                          ]
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Main List View of matching files
                  Expanded(
                    child: jobs.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isNotEmpty ? "No matching files found." : "No saved media in library yet.",
                              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13.0),
                            ),
                          )
                        : ListView.builder(
                            itemCount: jobs.length,
                            itemBuilder: (context, index) {
                              final job = jobs[index];
                              final isSelected = _selectedJobIds.contains(job.jobId);

                              if (_multiSelectMode) {
                                return CheckboxListTile(
                                  value: isSelected,
                                  title: Text(job.title, maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold)),
                                  subtitle: Text(job.author, style: const TextStyle(color: Colors.white30, fontSize: 11.0)),
                                  activeColor: AppColors.mint,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedJobIds.add(job.jobId);
                                      } else {
                                        _selectedJobIds.remove(job.jobId);
                                      }
                                    });
                                  },
                                );
                              }

                              return VideoCard(
                                job: job,
                                showFavoriteOption: true,
                                onFavoritePressed: () => _toggleFavorite(job),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 60), // absolute player gap
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCollectionChip(MediaCollection collection, int count, List<VideoJob> allJobs) {
    final accentColor = Color(collection.colorHex);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CollectionView(collection: collection, allJobs: allJobs),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withOpacity(0.3), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(_getIconData(collection.iconName), color: accentColor, size: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "$count",
                    style: TextStyle(color: accentColor, fontSize: 10.5, fontWeight: FontWeight.w800),
                  ),
                )
              ],
            ),
            const SizedBox(height: 6),
            Text(
              collection.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'favorite':
        return Icons.favorite_rounded;
      case 'radio_button_unchecked':
        return Icons.radio_button_unchecked_rounded;
      case 'play_circle_outline':
        return Icons.play_circle_fill_rounded;
      case 'content_cut':
        return Icons.content_cut_rounded;
      case 'music_note':
        return Icons.music_note_rounded;
      case 'video_library':
        return Icons.video_library_rounded;
      default:
        return Icons.folder_rounded;
    }
  }
}
