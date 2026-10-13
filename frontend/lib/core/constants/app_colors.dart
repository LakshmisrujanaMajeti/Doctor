import 'package:flutter/material.dart';

class AppColors {
  // Brand Healthcare Palette: Healthcare Blue & Subtle Teal Accents
  static const Color primaryBlue = Color(0xFF0F62FE);      // Clean medical blue
  static const Color primaryBlueDark = Color(0xFF0043CE);  // Deep hospital navy
  static const Color primaryBlueLight = Color(0xFFEDF5FF); // Soft healthcare blue wash

  static const Color accentTeal = Color(0xFF00A896);       // Modern subtle healthcare teal
  static const Color accentTealDark = Color(0xFF028090);
  static const Color accentTealLight = Color(0xFFE6F7F5);

  // Backward-compatible alias
  static const Color primaryTeal = accentTeal;
  static const Color primaryDark = primaryBlueDark;
  static const Color primaryLight = primaryBlueLight;
  static const Color secondaryNavy = primaryBlueDark;
  static const Color secondaryLight = primaryBlueLight;
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color borderLight = lightBorder;
  static const Color cardBackgroundLight = lightCard;

  // Triage Priorities (Hospital OPD Standard)
  static const Color triageNormal = Color(0xFF10B981);    // Emerald Green
  static const Color triagePriority = Color(0xFFF59E0B);  // Warm Amber
  static const Color triageEmergency = Color(0xFFEF4444); // Urgent Crimson

  // Status Indicators
  static const Color statusRegistered = Color(0xFF0F62FE);
  static const Color statusTriaged = Color(0xFF8A3FFC);
  static const Color statusInConsult = Color(0xFFFF832B);
  static const Color statusCompleted = Color(0xFF10B981);
  static const Color statusCancelled = Color(0xFF8D8D8D);

  // Light Mode Surfaces
  static const Color lightBg = Color(0xFFF4F7FB);
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF161616);
  static const Color lightTextSecondary = Color(0xFF525252);

  // Dark Mode Surfaces
  static const Color darkBg = Color(0xFF12161F);
  static const Color darkCard = Color(0xFF1B2232);
  static const Color darkBorder = Color(0xFF2C364C);
  static const Color darkTextPrimary = Color(0xFFF4F7FB);
  static const Color darkTextSecondary = Color(0xFFA2A9B8);
}
