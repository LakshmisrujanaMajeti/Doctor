import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/supabase_service.dart';
import '../models/prescription_model.dart';

class PrescriptionRepository {
  final DioClient _dioClient;

  PrescriptionRepository(this._dioClient);

  Future<List<PrescriptionModel>> getPrescriptionsByVisit(String visitId) async {
    if (DioClient.isHostReachable) {
      try {
        final res = await _dioClient.dio.get(ApiEndpoints.prescriptionsByVisit(visitId));
        if (res.data['status'] == 'success') {
          final list = res.data['data'] as List<dynamic>;
          return list.map((item) => PrescriptionModel.fromJson(item as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }

    // Direct Supabase Cloud Fetch
    try {
      final supaRx = await SupabaseService.fetchPrescription(visitId);
      if (supaRx != null) {
        return [PrescriptionModel.fromJson(supaRx)];
      }
    } catch (e) {
      debugPrint('Supabase fetchPrescription note: $e');
    }

    return [];
  }

  Future<List<MedicineCatalogItemModel>> searchMedicines({String? query}) async {
    try {
      final res = await _dioClient.dio.get(
        ApiEndpoints.medicineSearch,
        queryParameters: query != null && query.isNotEmpty ? {'q': query} : null,
      );
      if (res.data['status'] == 'success') {
        final list = res.data['data'] as List<dynamic>;
        return list.map((item) => MedicineCatalogItemModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    // Curated catalog fallback
    return [
      MedicineCatalogItemModel(
        name: 'Paracetamol',
        category: 'Analgesic / Antipyretic',
        commonForms: ['Tablet', 'Syrup', 'Injection'],
        commonDosages: ['650 mg', '500 mg', '250 mg/5ml'],
        defaultRoute: 'Oral',
      ),
      MedicineCatalogItemModel(
        name: 'Amoxicillin',
        category: 'Penicillin Antibiotic',
        commonForms: ['Capsule', 'Syrup', 'Tablet'],
        commonDosages: ['500 mg', '250 mg'],
        defaultRoute: 'Oral',
        allergyClass: 'penicillin',
      ),
      MedicineCatalogItemModel(
        name: 'Augmentin (Amoxicillin + Clavulanate)',
        category: 'Penicillin Antibiotic',
        commonForms: ['Tablet', 'Syrup'],
        commonDosages: ['625 mg', '375 mg'],
        defaultRoute: 'Oral',
        allergyClass: 'penicillin',
      ),
      MedicineCatalogItemModel(
        name: 'Co-trimoxazole (Bactrim)',
        category: 'Sulfonamide Antibacterial',
        commonForms: ['Tablet', 'Suspension'],
        commonDosages: ['Double Strength (800/160 mg)', 'Single Strength (400/80 mg)'],
        defaultRoute: 'Oral',
        allergyClass: 'sulfa',
      ),
      MedicineCatalogItemModel(
        name: 'Cetirizine',
        category: 'Antihistamine',
        commonForms: ['Tablet', 'Syrup'],
        commonDosages: ['10 mg', '5 mg'],
        defaultRoute: 'Oral',
      ),
      MedicineCatalogItemModel(
        name: 'Pantoprazole',
        category: 'Proton Pump Inhibitor',
        commonForms: ['Tablet', 'Injection'],
        commonDosages: ['40 mg', '20 mg'],
        defaultRoute: 'Oral',
      ),
      MedicineCatalogItemModel(
        name: 'Metformin',
        category: 'Antidiabetic Biguanide',
        commonForms: ['Tablet'],
        commonDosages: ['500 mg', '1000 mg SR'],
        defaultRoute: 'Oral',
      ),
    ];
  }

  Future<List<AllergyWarningModel>> checkAllergies({
    required String patientId,
    required List<String> medicines,
  }) async {
    try {
      final res = await _dioClient.dio.post(
        ApiEndpoints.checkAllergies,
        data: {
          'patient_id': patientId,
          'medicines': medicines,
        },
      );
      if (res.data['status'] == 'success') {
        final data = res.data['data'] as Map<String, dynamic>;
        final rawWarnings = data['warnings'] as List<dynamic>? ?? [];
        return rawWarnings.map((w) => AllergyWarningModel.fromJson(w as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<PrescriptionModel> createPrescription(
    PrescriptionModel rx, {
    String? idempotencyKey,
  }) async {
    final cli = SupabaseService.client;
    final rxId = rx.id.isNotEmpty ? rx.id : 'rx_${DateTime.now().millisecondsSinceEpoch}';
    if (cli != null) {
      cli.from('prescriptions').upsert({
        'id': rxId,
        'visit_id': rx.visitId,
        'patient_id': rx.patientId,
        'doctor_id': rx.doctorId,
        'status': rx.status,
        'version': rx.version,
        'notes': rx.notes,
        'is_ocr_extracted': rx.isOcrExtracted,
        'is_verified_by_clinician': rx.isVerifiedByClinician,
        'allergy_warning_acknowledged': rx.allergyWarningAcknowledged,
      }).catchError((_) => null);

      for (int i = 0; i < rx.items.length; i++) {
        final item = rx.items[i];
        cli.from('prescription_items').upsert({
          'id': item.id ?? 'item_${rxId}_$i',
          'prescription_id': rxId,
          'medicine_name': item.medicineName,
          'form': item.form,
          'dosage': item.dosage,
          'route': item.route,
          'frequency': item.frequency,
          'duration_days': item.durationDays,
          'timing': item.timing,
          'instructions': item.instructions,
          'is_dispensed': item.isDispensed,
        }).catchError((_) => null);
      }
    }

    final headers = <String, dynamic>{
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'X-Idempotency-Key': idempotencyKey,
    };

    try {
      final res = await _dioClient.dio.post(
        ApiEndpoints.prescriptions,
        options: Options(headers: headers),
        data: rx.toJson(),
      );
      if (res.data['status'] == 'success') {
        return PrescriptionModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    return rx;
  }

  Future<PrescriptionModel> signPrescription(
    String id, {
    bool acknowledgeAllergy = false,
  }) async {
    final cli = SupabaseService.client;
    if (cli != null) {
      cli.from('prescriptions').update({
        'status': 'SIGNED',
        'allergy_warning_acknowledged': acknowledgeAllergy,
        'signed_at': DateTime.now().toIso8601String(),
      }).eq('id', id).catchError((_) => null);
    }

    try {
      final res = await _dioClient.dio.post(
        ApiEndpoints.signPrescription(id),
        data: {'allergy_warning_acknowledged': acknowledgeAllergy},
      );
      if (res.data['status'] == 'success') {
        return PrescriptionModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    return PrescriptionModel(
      id: id,
      visitId: '',
      patientId: '',
      doctorId: '',
      status: 'SIGNED',
      items: [],
      allergyWarningAcknowledged: acknowledgeAllergy,
      signedAt: DateTime.now().toIso8601String(),
    );
  }

  Future<PrescriptionModel> amendPrescription(
    String id, {
    required String reason,
    required List<PrescriptionItemModel> items,
    String? notes,
  }) async {
    final cli = SupabaseService.client;
    if (cli != null) {
      cli.from('prescriptions').update({
        'status': 'AMENDED',
        'amendment_reason': reason,
        'notes': notes,
      }).eq('id', id).catchError((_) => null);
    }

    try {
      final res = await _dioClient.dio.post(
        ApiEndpoints.amendPrescription(id),
        data: {
          'amendment_reason': reason,
          'notes': notes,
          'items': items.map((i) => i.toJson()).toList(),
        },
      );
      if (res.data['status'] == 'success') {
        return PrescriptionModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    return PrescriptionModel(
      id: id,
      visitId: '',
      patientId: '',
      doctorId: '',
      status: 'AMENDED',
      amendmentReason: reason,
      notes: notes,
      items: items,
    );
  }

  Future<PrescriptionModel> cancelPrescription(String id, {String reason = 'Clinician cancelled'}) async {
    final cli = SupabaseService.client;
    if (cli != null) {
      cli.from('prescriptions').update({
        'status': 'CANCELLED',
      }).eq('id', id).catchError((_) => null);
    }

    try {
      final res = await _dioClient.dio.post(
        ApiEndpoints.cancelPrescription(id),
        data: {'reason': reason},
      );
      if (res.data['status'] == 'success') {
        return PrescriptionModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    return PrescriptionModel(
      id: id,
      visitId: '',
      patientId: '',
      doctorId: '',
      status: 'CANCELLED',
      items: [],
    );
  }
}
