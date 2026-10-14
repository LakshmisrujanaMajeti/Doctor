import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/patient_model.dart';
import '../repositories/patient_repository.dart';

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return PatientRepository(dioClient);
});

class PatientSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final patientSearchQueryProvider = NotifierProvider<PatientSearchNotifier, String>(PatientSearchNotifier.new);

final patientListProvider = FutureProvider<List<PatientModel>>((ref) async {
  final repository = ref.watch(patientRepositoryProvider);
  final query = ref.watch(patientSearchQueryProvider);
  return repository.getPatients(query: query);
});

final patientDetailProvider = FutureProvider.family<PatientModel?, String>((ref, patientId) async {
  final repository = ref.watch(patientRepositoryProvider);
  return repository.getPatientById(patientId);
});
