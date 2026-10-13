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

class RolePreset {
  final String roleKey;
  final String title;
  final String email;
  final String password;
  final String subtitle;
  final IconData icon;

  const RolePreset({
    required this.roleKey,
    required this.title,
    required this.email,
    required this.password,
    required this.subtitle,
    required this.icon,
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

  static const List<RolePreset> rolePresets = [
    RolePreset(
      roleKey: 'doctor',
      title: 'Doctor Portal',
      subtitle: 'Dr. Sarah Chen, MD (General Medicine)',
      email: 'dr.chen@opdconnect.com',
      password: 'Doctor@123456',
      icon: Icons.medical_services_rounded,
    ),
    RolePreset(
      roleKey: 'receptionist',
      title: 'Reception & Desk',
      subtitle: 'Alice Adams (Registration & Tokens)',
      email: 'receptionist@opdconnect.com',
      password: 'Reception@123456',
      icon: Icons.desk_rounded,
    ),
    RolePreset(
      roleKey: 'laboratory',
      title: 'Laboratory Staff',
      subtitle: 'Marcus Vance (Lab Orders & Results)',
      email: 'lab@opdconnect.com',
      password: 'Lab@123456',
      icon: Icons.biotech_rounded,
    ),
    RolePreset(
      roleKey: 'pharmacist',
      title: 'Pharmacy Portal',
      subtitle: 'Elena Rostova (Dispensing & Inventory)',
      email: 'pharmacist@opdconnect.com',
      password: 'Pharmacy@123456',
      icon: Icons.medication_rounded,
    ),
    RolePreset(
      roleKey: 'admin',
      title: 'Hospital Admin',
      subtitle: 'Admin Administrator (Users & Config)',
      email: 'admin@opdconnect.com',
      password: 'Admin@123456',
      icon: Icons.admin_panel_settings_rounded,
    ),
    RolePreset(
      roleKey: 'patient',
      title: 'Patient Portal',
      subtitle: 'Johnathan Reynolds (UHID-2026-00001)',
      email: 'patient@opdconnect.com',
      password: 'Patient@123456',
      icon: Icons.person_rounded,
    ),
  ];

  static const List<HospitalNotificationItem> sampleNotifications = [
    HospitalNotificationItem(
      id: 'notif-1',
      title: 'Emergency Triage Alert',
      message: 'Token #14 assigned Emergency priority by triage nurse. Room 104 notified.',
      timeAgo: '4m ago',
      category: 'alert',
      isRead: false,
      icon: Icons.warning_amber_rounded,
      color: AppColors.triageEmergency,
    ),
    HospitalNotificationItem(
      id: 'notif-2',
      title: 'Lab Report Completed',
      message: 'Complete Blood Count (CBC) report ready for UHID-2026-00001.',
      timeAgo: '22m ago',
      category: 'lab',
      isRead: false,
      icon: Icons.biotech_rounded,
      color: AppColors.primaryBlue,
    ),
    HospitalNotificationItem(
      id: 'notif-3',
      title: 'Prescription Dispensed',
      message: 'Prescription for Token #1 dispensed at Pharmacy Counter 2.',
      timeAgo: '1h ago',
      category: 'pharmacy',
      isRead: true,
      icon: Icons.medication_rounded,
      color: AppColors.accentTeal,
    ),
    HospitalNotificationItem(
      id: 'notif-4',
      title: 'OPD Session Scheduled',
      message: 'Pediatrics Clinic OPD morning session begins at 09:00 AM in Block B.',
      timeAgo: '2h ago',
      category: 'queue',
      isRead: true,
      icon: Icons.event_available_rounded,
      color: AppColors.primaryBlueDark,
    ),
  ];
}
