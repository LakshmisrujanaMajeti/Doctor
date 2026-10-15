import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/doctor_model.dart';

class DoctorRepository {
  final DioClient _dioClient;

  // Local doctor directory - shared static in-memory cache for instant 0ms access
  static final List<DoctorModel> _localDoctors = [];
  static bool _isLoaded = false;

  static List<DoctorModel> get cachedDoctors => List.unmodifiable(_localDoctors);

  static void initializeCache(List<DoctorModel> doctors) {
    _localDoctors.clear();
    _localDoctors.addAll(doctors);
    _isLoaded = true;
  }

  DoctorRepository(this._dioClient);

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
    _isLoaded = true;
  }

  /// Instant Stale-While-Revalidate: returns cached doctors in 0-1ms,
  /// then asynchronously updates from backend when online.
  Future<List<DoctorModel>> getDoctors({String? departmentId}) async {
    await _loadCacheIfNeeded();

    // 1. If we have cached doctors, return immediately (0ms) and background sync
    if (_localDoctors.isNotEmpty) {
      if (DioClient.isHostReachable) {
        _syncDoctorsFromServer(departmentId);
      }
      return _filterDoctors(_localDoctors, departmentId);
    }

    // 2. Cold first run with empty local cache: fetch from server
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
