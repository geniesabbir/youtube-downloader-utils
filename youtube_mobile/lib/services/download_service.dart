import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../models/video_job.dart';

class AntiRateLimitClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Add realistic headers to mimic a legitimate web browser session
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
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final YoutubeExplode _yt = YoutubeExplode(YoutubeHttpClient(AntiRateLimitClient()));
  final List<VideoJob> _queue = [];
  bool _isProcessing = false;

  final StreamController<List<VideoJob>> _queueController = StreamController<List<VideoJob>>.broadcast();
  Stream<List<VideoJob>> get queueStream => _queueController.stream;
  List<VideoJob> get queue => List.unmodifiable(_queue);

  final StreamController<String> _warningController = StreamController<String>.broadcast();
  Stream<String> get warningStream => _warningController.stream;

  void triggerWarning(String message) {
    _warningController.add(message);
  }

  final Connectivity _connectivity = Connectivity();
  final Battery _battery = Battery();

  bool _wifiOnly = false;
  bool _powerSaver = false;
  StreamSubscription? _connectivitySub;
  StreamSubscription? _batterySub;

  bool get wifiOnly => _wifiOnly;
  bool get powerSaver => _powerSaver;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _wifiOnly = prefs.getBool('download_wifi_only') ?? false;
    _powerSaver = prefs.getBool('download_power_saver') ?? false;
    await _loadPersistedQueue(prefs);
    await _restoreJobsFromStorage();
    _queueController.add(_queue);
    await _persistQueue();

    // Listen to network changes
    _connectivitySub = _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _checkConstraintsAndManageQueue();
    });

    // Listen to battery changes
    _batterySub = _battery.onBatteryStateChanged.listen((BatteryState state) {
      _checkConstraintsAndManageQueue();
    });

    // Periodic check for battery levels
    Timer.periodic(const Duration(seconds: 30), (_) => _checkConstraintsAndManageQueue());
  }

  Future<void> setWifiOnly(bool enabled) async {
    _wifiOnly = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('download_wifi_only', enabled);
    _checkConstraintsAndManageQueue();
  }

  Future<void> setPowerSaver(bool enabled) async {
    _powerSaver = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('download_power_saver', enabled);
    _checkConstraintsAndManageQueue();
  }

  Future<void> addJob(String url, {bool isAudio = false}) async {
    final jobId = DateTime.now().millisecondsSinceEpoch.toString();
    final job = VideoJob(
      jobId: jobId,
      sourceUrl: url,
      targetUrl: url,
      isAudio: isAudio,
    );
    _queue.add(job);
    _queueController.add(_queue);
    await _persistQueue();
    
    // Proactively start discovering and downloading
    _processQueue();
  }

  Future<void> analyzeUrls(String batchText, {bool isAudio = false}) async {
    final urls = batchText
        .split(RegExp(r'[\s,\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.contains("youtube.com") || e.contains("youtu.be"))
        .toList();

    for (final url in urls) {
      await addJob(url, isAudio: isAudio);
    }
  }

  Future<void> removeJob(String jobId) async {
    final jobIndex = _queue.indexWhere((j) => j.jobId == jobId);
    if (jobIndex != -1) {
      final job = _queue[jobIndex];
      job.downloading = false;
      if (job.localPath != null) {
        final file = File(job.localPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _queue.removeAt(jobIndex);
      _queueController.add(_queue);
      await _persistQueue();
    }
  }

  Future<void> startDownload(String jobId, {required bool isAudio}) async {
    final jobIndex = _queue.indexWhere((j) => j.jobId == jobId);
    if (jobIndex != -1) {
      _queue[jobIndex] = _queue[jobIndex].copyWith(
        isAudio: isAudio,
        downloadTriggered: true,
        status: "Queued",
      );
      _queueController.add(_queue);
      await _persistQueue();
      _processQueue();
    }
  }

  Future<void> retryJob(String jobId) async {
    final jobIndex = _queue.indexWhere((j) => j.jobId == jobId);
    if (jobIndex != -1) {
      final wasDiscovered = _queue[jobIndex].discovered;
      _queue[jobIndex] = _queue[jobIndex].copyWith(
        progress: 0.0,
        status: "Queued",
        discoverFailed: false,
        downloadFailed: false,
        downloading: false,
        downloadTriggered: wasDiscovered,
      );
      _queueController.add(_queue);
      await _persistQueue();
      _processQueue();
    }
  }

  Future<void> _checkConstraintsAndManageQueue() async {
    final hasConstraint = await _violatesConstraints();
    if (hasConstraint) {
      // Pause any active downloads
      for (int i = 0; i < _queue.length; i++) {
        if (_queue[i].downloading) {
          final batteryLvl = await _battery.batteryLevel;
          final netState = await _connectivity.checkConnectivity();
          String reason = "Paused (System Blocked)";
          if (_wifiOnly && netState != ConnectivityResult.wifi) {
            reason = "Paused (Cellular Locked)";
          } else if (_powerSaver && batteryLvl < 15) {
            reason = "Paused (Low Battery)";
          }
          _queue[i] = _queue[i].copyWith(
            downloading: false,
            status: reason,
          );
        }
      }
      _queueController.add(_queue);
      await _persistQueue();
    } else {
      // Resume queue
      _processQueue();
    }
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
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (_queue.any((j) =>
          (!j.discovered && !j.discoverFailed) ||
          (j.discovered && j.downloadTriggered && !j.downloading && !j.downloadFailed && j.localPath == null))) {
        // 1. Discover pending jobs
        final pendingDiscoverIndex = _queue.indexWhere((j) => !j.discovered && !j.discoverFailed);
        if (pendingDiscoverIndex != -1) {
          await _discoverJob(pendingDiscoverIndex);
          continue;
        }

        // Check system constraints before downloading
        if (await _violatesConstraints()) {
          break;
        }

        // 2. Download pending discovered jobs
        final pendingDownloadIndex = _queue.indexWhere(
          (j) => j.discovered && j.downloadTriggered && !j.downloading && !j.downloadFailed && j.localPath == null
        );
        if (pendingDownloadIndex != -1) {
          await _downloadJob(pendingDownloadIndex);
          continue;
        }

        break;
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _discoverJob(int index) async {
    var job = _queue[index];
    _queue[index] = job.copyWith(status: "Analyzing video...");
    _queueController.add(_queue);

    try {
      final video = await _yt.videos.get(job.sourceUrl);

      List<Chapter> chaptersList = [];
      try {
        // Try parsing description chapters
        chaptersList = _parseChapters(video.description, video.duration ?? Duration.zero);
      } catch (_) {}

      _queue[index] = job.copyWith(
        title: video.title,
        author: video.author,
        duration: _formatDuration(video.duration ?? Duration.zero),
        discovered: true,
        status: "Analyzed",
        thumbnailUrl: 'https://img.youtube.com/vi/${video.id.value}/mqdefault.jpg',
        chapters: chaptersList,
      );
    } catch (e, stack) {
      print("DISCOVERY ERROR: $e");
      print(stack);
      String displayStatus = "Discovery failed: $e";
      if (e.toString().contains("RequestLimitExceededException") || e.toString().contains("rate limiting") || e.toString().contains("429")) {
        displayStatus = "Rate Limited: Use Cellular Data or a VPN";
        triggerWarning("YouTube Rate Limit: Switch to Mobile Data or a VPN.");
      }
      _queue[index] = job.copyWith(
        discoverFailed: true,
        status: displayStatus,
      );
    }
    _queueController.add(_queue);
    await _persistQueue();
  }

  Future<void> _downloadJob(int index) async {
    var job = _queue[index];
    _queue[index] = job.copyWith(downloading: true, status: "Starting download...");
    _queueController.add(_queue);

    try {
      final video = await _yt.videos.get(job.sourceUrl);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      late StreamInfo streamInfo;
      String extension = "";

      if (job.isAudio) {
        streamInfo = manifest.audioOnly.withHighestBitrate();
        extension = "mp3";
      } else {
        streamInfo = manifest.muxed.withHighestBitrate();
        extension = "mp4";
      }

      // Request storage permission on Android to save directly to public Downloads folder
      bool usePublicStorage = false;
      String storagePath = "";

      if (Platform.isAndroid) {
        var status = await Permission.storage.request();
        if (status.isDenied) {
          if (job.isAudio) {
            await Permission.audio.request();
          } else {
            await Permission.videos.request();
          }
        }
        
        final publicDir = Directory('/storage/emulated/0/Download');
        if (await publicDir.exists() || await Permission.storage.isGranted || await Permission.videos.isGranted) {
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
      int downloadedBytes = 0;

      final speedStopwatch = Stopwatch()..start();
      int lastDownloadedBytes = 0;
      double speedMbps = 0.0;

      await for (final data in responseStream) {
        // Enforce pause if constraints are breached mid-download
        if (await _violatesConstraints()) {
          await output.close();
          _queue[index] = job.copyWith(
            downloading: false,
            status: "Paused (Constraints Breached)",
          );
          _queueController.add(_queue);
          await _persistQueue();
          return;
        }

        output.add(data);
        downloadedBytes += data.length;

        // Dynamic speed tracking (every 500ms)
        if (speedStopwatch.elapsedMilliseconds >= 500) {
          final elapsedSeconds = speedStopwatch.elapsedMilliseconds / 1000.0;
          final bytesDiff = downloadedBytes - lastDownloadedBytes;
          speedMbps = (bytesDiff / elapsedSeconds) / (1024 * 1024); // MB/s
          
          lastDownloadedBytes = downloadedBytes;
          speedStopwatch.reset();
          speedStopwatch.start();
        }

        final double progress = downloadedBytes / totalBytes;
        final double speedDisplay = speedMbps > 0.0 ? speedMbps : 0.01;
        final double remainingBytes = (totalBytes - downloadedBytes).toDouble();
        final double remainingSeconds = speedDisplay > 0.0 ? (remainingBytes / (speedDisplay * 1024 * 1024)) : 0.0;
        final String eta = remainingSeconds > 0 && remainingSeconds < 3600
            ? '${remainingSeconds.toStringAsFixed(0)}s remaining'
            : 'calculating ETA...';

        _queue[index] = job.copyWith(
          progress: progress,
          status: 'Downloading: ${(progress * 100).toStringAsFixed(1)}% | ${speedDisplay.toStringAsFixed(2)} MB/s | $eta',
        );
        _queueController.add(_queue);
      }

      await output.close();
      speedStopwatch.stop();

      _queue[index] = job.copyWith(
        downloading: false,
        status: "Completed",
        progress: 1.0,
        localPath: localFilePath,
      );
    } catch (e, stack) {
      print("DOWNLOAD ERROR: $e");
      print(stack);
      String displayStatus = "Download failed";
      if (e.toString().contains("RequestLimitExceededException") || e.toString().contains("rate limiting") || e.toString().contains("429")) {
        displayStatus = "Rate Limited: Use Cellular Data or a VPN";
        triggerWarning("YouTube Rate Limit: Switch to Mobile Data or a VPN.");
      }
      _queue[index] = job.copyWith(
        downloading: false,
        downloadFailed: true,
        status: displayStatus,
      );
    }
    _queueController.add(_queue);
    await _persistQueue();
  }

  Future<void> _loadPersistedQueue(SharedPreferences prefs) async {
    final rawQueue = prefs.getString(_queuePrefsKey);
    if (rawQueue == null || rawQueue.isEmpty) return;

    try {
      final decoded = jsonDecode(rawQueue) as List<dynamic>;
      final List<VideoJob> hydratedJobs = [];

      for (final item in decoded) {
        final job = VideoJob.fromJson(item as Map<String, dynamic>);
        final localPath = job.localPath;
        final fileExists = localPath != null && await File(localPath).exists();

        if (localPath != null && !fileExists) {
          if (job.status == "Completed") {
            continue;
          }

          hydratedJobs.add(job.copyWith(
            localPath: null,
            progress: 0.0,
            downloading: false,
            downloadFailed: true,
            status: "File missing. Retry download.",
          ));
          continue;
        }

        if (job.downloading) {
          hydratedJobs.add(job.copyWith(
            downloading: false,
            progress: fileExists ? job.progress : 0.0,
            status: job.localPath == null ? "Paused after restart" : job.status,
          ));
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

  VideoJob? _restoreJobFromFile(File file) {
    final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path;
    final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    if (extension != 'mp3' && extension != 'mp4') {
      return null;
    }

    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex == -1 ? fileName : fileName.substring(0, dotIndex);
    final separatorIndex = baseName.indexOf('_');

    String jobId = DateTime.now().millisecondsSinceEpoch.toString();
    String inferredTitle = baseName;

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

  List<Chapter> _parseChapters(String description, Duration videoDuration) {
    final List<Chapter> chapters = [];
    final lines = description.split('\n');
    final regex = RegExp(r'(?:(\d{1,2}):)?(\d{2}):(\d{2})');

    for (final line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final hours = match.group(1) != null ? int.parse(match.group(1)!) : 0;
        final minutes = int.parse(match.group(2)!);
        final seconds = int.parse(match.group(3)!);
        
        final start = Duration(hours: hours, minutes: minutes, seconds: seconds);
        final title = line.replaceFirst(match.group(0)!, '').trim();

        if (chapters.isNotEmpty) {
          // Update the end of the previous chapter
          final last = chapters.last;
          chapters[chapters.length - 1] = Chapter(
            title: last.title,
            start: last.start,
            end: start,
          );
        }

        chapters.add(Chapter(
          title: title.isEmpty ? "Chapter ${chapters.length + 1}" : title,
          start: start,
          end: videoDuration,
        ));
      }
    }

    return chapters;
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

  void dispose() {
    _yt.close();
    _connectivitySub?.cancel();
    _batterySub?.cancel();
    _queueController.close();
    _warningController.close();
  }
}
