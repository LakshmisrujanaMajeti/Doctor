import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/network/supabase_service.dart';
import '../models/doctor_model.dart';

class DoctorRepository {
  final DioClient _dioClient;

  // Local doctor directory - shared static in-memory cache for instant 0ms access
  static final List<DoctorModel> _localDoctors = [];
  static bool _isLoaded = false;

  static List<DoctorModel> get cachedDoctors =>
      _localDoctors.isNotEmpty ? List.unmodifiable(_localDoctors) : List.unmodifiable(_default10Doctors);
  static List<DoctorModel> get defaultDoctors => List.unmodifiable(_default10Doctors);


  static void initializeCache(List<DoctorModel> doctors) {
    _localDoctors.clear();
    _localDoctors.addAll(doctors);
    _isLoaded = true;
  }

  static void addDoctorToCache(DoctorModel doc) {
    final idx = _localDoctors.indexWhere((d) => d.id == doc.id || d.userId == doc.userId || d.name == doc.name);
    if (idx != -1) {
      _localDoctors[idx] = doc;
    } else {
      _localDoctors.insert(0, doc);
    }
  }

  DoctorRepository(this._dioClient);

  static final List<DoctorModel> _default10Doctors = [
    DoctorModel(
      id: '9c50c481-d49e-456d-93bb-0306c0f6282a',
      userId: 'ce94a083-9ec3-448d-96ca-45698398792f',
      name: 'Dr. Sarah Chen, MD',
      specialization: 'General Medicine',
      departmentId: 'ab24e180-0d08-4deb-ac80-890fb7e267de',
      departmentName: 'General Medicine',
      qualification: 'MBBS, MD (General Medicine)',
      roomNumber: 'Room 101',
      consultationFee: 500.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: '9f06ce12-c0d7-49a2-bcc5-cb0065e16c95',
      userId: '06b462d7-0ce4-4345-b5a5-736de20a22b0',
      name: 'Dr. R. Venkatesh, DM',
      specialization: 'Cardiology',
      departmentId: 'e6fa4073-bf17-449e-9487-0b62cbf15e8a',
      departmentName: 'Cardiology',
      qualification: 'MBBS, MD, DM (Cardiology)',
      roomNumber: 'Room 102',
      consultationFee: 750.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'bf94c4c4-7a20-49b6-90ab-8cf9339683c4',
      userId: 'c63963c2-8816-4eac-93f0-9854ab186532',
      name: 'Dr. Ananya Rao, MD',
      specialization: 'Dermatology',
      departmentId: 'f994be42-c702-4326-af25-a27719e6181b',
      departmentName: 'Dermatology',
      qualification: 'MBBS, MD (DVL)',
      roomNumber: 'Room 103',
      consultationFee: 600.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: '5f1a7e65-89f6-421b-a7d1-4f0a9b229d66',
      userId: '535bb7b5-c8ee-4a21-8851-27f1594d4095',
      name: 'Dr. S. Kulkarni, DM',
      specialization: 'Endocrinology',
      departmentId: '4008f0fb-01a5-4b72-9b23-8b4c627f4876',
      departmentName: 'Endocrinology',
      qualification: 'MBBS, MD, DM (Endocrinology)',
      roomNumber: 'Room 104',
      consultationFee: 700.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'e1ea6498-427c-476c-8d34-67ad71069fa3',
      userId: '23250378-5641-418f-a713-6bbe5aea7a21',
      name: 'Dr. Pradeep Menon, DM',
      specialization: 'Gastroenterology',
      departmentId: 'f86975b6-7196-412d-ac49-9a710325467b',
      departmentName: 'Gastroenterology',
      qualification: 'MBBS, MD, DM (Gastroenterology)',
      roomNumber: 'Room 105',
      consultationFee: 750.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'f5632023-25ec-41bd-a585-4b6e34e398ad',
      userId: 'a29529ae-f09c-4294-afe2-c6c8569aa3aa',
      name: 'Dr. Vikram Seth, DM',
      specialization: 'Neurology',
      departmentId: '3b6e5663-0cbf-435a-be5a-42d9bb5a27bf',
      departmentName: 'Neurology',
      qualification: 'MBBS, MD, DM (Neurology)',
      roomNumber: 'Room 106',
      consultationFee: 800.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'fc5b3240-077e-4e28-8f55-59a8543154a8',
      userId: 'e451ad24-7ac3-412c-b33a-9f354daa13e2',
      name: 'Dr. Malini Iyer, MD DM',
      specialization: 'Oncology',
      departmentId: 'b3b49dde-5c50-4eb2-b5f9-71d266e24932',
      departmentName: 'Oncology',
      qualification: 'MBBS, MD, DM (Medical Oncology)',
      roomNumber: 'Room 107',
      consultationFee: 900.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: '7e3587d5-40d3-49c0-9658-23d9e2d97420',
      userId: '02597d2f-edb1-4b4b-9c10-8b7a0aac6f9a',
      name: 'Dr. Harish Patel, MD',
      specialization: 'Pulmonology',
      departmentId: '4bd0604f-ddb8-455c-81ce-451ee5f30d11',
      departmentName: 'Pulmonology',
      qualification: 'MBBS, MD (Pulmonary Medicine)',
      roomNumber: 'Room 108',
      consultationFee: 650.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'e1ba4b4e-b301-4917-bd5c-dd5fd00ad352',
      userId: '4b2616cb-a867-46a4-91a1-dd84d0c4a711',
      name: 'Dr. Gautam Das, DM',
      specialization: 'Nephrology',
      departmentId: '99b8c1b4-a601-4f80-be62-5e73239ff555',
      departmentName: 'Nephrology',
      qualification: 'MBBS, MD, DM (Nephrology)',
      roomNumber: 'Room 109',
      consultationFee: 750.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'd4fff7a6-f502-4d41-9b09-1b89fee4bbff',
      userId: '903cbbe3-7051-4d7b-85ed-797adb6bd0f6',
      name: 'Dr. Radhika Nair, MS DGO',
      specialization: 'Gynecology',
      departmentId: '189df683-986f-48db-aa57-d20d8f3c1029',
      departmentName: 'Gynecology',
      qualification: 'MBBS, MS, DGO (Obstetrics & Gynecology)',
      roomNumber: 'Room 110',
      consultationFee: 600.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: '45f40b6d-2624-48e6-b352-41ca0f451752',
      userId: '635f00db-4b5e-4c6e-b9af-09e0b6d029a4',
      name: 'Dr. Ananya Roy, MD',
      specialization: 'Pediatrics',
      departmentId: '33ae54cc-089e-4996-971f-df4ad0d870b4',
      departmentName: 'Pediatrics',
      qualification: 'MBBS, MD (Pediatrics)',
      roomNumber: 'Room 103',
      consultationFee: 600.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'b2d06a39-797c-49af-b42a-7d1053bb9d6b',
      userId: '30b01a51-386c-4f55-9b38-e443c0c06e87',
      name: 'Dr. Vikram Mehta, MS',
      specialization: 'Orthopedics',
      departmentId: '3177e8d6-899e-46e9-acef-e22c706f68cf',
      departmentName: 'Orthopedics',
      qualification: 'MBBS, MS (Orthopedics)',
      roomNumber: 'Room 104',
      consultationFee: 700.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'd4483c06-55c7-4c14-a5b8-99788641b295',
      userId: '1cfb440b-e01e-47d5-9155-72bac963e1f2',
      name: 'Dr. M. Arunraj, MDS',
      specialization: 'Dental / Maxillofacial Surgery',
      departmentId: 'af512f73-41c8-4911-8217-5dc998997034',
      departmentName: 'Dental / Maxillofacial Surgery',
      qualification: 'BDS, MDS (Oral & Maxillofacial)',
      roomNumber: 'Room 113',
      consultationFee: 500.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: '94ec0fd8-80e2-4e81-b962-db77c8253d9d',
      userId: '8bf63271-510c-4a74-bb5a-87889edb08aa',
      name: 'Dr. Kavita Nair, MS ENT',
      specialization: 'ENT',
      departmentId: 'c8f0acea-6ebb-4843-8fa4-0f039bb4f921',
      departmentName: 'ENT',
      qualification: 'MBBS, MS (ENT)',
      roomNumber: 'Room 114',
      consultationFee: 550.0,
      isAvailable: true,
    ),
  ];


