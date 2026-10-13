import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/laboratory_models.dart';

class LaboratoryRepository {
  final DioClient _dioClient;

  LaboratoryRepository(this._dioClient);

  Future<List<LabCatalogueItem>> getCatalogue({String? category}) async {
    try {
      final res = await _dioClient.dio.get(
        ApiEndpoints.labCatalogue,
        queryParameters: category != null ? {'category': category} : null,
      );
      if (res.data['status'] == 'success') {
        final list = res.data['data'] as List<dynamic>;
        return list
            .map((item) => LabCatalogueItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<LabDashboardStatsModel> getDashboardStats() async {
    try {
      final res = await _dioClient.dio.get(ApiEndpoints.labDashboardStats);
      if (res.data['status'] == 'success') {
        return LabDashboardStatsModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return const LabDashboardStatsModel();
  }

  Future<List<LabOrderModel>> getOrders({
    String? department,
    String? status,
    String? specimenStatus,
    String? search,
    String? date,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (department != null && department.isNotEmpty && department != 'All') {
        queryParams['department'] = department;
      }
      if (status != null && status.isNotEmpty && status != 'All') {
        queryParams['status'] = status;
      }
      if (specimenStatus != null && specimenStatus.isNotEmpty && specimenStatus != 'All') {
        queryParams['specimen_status'] = specimenStatus;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (date != null && date.isNotEmpty) {
        queryParams['date'] = date;
      }

      final res = await _dioClient.dio.get(
        ApiEndpoints.labOrders,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (res.data['status'] == 'success') {
        final list = res.data['data'] as List<dynamic>;
        return list
            .map((item) => LabOrderModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<LabOrderModel?> getOrderById(String id) async {
    try {
      final res = await _dioClient.dio.get(ApiEndpoints.labOrderById(id));
      if (res.data['status'] == 'success') {
        return LabOrderModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<LabOrderModel> collectSpecimen({
    required String orderId,
    String? specimenType,
    String? collectionTime,
    String? collectorName,
  }) async {
    final payload = <String, dynamic>{};
    if (specimenType != null) payload['specimen_type'] = specimenType;
    if (collectionTime != null) payload['collection_time'] = collectionTime;
    if (collectorName != null) payload['collector_name'] = collectorName;

    final res = await _dioClient.dio.post(
      ApiEndpoints.labOrderCollect(orderId),
      data: payload,
    );
    if (res.data['status'] == 'success') {
      return LabOrderModel.fromJson(res.data['data'] as Map<String, dynamic>);
    }
    throw Exception(res.data['message'] ?? 'Failed to record specimen collection');
  }

  Future<LabOrderModel> receiveSpecimen({
    required String orderId,
    String? receivedByName,
  }) async {
    final payload = <String, dynamic>{};
    if (receivedByName != null) payload['received_by_name'] = receivedByName;

    final res = await _dioClient.dio.post(
      ApiEndpoints.labOrderReceive(orderId),
      data: payload,
    );
    if (res.data['status'] == 'success') {
      return LabOrderModel.fromJson(res.data['data'] as Map<String, dynamic>);
    }
    throw Exception(res.data['message'] ?? 'Failed to receive specimen in laboratory');
  }

  Future<LabOrderModel> rejectSpecimen({
    required String orderId,
    required String reason,
  }) async {
    final res = await _dioClient.dio.post(
      ApiEndpoints.labOrderReject(orderId),
      data: {'reason': reason},
    );
    if (res.data['status'] == 'success') {
      return LabOrderModel.fromJson(res.data['data'] as Map<String, dynamic>);
    }
    throw Exception(res.data['message'] ?? 'Failed to reject specimen');
  }

  Future<LabOrderModel> enterResults({
    required String orderId,
    required List<LabResultItemModel> results,
    bool flagReview = false,
  }) async {
    final payload = {
      'results': results.map((r) => r.toJson()).toList(),
      'flag_review': flagReview,
    };

    final res = await _dioClient.dio.post(
      ApiEndpoints.labOrderResults(orderId),
      data: payload,
    );
    if (res.data['status'] == 'success') {
      return LabOrderModel.fromJson(res.data['data'] as Map<String, dynamic>);
    }
    throw Exception(res.data['message'] ?? 'Failed to record results');
  }

  Future<LabOrderModel> verifyOrder({
    required String orderId,
    String? verificationNotes,
    bool publishToVisit = true,
  }) async {
    final payload = {
      'verification_notes': verificationNotes,
      'publish_to_visit': publishToVisit,
    };

    final res = await _dioClient.dio.post(
      ApiEndpoints.labOrderVerify(orderId),
      data: payload,
    );
    if (res.data['status'] == 'success') {
      return LabOrderModel.fromJson(res.data['data'] as Map<String, dynamic>);
    }
    throw Exception(res.data['message'] ?? 'Failed to verify lab order');
  }

  Future<LabReportDataModel> getPrintableReport(String orderId) async {
    final res = await _dioClient.dio.get(ApiEndpoints.labOrderReport(orderId));
    if (res.data['status'] == 'success') {
      return LabReportDataModel.fromJson(res.data['data'] as Map<String, dynamic>);
    }
    throw Exception(res.data['message'] ?? 'Failed to generate printable lab report');
  }

  Future<List<LabOrderModel>> getOrdersByVisit(String visitId) async {
    try {
      final res = await _dioClient.dio.get(ApiEndpoints.labOrdersByVisit(visitId));
      if (res.data['status'] == 'success') {
        final list = res.data['data'] as List<dynamic>;
        return list
            .map((item) => LabOrderModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
