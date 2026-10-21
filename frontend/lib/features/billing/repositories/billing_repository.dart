import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/billing_models.dart';

class BillingRepository {
  final DioClient _dioClient;

  BillingRepository(this._dioClient);

  Future<List<ServiceCatalogueItem>> getServicesCatalogue() async {
    try {
      final res = await _dioClient.dio.get(ApiEndpoints.billingServicesCatalogue);
      if (res.data['status'] == 'success') {
        final list = res.data['data'] as List<dynamic>;
        return list
            .map((item) => ServiceCatalogueItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<BillModel>> getBills({
    String? patientId,
    String? visitId,
    String? status,
    String? paymentStatus,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (patientId != null && patientId.isNotEmpty) {
        queryParams['patient_id'] = patientId;
      }
      if (visitId != null && visitId.isNotEmpty) {
        queryParams['visit_id'] = visitId;
      }
      if (status != null && status.isNotEmpty && status != 'All') {
        queryParams['status'] = status;
      }
      if (paymentStatus != null && paymentStatus.isNotEmpty && paymentStatus != 'All') {
        queryParams['payment_status'] = paymentStatus;
      }

      final res = await _dioClient.dio.get(
        ApiEndpoints.bills,
        queryParameters: queryParams,
      );
      if (res.data['status'] == 'success') {
        final list = res.data['data'] as List<dynamic>;
        return list
            .map((item) => BillModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<BillModel?> getBillById(String id) async {
    try {
      final res = await _dioClient.dio.get(ApiEndpoints.billById(id));
      if (res.data['status'] == 'success' && res.data['data'] != null) {
        return BillModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<BillModel?> createBill(Map<String, dynamic> payload) async {
    final res = await _dioClient.dio.post(
      ApiEndpoints.bills,
      data: payload,
    );
    if (res.data['status'] == 'success' && res.data['data'] != null) {
      return BillModel.fromJson(res.data['data'] as Map<String, dynamic>);
    }
    return null;
  }

  Future<Map<String, dynamic>?> recordPayment(
    String billId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dioClient.dio.post(
      ApiEndpoints.billingPayments(billId),
      data: payload,
    );
    if (res.data['status'] == 'success' && res.data['data'] != null) {
      return res.data['data'] as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>?> reconcilePaymentCallback(
    Map<String, dynamic> payload,
  ) async {
    final res = await _dioClient.dio.post(
      ApiEndpoints.billingPaymentCallback,
      data: payload,
    );
    if (res.data['status'] == 'success' && res.data['data'] != null) {
      return res.data['data'] as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>?> processRefund(
    String billId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dioClient.dio.post(
      ApiEndpoints.billingRefund(billId),
      data: payload,
    );
    if (res.data['status'] == 'success' && res.data['data'] != null) {
      return res.data['data'] as Map<String, dynamic>;
    }
    return null;
  }

  Future<BillModel?> cancelBill(String billId, {required String reason}) async {
    final res = await _dioClient.dio.post(
      ApiEndpoints.billingCancel(billId),
      data: {'reason': reason},
    );
    if (res.data['status'] == 'success' && res.data['data'] != null) {
      return BillModel.fromJson(res.data['data'] as Map<String, dynamic>);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getPrintableReceipt(String billId) async {
    try {
      final res = await _dioClient.dio.get(ApiEndpoints.billingReceipt(billId));
      if (res.data['status'] == 'success' && res.data['data'] != null) {
        return res.data['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
