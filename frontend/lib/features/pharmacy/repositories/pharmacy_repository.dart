import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/pharmacy_models.dart';

class PharmacyRepository {
  final DioClient _dioClient;

  PharmacyRepository(this._dioClient);

  Future<List<MedicineInventoryItem>> getInventory({
    String? query,
    String? dosageForm,
    bool? lowStock,
    bool? expiringSoon,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (query != null && query.trim().isNotEmpty) {
        queryParams['query'] = query.trim();
      }
      if (dosageForm != null && dosageForm.isNotEmpty && dosageForm != 'All') {
        queryParams['dosage_form'] = dosageForm;
      }
      if (lowStock == true) {
        queryParams['low_stock'] = true;
      }
      if (expiringSoon == true) {
        queryParams['expiring_soon'] = true;
      }

      final res = await _dioClient.dio.get(
        ApiEndpoints.pharmacyInventory,
        queryParameters: queryParams,
      );
      if (res.data['status'] == 'success') {
        final list = res.data['data'] as List<dynamic>;
        return list
            .map((item) => MedicineInventoryItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<InventoryStats> getInventoryStats() async {
    try {
      final res = await _dioClient.dio.get(ApiEndpoints.pharmacyInventoryStats);
      if (res.data['status'] == 'success') {
        return InventoryStats.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return const InventoryStats();
  }

  Future<MedicineInventoryItem?> receiveStock(Map<String, dynamic> payload) async {
    final res = await _dioClient.dio.post(
      ApiEndpoints.pharmacyInventoryReceive,
      data: payload,
    );
    if (res.data['status'] == 'success' && res.data['data'] != null) {
      return MedicineInventoryItem.fromJson(res.data['data'] as Map<String, dynamic>);
    }
    return null;
  }

  Future<Map<String, dynamic>?> adjustStock(Map<String, dynamic> payload) async {
    final res = await _dioClient.dio.post(
      ApiEndpoints.pharmacyInventoryAdjust,
      data: payload,
    );
    if (res.data['status'] == 'success' && res.data['data'] != null) {
      return res.data['data'] as Map<String, dynamic>;
    }
    return null;
  }

  Future<List<StockMovementItem>> getStockMovements({
    String? inventoryId,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (inventoryId != null && inventoryId.isNotEmpty) {
        queryParams['inventory_id'] = inventoryId;
      }

      final res = await _dioClient.dio.get(
        ApiEndpoints.pharmacyMovements,
        queryParameters: queryParams,
      );
      if (res.data['status'] == 'success') {
        final list = res.data['data'] as List<dynamic>;
        return list
            .map((item) => StockMovementItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<PrescriptionForDispensing>> getPrescriptionsForDispensing({
    String? visitId,
    String? patientId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (visitId != null && visitId.isNotEmpty) {
        queryParams['visit_id'] = visitId;
      }
      if (patientId != null && patientId.isNotEmpty) {
        queryParams['patient_id'] = patientId;
      }

      final res = await _dioClient.dio.get(
        ApiEndpoints.pharmacyPrescriptions,
        queryParameters: queryParams,
      );
      if (res.data['status'] == 'success') {
        final list = res.data['data'] as List<dynamic>;
        return list
            .map((item) => PrescriptionForDispensing.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<PharmacyDispenseRecord?> dispensePrescription(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    final headers = <String, dynamic>{
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'X-Idempotency-Key': idempotencyKey,
    };

    final res = await _dioClient.dio.post(
      ApiEndpoints.pharmacyDispense,
      options: Options(headers: headers),
      data: payload,
    );
    if (res.data['status'] == 'success' && res.data['data'] != null) {
      return PharmacyDispenseRecord.fromJson(res.data['data'] as Map<String, dynamic>);
    }
    return null;
  }

  Future<List<PharmacyDispenseRecord>> getDispensesHistory({
    String? visitId,
    String? patientId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (visitId != null && visitId.isNotEmpty) {
        queryParams['visit_id'] = visitId;
      }
      if (patientId != null && patientId.isNotEmpty) {
        queryParams['patient_id'] = patientId;
      }

      final res = await _dioClient.dio.get(
        ApiEndpoints.pharmacyDispenses,
        queryParameters: queryParams,
      );
      if (res.data['status'] == 'success') {
        final list = res.data['data'] as List<dynamic>;
        return list
            .map((item) => PharmacyDispenseRecord.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<PharmacyDispenseRecord?> getDispenseDetail(String dispenseId) async {
    try {
      final res = await _dioClient.dio.get(
        ApiEndpoints.pharmacyDispenseById(dispenseId),
      );
      if (res.data['status'] == 'success' && res.data['data'] != null) {
        return PharmacyDispenseRecord.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }
}
