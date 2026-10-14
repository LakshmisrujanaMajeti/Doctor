import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/repositories/auth_repository.dart';
import '../models/admin_portal_models.dart';
import '../../patient_portal/models/patient_portal_models.dart';

class AdminPortalRepository {
  final DioClient _dioClient;

  final List<AdminUserModel> _localUsers = [];

  AdminPortalRepository(this._dioClient);

  Future<void> _loadCacheIfNeeded() async {
    if (_localUsers.isNotEmpty) return;
    try {
      final raw = await SecureStorageService.getStaffDirectoryJson();
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _localUsers.clear();
        for (final item in list) {
          _localUsers.add(AdminUserModel.fromJson(item as Map<String, dynamic>));
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCache() async {
    try {
      final jsonList = _localUsers.map((u) => u.toJson()).toList();
      await SecureStorageService.saveStaffDirectoryJson(jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<AdminDashboardMetricsModel> getDashboardSummary() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.adminDashboardSummary);
      var metrics = AdminDashboardMetricsModel.fromJson(response.data['data'] as Map<String, dynamic>);
      if (metrics.totalPatientsRegistered == 0) {
        try {
          final rawPat = await SecureStorageService.getPatientsJson();
          if (rawPat != null && rawPat.isNotEmpty) {
            final pList = jsonDecode(rawPat) as List<dynamic>;
            if (pList.isNotEmpty) {
              metrics = metrics.copyWith(totalPatientsRegistered: pList.length);
            }
          }
        } catch (_) {}
      }
      return metrics;
    } catch (_) {
      // Dynamic fallback based on cached active users and real counters
      await _loadCacheIfNeeded();
      final byRole = <String, int>{};
      for (final u in _localUsers) {
        byRole[u.roleName] = (byRole[u.roleName] ?? 0) + 1;
      }

      int totalPatients = 0;
      try {
        final rawPat = await SecureStorageService.getPatientsJson();
        if (rawPat != null && rawPat.isNotEmpty) {
          final pList = jsonDecode(rawPat) as List<dynamic>;
          totalPatients = pList.length;
        }
      } catch (_) {}

      int totalVisitsToday = 0;
      final qBreakdown = <String, int>{'WAITING': 0, 'TRIAGED': 0, 'COMPLETED': 0};
      try {
        final rawVis = await SecureStorageService.getVisitsJson();
        if (rawVis != null && rawVis.isNotEmpty) {
          final vList = jsonDecode(rawVis) as List<dynamic>;
          totalVisitsToday = vList.length;
          for (final v in vList) {
            final st = (v['status'] ?? 'WAITING').toString().toUpperCase();
            if (st.contains('WAIT') || st.contains('REG')) {
              qBreakdown['WAITING'] = (qBreakdown['WAITING'] ?? 0) + 1;
            } else if (st.contains('TRIAG')) {
              qBreakdown['TRIAGED'] = (qBreakdown['TRIAGED'] ?? 0) + 1;
            } else if (st.contains('COMPLET')) {
              qBreakdown['COMPLETED'] = (qBreakdown['COMPLETED'] ?? 0) + 1;
            }
          }
        }
      } catch (_) {}

      return AdminDashboardMetricsModel(
        totalPatientsRegistered: totalPatients,
        visitsTodayCount: totalVisitsToday,
        queueBreakdown: qBreakdown,
        activeClinicsCount: 1,
        activeDoctorsCount: _localUsers.where((u) => u.roleName == 'doctor').length,
        revenueToday: 0.0,
        revenueMonth: 0.0,
        pendingBillsCount: 0,
        pendingBillsAmount: 0.0,
        revenueByMethod: {},
        lowStockItemsCount: 0,
        expiringSoonItemsCount: 0,
        totalMedicinesInFormulary: 0,
        pendingLabOrdersCount: 0,
        completedLabTodayCount: 0,
        totalStaffAccounts: _localUsers.length,
        staffByRole: byRole,
        inactiveAccountsCount: _localUsers.where((u) => !u.isActive).length,
        lockedAccountsCount: 0,
      );
    }
  }

  Future<List<AdminUserModel>> getUsers({String? role, bool? isActive, String? search}) async {
    try {
      final Map<String, dynamic> q = {};
      if (role != null && role.isNotEmpty) q['role'] = role;
      if (isActive != null) q['is_active'] = isActive;
      if (search != null && search.isNotEmpty) q['search'] = search;

      final response = await _dioClient.dio.get(ApiEndpoints.adminUsers, queryParameters: q);
      final list = (response.data['data'] as List?) ?? [];
      final fetched = list.map((u) => AdminUserModel.fromJson(u as Map<String, dynamic>)).toList();
      if ((role == null || role.isEmpty) && isActive == null && (search == null || search.isEmpty)) {
        _localUsers.clear();
        _localUsers.addAll(fetched);
        await _saveCache();
        return _localUsers;
      } else {
        for (final f in fetched) {
          final idx = _localUsers.indexWhere((x) => x.id == f.id || x.email == f.email);
          if (idx != -1) {
            _localUsers[idx] = f;
          } else {
            _localUsers.add(f);
          }
        }
        await _saveCache();
        return fetched;
      }
    } catch (_) {
      await _loadCacheIfNeeded();
      return _filterUsers(_localUsers, role, isActive, search);
    }
  }

  List<AdminUserModel> _filterUsers(List<AdminUserModel> users, String? role, bool? isActive, String? search) {
    var results = List<AdminUserModel>.from(users);
    if (role != null && role.isNotEmpty) {
      results = results.where((u) => u.roleName.toLowerCase() == role.toLowerCase()).toList();
    }
    if (isActive != null) {
      results = results.where((u) => u.isActive == isActive).toList();
    }
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      results = results.where((u) =>
          u.fullName.toLowerCase().contains(s) ||
          u.email.toLowerCase().contains(s) ||
          (u.phone != null && u.phone!.contains(s))).toList();
    }
    return results;
  }

  Future<AdminUserModel> provisionStaffUser({
    required String email,
    required String password,
    required String fullName,
    required String roleName,
    String? phone,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = fullName.trim();
    final cleanRole = roleName.trim().toLowerCase();

    // 1. Register with Supabase Auth Cloud
    try {
      await Supabase.instance.client.auth.signUp(
        email: cleanEmail,
        password: password.trim(),
        data: {
          'full_name': cleanName,
          'role': cleanRole,
          if (phone != null) 'phone': phone.trim(),
        },
      );
    } catch (_) {}

    AdminUserModel? createdUser;

    // 2. Try FastAPI Backend
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.adminUsers,
        data: {
          'email': cleanEmail,
          'password': password.trim(),
          'full_name': cleanName,
          'role_name': cleanRole,
          'phone': phone?.trim(),
        },
      );
      if (response.data['status'] == 'success') {
        createdUser = AdminUserModel.fromJson(response.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    // 3. Fallback persistent user
    createdUser ??= AdminUserModel(
      id: 'staff-${DateTime.now().millisecondsSinceEpoch}',
      email: cleanEmail,
      fullName: cleanName,
      roleName: cleanRole,
      phone: phone?.trim(),
      isActive: true,
      isVerified: true,
    );

    final idx = _localUsers.indexWhere((u) => u.email == cleanEmail);
    if (idx != -1) {
      _localUsers[idx] = createdUser;
    } else {
      _localUsers.insert(0, createdUser);
    }
    await _saveCache();

    // Register into AuthRepository so the new staff member can log in instantly
    await AuthRepository.registerDynamicStaff(
      email: cleanEmail,
      password: password.trim(),
      role: cleanRole,
      fullName: cleanName,
      phone: phone?.trim(),
    );

    return createdUser;
  }

  Future<AdminUserModel> updateUserStatus(String userId, {required bool isActive, bool unlock = false}) async {
    final response = await _dioClient.dio.patch(
      ApiEndpoints.adminUserStatus(userId),
      data: {
        'is_active': isActive,
        'unlock': unlock,
      },
    );
    return AdminUserModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<AdminUserModel> updateUserRole(String userId, {required String roleName}) async {
    final response = await _dioClient.dio.patch(
      ApiEndpoints.adminUserRole(userId),
      data: {'role_name': roleName},
    );
    return AdminUserModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<AdminUserModel> updateUserDetails(
    String userId, {
    String? fullName,
    String? email,
    String? phone,
    String? roleName,
    String? departmentName,
    String? roomNumber,
    String? qualification,
    String? consultationFee,
    bool? isActive,
  }) async {
    AdminUserModel? updated;
    try {
      final response = await _dioClient.dio.put(
        ApiEndpoints.adminUserById(userId),
        data: {
          if (fullName != null) 'full_name': fullName.trim(),
          if (email != null) 'email': email.trim().toLowerCase(),
          if (phone != null) 'phone': phone.trim(),
          if (roleName != null) 'role_name': roleName.trim().toLowerCase(),
          if (departmentName != null) 'department_name': departmentName.trim(),
          if (roomNumber != null) 'room_number': roomNumber.trim(),
          if (qualification != null) 'qualification': qualification.trim(),
          if (consultationFee != null) 'consultation_fee': consultationFee.trim(),
          if (isActive != null) 'is_active': isActive,
        },
      );
      if (response.data['status'] == 'success') {
        updated = AdminUserModel.fromJson(response.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    await _loadCacheIfNeeded();
    final idx = _localUsers.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final old = _localUsers[idx];
      updated ??= AdminUserModel(
        id: old.id,
        email: email?.trim().toLowerCase() ?? old.email,
        fullName: fullName?.trim() ?? old.fullName,
        roleName: roleName?.trim().toLowerCase() ?? old.roleName,
        phone: phone?.trim() ?? old.phone,
        isActive: isActive ?? old.isActive,
        isVerified: old.isVerified,
      );
      _localUsers[idx] = updated;
      await _saveCache();
    }
    return updated ?? _localUsers.firstWhere((u) => u.id == userId);
  }

  Future<void> deleteUserAccount(String userId) async {
    try {
      await _dioClient.dio.delete(ApiEndpoints.adminUserById(userId));
    } catch (_) {}

    await _loadCacheIfNeeded();
    _localUsers.removeWhere((u) => u.id == userId);
    await _saveCache();
  }

  Future<List<DepartmentAdminModel>> getDepartments() async {
    final response = await _dioClient.dio.get(ApiEndpoints.adminDepartments);
    final list = (response.data['data'] as List?) ?? [];
    return list.map((d) => DepartmentAdminModel.fromJson(d as Map<String, dynamic>)).toList();
  }

  Future<void> toggleDepartmentStatus(String departmentId) async {
    await _dioClient.dio.patch(ApiEndpoints.adminDepartmentToggle(departmentId));
  }

  Future<void> createDepartment({
    required String name,
    required String code,
    String? description,
  }) async {
    await _dioClient.dio.post(
      ApiEndpoints.adminDepartments,
      data: {
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        if (description != null && description.isNotEmpty) 'description': description.trim(),
      },
    );
  }

  Future<List<MedicineAdminModel>> getMedicineCatalogue({String? search, bool lowStockOnly = false}) async {
    final Map<String, dynamic> q = {'low_stock_only': lowStockOnly};
    if (search != null && search.isNotEmpty) q['search'] = search;

    final response = await _dioClient.dio.get(ApiEndpoints.adminMedicineCatalogue, queryParameters: q);
    final list = (response.data['data'] as List?) ?? [];
    return list.map((m) => MedicineAdminModel.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<void> updateMedicineConfig(String medicineId, {double? unitPrice, int? reorderLevel}) async {
    await _dioClient.dio.patch(
      ApiEndpoints.adminMedicineById(medicineId),
      data: {
        if (unitPrice != null) 'unit_price': unitPrice,
        if (reorderLevel != null) 'reorder_level': reorderLevel,
      },
    );
  }

  Future<Map<String, dynamic>> getRegistrationsReport({
    String? dateFrom,
    String? dateTo,
    String? departmentId,
    String? status,
  }) async {
    try {
      final Map<String, dynamic> q = {'format': 'json'};
      if (dateFrom != null) q['date_from'] = dateFrom;
      if (dateTo != null) q['date_to'] = dateTo;
      if (departmentId != null) q['department_id'] = departmentId;
      if (status != null) q['status'] = status;

      final response = await _dioClient.dio.get(ApiEndpoints.adminReportRegistrations, queryParameters: q);
      return response.data['data'] as Map<String, dynamic>;
    } catch (_) {
      final records = <Map<String, dynamic>>[];
      final statusSummary = <String, int>{'WAITING': 0, 'TRIAGED': 0, 'COMPLETED': 0};
      final deptSummary = <String, int>{};

      try {
        final rawVisits = await SecureStorageService.getVisitsJson();
        if (rawVisits != null && rawVisits.isNotEmpty) {
          final list = jsonDecode(rawVisits) as List<dynamic>;
          for (final item in list) {
            final st = (item['status'] ?? 'WAITING').toString();
            statusSummary[st] = (statusSummary[st] ?? 0) + 1;
            final dept = (item['department_name'] ?? 'General Medicine').toString();
            deptSummary[dept] = (deptSummary[dept] ?? 0) + 1;
            records.add(item as Map<String, dynamic>);
          }
        }
      } catch (_) {}

      return {
        'total_visits': records.length,
        'status_summary': statusSummary,
        'department_summary': deptSummary,
        'records': records,
      };
    }
  }

  Future<Map<String, dynamic>> getBillingReport({
    String? dateFrom,
    String? dateTo,
    String? paymentStatus,
  }) async {
    try {
      final Map<String, dynamic> q = {'format': 'json'};
      if (dateFrom != null) q['date_from'] = dateFrom;
      if (dateTo != null) q['date_to'] = dateTo;
      if (paymentStatus != null) q['payment_status'] = paymentStatus;

      final response = await _dioClient.dio.get(ApiEndpoints.adminReportBilling, queryParameters: q);
      return response.data['data'] as Map<String, dynamic>;
    } catch (_) {
      final records = <Map<String, dynamic>>[];
      double totalCollected = 0.0;
      double totalPending = 0.0;

      try {
        final rawBills = await SecureStorageService.getBillsJson();
        if (rawBills != null && rawBills.isNotEmpty) {
          final list = jsonDecode(rawBills) as List<dynamic>;
          for (final item in list) {
            final amt = (item['total_amount'] as num?)?.toDouble() ?? 0.0;
            final pst = (item['payment_status'] ?? 'PAID').toString().toUpperCase();
            if (pst == 'PAID' || pst == 'COMPLETED') {
              totalCollected += amt;
            } else {
              totalPending += amt;
            }
            records.add(item as Map<String, dynamic>);
          }
        }
      } catch (_) {}

      return {
        'total_invoices': records.length,
        'total_collected': totalCollected,
        'total_pending': totalPending,
        'records': records,
      };
    }
  }

  Future<List<AuditLogItemModel>> getAuditLogs({
    String? action,
    String? entityType,
    String? query,
    int limit = 50,
  }) async {
    final Map<String, dynamic> q = {'limit': limit};
    if (action != null && action.isNotEmpty) q['action'] = action;
    if (entityType != null && entityType.isNotEmpty) q['entity_type'] = entityType;
    if (query != null && query.isNotEmpty) q['query'] = query;

    final response = await _dioClient.dio.get(ApiEndpoints.auditLogs, queryParameters: q);
    final list = (response.data['data'] as List?) ?? [];
    return list.map((a) => AuditLogItemModel.fromJson(a as Map<String, dynamic>)).toList();
  }

  Future<List<SupportTicketModel>> getSupportTickets({String? status, String? category}) async {
    final Map<String, dynamic> q = {};
    if (status != null && status.isNotEmpty) q['status'] = status;
    if (category != null && category.isNotEmpty) q['category'] = category;

    final response = await _dioClient.dio.get(ApiEndpoints.adminSupportTickets, queryParameters: q);
    final list = (response.data['data'] as List?) ?? [];
    return list.map((t) => SupportTicketModel.fromJson(t as Map<String, dynamic>)).toList();
  }

  Future<SupportTicketModel> respondSupportTicket(String ticketId, {required String responseText, String status = 'RESOLVED'}) async {
    final response = await _dioClient.dio.post(
      ApiEndpoints.adminSupportTicketRespond(ticketId),
      data: {
        'admin_response': responseText,
        'status': status,
      },
    );
    return SupportTicketModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<SystemConfigModel>> getSystemConfigs() async {
    final response = await _dioClient.dio.get(ApiEndpoints.adminSystemConfig);
    final list = (response.data['data'] as List?) ?? [];
    return list.map((c) => SystemConfigModel.fromJson(c as Map<String, dynamic>)).toList();
  }

  Future<void> updateSystemConfigs(Map<String, String> configs) async {
    await _dioClient.dio.put(
      ApiEndpoints.adminSystemConfig,
      data: {'configs': configs},
    );
  }

  Future<BackupGuidanceModel> getBackupGuidance() async {
    final response = await _dioClient.dio.get(ApiEndpoints.adminBackupGuidance);
    return BackupGuidanceModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> triggerBackupExport() async {
    final response = await _dioClient.dio.post(ApiEndpoints.adminBackupExport);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<List<TestCatalogueItemModel>> getTestCatalogue() async {
    final response = await _dioClient.dio.get(ApiEndpoints.adminTestCatalogue);
    final list = (response.data['data'] as List?) ?? [];
    return list.map((t) => TestCatalogueItemModel.fromJson(t as Map<String, dynamic>)).toList();
  }

  Future<List<ServiceCatalogueItemModel>> getServicesCatalogue() async {
    final response = await _dioClient.dio.get(ApiEndpoints.adminServices);
    final list = (response.data['data'] as List?) ?? [];
    return list.map((s) => ServiceCatalogueItemModel.fromJson(s as Map<String, dynamic>)).toList();
  }
}
