import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'services/download_service.dart';
import 'services/playback_service.dart';
import 'services/share_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize lock screen playback engine
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.voidarchive.ytutils.channel.audio',
      androidNotificationChannelName: 'YT Utils Playback',
      androidNotificationOngoing: true,
    );
  } catch (_) {}

  // Initialize background state managers
  final downloadService = DownloadService();
  await downloadService.init();

  final playbackService = PlaybackService();
  playbackService.init();

  final shareService = ShareService();
  shareService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YT Utils',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AppShell(),
    );
  }
}
