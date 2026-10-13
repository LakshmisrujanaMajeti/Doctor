import 'package:flutter/foundation.dart';

@immutable
class AdminDashboardMetricsModel {
  final int totalPatientsRegistered;
  final int visitsTodayCount;
  final Map<String, int> queueBreakdown;
  final int activeClinicsCount;
  final int activeDoctorsCount;
  final double revenueToday;
  final double revenueMonth;
  final int pendingBillsCount;
  final double pendingBillsAmount;
  final Map<String, double> revenueByMethod;
  final int lowStockItemsCount;
  final int expiringSoonItemsCount;
  final int totalMedicinesInFormulary;
  final int pendingLabOrdersCount;
  final int completedLabTodayCount;
  final int totalStaffAccounts;
  final Map<String, int> staffByRole;
  final int inactiveAccountsCount;
  final int lockedAccountsCount;

  const AdminDashboardMetricsModel({
    required this.totalPatientsRegistered,
    required this.visitsTodayCount,
    required this.queueBreakdown,
    required this.activeClinicsCount,
    required this.activeDoctorsCount,
    required this.revenueToday,
    required this.revenueMonth,
    required this.pendingBillsCount,
    required this.pendingBillsAmount,
    required this.revenueByMethod,
    required this.lowStockItemsCount,
    required this.expiringSoonItemsCount,
    required this.totalMedicinesInFormulary,
    required this.pendingLabOrdersCount,
    required this.completedLabTodayCount,
    required this.totalStaffAccounts,
    required this.staffByRole,
    required this.inactiveAccountsCount,
    required this.lockedAccountsCount,
  });

