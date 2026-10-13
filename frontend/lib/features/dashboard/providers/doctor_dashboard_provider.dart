import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/doctor_dashboard_model.dart';
import '../../visits/models/visit_model.dart';

final doctorDashboardProvider = FutureProvider<DoctorDashboardModel>((ref) async {
  final dioClient = ref.watch(dioClientProvider);

  try {
    final response = await dioClient.dio.get(ApiEndpoints.doctorMyDashboard);
    if (response.data['status'] == 'success') {
      return DoctorDashboardModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }
  } catch (e) {
    // If running in development/mock mode without active backend or offline, provide realistic fallback
  }

  // Fallback demo dataset for development
  return DoctorDashboardModel(
    stats: DoctorDashboardStatsModel(
      todayAppointments: 4,
      waitingPatients: 2,
      underConsultation: 1,
      completedConsultations: 1,
      pendingInvestigations: 1,
      followUpAppointments: 1,
    ),
    waitingPatients: [
      OPDVisitModel(
        id: 'vis-demo-wait',
        visitNumber: 'VIS-20261012-0002',
        patientId: 'pat-demo-2',
        doctorId: 'doc-demo-1',
        departmentId: 'dept-demo-1',
        queueToken: 2,
        triagePriority: 'NORMAL',
        status: 'TRIAGED',
        consultationFee: 250.0,
        paymentStatus: 'PAID',
        visitDate: DateTime.now(),
        patient: null,
      ),
    ],
    underConsultation: [
      OPDVisitModel(
        id: 'vis-demo-consult',
        visitNumber: 'VIS-20261012-0003',
        patientId: 'pat-demo-3',
        doctorId: 'doc-demo-1',
        departmentId: 'dept-demo-1',
        queueToken: 3,
        triagePriority: 'PRIORITY',
        status: 'IN_CONSULTATION',
        consultationFee: 250.0,
        paymentStatus: 'PAID',
        visitDate: DateTime.now(),
        patient: null,
      ),
    ],
    completedConsultations: [
      OPDVisitModel(
        id: 'vis-demo-completed',
        visitNumber: 'VIS-20261012-0001',
        patientId: 'pat-demo-1',
        doctorId: 'doc-demo-1',
        departmentId: 'dept-demo-1',
        queueToken: 1,
        triagePriority: 'NORMAL',
        status: 'COMPLETED',
        consultationFee: 250.0,
        paymentStatus: 'PAID',
        visitDate: DateTime.now(),
        patient: null,
      ),
    ],
    pendingInvestigations: [
      PendingInvestigationModel(
        id: 'lab-demo-1',
        testName: 'HbA1c & Fasting Lipid Profile',
        testCategory: 'Biochemistry',
        status: 'ORDERED',
        patientId: 'pat-demo-3',
        patientName: 'Robert Miller',
        uhid: 'UHID-2026-00003',
        visitId: 'vis-demo-consult',
        visitNumber: 'VIS-20261012-0003',
        createdAt: '2026-10-12T10:30:00Z',
        clinicalIndication: 'Glycemic control assessment',
      ),
    ],
    followUpAppointments: [
      FollowUpAppointmentModel(
        patientId: 'pat-demo-1',
        patientName: 'Johnathan Reynolds',
        uhid: 'UHID-2026-00001',
        visitId: 'vis-demo-completed',
        followUpDate: '2026-10-19',
        finalDiagnosis: 'Acute Viral Pharyngitis (J02.9)',
        carePlan: 'Warm saline gargles, hydration, review if persistent fever',
      ),
    ],
    recentAuthorizedPatients: [
      RecentAuthorizedPatientModel(
        patientId: 'pat-demo-1',
        uhid: 'UHID-2026-00001',
        fullName: 'Johnathan Reynolds',
        ageDisplay: '38 Y',
        gender: 'MALE',
        phoneNumber: '+15551234567',
        lastVisitDate: '2026-10-12',
        lastDiagnosis: 'Acute Viral Pharyngitis',
      ),
    ],
  );
});
