import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/theme/glassmorphism.dart';
import 'package:frontend/widgets/interactive_scale.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? ctaLabel;
  final VoidCallback? onCtaPressed;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.ctaLabel,
    this.onCtaPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[600];

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: GlassContainer(
          isDarkMode: isDark,
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with glowing circle background
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(isDark ? 0.12 : 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(isDark ? 0.25 : 0.15),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              // Description
              Text(
                description,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  height: 1.4,
                  color: subtitleColor,
                ),
              ),
              // CTA Button (Optional)
              if (ctaLabel != null && onCtaPressed != null) ...[
                const SizedBox(height: 28),
                InteractiveScale(
                  onTap: onCtaPressed!,
                  child: ElevatedButton(
                    onPressed: () {}, // Action handled by InteractiveScale onTap wrapper
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                    ),
                    child: Text(
                      ctaLabel!,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
