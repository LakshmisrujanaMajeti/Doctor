import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opd_connect/core/utils/responsive.dart';
import 'package:opd_connect/shared/widgets/triage_chip.dart';
import 'package:opd_connect/shared/widgets/status_badge.dart';
import 'package:opd_connect/shared/widgets/opd_card.dart';

void main() {
  group('Responsive Breakpoints and Screen Detection', () {
    testWidgets('Responsive correctly identifies mobile vs desktop dimensions', (tester) async {
      // 1. Mobile viewport (360x800)
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late bool isMobile;
      late bool isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isMobile = context.isMobile;
              isDesktop = context.isDesktop;
              return const Scaffold(body: Text('Viewport'));
            },
          ),
        ),
      );

      expect(isMobile, isTrue);
      expect(isDesktop, isFalse);

      // 2. Desktop viewport (1366x768)
      tester.view.physicalSize = const Size(1366, 768);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isMobile = context.isMobile;
              isDesktop = context.isDesktop;
              return const Scaffold(body: Text('Viewport Desktop'));
            },
          ),
        ),
      );

      expect(isMobile, isFalse);
      expect(isDesktop, isTrue);
    });
  });

  group('Mobile Responsive Patient Card Layout Tests', () {
    testWidgets('Patient Card renders full width on 360x800 mobile without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: OpdCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.confirmation_number_outlined, size: 13),
                              SizedBox(width: 4),
                              Text('SMVMCH1510260001', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              SizedBox(width: 4),
                              Text('#1', style: TextStyle(fontSize: 10.5)),
                            ],
                          ),
                        ),
                        const Wrap(
                          spacing: 6,
                          children: [
                            TriageChip(priority: 'NORMAL', compact: true),
                            StatusBadge(status: 'IN_CONSULTATION'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Patient SMVMCH1510260001',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'UHID Pending • General Medicine',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Patient SMVMCH1510260001'), findsOneWidget);
      expect(find.text('SMVMCH1510260001'), findsOneWidget);
      expect(find.text('UHID Pending • General Medicine'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Patient Card renders cleanly on 1366x768 desktop view', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: OpdCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: const Column(
                        children: [
                          Text('TOKEN', style: TextStyle(fontSize: 7.5)),
                          Text('SMVMCH1510260001', style: TextStyle(fontSize: 9.5)),
                          Text('Seq #1', style: TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Patient SMVMCH1510260001', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                          SizedBox(height: 3),
                          Text('UHID Pending • General Medicine', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TriageChip(priority: 'NORMAL', compact: true),
                        SizedBox(height: 4),
                        StatusBadge(status: 'IN_CONSULTATION'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Patient SMVMCH1510260001'), findsOneWidget);
      expect(find.text('SMVMCH1510260001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('NavigationBar destinations with concise labels do not wrap or overflow on 360px', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: NavigationBar(
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
                NavigationDestination(icon: Icon(Icons.queue_play_next_rounded), label: 'Queue'),
                NavigationDestination(icon: Icon(Icons.admin_panel_settings_rounded), label: 'Admin'),
                NavigationDestination(icon: Icon(Icons.people_alt_rounded), label: 'Patients'),
                NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Queue'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Patients'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
