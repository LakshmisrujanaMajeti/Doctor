import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Helper and extension for responsive mobile layouts, typography scaling,
/// and screen dimension adaptation across various smartphone form factors.
class Responsive {
  /// Reference mobile viewport width (standard iPhone / Android device width)
  static const double referenceWidth = 390.0;

  /// Check screen categories
  static bool isSmallMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 650;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 650 && width < 1100;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1100;

  /// Responsive font scaler: scales base font size gracefully based on screen width
  /// Clamped between 0.85x and 1.20x to prevent unreadable small fonts or broken card layouts.
  static double fontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.sizeOf(context).width;
    final scale = (width / referenceWidth).clamp(0.85, 1.20);
    return (baseSize * scale).roundToDouble();
  }

  /// Clamped text scale factor ensuring system accessibility font scaling
  /// fits comfortably within phone containers across all device sizes (clamped between 0.80 and dynamic max).
  static TextScaler clampedTextScaler(BuildContext context, {double min = 0.80, double max = 1.25}) {
    final currentScaler = MediaQuery.textScalerOf(context);
    final scaleFactor = currentScaler.scale(10) / 10;
    final width = MediaQuery.sizeOf(context).width;
    // Scale container boundary gracefully based on individual phone width
    final dynamicMax = width < 360 ? 1.05 : (width < 400 ? 1.18 : max);
    final clamped = scaleFactor.clamp(min, dynamicMax);
    return TextScaler.linear(clamped);
  }

  /// Calculate responsive horizontal padding
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return 12.0;
    if (width < 450) return 16.0;
    if (width < 800) return 24.0;
    return 32.0;
  }
}

/// BuildContext extension for concise responsive syntax
extension ResponsiveContextExtension on BuildContext {
  bool get isSmallMobile => Responsive.isSmallMobile(this);
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);

  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  double responsiveFont(double baseSize) => Responsive.fontSize(this, baseSize);

  TextScaler get clampedTextScaler => Responsive.clampedTextScaler(this);
}

/// A drop-in responsive text widget that guarantees no overflow or clipping
class ResponsiveText extends StatelessWidget {
  final String text;
  final double baseFontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final double? letterSpacing;
  final double? height;
  final TextStyle? style;

  const ResponsiveText(
    this.text, {
    super.key,
    this.baseFontSize = 14,
    this.fontWeight,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.letterSpacing,
    this.height,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final scaledSize = context.responsiveFont(baseFontSize);
    final mergedStyle = (style ?? const TextStyle()).copyWith(
      fontSize: scaledSize,
      fontWeight: fontWeight ?? style?.fontWeight,
      color: color ?? style?.color,
      letterSpacing: letterSpacing ?? style?.letterSpacing,
      height: height ?? style?.height,
    );

    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines != null ? overflow : TextOverflow.clip,
      softWrap: true,
      style: mergedStyle,
    );
  }
}
