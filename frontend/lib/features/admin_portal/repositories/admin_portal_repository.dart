import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/admin_portal_models.dart';
import '../../patient_portal/models/patient_portal_models.dart';

class AdminPortalRepository {
  final DioClient _dioClient;

  AdminPortalRepository(this._dioClient);

  Future<AdminDashboardMetricsModel> getDashboardSummary() async {
    final response = await _dioClient.dio.get(ApiEndpoints.adminDashboardSummary);
    return AdminDashboardMetricsModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<AdminUserModel>> getUsers({String? role, bool? isActive, String? search}) async {
    final Map<String, dynamic> q = {};
    if (role != null && role.isNotEmpty) q['role'] = role;
    if (isActive != null) q['is_active'] = isActive;
    if (search != null && search.isNotEmpty) q['search'] = search;

    final response = await _dioClient.dio.get(ApiEndpoints.adminUsers, queryParameters: q);
    final list = (response.data['data'] as List?) ?? [];
    return list.map((u) => AdminUserModel.fromJson(u as Map<String, dynamic>)).toList();
  }

  Future<AdminUserModel> provisionStaffUser({
    required String email,
    required String password,
    required String fullName,
    required String roleName,
    String? phone,
  }) async {
    final response = await _dioClient.dio.post(
      ApiEndpoints.adminUsers,
      data: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'role_name': roleName,
        'phone': phone,
      },
    );
    return AdminUserModel.fromJson(response.data['data'] as Map<String, dynamic>);
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

  Future<List<DepartmentAdminModel>> getDepartments() async {
    final response = await _dioClient.dio.get(ApiEndpoints.adminDepartments);
    final list = (response.data['data'] as List?) ?? [];
    return list.map((d) => DepartmentAdminModel.fromJson(d as Map<String, dynamic>)).toList();
  }

  Future<void> toggleDepartmentStatus(String departmentId) async {
    await _dioClient.dio.patch(ApiEndpoints.adminDepartmentToggle(departmentId));
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
    final Map<String, dynamic> q = {'format': 'json'};
    if (dateFrom != null) q['date_from'] = dateFrom;
    if (dateTo != null) q['date_to'] = dateTo;
    if (departmentId != null) q['department_id'] = departmentId;
    if (status != null) q['status'] = status;

    final response = await _dioClient.dio.get(ApiEndpoints.adminReportRegistrations, queryParameters: q);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getBillingReport({
    String? dateFrom,
    String? dateTo,
    String? paymentStatus,
  }) async {
    final Map<String, dynamic> q = {'format': 'json'};
    if (dateFrom != null) q['date_from'] = dateFrom;
    if (dateTo != null) q['date_to'] = dateTo;
    if (paymentStatus != null) q['payment_status'] = paymentStatus;

    final response = await _dioClient.dio.get(ApiEndpoints.adminReportBilling, queryParameters: q);
    return response.data['data'] as Map<String, dynamic>;
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