  factory AdminDashboardMetricsModel.fromJson(Map<String, dynamic> json) {
    final rawQueue = (json['queue_breakdown'] as Map<String, dynamic>?) ?? {};
    final rawRevMethod = (json['revenue_by_method'] as Map<String, dynamic>?) ?? {};
    final rawStaff = (json['staff_by_role'] as Map<String, dynamic>?) ?? {};

    return AdminDashboardMetricsModel(
      totalPatientsRegistered: (json['total_patients_registered'] as num?)?.toInt() ?? 0,
      visitsTodayCount: (json['visits_today_count'] as num?)?.toInt() ?? 0,
      queueBreakdown: rawQueue.map((k, v) => MapEntry(k, (v as num).toInt())),
      activeClinicsCount: (json['active_clinics_count'] as num?)?.toInt() ?? 0,
      activeDoctorsCount: (json['active_doctors_count'] as num?)?.toInt() ?? 0,
      revenueToday: (json['revenue_today'] as num?)?.toDouble() ?? 0.0,
      revenueMonth: (json['revenue_month'] as num?)?.toDouble() ?? 0.0,
      pendingBillsCount: (json['pending_bills_count'] as num?)?.toInt() ?? 0,
      pendingBillsAmount: (json['pending_bills_amount'] as num?)?.toDouble() ?? 0.0,
      revenueByMethod: rawRevMethod.map((k, v) => MapEntry(k, (v as num).toDouble())),
      lowStockItemsCount: (json['low_stock_items_count'] as num?)?.toInt() ?? 0,
      expiringSoonItemsCount: (json['expiring_soon_items_count'] as num?)?.toInt() ?? 0,
      totalMedicinesInFormulary: (json['total_medicines_in_formulary'] as num?)?.toInt() ?? 0,
      pendingLabOrdersCount: (json['pending_lab_orders_count'] as num?)?.toInt() ?? 0,
      completedLabTodayCount: (json['completed_lab_today_count'] as num?)?.toInt() ?? 0,
      totalStaffAccounts: (json['total_staff_accounts'] as num?)?.toInt() ?? 0,
      staffByRole: rawStaff.map((k, v) => MapEntry(k, (v as num).toInt())),
      inactiveAccountsCount: (json['inactive_accounts_count'] as num?)?.toInt() ?? 0,
      lockedAccountsCount: (json['locked_accounts_count'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class AdminUserModel {
  final String id;
  final String email;
  final String fullName;
  final String roleName;
  final String? phone;
  final bool isActive;
  final bool isVerified;
  final String? lockedUntil;

  const AdminUserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.roleName,
    this.phone,
    required this.isActive,
    required this.isVerified,
    this.lockedUntil,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    final roleObj = json['role'] as Map<String, dynamic>?;
    final rName = roleObj != null ? (roleObj['name'] as String? ?? 'none') : (json['role_name'] as String? ?? 'none');

    return AdminUserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      roleName: rName,
      phone: json['phone'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      isVerified: (json['is_verified'] as bool?) ?? false,
      lockedUntil: json['locked_until'] as String?,
    );
  }
}

@immutable
class DepartmentAdminModel {
  final String id;
  final String name;
  final String code;
  final String? description;
  final bool isActive;
  final int doctorsCount;

  const DepartmentAdminModel({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    required this.isActive,
    required this.doctorsCount,
  });

  factory DepartmentAdminModel.fromJson(Map<String, dynamic> json) {
    return DepartmentAdminModel(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      description: json['description'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      doctorsCount: (json['doctors_count'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class MedicineAdminModel {
  final String id;
  final String medicineCode;
  final String name;
  final String genericName;
  final String strength;
  final String dosageForm;
  final int quantity;
  final int reorderLevel;
  final double unitPrice;
  final double taxPercentage;
  final bool isLowStock;
  final bool isActive;

  const MedicineAdminModel({
    required this.id,
    required this.medicineCode,
    required this.name,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    required this.quantity,
    required this.reorderLevel,
    required this.unitPrice,
    required this.taxPercentage,
    required this.isLowStock,
    required this.isActive,
  });

  factory MedicineAdminModel.fromJson(Map<String, dynamic> json) {
    return MedicineAdminModel(
      id: json['id'] as String,
      medicineCode: json['medicine_code'] as String,
      name: json['name'] as String,
      genericName: json['generic_name'] as String,
      strength: json['strength'] as String,
      dosageForm: json['dosage_form'] as String,
      quantity: (json['quantity'] as num).toInt(),
      reorderLevel: (json['reorder_level'] as num).toInt(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      taxPercentage: (json['tax_percentage'] as num).toDouble(),
      isLowStock: (json['is_low_stock'] as bool?) ?? false,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}

@immutable
class SystemConfigModel {
  final String configKey;
  final String configValue;
  final String category;
  final String? description;
  final String? updatedAt;

  const SystemConfigModel({
    required this.configKey,
    required this.configValue,
    required this.category,
    this.description,
    this.updatedAt,
  });

  factory SystemConfigModel.fromJson(Map<String, dynamic> json) {
    return SystemConfigModel(
      configKey: json['config_key'] as String,
      configValue: json['config_value'] as String,
      category: json['category'] as String,
      description: json['description'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

@immutable
class BackupGuidanceModel {
  final String databaseEngine;
  final String backupSchedule;
  final int retentionPeriodDays;
  final String lastBackupStatus;
  final String lastBackupTime;
  final List<String> guidanceChecklist;
  final String cronSpecification;
  final List<String> restoreProcedureSteps;

  const BackupGuidanceModel({
    required this.databaseEngine,
    required this.backupSchedule,
    required this.retentionPeriodDays,
    required this.lastBackupStatus,
    required this.lastBackupTime,
    required this.guidanceChecklist,
    required this.cronSpecification,
    required this.restoreProcedureSteps,
  });

  factory BackupGuidanceModel.fromJson(Map<String, dynamic> json) {
    return BackupGuidanceModel(
      databaseEngine: json['database_engine'] as String,
      backupSchedule: json['backup_schedule'] as String,
      retentionPeriodDays: (json['retention_period_days'] as num).toInt(),
      lastBackupStatus: json['last_backup_status'] as String,
      lastBackupTime: json['last_backup_time'] as String,
      guidanceChecklist: ((json['guidance_checklist'] as List?) ?? []).cast<String>(),
      cronSpecification: json['cron_specification'] as String,
      restoreProcedureSteps: ((json['restore_procedure_steps'] as List?) ?? []).cast<String>(),
    );
  }
}

@immutable
class AuditLogItemModel {
  final String id;
  final String? userId;
  final String action;
  final String entityType;
  final String? entityId;
  final String? ipAddress;
  final Map<String, dynamic> details;
  final String timestamp;

  const AuditLogItemModel({
    required this.id,
    this.userId,
    required this.action,
    required this.entityType,
    this.entityId,
    this.ipAddress,
    required this.details,
    required this.timestamp,
  });

  factory AuditLogItemModel.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'];
    Map<String, dynamic> det = {};
    if (rawDetails is Map<String, dynamic>) {
      det = rawDetails;
    }
    return AuditLogItemModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      action: json['action'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      ipAddress: json['ip_address'] as String?,
      details: det,
      timestamp: (json['timestamp'] as String?) ?? '',
    );
  }
}

@immutable
class TestCatalogueItemModel {
  final String code;
  final String name;
  final String sampleType;
  final int turnaroundHours;
  final double price;
  final List<String> parameters;

  const TestCatalogueItemModel({
    required this.code,
    required this.name,
    required this.sampleType,
    required this.turnaroundHours,
    required this.price,
    required this.parameters,
  });

  factory TestCatalogueItemModel.fromJson(Map<String, dynamic> json) {
    return TestCatalogueItemModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sampleType: json['sample_type'] as String? ?? 'Blood/Serum',
      turnaroundHours: (json['turnaround_hours'] as num?)?.toInt() ?? 2,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      parameters: ((json['parameters'] as List?) ?? []).cast<String>(),
    );
  }
}

@immutable
class ServiceCatalogueItemModel {
  final String code;
  final String name;
  final String category;
  final double price;
  final bool isActive;

  const ServiceCatalogueItemModel({
    required this.code,
    required this.name,
    required this.category,
    required this.price,
    required this.isActive,
  });

  factory ServiceCatalogueItemModel.fromJson(Map<String, dynamic> json) {
    return ServiceCatalogueItemModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}
