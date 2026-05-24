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
      eyebrow: "BATCH FASTER",
      title: "Paste one link or fifty. Stay in control of the batch.",
      body:
          "YT Utils is built for real download volume. Queue single links, large pasted batches, and later playlist jobs without turning the app into a mess.",
      icon: Icons.queue_rounded,
      colors: [AppColors.cyan, Color(0xff4a7dff)],
    ),
    _OnboardingPageData(
      eyebrow: "KEEP THE FILES",
      title: "Your downloads should behave like actual media files.",
      body:
          "Saved audio and video should survive reloads, stay visible in library, and remain accessible from public storage instead of being trapped in a streaming app silo.",
      icon: Icons.download_done_rounded,
      colors: [Color(0xff7bffb2), Color(0xff2ed8a3)],
    ),
    _OnboardingPageData(
      eyebrow: "USEFUL OFFLINE",
      title: "Organize, search, and play offline media without fighting the UI.",
      body:
          "The goal is not just downloading. YT Utils is being built to give users what YouTube still lacks: better queueing, clearer libraries, and faster offline access.",
      icon: Icons.play_circle_fill_rounded,
      colors: [Color(0xff8fc7ff), Color(0xff7bffb2)],
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

    return BrandBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
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
                const SizedBox(height: 24),
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
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
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
                        current.title,
                        style: const TextStyle(
                          color: AppColors.cloud,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
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
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      page.colors.first.withOpacity(0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 156,
                  height: 156,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        page.colors.first.withOpacity(0.22),
                        page.colors.last.withOpacity(0.08),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      page.icon,
                      size: 82,
                      color: page.colors.first,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
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
              style: const TextStyle(
                color: AppColors.cloud,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              page.body,
              style: TextStyle(
                color: AppColors.cloud.withOpacity(0.72),
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoChip(
                  icon: Icons.shield_outlined,
                  label: "Public local storage",
                ),
                _InfoChip(
                  icon: Icons.offline_bolt_outlined,
                  label: "Offline-first playback",
                ),
                _InfoChip(
                  icon: Icons.auto_awesome_outlined,
                  label: "Batch-friendly workflow",
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.06, end: 0);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.mint),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.cloud,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
  final List<Color> colors;

  const _OnboardingPageData({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
    required this.colors,
  });
}
