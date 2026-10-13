import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/admin_portal_models.dart';
import '../repositories/admin_portal_repository.dart';
import '../../patient_portal/models/patient_portal_models.dart';

final adminPortalRepositoryProvider = Provider<AdminPortalRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AdminPortalRepository(dioClient);
});

class NullableStringNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  set state(String? val) => super.state = val;
}

class NullableBoolNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;

  set state(bool? val) => super.state = val;
}

// Operational Dashboard Summary
final adminDashboardSummaryProvider = FutureProvider<AdminDashboardMetricsModel>((ref) async {
  final repo = ref.watch(adminPortalRepositoryProvider);
  return repo.getDashboardSummary();
});

// Staff Users
final adminUsersFilterRoleProvider = NotifierProvider<NullableStringNotifier, String?>(NullableStringNotifier.new);
final adminUsersFilterActiveProvider = NotifierProvider<NullableBoolNotifier, bool?>(NullableBoolNotifier.new);
final adminUsersSearchProvider = NotifierProvider<NullableStringNotifier, String?>(NullableStringNotifier.new);

final adminUsersProvider = FutureProvider<List<AdminUserModel>>((ref) async {
  final repo = ref.watch(adminPortalRepositoryProvider);
  final role = ref.watch(adminUsersFilterRoleProvider);
  final isActive = ref.watch(adminUsersFilterActiveProvider);
  final search = ref.watch(adminUsersSearchProvider);
  return repo.getUsers(role: role, isActive: isActive, search: search);
});

// Departments
final adminDepartmentsProvider = FutureProvider<List<DepartmentAdminModel>>((ref) async {
  final repo = ref.watch(adminPortalRepositoryProvider);
  return repo.getDepartments();
});

// Medicine Formulary
final adminMedicinesProvider = FutureProvider<List<MedicineAdminModel>>((ref) async {
  final repo = ref.watch(adminPortalRepositoryProvider);
  return repo.getMedicineCatalogue();
});

// Audit Logs
final adminAuditLogsActionFilterProvider = NotifierProvider<NullableStringNotifier, String?>(NullableStringNotifier.new);
final adminAuditLogsQueryProvider = NotifierProvider<NullableStringNotifier, String?>(NullableStringNotifier.new);

final adminAuditLogsProvider = FutureProvider<List<AuditLogItemModel>>((ref) async {
  final repo = ref.watch(adminPortalRepositoryProvider);
  final action = ref.watch(adminAuditLogsActionFilterProvider);
  final query = ref.watch(adminAuditLogsQueryProvider);
  return repo.getAuditLogs(action: action, query: query);
});

// Support Tickets
final adminSupportTicketsProvider = FutureProvider<List<SupportTicketModel>>((ref) async {
  final repo = ref.watch(adminPortalRepositoryProvider);
  return repo.getSupportTickets();
});

// System Configurations
final adminSystemConfigsProvider = FutureProvider<List<SystemConfigModel>>((ref) async {
  final repo = ref.watch(adminPortalRepositoryProvider);
  return repo.getSystemConfigs();
});

// Backup Guidance
final adminBackupGuidanceProvider = FutureProvider<BackupGuidanceModel>((ref) async {
  final repo = ref.watch(adminPortalRepositoryProvider);
  return repo.getBackupGuidance();
});

// Diagnostic Test Catalogue
final adminTestCatalogueProvider = FutureProvider<List<TestCatalogueItemModel>>((ref) async {
  final repo = ref.watch(adminPortalRepositoryProvider);
  return repo.getTestCatalogue();
});

// Hospital Tariffs / Services Catalogue
final adminServicesCatalogueProvider = FutureProvider<List<ServiceCatalogueItemModel>>((ref) async {
  final repo = ref.watch(adminPortalRepositoryProvider);
  return repo.getServicesCatalogue();
});

// Reports Filter Providers
final adminReportDateFromProvider = NotifierProvider<NullableStringNotifier, String?>(NullableStringNotifier.new);
final adminReportDateToProvider = NotifierProvider<NullableStringNotifier, String?>(NullableStringNotifier.new);
final adminReportDepartmentIdProvider = NotifierProvider<NullableStringNotifier, String?>(NullableStringNotifier.new);
final adminReportStatusProvider = NotifierProvider<NullableStringNotifier, String?>(NullableStringNotifier.new);
final adminReportPaymentStatusProvider = NotifierProvider<NullableStringNotifier, String?>(NullableStringNotifier.new);

// Registration & Footfall Report Provider
final adminRegistrationsReportProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(adminPortalRepositoryProvider);
  final dFrom = ref.watch(adminReportDateFromProvider);
  final dTo = ref.watch(adminReportDateToProvider);
  final deptId = ref.watch(adminReportDepartmentIdProvider);
  final status = ref.watch(adminReportStatusProvider);
  return repo.getRegistrationsReport(dateFrom: dFrom, dateTo: dTo, departmentId: deptId, status: status);
});

// Financial & Billing Report Provider
final adminBillingReportProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(adminPortalRepositoryProvider);
  final dFrom = ref.watch(adminReportDateFromProvider);
  final dTo = ref.watch(adminReportDateToProvider);
  final paymentStatus = ref.watch(adminReportPaymentStatusProvider);
  return repo.getBillingReport(dateFrom: dFrom, dateTo: dTo, paymentStatus: paymentStatus);
});
