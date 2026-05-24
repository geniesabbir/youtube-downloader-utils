import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import 'brand_mark.dart';

class BrandedSplashScreen extends StatelessWidget {
  const BrandedSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BrandBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BrandOrbit(size: 180)
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .scale(begin: const Offset(0.92, 0.92)),
                  const SizedBox(height: 28),
                  const BrandLockup(
                    markSize: 0,
                    showTagline: false,
                  )
                      .animate()
                      .fadeIn(delay: 220.ms, duration: 400.ms)
                      .slideY(begin: 0.18, end: 0),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      "Archive video cleanly, keep playback local, and make every saved file feel organized from the first tap.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.cloud.withOpacity(0.72),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ).animate().fadeIn(delay: 420.ms, duration: 400.ms),
                  const SizedBox(height: 36),
                  Container(
                    width: 120,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.cyan, AppColors.mint],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ).animate(onPlay: (controller) => controller.repeat(reverse: true)).moveX(
                          begin: 0,
                          end: 72,
                          duration: 900.ms,
                          curve: Curves.easeInOut,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
