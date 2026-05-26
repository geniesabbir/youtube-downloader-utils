import 'package:flutter/material.dart';
import '../models/collection.dart';
import '../models/video_job.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import 'video_card.dart';

class CollectionView extends StatelessWidget {
  final MediaCollection collection;
  final List<VideoJob> allJobs;

  const CollectionView({
    super.key,
    required this.collection,
    required this.allJobs,
  });

  @override
  Widget build(BuildContext context) {
    final LibraryService library = LibraryService();
    final matchedJobs = library.filterJobsForCollection(collection, allJobs);
    final accentColor = Color(collection.colorHex);

    return Scaffold(
      backgroundColor: const Color(0xff080b0e),
      appBar: AppBar(
        backgroundColor: const Color(0xff080b0e).withOpacity(0.5),
        title: Row(
          children: [
            Icon(_getIconData(collection.iconName), color: accentColor, size: 22),
            const SizedBox(width: 10),
            Text(
              collection.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14.0,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: AppColors.cyan),
            onPressed: () => _showRulesOverlay(context),
            tooltip: "View Smart Rules",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Dynamic count badge banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.08),
                border: Border(
                  bottom: BorderSide(color: accentColor.withOpacity(0.18), width: 1.0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    collection.isSmart ? "DYNAMIC SMART FILTER" : "MANUAL USER COLLECTION",
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    "${matchedJobs.length} ARCHIVES",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Content List View
            Expanded(
              child: matchedJobs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 48, color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 12),
                          Text(
                            "No offline archives currently match this collection.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      itemCount: matchedJobs.length,
                      itemBuilder: (context, index) {
                        return VideoCard(job: matchedJobs[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRulesOverlay(BuildContext context) {
    final accentColor = Color(collection.colorHex);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff0b0f17),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_getIconData(collection.iconName), color: accentColor, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    "${collection.name.toUpperCase()} RULES",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "MATCH ALL CRITERIA BELOW:",
                style: TextStyle(color: AppColors.mint, fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 1.0),
              ),
              const SizedBox(height: 12),
              if (collection.rules.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("• No dynamic rules defined for this manual playlist.", style: TextStyle(color: Colors.white54, fontSize: 12.5)),
                )
              else
                ...collection.rules.map((rule) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 8, color: AppColors.cyan),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                text: "${rule.field.toUpperCase()} ",
                                style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: "monospace"),
                                children: [
                                  TextSpan(
                                    text: "${rule.operator.toUpperCase()} ",
                                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.normal, fontSize: 12),
                                  ),
                                  TextSpan(
                                    text: "${rule.value}",
                                    style: const TextStyle(color: AppColors.mint, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
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
