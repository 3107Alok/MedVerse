import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool isDarkMode;
  final Color? baseColor;
  final double blur;
  final Border? border;
  final bool showAccentCircle;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
    this.isDarkMode = false,
    this.baseColor,
    this.blur = 15.0,
    this.border,
    this.showAccentCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    final defaultBg = isDarkMode
        ? const Color(0xFF1E1E2E).withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.6);
        
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.4);

    final shadowColor = isDarkMode
        ? Colors.black.withValues(alpha: 0.3)
        : const Color(0xFF9E84FF).withValues(alpha: 0.1);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: showAccentCircle ? null : padding,
            decoration: BoxDecoration(
              color: baseColor ?? defaultBg,
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ??
                  Border.all(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
            ),
            child: showAccentCircle
                ? CustomPaint(
                    painter: CirclePainter(
                      color: (isDarkMode ? Colors.white : const Color(0xFF9C27B0))
                          .withValues(alpha: isDarkMode ? 0.05 : 0.07),
                    ),
                    child: Padding(
                      padding: padding ?? EdgeInsets.zero,
                      child: child,
                    ),
                  )
                : child,
          ),
        ),
      ),
    );
  }
}

class CirclePainter extends CustomPainter {
  final Color color;
  CirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(size.width + 10, -10), 65, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GlassLoadingIndicator extends StatelessWidget {
  final bool isDarkMode;
  
  const GlassLoadingIndicator({super.key, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassContainer(
        isDarkMode: isDarkMode,
        width: 80,
        height: 80,
        borderRadius: 20,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9E84FF)), // Lavender
          ),
        ),
      ),
    );
  }
}
