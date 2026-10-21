import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opd_connect/shared/widgets/status_badge.dart';
import 'package:opd_connect/shared/widgets/triage_chip.dart';
import 'package:opd_connect/shared/widgets/stat_metric_card.dart';

void main() {
  testWidgets('TriageChip renders EMERGENCY with correct styling', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TriageChip(priority: 'EMERGENCY'),
        ),
      ),
    );

    expect(find.text('EMERGENCY'), findsOneWidget);
    expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
  });

  testWidgets('StatusBadge renders TRIAGED badge correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBadge(status: 'TRIAGED'),
        ),
      ),
    );

    expect(find.text('TRIAGED'), findsOneWidget);
  });

  testWidgets('StatMetricCard displays title, count and icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatMetricCard(
            title: 'Waiting in Queue',
            value: '12',
            icon: Icons.hourglass_top_rounded,
            color: Colors.amber,
          ),
        ),
      ),
    );

    expect(find.text('Waiting in Queue'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
  });
}
