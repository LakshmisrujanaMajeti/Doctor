import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opd_connect/core/network/dio_client.dart';
import 'package:opd_connect/features/patients/models/patient_model.dart';
import 'package:opd_connect/features/patient_portal/models/patient_portal_models.dart';
import 'package:opd_connect/features/patient_portal/repositories/patient_portal_repository.dart';
import 'package:opd_connect/features/patient_portal/providers/patient_portal_provider.dart';
import 'package:opd_connect/features/patient_portal/screens/patient_portal_workspace_view.dart';
import 'package:opd_connect/features/admin_portal/models/admin_portal_models.dart';
import 'package:opd_connect/features/admin_portal/repositories/admin_portal_repository.dart';
import 'package:opd_connect/features/admin_portal/providers/admin_portal_provider.dart';
import 'package:opd_connect/features/admin_portal/screens/hospital_admin_workspace_view.dart';

class MockPatientPortalRepository extends PatientPortalRepository {
  MockPatientPortalRepository() : super(DioClient());

  @override
  Future<PatientPortalProfile> getProfile() async {
    return PatientPortalProfile(
      patient: PatientModel(
        id: 'pat-101',
        uhid: 'UHID-20261012-0001',
        fullName: 'Aarav Sharma',
        gender: 'MALE',
        ageYears: 34,
        phone: '+919876543210',
        bloodGroup: 'O+',
      ),
      dependents: const [
        DependentProfile(
          id: 'dep-201',
          uhid: 'UHID-20261012-0002',
          fullName: 'Ananya Sharma',
          relation: 'Daughter',
          gender: 'FEMALE',
          ageDisplay: '6 Y',
          bloodGroup: 'B+',
          registrationDate: '2026-10-12',
        ),
      ],
      hasActiveToken: true,
      activeTokenNumber: '#14',
      activeTokenQueueStatus: 'WAITING (3 Ahead)',
    );
  }

  @override
  Future<List<UpcomingAppointment>> getAppointments({String? patientId}) async {
    return const [
      UpcomingAppointment(
        visitId: 'vis-101',
        visitNumber: 'VIS-1002',
        doctorName: 'Dr. Sarah Chen',
        departmentName: 'General OPD',
        scheduledDate: '2026-10-15',
        followUpReason: 'Hypertension routine review',
      ),
    ];
  }

