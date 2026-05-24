import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BrandBackdrop extends StatelessWidget {
  final Widget child;

  const BrandBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xff09101a),
            AppColors.ink,
            Color(0xff030508),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -40,
            child: _GlowOrb(
              size: 260,
              colors: [
                AppColors.cyan.withOpacity(0.24),
                Colors.transparent,
              ],
            ),
          ),
          Positioned(
            top: 160,
            right: -120,
            child: _GlowOrb(
              size: 320,
              colors: [
                AppColors.mint.withOpacity(0.16),
                Colors.transparent,
              ],
            ),
          ),
          Positioned(
            bottom: -100,
            left: 40,
            child: _GlowOrb(
              size: 240,
              colors: [
                const Color(0xff4c6fff).withOpacity(0.14),
                Colors.transparent,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _GlowOrb({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  final double size;

  const BrandMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.cyan, AppColors.mint],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withOpacity(0.24),
              blurRadius: 26,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.06),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xff0a1018),
              borderRadius: BorderRadius.circular(size * 0.24),
            ),
            child: CustomPaint(
              painter: _BrandMarkPainter(),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cyanPaint = Paint()
      ..color = AppColors.cyan
      ..strokeWidth = size.width * 0.11
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final mintPaint = Paint()
      ..color = AppColors.mint
      ..strokeWidth = size.width * 0.11
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final accentPaint = Paint()
      ..color = Colors.white.withOpacity(0.16)
      ..strokeWidth = size.width * 0.04
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final left = Offset(size.width * 0.28, size.height * 0.28);
    final bottom = Offset(size.width * 0.50, size.height * 0.70);
    final right = Offset(size.width * 0.72, size.height * 0.28);

    canvas.drawLine(left, bottom, cyanPaint);
    canvas.drawLine(bottom, right, mintPaint);

    final archive = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.31,
        size.height * 0.18,
        size.width * 0.38,
        size.height * 0.10,
      ),
      Radius.circular(size.width * 0.06),
    );
    canvas.drawRRect(archive, accentPaint);

    final dotPaint = Paint()..color = Colors.white.withOpacity(0.75);
    canvas.drawCircle(
      Offset(size.width * 0.73, size.height * 0.68),
      size.width * 0.035,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BrandLockup extends StatelessWidget {
  final double markSize;
  final bool compact;
  final bool? showTagline;

  const BrandLockup({
    super.key,
    this.markSize = 56,
    this.compact = false,
    this.showTagline,
  });

  @override
  Widget build(BuildContext context) {
    final displayTagline = showTagline ?? !compact;

    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (markSize > 0) ...[
          BrandMark(size: markSize),
          SizedBox(width: compact ? 12 : 16),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.cloud, AppColors.cyan],
              ).createShader(bounds),
              child: Text(
                "VOID ARCHIVE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 18 : 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: compact ? 1.6 : 2.4,
                ),
              ),
            ),
            if (displayTagline) ...[
              const SizedBox(height: 4),
              Text(
                "Private offline capture for lectures and long-form video.",
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: compact ? 10 : 12,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class BrandOrbit extends StatefulWidget {
  final double size;

  const BrandOrbit({super.key, this.size = 164});

  @override
  State<BrandOrbit> createState() => _BrandOrbitState();
}

class _BrandOrbitState extends State<BrandOrbit> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: _controller.value * math.pi * 2,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
              ),
              Transform.rotate(
                angle: -_controller.value * math.pi * 2,
                child: Container(
                  width: widget.size * 0.76,
                  height: widget.size * 0.76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.cyan.withOpacity(0.18),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.mint,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 20, bottom: 18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cyan.withOpacity(0.8),
                  ),
                ),
              ),
              BrandMark(size: widget.size * 0.52),
            ],
          );
        },
      ),
    );
  }
}
