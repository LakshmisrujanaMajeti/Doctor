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
      id: 'doc-genmed',
      userId: 'user-doc-genmed',
      name: 'Dr. Sarah Chen, MD',
      specialization: 'General Medicine',
      departmentId: 'General Medicine',
      departmentName: 'General Medicine',
      qualification: 'MBBS, MD (General Medicine)',
      roomNumber: 'Room 101',
      consultationFee: 500.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'doc-cardio',
      userId: 'user-doc-cardio',
      name: 'Dr. R. Venkatesh, DM',
      specialization: 'Cardiology',
      departmentId: 'Cardiology',
      departmentName: 'Cardiology',
      qualification: 'MBBS, MD, DM (Cardiology)',
      roomNumber: 'Room 102',
      consultationFee: 750.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'doc-derma',
      userId: 'user-doc-derma',
      name: 'Dr. Ananya Rao, MD',
      specialization: 'Dermatology',
      departmentId: 'Dermatology',
      departmentName: 'Dermatology',
      qualification: 'MBBS, MD (DVL)',
      roomNumber: 'Room 103',
      consultationFee: 600.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'doc-endo',
      userId: 'user-doc-endo',
      name: 'Dr. S. Kulkarni, DM',
      specialization: 'Endocrinology',
      departmentId: 'Endocrinology',
      departmentName: 'Endocrinology',
      qualification: 'MBBS, MD, DM (Endocrinology)',
      roomNumber: 'Room 104',
      consultationFee: 700.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'doc-gastro',
      userId: 'user-doc-gastro',
      name: 'Dr. Pradeep Menon, DM',
      specialization: 'Gastroenterology',
      departmentId: 'Gastroenterology',
      departmentName: 'Gastroenterology',
      qualification: 'MBBS, MD, DM (Gastroenterology)',
      roomNumber: 'Room 105',
      consultationFee: 750.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'doc-neuro',
      userId: 'user-doc-neuro',
      name: 'Dr. Vikram Seth, DM',
      specialization: 'Neurology',
      departmentId: 'Neurology',
      departmentName: 'Neurology',
      qualification: 'MBBS, MD, DM (Neurology)',
      roomNumber: 'Room 106',
      consultationFee: 800.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'doc-onco',
      userId: 'user-doc-onco',
      name: 'Dr. Malini Iyer, MD DM',
      specialization: 'Oncology',
      departmentId: 'Oncology',
      departmentName: 'Oncology',
      qualification: 'MBBS, MD, DM (Medical Oncology)',
      roomNumber: 'Room 107',
      consultationFee: 900.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'doc-pulmo',
      userId: 'user-doc-pulmo',
      name: 'Dr. Harish Patel, MD',
      specialization: 'Pulmonology',
      departmentId: 'Pulmonology',
      departmentName: 'Pulmonology',
      qualification: 'MBBS, MD (Pulmonary Medicine)',
      roomNumber: 'Room 108',
      consultationFee: 650.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'doc-nephro',
      userId: 'user-doc-nephro',
      name: 'Dr. Gautam Das, DM',
      specialization: 'Nephrology',
      departmentId: 'Nephrology',
      departmentName: 'Nephrology',
      qualification: 'MBBS, MD, DM (Nephrology)',
      roomNumber: 'Room 109',
      consultationFee: 750.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'doc-gynec',
      userId: 'user-doc-gynec',
      name: 'Dr. Radhika Nair, MS DGO',
      specialization: 'Gynecology',
      departmentId: 'Gynecology',
      departmentName: 'Gynecology',
      qualification: 'MBBS, MS, DGO (Obstetrics & Gynecology)',
      roomNumber: 'Room 110',
      consultationFee: 600.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'doc-pediatric',
      userId: 'user-doc-pediatric',
      name: 'Dr. Ananya Roy, MD',
      specialization: 'Pediatrics',
      departmentId: 'Pediatrics',
      departmentName: 'Pediatrics',
      qualification: 'MBBS, MD (Pediatrics)',
      roomNumber: 'Room 103',
      consultationFee: 600.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'doc-ortho',
      userId: 'user-doc-ortho',
      name: 'Dr. Vikram Mehta, MS',
      specialization: 'Orthopedics',
      departmentId: 'Orthopedics',
      departmentName: 'Orthopedics',
      qualification: 'MBBS, MS (Orthopedics)',
      roomNumber: 'Room 104',
      consultationFee: 700.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'doc-dental',
      userId: 'user-doc-dental',
      name: 'Dr. M. Arunraj, MDS',
      specialization: 'Dental / Maxillofacial Surgery',
      departmentId: 'Dental / Maxillofacial Surgery',
      departmentName: 'Dental / Maxillofacial Surgery',
      qualification: 'BDS, MDS (Oral & Maxillofacial)',
      roomNumber: 'Room 113',
      consultationFee: 500.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'doc-ent',
      userId: 'user-doc-ent',
      name: 'Dr. Kavita Nair, MS ENT',
      specialization: 'ENT',
      departmentId: 'ENT',
      departmentName: 'ENT',
      qualification: 'MBBS, MS (ENT)',
      roomNumber: 'Room 114',
      consultationFee: 550.0,
      isAvailable: true,
    ),
    DoctorModel(
      id: 'doc-pulmo-uday',
      userId: 'user-doc-pulmo-uday',
      name: 'Dr. Uday Kumar, MD',
      specialization: 'Pulmonology',
      departmentId: 'Pulmonology',
      departmentName: 'Pulmonology',
      qualification: 'MBBS, MD (Pulmonary Medicine)',
      roomNumber: 'Room 108',
      consultationFee: 650.0,
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