  @override
  Future<List<PatientPrescriptionSummaryItem>> getPrescriptions({String? patientId}) async {
    return const [
      PatientPrescriptionSummaryItem(
        id: 'rx-1',
        visitId: 'vis-1001',
        doctorName: 'Dr. Sarah Chen',
        departmentName: 'General OPD',
        status: 'SIGNED',
        items: [
          PatientPrescriptionItemDetail(
            medicineName: 'Amoxicillin 500mg',
            form: 'Capsule',
            dosage: '500mg',
            route: 'Oral',
            frequency: 'TDS (3 times/day)',
            durationDays: 5,
            quantity: 15,
            instructions: 'Post meals',
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<PatientLabReportSummary>> getLabReports({String? patientId}) async {
    return const [
      PatientLabReportSummary(
        id: 'lab-1',
        orderNumber: 'LAB-20261012-0001',
        testName: 'Complete Blood Count (CBC)',
        testCategory: 'HAEMATOLOGY',
        status: 'COMPLETED',
        orderedAt: '2026-10-12',
        results: [
          PatientLabResultItem(
            parameterName: 'Hemoglobin',
            resultValue: '14.2',
            unit: 'g/dL',
            referenceRange: '13.0 - 17.0',
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<PatientBillSummary>> getBills({String? patientId}) async {
    return const [
      PatientBillSummary(
        id: 'bill-1',
        invoiceNumber: 'INV-20261012-001',
        totalAmount: 750.0,
        paidAmount: 750.0,
        discountAmount: 0.0,
        paymentStatus: 'PAID',
        billedAt: '2026-10-12',
        itemsCount: 3,
      ),
    ];
  }

  @override
  Future<List<SupportTicketModel>> getSupportTickets({String? patientId}) async {
    return const [
      SupportTicketModel(
        id: 'tkt-1',
        patientId: 'pat-101',
        patientName: 'Aarav Sharma',
        patientUhid: 'UHID-20261012-0001',
        subject: 'Billing discrepancy inquiry',
        category: 'BILLING',
        priority: 'NORMAL',
        message: 'Could you please clarify invoice item #2?',
        status: 'OPEN',
        createdAt: '2026-10-12 10:00:00',
      ),
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getVisits({String? patientId}) async {
    return const [
      {
        'id': 'vis-101',
        'visit_number': 'VIS-20261012-0001',
        'queue_token': 14,
        'doctor_name': 'Dr. Sarah Chen',
        'department_name': 'General OPD',
        'visit_date': '2026-10-12',
        'status': 'WAITING',
      }
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getDocuments({String? patientId}) async {
    return const [];
  }
}

class MockAdminPortalRepository extends AdminPortalRepository {
  MockAdminPortalRepository() : super(DioClient());

  @override
  Future<AdminDashboardMetricsModel> getDashboardSummary() async {
    return const AdminDashboardMetricsModel(
      totalPatientsRegistered: 1240,
      visitsTodayCount: 88,
      queueBreakdown: {
        'WAITING': 15,
        'IN_CONSULTATION': 4,
        'COMPLETED': 65,
        'TRIAGE': 4,
      },
      activeClinicsCount: 6,
      activeDoctorsCount: 12,
      revenueToday: 24500.0,
      revenueMonth: 485000.0,
      pendingBillsCount: 3,
      pendingBillsAmount: 1850.0,
      revenueByMethod: {
        'UPI': 16500.0,
        'CASH': 6000.0,
        'CARD': 2000.0,
      },
      lowStockItemsCount: 2,
      expiringSoonItemsCount: 1,
      totalMedicinesInFormulary: 145,
      pendingLabOrdersCount: 8,
      completedLabTodayCount: 42,
      totalStaffAccounts: 28,
      staffByRole: {
        'doctor': 12,
        'nurse': 6,
        'receptionist': 4,
        'admin': 3,
        'pharmacist': 2,
        'lab_technician': 1,
      },
      inactiveAccountsCount: 1,
      lockedAccountsCount: 0,
    );
  }

  @override
  Future<List<AdminUserModel>> getUsers({String? role, bool? isActive, String? search}) async {
    return [
      const AdminUserModel(
        id: 'usr-1',
        email: 'dr.chen@opdconnect.com',
        fullName: 'Dr. Sarah Chen',
        roleName: 'doctor',
        phone: '+919876543201',
        isActive: true,
        isVerified: true,
      ),
      const AdminUserModel(
        id: 'usr-2',
        email: 'nurse.joy@opdconnect.com',
        fullName: 'Nurse Joy',
        roleName: 'nurse',
        phone: '+919876543202',
        isActive: true,
        isVerified: true,
      ),
    ];
  }

  @override
  Future<List<DepartmentAdminModel>> getDepartments() async {
    return [
      const DepartmentAdminModel(
        id: 'dept-1',
        name: 'General Medicine OPD',
        code: 'GEN',
        description: 'Primary consultation & triage clinic',
        isActive: true,
        doctorsCount: 4,
      ),
    ];
  }

  @override
  Future<List<ServiceCatalogueItemModel>> getServicesCatalogue() async {
    return [
      const ServiceCatalogueItemModel(
        code: 'REG_GEN',
        name: 'General OPD Registration & Token',
        category: 'REGISTRATION',
        price: 100.0,
        isActive: true,
      ),
    ];
  }

  @override
  Future<List<MedicineAdminModel>> getMedicineCatalogue({String? search, bool lowStockOnly = false}) async {
    return [
      const MedicineAdminModel(
        id: 'med-1',
        medicineCode: 'MED001',
        name: 'Paracetamol',
        genericName: 'Acetaminophen',
        strength: '650mg',
        dosageForm: 'Tablet',
        quantity: 120,
        reorderLevel: 200,
        unitPrice: 2.5,
        taxPercentage: 12.0,
        isLowStock: true,
        isActive: true,
      ),
    ];
  }

  @override
  Future<List<TestCatalogueItemModel>> getTestCatalogue() async {
    return [
      const TestCatalogueItemModel(
        code: 'CBC',
        name: 'Complete Blood Count',
        sampleType: 'Whole Blood (EDTA)',
        turnaroundHours: 2,
        price: 250.0,
        parameters: ['Hemoglobin', 'WBC', 'Platelets'],
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> getRegistrationsReport({String? dateFrom, String? dateTo, String? departmentId, String? status}) async {
    return {
      'total_visits': 88,
      'status_summary': {'COMPLETED': 65, 'WAITING': 15, 'TRIAGE': 4},
      'department_summary': {'General Medicine': 50, 'Pediatrics': 38},
      'records': [
        {
          'visit_number': 'VIS-001',
          'patient_uhid': 'UHID-001',
          'department': 'General Medicine',
          'doctor': 'Dr. Sarah Chen',
          'queue_token': 1,
          'status': 'COMPLETED',
        }
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> getBillingReport({String? dateFrom, String? dateTo, String? paymentStatus}) async {
    return {
      'total_revenue': 24500.0,
      'total_discount': 500.0,
      'total_paid': 24000.0,
      'total_pending': 500.0,
      'total_bills_count': 32,
      'by_status': {'PAID': 30, 'PENDING': 2},
    };
  }

  @override
  Future<List<AuditLogItemModel>> getAuditLogs({String? action, String? entityType, String? query, int limit = 50}) async {
    return [
      const AuditLogItemModel(
        id: 'aud-1',
        userId: 'admin-1',
        action: 'ROLE_CHANGED',
        entityType: 'User',
        entityId: 'usr-2',
        ipAddress: '192.168.1.50',
        details: {'old_role': 'receptionist', 'new_role': 'nurse'},
        timestamp: '2026-10-12 11:30:00',
      ),
    ];
  }

  @override
  Future<List<SupportTicketModel>> getSupportTickets({String? status, String? category}) async {
    return [
      const SupportTicketModel(
        id: 'tkt-1',
        patientId: 'pat-101',
        patientName: 'Aarav Sharma',
        patientUhid: 'UHID-20261012-0001',
        subject: 'Billing inquiry',
        category: 'BILLING',
        priority: 'NORMAL',
        message: 'Discrepancy in consultation charge',
        status: 'OPEN',
        createdAt: '2026-10-12 10:00:00',
      ),
    ];
  }

  @override
  Future<List<SystemConfigModel>> getSystemConfigs() async {
    return [
      const SystemConfigModel(
        configKey: 'HOSPITAL_NAME',
        configValue: 'City General OPD Health Complex',
        category: 'GENERAL',
        description: 'Official clinical institution name',
      ),
    ];
  }

  @override
  Future<BackupGuidanceModel> getBackupGuidance() async {
    return const BackupGuidanceModel(
      databaseEngine: 'PostgreSQL / Supabase Engine',
      backupSchedule: 'Every 6 hours',
      retentionPeriodDays: 30,
      lastBackupStatus: 'SUCCESS',
      lastBackupTime: '2026-10-12 06:00:00',
      guidanceChecklist: ['WAL Archiving Active', 'Offsite S3 Replication Verified'],
      cronSpecification: '0 */6 * * *',
      restoreProcedureSteps: ['Spin up staging server', 'Replay pg_dump archive'],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Patient and Admin Models Unit Tests', () {
    test('PatientPortalProfile model deserializes correctly', () {
      final json = {
        'patient': {
          'id': 'p1',
          'uhid': 'UHID-001',
          'full_name': 'Ramesh Kumar',
          'gender': 'MALE',
          'age_years': 42,
          'phone': '9876543210',
          'blood_group': 'B+',
          'allergies': ['Pollen', 'Dust'],
        },
        'dependents': [
          {
            'id': 'd1',
            'uhid': 'UHID-002',
            'full_name': 'Kavya Kumar',
            'relation': 'Daughter',
            'gender': 'FEMALE',
            'age_display': '8 Y',
            'registration_date': '2026-10-12',
          }
        ],
        'has_active_token': true,
        'active_token_number': '#5',
        'active_token_queue_status': 'WAITING',
      };

      final profile = PatientPortalProfile.fromJson(json);
      expect(profile.patient.fullName, 'Ramesh Kumar');
      expect(profile.patient.uhid, 'UHID-001');
      expect(profile.dependents.length, 1);
      expect(profile.dependents.first.relation, 'Daughter');
      expect(profile.hasActiveToken, true);
      expect(profile.activeTokenNumber, '#5');
    });

    test('AdminDashboardMetricsModel model deserializes correctly', () {
      final json = {
        'total_patients_registered': 500,
        'visits_today_count': 45,
        'queue_breakdown': {'WAITING': 10, 'COMPLETED': 35},
        'active_clinics_count': 4,
        'active_doctors_count': 8,
        'revenue_today': 12000.5,
        'revenue_month': 350000.0,
        'pending_bills_count': 2,
        'pending_bills_amount': 900.0,
        'revenue_by_method': {'UPI': 8000.0, 'CASH': 4000.5},
        'low_stock_items_count': 3,
        'expiring_soon_items_count': 1,
        'total_medicines_in_formulary': 120,
        'pending_lab_orders_count': 5,
        'completed_lab_today_count': 20,
        'total_staff_accounts': 18,
        'staff_by_role': {'doctor': 8, 'nurse': 6, 'admin': 4},
        'inactive_accounts_count': 0,
        'locked_accounts_count': 0,
      };

      final metrics = AdminDashboardMetricsModel.fromJson(json);
      expect(metrics.totalPatientsRegistered, 500);
      expect(metrics.visitsTodayCount, 45);
      expect(metrics.revenueToday, 12000.5);
      expect(metrics.queueBreakdown['WAITING'], 10);
      expect(metrics.staffByRole['doctor'], 8);
    });
  });

  group('Patient Portal Widget UI Tests', () {
    testWidgets('Renders patient profile header and tabs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final container = ProviderContainer(
        overrides: [
          patientPortalRepositoryProvider.overrideWithValue(MockPatientPortalRepository()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: PatientPortalWorkspaceView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Patient Portal & Health Records'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsAtLeastNWidgets(1));
      expect(find.textContaining('UHID-20261012-0001'), findsAtLeastNWidgets(1));
      expect(find.textContaining('+919876543210'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Self (Aarav Sharma)'), findsAtLeastNWidgets(1));
      expect(find.text('Add Dependent'), findsOneWidget);

      // Verify Dependent Chip
      expect(find.textContaining('Ananya Sharma'), findsOneWidget);

      // Verify Tabs
      expect(find.text('Appointments'), findsOneWidget);
      expect(find.text('Prescriptions'), findsOneWidget);
      expect(find.text('Lab Reports'), findsOneWidget);
      expect(find.text('Medical Documents'), findsOneWidget);
      expect(find.text('Bills & Receipts'), findsOneWidget);
      expect(find.text('Visit History'), findsOneWidget);
      expect(find.text('Support & Inquiries'), findsOneWidget);

      // Active Token Banner
      expect(find.textContaining('Active Token: #14'), findsOneWidget);
      expect(find.textContaining('WAITING (3 Ahead)'), findsOneWidget);
    });
  });

  group('Hospital Administrator Portal Widget UI Tests', () {
    testWidgets('Renders top operational KPI metrics and tabs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final container = ProviderContainer(
        overrides: [
          adminPortalRepositoryProvider.overrideWithValue(MockAdminPortalRepository()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HospitalAdminWorkspaceView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top Title
      expect(find.text('Hospital Administrator Portal'), findsOneWidget);
      expect(find.text('Operations, Security & Governance Console'), findsOneWidget);

      // Top KPI Chips
      expect(find.text('Total UHID'), findsOneWidget);
      expect(find.text('1240'), findsOneWidget);
      expect(find.text("Today's Footfall"), findsOneWidget);
      expect(find.text('88'), findsOneWidget);
      expect(find.text("Today's Revenue"), findsOneWidget);
      expect(find.text('₹24500'), findsOneWidget);

      // Tab Headers
      expect(find.text('Operations & Financials'), findsOneWidget);
      expect(find.text('Staff & Roles'), findsOneWidget);
      expect(find.text('Departments & Tariffs'), findsOneWidget);
      expect(find.text('Catalogues & Formulary'), findsOneWidget);
      expect(find.text('Operational Reports'), findsOneWidget);
      expect(find.text('Compliance & Audit'), findsOneWidget);
      expect(find.text('Support Desk'), findsOneWidget);
      expect(find.text('System Config & Backup'), findsOneWidget);

      // Tab 1 Operations & Financials Content
      expect(find.text('Waiting in Queue'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Collections Summary'), findsOneWidget);

      // Switch to Staff Tab
      await tester.tap(find.text('Staff & Roles'));
      await tester.pumpAndSettle();
      expect(find.text('Provision Staff User'), findsOneWidget);
      expect(find.text('Dr. Sarah Chen'), findsOneWidget);
      expect(find.text('Nurse Joy'), findsOneWidget);

      // Switch to Compliance & Audit Tab
      await tester.ensureVisible(find.text('Compliance & Audit'));
      await tester.tap(find.text('Compliance & Audit'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Segregation of Duties'), findsOneWidget);
      expect(find.text('ROLE_CHANGED'), findsOneWidget);
      expect(find.text('Inspect Details'), findsOneWidget);
    });
  });
}
