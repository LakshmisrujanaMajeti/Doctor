import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/patient_model.dart';

class PatientRepository {
  final DioClient _dioClient;

  // Local fallback cache
  final List<PatientModel> _localPatients = [
    PatientModel(
      id: 'demo-pat-1',
      uhid: 'UHID-2026-00001',
      hospitalRegNum: 'REG-2026-00001',
      fullName: 'Johnathan Reynolds',
      parentSpouseName: 'Thomas Reynolds',
      parentSpouseRelation: 'S/o',
      ageYears: 38,
      ageMonths: 0,
      gender: 'MALE',
      phone: '+15551234567',
      email: 'johnathan@example.com',
      bloodGroup: 'O+',
      address: '123 Hospital Ave, Metro Health District',
      city: 'Metro City',
      state: 'State Health Region',
      postalCode: '500001',
      barcodeValue: 'BAR-UHID-2026-00001',
      qrCodeData: 'OPDCONNECT+UHID-2026-00001+REG-2026-00001',
      emergencyContactName: 'Mary Reynolds',
      emergencyContactPhone: '+15559998888',
      emergencyContactRelation: 'Spouse',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    PatientModel(
      id: 'demo-pat-2',
      uhid: 'UHID-2026-00002',
      hospitalRegNum: 'REG-2026-00002',
      fullName: 'Priya Sharma',
      parentSpouseName: 'Rajesh Sharma',
      parentSpouseRelation: 'W/o',
      ageYears: 32,
      ageMonths: 0,
      gender: 'FEMALE',
      phone: '+15559876543',
      email: 'priya@example.com',
      bloodGroup: 'B+',
      address: '45 Lake View Road, Metropolis',
      city: 'Metropolis',
      state: 'Central Province',
      postalCode: '500045',
      barcodeValue: 'BAR-UHID-2026-00002',
      qrCodeData: 'OPDCONNECT+UHID-2026-00002+REG-2026-00002',
      emergencyContactName: 'Raj Sharma',
      emergencyContactPhone: '+15557776666',
      emergencyContactRelation: 'Brother',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    PatientModel(
      id: 'demo-pat-3',
      uhid: 'UHID-2026-00003',
      hospitalRegNum: 'REG-2026-00003',
      fullName: 'Robert Miller',
      parentSpouseName: 'George Miller',
      parentSpouseRelation: 'S/o',
      ageYears: 60,
      ageMonths: 0,
      gender: 'MALE',
      phone: '+15554567890',
      bloodGroup: 'A+',
      address: '77 Pine Street, Springfield',
      city: 'Springfield',
      state: 'Northern Territory',
      postalCode: '500077',
      barcodeValue: 'BAR-UHID-2026-00003',
      qrCodeData: 'OPDCONNECT+UHID-2026-00003+REG-2026-00003',
      emergencyContactName: 'Linda Miller',
      emergencyContactPhone: '+15553332222',
      emergencyContactRelation: 'Daughter',
      createdAt: DateTime.now(),
    ),
  ];

  PatientRepository(this._dioClient);

  Future<List<PatientModel>> getPatients({String? query}) async {
    try {
      final res = await _dioClient.dio.get(
        ApiEndpoints.patients,
        queryParameters: query != null && query.isNotEmpty ? {'query': query} : null,
      );

      if (res.data['status'] == 'success') {
        final list = res.data['data'] as List<dynamic>;
        return list.map((item) => PatientModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    // Fallback search in local items
    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      return _localPatients.where((p) =>
        p.fullName.toLowerCase().contains(q) ||
        p.uhid.toLowerCase().contains(q) ||
        (p.hospitalRegNum != null && p.hospitalRegNum!.toLowerCase().contains(q)) ||
        (p.barcodeValue != null && p.barcodeValue!.toLowerCase().contains(q)) ||
        p.phone.contains(q)
      ).toList();
    }
    return _localPatients;
  }

  Future<DuplicateCheckResult> checkDuplicates({
    required String phone,
    String? fullName,
    String? hospitalRegNum,
  }) async {
    try {
      final res = await _dioClient.dio.post(
        ApiEndpoints.checkDuplicate,
        data: {
          'phone': phone,
          if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
          if (hospitalRegNum != null && hospitalRegNum.isNotEmpty) 'hospital_reg_num': hospitalRegNum,
        },
      );
      if (res.data['status'] == 'success') {
        return DuplicateCheckResult.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    // Local check fallback
    final candidates = <DuplicateCandidateModel>[];
    for (final p in _localPatients) {
      if (hospitalRegNum != null && p.hospitalRegNum == hospitalRegNum) {
        candidates.add(DuplicateCandidateModel(
          id: p.id,
          uhid: p.uhid,
          hospitalRegNum: p.hospitalRegNum,
          fullName: p.fullName,
          phone: p.phone,
          gender: p.gender,
          ageYears: p.ageYears,
          parentSpouseName: p.parentSpouseName,
          matchReason: 'Identical Hospital Reg No',
        ));
      } else if (p.phone == phone) {
        final isNameMatch = fullName != null && p.fullName.toLowerCase() == fullName.toLowerCase();
        candidates.add(DuplicateCandidateModel(
          id: p.id,
          uhid: p.uhid,
          hospitalRegNum: p.hospitalRegNum,
          fullName: p.fullName,
          phone: p.phone,
          gender: p.gender,
          ageYears: p.ageYears,
          parentSpouseName: p.parentSpouseName,
          matchReason: isNameMatch
              ? 'Identical Phone Number and Matching Full Name'
              : 'Identical Contact Phone Number',
        ));
      }
    }

    return DuplicateCheckResult(
      isDuplicate: candidates.isNotEmpty,
      candidates: candidates,
      message: candidates.isNotEmpty
          ? 'Found ${candidates.length} potential duplicate record(s).'
          : 'No existing duplicate records found.',
    );
  }

  Future<PatientModel> registerPatient(PatientModel patient, {bool allowDuplicate = false}) async {
    try {
      final res = await _dioClient.dio.post(
        ApiEndpoints.patients,
        queryParameters: {'allow_duplicate': allowDuplicate},
        data: patient.toJson(),
      );

      if (res.data['status'] == 'success') {
        return PatientModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response!.data['message'] ?? e.response!.data['detail'];
        if (msg != null) throw Exception(msg.toString());
      }
      rethrow;
    } catch (_) {}

    // Fallback local registration
    final generatedUhid = 'UHID-2026-${(_localPatients.length + 1).toString().padLeft(5, '0')}';
    final generatedReg = 'REG-2026-${(_localPatients.length + 1).toString().padLeft(5, '0')}';
    final newPat = PatientModel(
      id: 'demo-pat-${_localPatients.length + 1}',
      uhid: generatedUhid,
      hospitalRegNum: patient.hospitalRegNum ?? generatedReg,
      fullName: patient.fullName,
      parentSpouseName: patient.parentSpouseName,
      parentSpouseRelation: patient.parentSpouseRelation,
      dateOfBirth: patient.dateOfBirth,
      ageYears: patient.ageYears,
      ageMonths: patient.ageMonths,
      gender: patient.gender,
      phone: patient.phone,
      email: patient.email,
      address: patient.address,
      city: patient.city,
      state: patient.state,
      postalCode: patient.postalCode,
      bloodGroup: patient.bloodGroup,
      barcodeValue: 'BAR-$generatedUhid',
      qrCodeData: 'OPDCONNECT+$generatedUhid+$generatedReg',
      emergencyContactName: patient.emergencyContactName,
      emergencyContactPhone: patient.emergencyContactPhone,
      emergencyContactRelation: patient.emergencyContactRelation,
      createdAt: DateTime.now(),
    );
    _localPatients.insert(0, newPat);
    return newPat;
  }

  Future<PatientModel?> getPatientByReg(String regNum) async {
    try {
      final res = await _dioClient.dio.get(ApiEndpoints.patientByReg(regNum));
      if (res.data['status'] == 'success') {
        return PatientModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return _localPatients.cast<PatientModel?>().firstWhere(
      (p) => p?.hospitalRegNum == regNum,
      orElse: () => null,
    );
  }

  Future<PatientModel?> getPatientByBarcode(String barcode) async {
    try {
      final res = await _dioClient.dio.get(ApiEndpoints.patientByBarcode(barcode));
      if (res.data['status'] == 'success') {
        return PatientModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return _localPatients.cast<PatientModel?>().firstWhere(
      (p) => p?.barcodeValue == barcode,
      orElse: () => null,
    );
  }
}
