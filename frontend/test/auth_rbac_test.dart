import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opd_connect/features/auth/models/auth_state.dart';
import 'package:opd_connect/features/auth/providers/auth_provider.dart';
import 'package:opd_connect/features/dashboard/screens/role_dashboard_shell.dart';
import 'package:opd_connect/core/storage/secure_storage_service.dart';

void main() {
  group('Auth & RBAC Role Dashboard Shell Tests', () {
    test('All 6 role models deserialize correctly', () {
      final roles = ['patient', 'doctor', 'receptionist', 'laboratory', 'pharmacist', 'admin'];
      for (final r in roles) {
        final json = {
          'id': 'usr-$r',
          'email': '$r@opdconnect.com',
          'full_name': 'Test $r',
          'phone': '+1555000000',
          'role': {'id': 'r-1', 'name': r, 'code': r.toUpperCase()}
        };
        final user = UserModel.fromJson(json);
        expect(user.roleName, equals(r));
        expect(user.email, equals('$r@opdconnect.com'));
      }
    });

    test('SecureStorageService saves and clears tokens', () async {
      SharedPreferences.setMockInitialValues({});
      await SecureStorageService.saveTokens(
        accessToken: 'mock_jwt_access_token',
        refreshToken: 'mock_jwt_refresh_token',
        role: 'doctor',
      );

      final access = await SecureStorageService.getAccessToken();
      final refresh = await SecureStorageService.getRefreshToken();
      final role = await SecureStorageService.getUserRole();

      expect(access, equals('mock_jwt_access_token'));
      expect(refresh, equals('mock_jwt_refresh_token'));
      expect(role, equals('doctor'));

      await SecureStorageService.clearTokens();
      final clearedAccess = await SecureStorageService.getAccessToken();
      expect(clearedAccess, isNull);
    });

    for (final role in ['doctor', 'receptionist', 'laboratory', 'pharmacist', 'admin', 'patient']) {
      testWidgets('RoleDashboardShell renders correctly for role: $role', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer();
        container.read(authProvider.notifier).setSimulatedUser(
          UserModel(
            id: 'usr-$role',
            email: '$role@opdconnect.com',
            fullName: 'Dr. / Staff $role',
            roleName: role,
          ),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: RoleDashboardShell(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(RoleDashboardShell), findsOneWidget);
        expect(find.text('OPD Connect+'), findsOneWidget);
      });
    }
  });
}
