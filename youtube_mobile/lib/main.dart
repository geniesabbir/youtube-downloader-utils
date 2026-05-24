import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'services/download_service.dart';
import 'services/playback_service.dart';
import 'services/share_service.dart';
import 'widgets/dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize lock screen playback engine
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.voidarchive.youtube_mobile.channel.audio',
      androidNotificationChannelName: 'Lecture Playback',
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
      title: 'Void Archive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xff080b0e),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff0a0d14),
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff00d2ff),
          primary: const Color(0xff00d2ff),
          secondary: const Color(0xff00ff88),
          background: const Color(0xff080b0e),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const Color(0xff00ff88);
            }
            return Colors.blueGrey;
          }),
          trackColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const Color(0xff00ff88).withOpacity(0.4);
            }
            return Colors.blueGrey.withOpacity(0.4);
          }),
        ),
      ),
      home: const Dashboard(),
    );
  }
}