  Future<void> _loadCacheIfNeeded() async {
    if (_localDoctors.isNotEmpty) return;
    try {
      final raw = await SecureStorageService.getStaffDirectoryJson();
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          final role = (map['role_name'] as String? ?? map['role'] as String? ?? '').toLowerCase();
          if (role == 'doctor') {
            final docId = map['id'] as String? ?? 'doc-${map['email']}';
            if (!_localDoctors.any((d) => d.id == docId || d.userId == docId)) {
              _localDoctors.add(DoctorModel(
                id: docId,
                userId: docId,
                name: map['full_name'] as String? ?? map['name'] as String? ?? 'Dr. Specialist',
                specialization: map['specialization'] as String? ?? 'General Medicine',
                departmentId: map['department_id'] as String? ?? 'General Medicine',
                departmentName: map['department_name'] as String? ?? 'General Medicine',
                qualification: map['qualification'] as String? ?? 'MBBS, Specialist',
                roomNumber: map['room_number'] as String? ?? 'Room ${101 + _localDoctors.length}',
                consultationFee: 500.0,
                isAvailable: true,
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading doctor staff cache: $e');
    }

    // If still empty, seed with the 10 core hospital clinical doctor specialists
    if (_localDoctors.isEmpty) {
      _localDoctors.addAll(_default10Doctors);
    }
    _isLoaded = true;
  }

  /// Instant Stale-While-Revalidate: returns cached doctors in 0-1ms,
  /// then asynchronously updates from Supabase Cloud & backend when online.
  Future<List<DoctorModel>> getDoctors({String? departmentId}) async {
    await _loadCacheIfNeeded();

    // 1. If we have cached doctors, return immediately (0ms) and background sync
    if (_localDoctors.isNotEmpty) {
      _syncDoctorsFromSupabase(departmentId);
      if (DioClient.isHostReachable) {
        _syncDoctorsFromServer(departmentId);
      }
      return _filterDoctors(_localDoctors, departmentId);
    }

    // 2. Direct Supabase Cloud Fetch (Fastest & direct connection on physical devices)
    try {
      final supaDoctors = await SupabaseService.fetchDoctors();
      if (supaDoctors.isNotEmpty) {
        final fetched = supaDoctors.map((m) => DoctorModel.fromJson(m)).toList();
        for (final f in fetched) {
          final idx = _localDoctors.indexWhere((d) => d.id == f.id || d.userId == f.userId);
          if (idx != -1) {
            _localDoctors[idx] = f;
          } else {
            _localDoctors.add(f);
          }
        }
        return _filterDoctors(_localDoctors, departmentId);
      }
    } catch (e) {
      debugPrint('Supabase direct doctor fetch note: $e');
    }

    // 3. Cold first run with empty local cache: fetch from server
    try {
      final res = await _dioClient.dio.get(
        ApiEndpoints.doctors,
        queryParameters: departmentId != null && departmentId.isNotEmpty
            ? {'department_id': departmentId}
            : null,
      );

      if (res.data['status'] == 'success') {
        final list = res.data['data'] as List<dynamic>;
        final fetched = list.map((m) => DoctorModel.fromJson(m as Map<String, dynamic>)).toList();
        for (final f in fetched) {
          final idx = _localDoctors.indexWhere((d) => d.id == f.id || d.userId == f.userId);
          if (idx != -1) {
            _localDoctors[idx] = f;
          } else {
            _localDoctors.add(f);
          }
        }
        return _filterDoctors(_localDoctors, departmentId);
      }
    } catch (_) {}

    return _filterDoctors(_localDoctors, departmentId);
  }

  void _syncDoctorsFromSupabase(String? departmentId) {
    Future.microtask(() async {
      try {
        final supaDoctors = await SupabaseService.fetchDoctors();
        if (supaDoctors.isNotEmpty) {
          final fetched = supaDoctors.map((m) => DoctorModel.fromJson(m)).toList();
          for (final f in fetched) {
            final idx = _localDoctors.indexWhere((d) => d.id == f.id || d.userId == f.userId);
            if (idx != -1) {
              _localDoctors[idx] = f;
            } else {
              _localDoctors.add(f);
            }
          }
        }
      } catch (_) {}
    });
  }

  void _syncDoctorsFromServer(String? departmentId) {
    Future.microtask(() async {
      try {
        final res = await _dioClient.dio.get(
          ApiEndpoints.doctors,
          queryParameters: departmentId != null && departmentId.isNotEmpty
              ? {'department_id': departmentId}
              : null,
        );

        if (res.data['status'] == 'success') {
          final list = res.data['data'] as List<dynamic>;
          final fetched = list.map((m) => DoctorModel.fromJson(m as Map<String, dynamic>)).toList();
          for (final f in fetched) {
            final idx = _localDoctors.indexWhere((d) => d.id == f.id || d.userId == f.userId);
            if (idx != -1) {
              _localDoctors[idx] = f;
            } else {
              _localDoctors.add(f);
            }
          }
        }
      } catch (_) {}
    });
  }

  List<DoctorModel> _filterDoctors(List<DoctorModel> source, String? departmentId) {
    if (departmentId != null && departmentId.isNotEmpty) {
      return source.where((d) =>
          d.departmentId == departmentId ||
          d.departmentName.toLowerCase() == departmentId.toLowerCase()).toList();
    }
    return List.unmodifiable(source);
  }

  Future<void> addDoctor(DoctorModel doctor) async {
    final idx = _localDoctors.indexWhere((d) => d.id == doctor.id || d.userId == doctor.userId);
    if (idx != -1) {
      _localDoctors[idx] = doctor;
    } else {
      _localDoctors.add(doctor);
    }
  }
}

final doctorRepositoryProvider = Provider<DoctorRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return DoctorRepository(dioClient);
});

final doctorListProvider = FutureProvider<List<DoctorModel>>((ref) async {
  final repo = ref.watch(doctorRepositoryProvider);
  return repo.getDoctors();
});
