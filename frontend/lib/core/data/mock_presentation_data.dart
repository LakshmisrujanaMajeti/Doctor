import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Explicit presentation models used exclusively for UI demonstration
/// and clearly separated from production API data.

class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;

  const OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
  });
}

class HospitalNotificationItem {
  final String id;
  final String title;
  final String message;
  final String timeAgo;
  final String category; // 'queue', 'alert', 'lab', 'pharmacy'
  final bool isRead;
  final IconData icon;
  final Color color;

  const HospitalNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.category,
    required this.isRead,
    required this.icon,
    required this.color,
  });
}


class MockPresentationData {
  static const List<OnboardingItem> onboardingItems = [
    OnboardingItem(
      title: 'Digital OPD Records',
      description:
          'Seamless outpatient booklet digitization. Access patient history, allergies, and diagnostic charts in seconds.',
      icon: Icons.menu_book_rounded,
      accentColor: AppColors.primaryBlue,
    ),
    OnboardingItem(
      title: 'Smart Token Queue',
      description:
          'Live token tracking with clinical triage priority. Coordinate waiting rooms, triage nurses, and doctors smoothly.',
      icon: Icons.confirmation_number_rounded,
      accentColor: AppColors.accentTeal,
    ),
    OnboardingItem(
      title: 'Connected Hospital Care',
      description:
          'Integrated e-prescriptions, instant laboratory requests, and private encrypted medical document storage.',
      icon: Icons.hub_rounded,
      accentColor: AppColors.primaryBlueDark,
    ),
  ];
}
