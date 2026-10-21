import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/consultation_context_model.dart';

final consultationContextProvider = FutureProvider.family<ConsultationContextModel, String>((ref, visitId) async {
  final dioClient = ref.watch(dioClientProvider);
  try {
    final response = await dioClient.dio.get(ApiEndpoints.consultationContext(visitId));
    if (response.data != null && response.data['data'] != null) {
      return ConsultationContextModel.fromJson(response.data['data']);
    }
    throw Exception('Failed to load consultation context');
  } catch (e) {
    // Return empty context fallback for offline / disconnected states
    return ConsultationContextModel(
      visit: {},
      patient: {},
      medicalHistory: PatientMedicalHistorySummaryModel(),
      previousVisits: [],
      availableInvestigations: [],
      activePrescriptions: [],
    );
  }
});
