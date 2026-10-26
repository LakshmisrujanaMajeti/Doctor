import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/repositories/auth_repository.dart';
import '../models/admin_portal_models.dart';
import '../../patient_portal/models/patient_portal_models.dart';
import '../../patients/repositories/patient_repository.dart';
import '../../visits/repositories/visit_repository.dart';
import 'dart:math';
import '../../doctors/models/doctor_model.dart';
import '../../doctors/repositories/doctor_repository.dart';
import '../../billing/repositories/billing_repository.dart';

class AdminPortalRepository {
  final DioClient _dioClient;

  // Shared static in-memory cache for instant 0ms access
  static final List<AdminUserModel> _localUsers = [];
  static bool _isLoaded = false;

  static List<AdminUserModel> get cachedUsers => List.unmodifiable(_localUsers);

  static void initializeCache(List<AdminUserModel> users) {
    _localUsers.clear();
    _localUsers.addAll(users);
    _isLoaded = true;
  }

  AdminPortalRepository(this._dioClient);

  Future<void> _loadCacheIfNeeded() async {
    if (_localUsers.isEmpty) {
      try {
        final raw = await SecureStorageService.getStaffDirectoryJson();
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          _localUsers.clear();
          for (final item in list) {
            final u = AdminUserModel.fromJson(item as Map<String, dynamic>);
            if (u.roleName.toLowerCase() != 'none') {
              _localUsers.add(u);
            }
          }
        }
      } catch (_) {}
    }
    _ensureDefaultDoctorsMerged();
    _deduplicateLocalUsers();
    _isLoaded = true;
  }

  void _ensureDefaultDoctorsMerged() {
    final docs = DoctorRepository.defaultDoctors;
    for (final d in docs) {
      final docEmail = d.name.toLowerCase().contains('sarah')
          ? 'doctor@smvmch.ac.in'
          : '${d.departmentName.toLowerCase().replaceAll(' ', '')}@smvmch.ac.in';
      final existingIdx = _localUsers.indexWhere((u) => u.email.toLowerCase() == docEmail.toLowerCase());
      final docModel = AdminUserModel(
        id: d.userId,
        email: docEmail,
        fullName: d.name,
        roleName: 'doctor',
        phone: '98401${10000 + _localUsers.length}',
        isActive: true,
        isVerified: true,
        departmentName: d.departmentName,
        specialization: d.specialization,
        qualification: d.qualification,
        roomNumber: d.roomNumber,
        consultationFee: d.consultationFee.toStringAsFixed(0),
        doctorId: d.id,
        registrationNumber: 'MCI-${30000 + _localUsers.length}',
      );
      if (existingIdx != -1) {
        _localUsers[existingIdx] = docModel;
      } else {
        _localUsers.add(docModel);
      }
    }
  }

  void _deduplicateLocalUsers() {
    final seen = <String>{};
    _localUsers.retainWhere((u) => u.roleName.toLowerCase() != 'none' && u.email.isNotEmpty && seen.add(u.email.toLowerCase()));
  }

  Future<void> _saveCache() async {
    try {
      final jsonList = _localUsers.map((u) => u.toJson()).toList();
      await SecureStorageService.saveStaffDirectoryJson(jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<AdminDashboardMetricsModel> getDashboardSummary() async {
    await BillingRepository.loadCacheIfNeeded();
    final cachedBills = BillingRepository.cachedBills;
    double localSumPaid = 0.0;
    int localPendingCount = 0;
    double localPendingAmt = 0.0;
    final localRevByMethod = <String, double>{};
    for (final b in cachedBills) {
      if (b.paidAmount > 0) {
        localSumPaid += b.paidAmount;
        final m = b.payments.isNotEmpty ? b.payments.first.paymentMethod : 'CASH';
        localRevByMethod[m] = (localRevByMethod[m] ?? 0.0) + b.paidAmount;
      } else {
        localPendingCount += 1;
        localPendingAmt += b.outstandingBalance;
      }
    }

    if (DioClient.isHostReachable) {
      try {
        final response = await _dioClient.dio.get(ApiEndpoints.adminDashboardSummary);
        var metrics = AdminDashboardMetricsModel.fromJson(response.data['data'] as Map<String, dynamic>);
        if (metrics.totalPatientsRegistered == 0) {
          final count = PatientRepository.cachedPatients.length;
          if (count > 0) {
            metrics = metrics.copyWith(totalPatientsRegistered: count);
          }
        }
        if (localSumPaid > metrics.revenueToday) {
          metrics = metrics.copyWith(
            revenueToday: localSumPaid,
            revenueMonth: max(metrics.revenueMonth, localSumPaid),
            grandTotalRevenue: max(metrics.grandTotalRevenue, localSumPaid),
            revenueByMethod: metrics.revenueByMethod.isEmpty ? localRevByMethod : metrics.revenueByMethod,
            pendingBillsCount: metrics.pendingBillsCount > 0 ? metrics.pendingBillsCount : localPendingCount,
            pendingBillsAmount: metrics.pendingBillsAmount > 0 ? metrics.pendingBillsAmount : localPendingAmt,
          );
        }
        return metrics;
      } catch (_) {}
    }

    // Dynamic 0ms fallback based on cached active users and real in-memory counters
    await _loadCacheIfNeeded();
    final byRole = <String, int>{};
    for (final u in _localUsers) {
      byRole[u.roleName] = (byRole[u.roleName] ?? 0) + 1;
    }

    final totalPatients = PatientRepository.cachedPatients.length;
    final cachedVisits = VisitRepository.cachedVisits;
    final totalVisitsToday = cachedVisits.length;
    final qBreakdown = <String, int>{'WAITING': 0, 'TRIAGED': 0, 'COMPLETED': 0};

    for (final v in cachedVisits) {
      final st = v.status.toUpperCase();
      if (st.contains('WAIT') || st.contains('REG')) {
        qBreakdown['WAITING'] = (qBreakdown['WAITING'] ?? 0) + 1;
      } else if (st.contains('TRIAG')) {
        qBreakdown['TRIAGED'] = (qBreakdown['TRIAGED'] ?? 0) + 1;
      } else if (st.contains('COMPLET')) {
        qBreakdown['COMPLETED'] = (qBreakdown['COMPLETED'] ?? 0) + 1;
      }
    }

    return AdminDashboardMetricsModel(
      totalPatientsRegistered: totalPatients,
      visitsTodayCount: totalVisitsToday,
      queueBreakdown: qBreakdown,
      activeClinicsCount: 1,
      activeDoctorsCount: _localUsers.where((u) => u.roleName == 'doctor').length,
      revenueToday: localSumPaid,
      revenueMonth: localSumPaid,
      grandTotalRevenue: localSumPaid,
      yesterdayRevenue: 0.0,
      todayBillsCount: cachedVisits.length,
      yesterdayBillsCount: 0,
      pendingBillsCount: localPendingCount,
      pendingBillsAmount: localPendingAmt,
      revenueByMethod: localRevByMethod,
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

  Future<List<AdminUserModel>> getUsers({String? role, bool? isActive, String? search}) async {
    await _loadCacheIfNeeded();

    // 1. Authoritative: Always attempt fetch from backend API
    try {
      final Map<String, dynamic> q = {'limit': 150};
      if (role != null && role.isNotEmpty) q['role'] = role;
      if (isActive != null) q['is_active'] = isActive;
      if (search != null && search.isNotEmpty) q['search'] = search;

      final response = await _dioClient.dio.get(ApiEndpoints.adminUsers, queryParameters: q);
      if (response.data is Map && response.data['status'] == 'success') {
        final list = (response.data['data'] as List?) ?? [];
        final fetched = list.map((u) => AdminUserModel.fromJson(u as Map<String, dynamic>)).toList();
        if (fetched.isNotEmpty) {
          for (final f in fetched) {
            final idx = _localUsers.indexWhere((x) => x.id == f.id || x.email.toLowerCase() == f.email.toLowerCase());
            if (idx != -1) {
              _localUsers[idx] = f;
            } else {
              _localUsers.add(f);
            }
          }
          _ensureDefaultDoctorsMerged();
          _deduplicateLocalUsers();
          await _saveCache();
          return _filterUsers(_localUsers, role, isActive, search);
        }
      }
    } catch (e) {
      debugPrint('Admin users fetch note: $e');
    }

    // 2. Fallback: return cached + default merged doctors
    _ensureDefaultDoctorsMerged();
    _deduplicateLocalUsers();
    return _filterUsers(_localUsers, role, isActive, search);
  }

  List<AdminUserModel> _filterUsers(List<AdminUserModel> users, String? role, bool? isActive, String? search) {
    var results = List<AdminUserModel>.from(users);
    if (role != null && role.isNotEmpty) {
      final r = role.toLowerCase().trim();
      results = results.where((u) {
        final ur = u.roleName.toLowerCase().trim();
        if (r == 'doctor') return ur == 'doctor';
        if (r == 'receptionist') return ur == 'receptionist' || ur == 'reception';
        if (r == 'nurse') return ur == 'nurse';
        if (r == 'pharmacist') return ur == 'pharmacist';
        if (r == 'lab_technician' || r == 'lab_tech' || r == 'laboratory') {
          return ur == 'lab_technician' || ur == 'lab_tech' || ur == 'laboratory';
        }
        if (r == 'admin') return ur == 'admin';
        return ur == r;
      }).toList();
    }
    if (isActive != null) {
      results = results.where((u) => u.isActive == isActive).toList();
    }
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase().trim();
      results = results.where((u) =>
          u.fullName.toLowerCase().contains(s) ||
          u.email.toLowerCase().contains(s) ||
          (u.phone != null && u.phone!.contains(s)) ||
          (u.specialization != null && u.specialization!.toLowerCase().contains(s)) ||
          (u.departmentName != null && u.departmentName!.toLowerCase().contains(s))).toList();
    }
    return results;
  }

  Future<AdminUserModel> provisionStaffUser({
    required String email,
    required String password,
    required String fullName,
    required String roleName,
    String? phone,
    String? departmentName,
    String? specialization,
    String? roomNumber,
    String? qualification,
    double? consultationFee,
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

    // Persist directly to Supabase PostgreSQL table 'users'
    SupabaseService.upsertUser({
      'id': createdUser.id,
      'email': cleanEmail,
      'full_name': cleanName,
      'phone': phone?.trim(),
      'is_active': true,
      'is_verified': true,
      'failed_login_attempts': 0,
    }).catchError((_) => false);

    // Register into AuthRepository so the new staff member can log in instantly
    await AuthRepository.registerDynamicStaff(
      email: cleanEmail,
      password: password.trim(),
      role: cleanRole,
      fullName: cleanName,
      phone: phone?.trim(),
      departmentName: departmentName,
    );

    // If role is doctor, register into DoctorRepository directory and cache
    if (cleanRole == 'doctor') {
      final docModel = DoctorModel(
        id: createdUser.id,
        userId: createdUser.id,
        name: cleanName,
        specialization: specialization ?? departmentName ?? 'General Medicine',
        departmentId: departmentName ?? 'General Medicine',
        departmentName: departmentName ?? 'General Medicine',
        qualification: qualification ?? 'MBBS, Specialist',
        roomNumber: roomNumber ?? 'Room 101',
        consultationFee: consultationFee ?? 500.0,
        isAvailable: true,
      );
      DoctorRepository.addDoctorToCache(docModel);
    }

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
