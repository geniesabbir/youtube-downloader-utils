import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import 'brand_mark.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _controller = PageController();
  int _page = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      eyebrow: "BATCH CONTROL",
      title: "Paste single links, large batches, or playlist URLs without chaos.",
      body:
          "YT Utils is being shaped around deliberate queueing. Instead of flooding the app the moment you paste links, the next version is planned around staged review, cleaner batch starts, and better high-volume control.",
      icon: Icons.queue_rounded,
      colors: [AppColors.cyan, Color(0xff4a7dff)],
      highlights: [
        "Stage pasted URLs before adding them",
        "Start one controlled batch instead of instant queue spam",
        "Keep large link sets readable and editable",
      ],
    ),
    _OnboardingPageData(
      eyebrow: "PLAYLIST READY",
      title: "Handle real YouTube workflows: playlists, retries, and parallel downloads.",
      body:
          "The core feature is still downloading, but it needs the settings and pipeline serious users expect. The roadmap now includes playlist ingestion, selected-entry downloads, and user-controlled concurrency with a stable default.",
      icon: Icons.download_for_offline_rounded,
      colors: [Color(0xff7bffb2), Color(0xff2ed8a3)],
      highlights: [
        "Playlist summary before starting",
        "Default 3 concurrent downloads",
        "Retry, pause, and waiting-state clarity",
      ],
    ),
    _OnboardingPageData(
      eyebrow: "OFFLINE UTILITY",
      title: "Keep files local, split audio and video cleanly, and make playback feel standard.",
      body:
          "This app should feel like a real offline media utility, not a temporary downloader. That means public files, persistent libraries, separate audio and video access, and familiar playback instead of awkward custom behavior.",
      icon: Icons.play_circle_fill_rounded,
      colors: [Color(0xff8fc7ff), Color(0xff7bffb2)],
      highlights: [
        "Public local storage that survives reloads",
        "Separate audio and video library tabs",
        "Cleaner standard player experience",
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _advance() {
    if (_page == _pages.length - 1) {
      widget.onComplete();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _pages[_page];
    final height = MediaQuery.sizeOf(context).height;
    final compact = height < 760;

    return BrandBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, compact ? 14 : 18, 24, compact ? 18 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: BrandLockup(
                        compact: true,
                        markSize: 42,
                        showTagline: false,
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onComplete,
                      child: const Text("Skip"),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 16 : 24),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (index) => setState(() => _page = index),
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return _OnboardingPanel(page: page);
                    },
                  ),
                ),
                SizedBox(height: compact ? 14 : 18),
                Row(
                  children: [
                    ...List.generate(_pages.length, (index) {
                      final active = index == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        margin: const EdgeInsets.only(right: 8),
                        width: active ? 28 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: active
                              ? const LinearGradient(
                                  colors: [AppColors.cyan, AppColors.mint],
                                )
                              : null,
                          color: active ? null : Colors.white.withOpacity(0.14),
                        ),
                      );
                    }),
                    const Spacer(),
                    Text(
                      "${_page + 1}/${_pages.length}",
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 14 : 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.panel.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.eyebrow,
                        style: const TextStyle(
                          color: AppColors.cyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        current.footerTitle,
                        style: const TextStyle(
                          color: AppColors.cloud,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        current.footerBody,
                        style: TextStyle(
                          color: AppColors.cloud.withOpacity(0.68),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _advance,
                          child: Text(_page == _pages.length - 1 ? "Enter App" : "Next"),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 320.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPanel extends StatelessWidget {
  final _OnboardingPageData page;

  const _OnboardingPanel({required this.page});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        final iconShell = compact ? 140.0 : 168.0;
        final iconSize = compact ? 72.0 : 82.0;
        final titleSize = compact ? 20.0 : 24.0;

        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: EdgeInsets.all(compact ? 20 : 24),
            decoration: BoxDecoration(
              color: AppColors.panel.withOpacity(0.78),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.stroke),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: iconShell + 44,
                      height: iconShell + 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            page.colors.first.withOpacity(0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: iconShell,
                        height: iconShell,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(36),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              page.colors.first.withOpacity(0.16),
                              page.colors.last.withOpacity(0.06),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            page.icon,
                            size: iconSize,
                            color: page.colors.first,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 18),
                  Text(
                    page.eyebrow,
                    style: const TextStyle(
                      color: AppColors.cyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    page.title,
                    style: TextStyle(
                      color: AppColors.cloud,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    page.body,
                    style: TextStyle(
                      color: AppColors.cloud.withOpacity(0.72),
                      fontSize: compact ? 13.5 : 14.5,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...page.highlights.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FeatureLine(
                        color: page.colors.first,
                        label: item,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.06, end: 0);
      },
    );
  }
}

class _FeatureLine extends StatelessWidget {
  final Color color;
  final String label;

  const _FeatureLine({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.cloud.withOpacity(0.88),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingPageData {
  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
  final List<Color> colors;
  final List<String> highlights;

  const _OnboardingPageData({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
    required this.colors,
    required this.highlights,
  });

  String get footerTitle {
    switch (eyebrow) {
      case "BATCH CONTROL":
        return "Next up: staged batch start";
      case "PLAYLIST READY":
        return "Planned defaults: playlist support + 3-way concurrency";
      case "OFFLINE UTILITY":
        return "Goal: cleaner libraries and more familiar playback";
      default:
        return title;
    }
  }

  String get footerBody {
    switch (eyebrow) {
      case "BATCH CONTROL":
        return "We are building this around safer high-volume queueing, not accidental paste-and-pray behavior.";
      case "PLAYLIST READY":
        return "Heavy users need playlist import, retry clarity, and download settings that respect speed and stability.";
      case "OFFLINE UTILITY":
        return "The app should feel like a polished media tool after download, not just a downloader before it.";
      default:
        return body;
    }
  }
}
