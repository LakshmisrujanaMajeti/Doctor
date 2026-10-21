import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/clinical_record_model.dart';
import '../repositories/clinical_repository.dart';

final clinicalRepositoryProvider = Provider<ClinicalRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ClinicalRepository(dioClient);
});

final clinicalRecordProvider = FutureProvider.family<ClinicalRecordModel?, String>((ref, visitId) async {
  final repository = ref.watch(clinicalRepositoryProvider);
  return repository.getRecordByVisit(visitId);
});
