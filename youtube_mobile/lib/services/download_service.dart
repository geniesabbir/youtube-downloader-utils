import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/video_job.dart';

class AntiRateLimitClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
    request.headers['Accept'] = '*/*';
    request.headers['Accept-Language'] = 'en-US,en;q=0.9';
    request.headers['Sec-Fetch-Mode'] = 'navigate';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class DownloadService {
  static const String _queuePrefsKey = 'download_queue_jobs';
  static const String _maxConcurrentDownloadsPrefsKey =
      'download_max_concurrent';

  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final YoutubeExplode _yt = YoutubeExplode(
    YoutubeHttpClient(AntiRateLimitClient()),
  );
  final List<VideoJob> _queue = [];
  final Set<String> _activeDownloadJobIds = <String>{};
  final Connectivity _connectivity = Connectivity();
  final Battery _battery = Battery();

  final StreamController<List<VideoJob>> _queueController =
      StreamController<List<VideoJob>>.broadcast();
  final StreamController<String> _warningController =
      StreamController<String>.broadcast();

  bool _isScheduling = false;
  bool _isDiscovering = false;
  bool _wifiOnly = false;
  bool _powerSaver = false;
  int _maxConcurrentDownloads = 3;
  StreamSubscription? _connectivitySub;
  StreamSubscription? _batterySub;

  Stream<List<VideoJob>> get queueStream => _queueController.stream;
  List<VideoJob> get queue => List.unmodifiable(_queue);
  Stream<String> get warningStream => _warningController.stream;

  bool get wifiOnly => _wifiOnly;
  bool get powerSaver => _powerSaver;
  int get maxConcurrentDownloads => _maxConcurrentDownloads;

  void triggerWarning(String message) {
    _warningController.add(message);
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _wifiOnly = prefs.getBool('download_wifi_only') ?? false;
    _powerSaver = prefs.getBool('download_power_saver') ?? false;
    _maxConcurrentDownloads =
        prefs.getInt(_maxConcurrentDownloadsPrefsKey) ?? 3;

    await _loadPersistedQueue(prefs);
    await _restoreJobsFromStorage();
    _emitQueue();
    await _persistQueue();

    _connectivitySub = _connectivity.onConnectivityChanged.listen((_) {
      _checkConstraintsAndManageQueue();
    });
    _batterySub = _battery.onBatteryStateChanged.listen((_) {
      _checkConstraintsAndManageQueue();
    });

    Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkConstraintsAndManageQueue(),
    );
    _processQueue();
  }

  Future<void> setWifiOnly(bool enabled) async {
    _wifiOnly = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('download_wifi_only', enabled);
    await _checkConstraintsAndManageQueue();
  }

  Future<void> setPowerSaver(bool enabled) async {
    _powerSaver = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('download_power_saver', enabled);
    await _checkConstraintsAndManageQueue();
  }

  Future<void> setMaxConcurrentDownloads(int value) async {
    _maxConcurrentDownloads = value.clamp(1, 5);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _maxConcurrentDownloadsPrefsKey,
      _maxConcurrentDownloads,
    );
    _refreshWaitingStatuses();
    _emitQueue();
    await _persistQueue();
    _processQueue();
  }

  List<String> extractSupportedUrls(String rawText) {
    return rawText
        .split(RegExp(r'[\s,\n]+'))
        .map((e) => e.trim())
        .where(
          (e) =>
              e.isNotEmpty &&
              (e.contains('youtube.com') || e.contains('youtu.be')),
        )
        .toList();
  }

  Future<void> addJob(String url, {bool isAudio = false}) async {
    await addJobs([url], isAudio: isAudio);
  }

  Future<int> addJobs(List<String> urls, {bool isAudio = false}) async {
    final resolvedUrls = await _resolveQueueableUrls(urls);
    for (final url in resolvedUrls) {
      final jobId = '${DateTime.now().microsecondsSinceEpoch}_${_queue.length}';
      _queue.add(
        VideoJob(
          jobId: jobId,
          sourceUrl: url,
          targetUrl: url,
          isAudio: isAudio,
        ),
      );
    }
    _emitQueue();
    await _persistQueue();
    _processQueue();
    return resolvedUrls.length;
  }

  Future<void> analyzeUrls(String batchText, {bool isAudio = false}) async {
    final urls = extractSupportedUrls(batchText);
    await addJobs(urls, isAudio: isAudio);
  }

  Future<List<String>> _resolveQueueableUrls(List<String> urls) async {
    final resolved = <String>[];
    final seen = <String>{};

    for (final url in urls) {
      if (_isPlaylistUrl(url)) {
        try {
          final playlist = await _yt.playlists.get(url);
          await for (final video in _yt.playlists.getVideos(playlist.id)) {
            final videoUrl =
                'https://www.youtube.com/watch?v=${video.id.value}';
            if (seen.add(videoUrl)) {
              resolved.add(videoUrl);
            }
          }
        } catch (e, stack) {
          debugPrint('PLAYLIST RESOLVE ERROR: $e');
          debugPrintStack(stackTrace: stack);
          triggerWarning(
            'Playlist import failed. Try again or paste direct video links.',
          );
        }
        continue;
      }

      if (seen.add(url)) {
        resolved.add(url);
      }
    }

    return resolved;
  }

  bool _isPlaylistUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    final isYoutubeHost =
        host.contains('youtube.com') || host.contains('youtu.be');
    return isYoutubeHost &&
        (uri.queryParameters.containsKey('list') ||
            uri.path.contains('/playlist'));
  }

  Future<void> removeJob(String jobId) async {
    final jobIndex = _jobIndex(jobId);
    if (jobIndex == -1) return;

    final job = _queue[jobIndex];
    _activeDownloadJobIds.remove(jobId);
    if (job.localPath != null) {
      final file = File(job.localPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    _queue.removeAt(jobIndex);
    _emitQueue();
    await _persistQueue();
    _processQueue();
  }

  Future<void> startDownload(String jobId, {required bool isAudio}) async {
    final jobIndex = _jobIndex(jobId);
    if (jobIndex == -1) return;

    _queue[jobIndex] = _queue[jobIndex].copyWith(
      isAudio: isAudio,
      downloadTriggered: true,
      status: 'Waiting for slot',
      downloadFailed: false,
    );
    _refreshWaitingStatuses();
    _emitQueue();
    await _persistQueue();
    _processQueue();
  }

  Future<void> retryJob(String jobId) async {
    final jobIndex = _jobIndex(jobId);
    if (jobIndex == -1) return;

    final wasDiscovered = _queue[jobIndex].discovered;
    _queue[jobIndex] = _queue[jobIndex].copyWith(
      progress: 0.0,
      status: wasDiscovered ? 'Waiting for slot' : 'Queued',
      discoverFailed: false,
      downloadFailed: false,
      downloading: false,
      downloadTriggered: wasDiscovered,
      clearLocalPath: true,
    );
    _activeDownloadJobIds.remove(jobId);
    _emitQueue();
    await _persistQueue();
    _processQueue();
  }

  Future<void> _checkConstraintsAndManageQueue() async {
    final hasConstraint = await _violatesConstraints();
    if (!hasConstraint) {
      _processQueue();
      return;
    }

    for (var i = 0; i < _queue.length; i++) {
      if (_queue[i].downloading) {
        final batteryLvl = await _battery.batteryLevel;
        final netState = await _connectivity.checkConnectivity();
        var reason = 'Paused (System Blocked)';
        if (_wifiOnly && netState != ConnectivityResult.wifi) {
          reason = 'Paused (Cellular Locked)';
        } else if (_powerSaver && batteryLvl < 15) {
          reason = 'Paused (Low Battery)';
        }
        _queue[i] = _queue[i].copyWith(downloading: false, status: reason);
      }
    }

    _activeDownloadJobIds.clear();
    _refreshWaitingStatuses();
    _emitQueue();
    await _persistQueue();
  }

  Future<bool> _violatesConstraints() async {
    if (_wifiOnly) {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult != ConnectivityResult.wifi) {
        return true;
      }
    }
    if (_powerSaver) {
      final batteryLevel = await _battery.batteryLevel;
      if (batteryLevel < 15) {
        return true;
      }
    }
    return false;
  }

  Future<void> _processQueue() async {
    if (_isScheduling) return;
    _isScheduling = true;

    try {
      if (await _violatesConstraints()) {
        return;
      }

      _scheduleDiscovery();
      _scheduleDownloads();
      _refreshWaitingStatuses();
      _emitQueue();
      await _persistQueue();
    } finally {
      _isScheduling = false;
    }
  }

  void _scheduleDiscovery() {
    if (_isDiscovering) return;

    final pendingDiscoverIndex = _queue.indexWhere(
      (j) => !j.discovered && !j.discoverFailed,
    );
    if (pendingDiscoverIndex == -1) return;

    final jobId = _queue[pendingDiscoverIndex].jobId;
    _isDiscovering = true;
    unawaited(
      _discoverJob(jobId).whenComplete(() {
        _isDiscovering = false;
        _processQueue();
      }),
    );
  }

  void _scheduleDownloads() {
    while (_activeDownloadJobIds.length < _maxConcurrentDownloads) {
      final pendingDownloadIndex = _queue.indexWhere(
        (j) =>
            j.discovered &&
            j.downloadTriggered &&
            !j.downloading &&
            !j.downloadFailed &&
            j.localPath == null,
      );

      if (pendingDownloadIndex == -1) break;

      final jobId = _queue[pendingDownloadIndex].jobId;
      final job = _queue[pendingDownloadIndex];
      _activeDownloadJobIds.add(jobId);
      _queue[pendingDownloadIndex] = job.copyWith(
        downloading: true,
        status: 'Starting download...',
      );

      unawaited(
        _downloadJob(jobId).whenComplete(() {
          _activeDownloadJobIds.remove(jobId);
          _processQueue();
        }),
      );
    }
  }

  void _refreshWaitingStatuses() {
    for (var i = 0; i < _queue.length; i++) {
      final job = _queue[i];
      if (job.localPath != null || job.downloading || job.downloadFailed) {
        continue;
      }
      if (job.discovered && job.downloadTriggered) {
        _queue[i] = job.copyWith(status: 'Waiting for slot');
      }
    }
  }

  Future<void> _discoverJob(String jobId) async {
    final index = _jobIndex(jobId);
    if (index == -1) return;

    final job = _queue[index];
    _queue[index] = job.copyWith(status: 'Analyzing video...');
    _emitQueue();
    await _persistQueue();

    try {
      final video = await _yt.videos.get(job.sourceUrl);
      List<Chapter> chaptersList = [];
      try {
        chaptersList = _parseChapters(
          video.description,
          video.duration ?? Duration.zero,
        );
      } catch (_) {}

      final resolvedIndex = _jobIndex(jobId);
      if (resolvedIndex == -1) return;

      _queue[resolvedIndex] = job.copyWith(
        title: video.title,
        author: video.author,
        duration: _formatDuration(video.duration ?? Duration.zero),
        discovered: true,
        status: job.downloadTriggered ? 'Waiting for slot' : 'Analyzed',
        thumbnailUrl:
            'https://img.youtube.com/vi/${video.id.value}/mqdefault.jpg',
        chapters: chaptersList,
      );
    } catch (e, stack) {
      debugPrint('DISCOVERY ERROR: $e');
      debugPrintStack(stackTrace: stack);
      var displayStatus = 'Discovery failed: $e';
      if (e.toString().contains('RequestLimitExceededException') ||
          e.toString().contains('rate limiting') ||
          e.toString().contains('429')) {
        displayStatus = 'Rate Limited: Use Cellular Data or a VPN';
        triggerWarning('YouTube Rate Limit: Switch to Mobile Data or a VPN.');
      }

      final failedIndex = _jobIndex(jobId);
      if (failedIndex == -1) return;
      _queue[failedIndex] = job.copyWith(
        discoverFailed: true,
        status: displayStatus,
      );
    }

    _emitQueue();
    await _persistQueue();
  }

  Future<void> _downloadJob(String jobId) async {
    final index = _jobIndex(jobId);
    if (index == -1) return;
    final job = _queue[index];

    try {
      final video = await _yt.videos.get(job.sourceUrl);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      late StreamInfo streamInfo;
      late String extension;
      if (job.isAudio) {
        streamInfo = manifest.audioOnly.withHighestBitrate();
        extension = 'mp3';
      } else {
        streamInfo = manifest.muxed.withHighestBitrate();
        extension = 'mp4';
      }

      var usePublicStorage = false;
      var storagePath = '';

      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status.isDenied) {
          if (job.isAudio) {
            await Permission.audio.request();
          } else {
            await Permission.videos.request();
          }
        }

        final publicDir = Directory('/storage/emulated/0/Download');
        if (await publicDir.exists() ||
            await Permission.storage.isGranted ||
            await Permission.videos.isGranted) {
          usePublicStorage = true;
          storagePath = publicDir.path;
        }
      }

      if (!usePublicStorage) {
        final dir = await getApplicationDocumentsDirectory();
        final archiveDir = Directory('${dir.path}/archives');
        if (!await archiveDir.exists()) {
          await archiveDir.create(recursive: true);
        }
        storagePath = archiveDir.path;
      }

      final safeTitle = job.title.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');
      final localFilePath = '$storagePath/${job.jobId}_$safeTitle.$extension';
      final file = File(localFilePath);
      final responseStream = _yt.videos.streamsClient.get(streamInfo);
      final output = file.openWrite(mode: FileMode.write);

      final totalBytes = streamInfo.size.totalBytes;
      var downloadedBytes = 0;
      final speedStopwatch = Stopwatch()..start();
      var lastDownloadedBytes = 0;
      var speedMbps = 0.0;

      await for (final data in responseStream) {
        final currentIndex = _jobIndex(jobId);
        if (currentIndex == -1) {
          await output.close();
          return;
        }

        if (await _violatesConstraints()) {
          await output.close();
          _queue[currentIndex] = job.copyWith(
            downloading: false,
            status: 'Paused (Constraints Breached)',
          );
          _emitQueue();
          await _persistQueue();
          return;
        }

        output.add(data);
        downloadedBytes += data.length;

        if (speedStopwatch.elapsedMilliseconds >= 500) {
          final elapsedSeconds = speedStopwatch.elapsedMilliseconds / 1000.0;
          final bytesDiff = downloadedBytes - lastDownloadedBytes;
          speedMbps = (bytesDiff / elapsedSeconds) / (1024 * 1024);
          lastDownloadedBytes = downloadedBytes;
          speedStopwatch
            ..reset()
            ..start();
        }

        final progress = downloadedBytes / totalBytes;
        final speedDisplay = speedMbps > 0.0 ? speedMbps : 0.01;
        final remainingBytes = (totalBytes - downloadedBytes).toDouble();
        final remainingSeconds = speedDisplay > 0.0
            ? (remainingBytes / (speedDisplay * 1024 * 1024))
            : 0.0;
        final eta = remainingSeconds > 0 && remainingSeconds < 3600
            ? '${remainingSeconds.toStringAsFixed(0)}s remaining'
            : 'calculating ETA...';

        _queue[currentIndex] = job.copyWith(
          downloading: true,
          progress: progress,
          status:
              'Downloading: ${(progress * 100).toStringAsFixed(1)}% | ${speedDisplay.toStringAsFixed(2)} MB/s | $eta',
        );
        _emitQueue();
      }

      await output.close();
      speedStopwatch.stop();

      final completeIndex = _jobIndex(jobId);
      if (completeIndex == -1) return;
      _queue[completeIndex] = job.copyWith(
        downloading: false,
        status: 'Completed',
        progress: 1.0,
        localPath: localFilePath,
      );
    } catch (e, stack) {
      debugPrint('DOWNLOAD ERROR: $e');
      debugPrintStack(stackTrace: stack);
      var displayStatus = 'Download failed';
      if (e.toString().contains('RequestLimitExceededException') ||
          e.toString().contains('rate limiting') ||
          e.toString().contains('429')) {
        displayStatus = 'Rate Limited: Use Cellular Data or a VPN';
        triggerWarning('YouTube Rate Limit: Switch to Mobile Data or a VPN.');
      }

      final failedIndex = _jobIndex(jobId);
      if (failedIndex != -1) {
        _queue[failedIndex] = job.copyWith(
          downloading: false,
          downloadFailed: true,
          status: displayStatus,
        );
      }
    }

    _emitQueue();
    await _persistQueue();
  }

  Future<void> _loadPersistedQueue(SharedPreferences prefs) async {
    final rawQueue = prefs.getString(_queuePrefsKey);
    if (rawQueue == null || rawQueue.isEmpty) return;

    try {
      final decoded = jsonDecode(rawQueue) as List<dynamic>;
      final hydratedJobs = <VideoJob>[];

      for (final item in decoded) {
        final job = VideoJob.fromJson(item as Map<String, dynamic>);
        final localPath = job.localPath;
        final fileExists = localPath != null && await File(localPath).exists();

        if (localPath != null && !fileExists) {
          if (job.status == 'Completed') {
            continue;
          }
          hydratedJobs.add(
            job.copyWith(
              progress: 0.0,
              downloading: false,
              downloadFailed: true,
              status: 'File missing. Retry download.',
              clearLocalPath: true,
            ),
          );
          continue;
        }

        if (job.downloading) {
          hydratedJobs.add(
            job.copyWith(
              downloading: false,
              progress: 0.0,
              status: job.downloadTriggered ? 'Waiting for slot' : 'Queued',
            ),
          );
          continue;
        }

        hydratedJobs.add(job);
      }

      _queue
        ..clear()
        ..addAll(hydratedJobs);
    } catch (_) {
      await prefs.remove(_queuePrefsKey);
      _queue.clear();
    }
  }

  Future<void> _restoreJobsFromStorage() async {
    final existingPaths = _queue
        .map((job) => job.localPath)
        .whereType<String>()
        .toSet();
    final directories = <Directory>[];

    if (Platform.isAndroid) {
      directories.add(Directory('/storage/emulated/0/Download'));
    }

    final appDocsDir = await getApplicationDocumentsDirectory();
    directories.add(Directory('${appDocsDir.path}/archives'));

    for (final directory in directories) {
      if (!await directory.exists()) continue;
      final entities = await directory.list().toList();
      for (final entity in entities) {
        if (entity is! File) continue;

        final path = entity.path;
        if (existingPaths.contains(path)) continue;

        final restored = _restoreJobFromFile(entity);
        if (restored == null) continue;

        _queue.add(restored);
        existingPaths.add(path);
      }
    }
  }

  Future<void> rescanStorage() async {
    await _restoreJobsFromStorage();
    _emitQueue();
    await _persistQueue();
  }

  VideoJob? _restoreJobFromFile(File file) {
    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path;
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    if (extension != 'mp3' && extension != 'mp4') {
      return null;
    }

    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex == -1
        ? fileName
        : fileName.substring(0, dotIndex);
    final separatorIndex = baseName.indexOf('_');

    var jobId = DateTime.now().millisecondsSinceEpoch.toString();
    var inferredTitle = baseName;

    if (separatorIndex > 0) {
      jobId = baseName.substring(0, separatorIndex);
      inferredTitle = baseName.substring(separatorIndex + 1);
    }

    inferredTitle = inferredTitle.replaceAll('_', ' ').trim();
    if (inferredTitle.isEmpty) {
      inferredTitle = 'Recovered Download';
    }

    return VideoJob(
      jobId: jobId,
      sourceUrl: file.path,
      targetUrl: file.path,
      title: inferredTitle,
      author: 'Recovered from storage',
      duration: 'N/A',
      status: 'Completed',
      progress: 1.0,
      discovered: true,
      localPath: file.path,
      isAudio: extension == 'mp3',
      downloadTriggered: true,
    );
  }

  Future<void> _persistQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _queue.map((job) => job.toJson()).toList();
    await prefs.setString(_queuePrefsKey, jsonEncode(payload));
  }

  void _emitQueue() {
    _queueController.add(List<VideoJob>.from(_queue));
  }

  int _jobIndex(String jobId) => _queue.indexWhere((j) => j.jobId == jobId);

  List<Chapter> _parseChapters(String description, Duration videoDuration) {
    final chapters = <Chapter>[];
    final lines = description.split('\n');
    final regex = RegExp(r'(?:(\d{1,2}):)?(\d{2}):(\d{2})');

    for (final line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final hours = match.group(1) != null ? int.parse(match.group(1)!) : 0;
        final minutes = int.parse(match.group(2)!);
        final seconds = int.parse(match.group(3)!);

        final start = Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
        );
        final title = line.replaceFirst(match.group(0)!, '').trim();

        if (chapters.isNotEmpty) {
          final last = chapters.last;
          chapters[chapters.length - 1] = Chapter(
            title: last.title,
            start: last.start,
            end: start,
          );
        }

        chapters.add(
          Chapter(
            title: title.isEmpty ? 'Chapter ${chapters.length + 1}' : title,
            start: start,
            end: videoDuration,
          ),
        );
      }
    }

    return chapters;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    }
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  void dispose() {
    _yt.close();
    _connectivitySub?.cancel();
    _batterySub?.cancel();
    _queueController.close();
    _warningController.close();
  }
}
