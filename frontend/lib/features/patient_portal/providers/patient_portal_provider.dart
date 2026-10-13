import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/patient_portal_models.dart';
import '../repositories/patient_portal_repository.dart';

final patientPortalRepositoryProvider = Provider<PatientPortalRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return PatientPortalRepository(dioClient);
});

class PortalPatientFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  set state(String? value) => super.state = value;
}

// Selected Dependent Patient ID (null = Primary Patient)
final selectedPortalPatientIdProvider =
    NotifierProvider<PortalPatientFilterNotifier, String?>(PortalPatientFilterNotifier.new);

// Profile
final patientProfileProvider = FutureProvider<PatientPortalProfile>((ref) async {
  final repo = ref.watch(patientPortalRepositoryProvider);
  return repo.getProfile();
});

// Dependents
final patientDependentsProvider = FutureProvider<List<DependentProfile>>((ref) async {
  final repo = ref.watch(patientPortalRepositoryProvider);
  return repo.getDependents();
});

// Visits
final patientVisitsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(patientPortalRepositoryProvider);
  final targetId = ref.watch(selectedPortalPatientIdProvider);
  return repo.getVisits(patientId: targetId);
});

// Appointments
final patientAppointmentsProvider = FutureProvider<List<UpcomingAppointment>>((ref) async {
  final repo = ref.watch(patientPortalRepositoryProvider);
  final targetId = ref.watch(selectedPortalPatientIdProvider);
  return repo.getAppointments(patientId: targetId);
});

// Prescriptions
final patientPrescriptionsProvider = FutureProvider<List<PatientPrescriptionSummaryItem>>((ref) async {
  final repo = ref.watch(patientPortalRepositoryProvider);
  final targetId = ref.watch(selectedPortalPatientIdProvider);
  return repo.getPrescriptions(patientId: targetId);
});

// Lab Reports
final patientLabReportsProvider = FutureProvider<List<PatientLabReportSummary>>((ref) async {
  final repo = ref.watch(patientPortalRepositoryProvider);
  final targetId = ref.watch(selectedPortalPatientIdProvider);
  return repo.getLabReports(patientId: targetId);
});

// Medical Documents
final patientDocumentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(patientPortalRepositoryProvider);
  final targetId = ref.watch(selectedPortalPatientIdProvider);
  return repo.getDocuments(patientId: targetId);
});

// Bills
final patientBillsProvider = FutureProvider<List<PatientBillSummary>>((ref) async {
  final repo = ref.watch(patientPortalRepositoryProvider);
  final targetId = ref.watch(selectedPortalPatientIdProvider);
  return repo.getBills(patientId: targetId);
});

// Support Tickets
final patientSupportTicketsProvider = FutureProvider<List<SupportTicketModel>>((ref) async {
  final repo = ref.watch(patientPortalRepositoryProvider);
  final targetId = ref.watch(selectedPortalPatientIdProvider);
  return repo.getSupportTickets(patientId: targetId);
});
