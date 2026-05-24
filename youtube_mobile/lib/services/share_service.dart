import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'download_service.dart';

class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  StreamSubscription? _intentSub;

  void init() {
    // Listen to shared texts while app is running in memory
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        for (final item in value) {
          final path = item.path;
          if (path.contains("youtube.com") || path.contains("youtu.be")) {
            DownloadService().addJob(path);
          }
        }
      }
    }, onError: (_) {});

    // Get shared text that launched the app from a closed state
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        for (final item in value) {
          final path = item.path;
          if (path.contains("youtube.com") || path.contains("youtu.be")) {
            DownloadService().addJob(path);
          }
        }
      }
      ReceiveSharingIntent.instance.reset();
    }).catchError((_) {});
  }

  void dispose() {
    _intentSub?.cancel();
  }
}
