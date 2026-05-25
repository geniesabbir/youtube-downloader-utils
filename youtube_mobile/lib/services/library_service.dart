import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/collection.dart';
import '../models/video_job.dart';
import 'download_service.dart';

class LibraryService {
  static final LibraryService _instance = LibraryService._internal();
  factory LibraryService() => _instance;
  LibraryService._internal();

  static const String _collectionsPrefsKey = 'library_media_collections';

  final List<MediaCollection> _collections = [];
  final StreamController<List<MediaCollection>> _collectionsController =
      StreamController<List<MediaCollection>>.broadcast();

  Stream<List<MediaCollection>> get collectionsStream => _collectionsController.stream;
  List<MediaCollection> get collections => List.unmodifiable(_collections);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    await _loadCollections(prefs);
    if (_collections.isEmpty) {
      _createDefaultSmartCollections();
      await _persistCollections(prefs);
    }
    _collectionsController.add(_collections);
  }

  Future<void> _loadCollections(SharedPreferences prefs) async {
    final raw = prefs.getString(_collectionsPrefsKey);
    if (raw != null) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        _collections.clear();
        _collections.addAll(decoded.map((e) => MediaCollection.fromJson(e)));
      } catch (_) {}
    }
  }

  Future<void> _persistCollections(SharedPreferences prefs) async {
    final raw = jsonEncode(_collections.map((e) => e.toJson()).toList());
    await prefs.setString(_collectionsPrefsKey, raw);
  }

  void _createDefaultSmartCollections() {
    _collections.addAll([
      MediaCollection(
        id: 'favorites',
        name: 'Favorites',
        iconName: 'favorite',
        colorHex: 0xffff4b5c,
        isSmart: true,
        rules: [CollectionRule(field: 'isFavorited', operator: 'eq', value: true)],
      ),
      MediaCollection(
        id: 'unwatched',
        name: 'Unwatched',
        iconName: 'radio_button_unchecked',
        colorHex: 0xff00d2ff,
        isSmart: true,
        rules: [CollectionRule(field: 'watchedPercent', operator: 'eq', value: 0.0)],
      ),
      MediaCollection(
        id: 'in_progress',
        name: 'In Progress',
        iconName: 'play_circle_outline',
        colorHex: 0xff00ff88,
        isSmart: true,
        rules: [
          CollectionRule(field: 'watchedPercent', operator: 'gt', value: 0.0),
          CollectionRule(field: 'watchedPercent', operator: 'lt', value: 1.0),
        ],
      ),
      MediaCollection(
        id: 'audio_only',
        name: 'Audio Only',
        iconName: 'music_note',
        colorHex: 0xfff6c453,
        isSmart: true,
        rules: [CollectionRule(field: 'isAudio', operator: 'eq', value: true)],
      ),
      MediaCollection(
        id: 'long_videos',
        name: 'Long Videos (>20m)',
        iconName: 'video_library',
        colorHex: 0xff903dfc,
        isSmart: true,
        rules: [CollectionRule(field: 'duration', operator: 'gt', value: 1200)], // gt 20 minutes
      ),
    ]);
  }

  Future<void> addCollection(MediaCollection collection) async {
    _collections.add(collection);
    _collectionsController.add(_collections);
    final prefs = await SharedPreferences.getInstance();
    await _persistCollections(prefs);
  }

  Future<void> removeCollection(String id) async {
    _collections.removeWhere((c) => c.id == id);
    _collectionsController.add(_collections);
    final prefs = await SharedPreferences.getInstance();
    await _persistCollections(prefs);
  }

  List<VideoJob> filterJobsForCollection(MediaCollection collection, List<VideoJob> allJobs) {
    // Only query completed downloaded jobs
    final completed = allJobs.where((j) => j.localPath != null).toList();
    if (!collection.isSmart) {
      // Manual collection matches on collectionId
      return completed.where((j) => j.collectionId == collection.id).toList();
    }

    // Smart collection filters dynamically using rule sets
    return completed.where((j) => matchesRules(j, collection.rules)).toList();
  }

  bool matchesRules(VideoJob job, List<CollectionRule> rules) {
    for (final rule in rules) {
      if (!_matchRule(job, rule)) {
        return false;
      }
    }
    return true;
  }

  bool _matchRule(VideoJob job, CollectionRule rule) {
    switch (rule.field) {
      case 'isFavorited':
        return rule.operator == 'eq' ? job.isFavorited == rule.value : job.isFavorited != rule.value;
      case 'isAudio':
        return rule.operator == 'eq' ? job.isAudio == rule.value : job.isAudio != rule.value;
      case 'watchedPercent':
        final double val = (rule.value as num).toDouble();
        if (rule.operator == 'eq') return job.watchedPercent == val;
        if (rule.operator == 'gt') return job.watchedPercent > val;
        if (rule.operator == 'lt') return job.watchedPercent < val;
        break;
      case 'author':
        final String val = rule.value.toString().toLowerCase();
        final String author = job.author.toLowerCase();
        if (rule.operator == 'contains') return author.contains(val);
        if (rule.operator == 'eq') return author == val;
        break;
      case 'tags':
        final String val = rule.value.toString().toLowerCase();
        if (rule.operator == 'contains') {
          return job.tags.any((t) => t.toLowerCase() == val);
        }
        break;
      case 'duration':
        // Parse "12:34" or "01:23:45" to seconds or use duration as seconds if already parsed
        final int durSecs = _parseDurationSeconds(job.duration);
        final int val = rule.value as int;
        if (rule.operator == 'gt') return durSecs > val;
        if (rule.operator == 'lt') return durSecs < val;
        if (rule.operator == 'eq') return durSecs == val;
        break;
    }
    return false;
  }

  int _parseDurationSeconds(String durationStr) {
    try {
      final parts = durationStr.split(':').map((e) => int.parse(e.trim())).toList();
      if (parts.length == 2) {
        return parts[0] * 60 + parts[1];
      } else if (parts.length == 3) {
        return parts[0] * 3600 + parts[1] * 60 + parts[2];
      }
    } catch (_) {}
    return 0;
  }
}
