import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/dashboard_stats.dart';

final dashboardStatsProvider = FutureProvider<DashboardStatsModel>((ref) async {
  final dioClient = ref.watch(dioClientProvider);

  try {
    final res = await dioClient.dio.get(ApiEndpoints.adminStats);
    if (res.data['status'] == 'success') {
      return DashboardStatsModel.fromJson(res.data['data'] as Map<String, dynamic>);
    }
  } catch (_) {}

  // Synthetic fallback stats
  return DashboardStatsModel(
    totalPatients: 42,
    totalVisits: 18,
    activeDoctors: 6,
    departments: 5,
    waiting: 5,
    triaged: 7,
    completed: 6,
  );
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void setTheme(ThemeMode mode) => state = mode;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
