import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/prescription_model.dart';
import '../repositories/prescription_repository.dart';

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return PrescriptionRepository(dioClient);
});

final prescriptionListProvider = FutureProvider.family<List<PrescriptionModel>, String>((ref, visitId) async {
  final repository = ref.watch(prescriptionRepositoryProvider);
  return repository.getPrescriptionsByVisit(visitId);
});
