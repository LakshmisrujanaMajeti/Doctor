import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

enum LogoLayout {
  iconOnly,
  horizontal,
  vertical,
}

/// Official Sri Manakula Vinayagar Medical College and Hospital (SMVMCH) Logo & Crest
class SmvmchHospitalLogo extends StatelessWidget {
  final double size;
  final LogoLayout layout;
  final bool showTamilText;
  final Color? iconColor;

  const SmvmchHospitalLogo({
    super.key,
    this.size = 48,
    this.layout = LogoLayout.iconOnly,
    this.showTamilText = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final emblem = _buildCrestEmblem(context);

    if (layout == LogoLayout.iconOnly) {
      return emblem;
    }

    if (layout == LogoLayout.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          emblem,
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showTamilText)
                  const Text(
                    AppStrings.hospitalTamilName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.hospitalMaroon,
                      letterSpacing: -0.2,
                    ),
                  ),
                const Text(
                  'SRI MANAKULA VINAYAGAR',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: AppColors.hospitalNavy,
                  ),
                ),
                Text(
                  'Medical College & Hospital • Puducherry',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Vertical layout
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        emblem,
        const SizedBox(height: 12),
        if (showTamilText)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppStrings.hospitalTamilName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.hospitalMaroon,
                letterSpacing: -0.2,
              ),
            ),
          ),
        const SizedBox(height: 2),
        const Text(
          'SRI MANAKULA VINAYAGAR',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: AppColors.hospitalNavy,
          ),
        ),
        const Text(
          'MEDICAL COLLEGE AND HOSPITAL',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Kalitheerthalkuppam, Madagadipet, Puducherry - 605 107',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCrestEmblem(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: size * 0.15,
            offset: Offset(0, size * 0.04),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF1E295A).withValues(alpha: 0.18),
          width: size > 40 ? 1.5 : 1.0,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/medical_college.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildFallbackCrest(context),
        ),
      ),
    );
  }

  Widget _buildFallbackCrest(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.2, -0.3),
          radius: 1.1,
          colors: [
            Color(0xFF831843), // Vivid royal maroon
            Color(0xFF500724), // Deep maroon border
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFDE047),
          width: size > 40 ? 2.5 : 1.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Icon(
              Icons.temple_hindu_rounded,
              size: size * 0.48,
              color: iconColor ?? const Color(0xFFFEF08A),
            ),
          ),
          Positioned(
            bottom: size * 0.06,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: size * 0.08, vertical: size * 0.02),
              decoration: BoxDecoration(
                color: const Color(0xFF1E295A),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFDE047), width: 0.8),
              ),
              child: Text(
                'SMVMCH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: (size * 0.14).clamp(6.0, 11.0),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
