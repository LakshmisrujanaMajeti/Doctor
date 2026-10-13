import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opd_connect/core/constants/app_strings.dart';
import 'package:opd_connect/features/auth/screens/forgot_password_screen.dart';
import 'package:opd_connect/features/auth/screens/onboarding_screen.dart';
import 'package:opd_connect/features/auth/screens/profile_setup_screen.dart';
import 'package:opd_connect/features/auth/screens/splash_screen.dart';
import 'package:opd_connect/features/auth/screens/welcome_screen.dart';
import 'package:opd_connect/features/notifications/screens/notifications_screen.dart';
import 'package:opd_connect/features/settings/screens/settings_screen.dart';
import 'package:opd_connect/shared/screens/empty_screen.dart';
import 'package:opd_connect/shared/screens/loading_screen.dart';
import 'package:opd_connect/shared/screens/not_found_screen.dart';
import 'package:opd_connect/shared/screens/offline_screen.dart';
import 'package:opd_connect/shared/screens/unauthorized_screen.dart';
import 'package:opd_connect/shared/widgets/empty_state_widget.dart';
import 'package:opd_connect/shared/widgets/error_banner_widget.dart';
import 'package:opd_connect/shared/widgets/opd_button.dart';
import 'package:opd_connect/shared/widgets/opd_card.dart';
import 'package:opd_connect/shared/widgets/opd_text_field.dart';

void main() {
  group('OPD Connect+ Reusable Components Tests', () {
    testWidgets('OpdButton renders label and responds to taps',
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OpdButton(
              label: 'Confirm Patient',
              icon: Icons.check,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Confirm Patient'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('Confirm Patient'));
      expect(tapped, isTrue);
    });

    testWidgets('OpdButton displays CircularProgressIndicator when loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OpdButton(
              label: 'Submit',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
    });

    testWidgets('OpdTextField renders label and hint text',
        (WidgetTester tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OpdTextField(
              label: 'UHID Number',
              hint: 'UHID-2026-00001',
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text('UHID Number'), findsOneWidget);
      expect(find.text('UHID-2026-00001'), findsOneWidget);
    });

    testWidgets('OpdCard displays child content and handles tap',
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OpdCard(
              onTap: () => tapped = true,
              child: const Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      await tester.tap(find.text('Card Content'));
      expect(tapped, isTrue);
    });

    testWidgets('EmptyStateWidget renders title and message',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              title: 'No Active Visits',
              message: 'The outpatient hall queue is empty.',
            ),
          ),
        ),
      );

      expect(find.text('No Active Visits'), findsOneWidget);
      expect(find.text('The outpatient hall queue is empty.'), findsOneWidget);
    });

    testWidgets('ErrorBannerWidget displays error and invokes retry',
        (WidgetTester tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorBannerWidget(
              message: 'Failed to synchronize with hospital server.',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Failed to synchronize with hospital server.'),
          findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });

  group('OPD Connect+ Core Screens Tests', () {
    testWidgets('SplashScreen displays app name and hospital branding',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.tagline), findsOneWidget);
      expect(find.byIcon(Icons.local_hospital_rounded), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2000));
    });

    testWidgets('OnboardingScreen displays digital records introduction',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      expect(find.text('Digital OPD Records'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('WelcomeScreen displays Sign In and Register options',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WelcomeScreen(),
          ),
        ),
      );

      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text('Sign In to Portal'), findsOneWidget);
      expect(find.text('Register New Account'), findsOneWidget);
      expect(find.text('Doctor Portal'), findsOneWidget);
    });

    testWidgets('ForgotPasswordScreen renders reset input field',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Send Recovery Link'), findsOneWidget);
    });

    testWidgets('ProfileSetupScreen displays role selection form',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ProfileSetupScreen(),
          ),
        ),
      );

      expect(find.text('Hospital Profile Setup'), findsOneWidget);
      expect(find.text('1. Authorized Role *'), findsOneWidget);
      expect(find.text('Full Name *'), findsOneWidget);
    });

    testWidgets('NotificationsScreen displays category filter chips',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NotificationsScreen(),
        ),
      );

      expect(find.text('Hospital Alerts'), findsOneWidget);
      expect(find.text('All Updates'), findsOneWidget);
      expect(find.text('Triage Alerts'), findsOneWidget);
      expect(find.text('Queue Updates'), findsOneWidget);
      expect(find.text('Lab Reports'), findsOneWidget);
    });

    testWidgets('SettingsScreen displays profile and appearance options',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      expect(find.text('Profile & Hospital Settings'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('Simulate Clinical Role Perspective'), findsOneWidget);
      expect(find.text('Sign Out of OPD Connect+'), findsOneWidget);
    });
  });

  group('OPD Connect+ System State Screens Tests', () {
    testWidgets('LoadingScreen displays title, message, and return button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoadingScreen(
            title: 'Loading Queue',
            message: 'Fetching live outpatient queue data...',
          ),
        ),
      );

      expect(find.text('Loading Queue'), findsOneWidget);
      expect(find.text('Fetching live outpatient queue data...'), findsOneWidget);
      expect(find.text('Return to Dashboard'), findsOneWidget);
    });

    testWidgets('EmptyScreen displays empty state message',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmptyScreen(
            title: 'No Consultations',
            description: 'No consultations booked for this shift.',
          ),
        ),
      );

      expect(find.text('No Consultations'), findsOneWidget);
      expect(find.text('No consultations booked for this shift.'), findsOneWidget);
    });

    testWidgets('OfflineScreen displays offline warning and retry button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OfflineScreen(),
        ),
      );

      expect(find.text('Hospital Network Offline'), findsOneWidget);
      expect(find.text('Retry Network Connection'), findsOneWidget);
      expect(find.text('Continue in Offline Cache Mode'), findsOneWidget);
    });

    testWidgets('UnauthorizedScreen displays 403 access warning',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UnauthorizedScreen(
            currentRole: 'Receptionist',
            requiredRole: 'Doctor',
          ),
        ),
      );

      expect(find.text('Clinical Clearance Required'), findsOneWidget);
      expect(find.text('Return to Authorized Dashboard'), findsOneWidget);
      expect(find.text('RECEPTIONIST'), findsOneWidget);
      expect(find.text('DOCTOR'), findsOneWidget);
    });

    testWidgets('NotFoundScreen displays 404 message and dashboard button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NotFoundScreen(path: '/unknown/clinical/route'),
        ),
      );

      expect(find.text('404 - Screen Not Found'), findsOneWidget);
      expect(find.text('/unknown/clinical/route'), findsOneWidget);
      expect(find.text('Return to OPD Dashboard'), findsOneWidget);
    });
  });
}
