import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/patients/models/patient_model.dart';
import '../../features/visits/models/visit_model.dart';
import '../../features/admin_portal/models/admin_portal_models.dart';
import '../config/app_config.dart';

class SupabaseService {
  static bool get isReady {
    try {
      return Supabase.instance.client.auth.currentSession != null ||
          AppConfig.supabaseUrl.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // PATIENTS
  // ==========================================

  static Future<List<PatientModel>> fetchPatients() async {
    final cli = client;
    if (cli == null) return [];
    try {
      final res = await cli
          .from('patients')
          .select()
          .order('created_at', ascending: false);

      final list = res as List<dynamic>;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return PatientModel.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('Supabase fetchPatients note: $e');
      return [];
    }
  }

  // ==========================================
  // DOCTORS
  // ==========================================

  static Future<List<Map<String, dynamic>>> fetchDoctors() async {
    final cli = client;
    if (cli == null) return [];
    try {
      final res = await cli
          .from('doctors')
          .select('*, user:users(*), department:departments(*)');

      final list = res as List<dynamic>;
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (e) {
      debugPrint('Supabase fetchDoctors note: $e');
      return [];
    }
  }

  static Future<bool> upsertPatient(PatientModel patient) async {
    final cli = client;
    if (cli == null) return false;
    try {
      final nowIso = DateTime.now().toIso8601String();
      final data = Map<String, dynamic>.from(patient.toJson());
      data['registration_date'] = (patient.registrationDate ?? patient.createdAt ?? DateTime.now()).toIso8601String();
      data['created_at'] = (patient.createdAt ?? DateTime.now()).toIso8601String();
      data['updated_at'] = nowIso;
      if (data['id'] == null || data['id'].toString().isEmpty) {
        data['id'] = 'pat_${DateTime.now().millisecondsSinceEpoch}';
      }

      await cli.from('patients').upsert(data);
      return true;
    } catch (e) {
      debugPrint('Supabase upsertPatient error: $e');
      return false;
    }
  }

  // ==========================================
  // OPD VISITS
  // ==========================================

  static Future<List<OPDVisitModel>> fetchVisits() async {
    final cli = client;
    if (cli == null) return [];
    try {
      final res = await cli
          .from('opd_visits')
          .select()
          .order('created_at', ascending: false);

      final list = res as List<dynamic>;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return OPDVisitModel.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('Supabase fetchVisits note: $e');
      return [];
    }
  }

  static Future<bool> upsertVisit(OPDVisitModel visit) async {
    final cli = client;
    if (cli == null) return false;
    try {
      final nowIso = DateTime.now().toIso8601String();
      final data = <String, dynamic>{
        'id': visit.id.isNotEmpty ? visit.id : 'vis_${DateTime.now().millisecondsSinceEpoch}',
        'visit_number': visit.visitNumber,
        'patient_id': visit.patientId,
        'doctor_id': visit.doctorId.isNotEmpty ? visit.doctorId : '5ebeb27e-df19-4b9a-9971-849c4fdf593f',
        'department_id': visit.departmentId.isNotEmpty ? visit.departmentId : '14348862-6761-4bce-9e9e-f45ed47ec6c6',
        'visit_date': visit.visitDate.toIso8601String(),
        'queue_token': visit.queueToken,
        'triage_priority': visit.triagePriority,
        'status': visit.status,
        'consultation_fee': visit.consultationFee,
        'payment_status': visit.paymentStatus,
        'notes': visit.notes,
        'created_at': nowIso,
        'updated_at': nowIso,
      };

      await cli.from('opd_visits').upsert(data);
      return true;
    } catch (e) {
      debugPrint('Supabase upsertVisit error: $e');
      return false;
    }
  }

  // ==========================================
  // USERS
  // ==========================================

  static Future<List<AdminUserModel>> fetchUsers() async {
    final cli = client;
    if (cli == null) return [];
    try {
      final res = await cli
          .from('users')
          .select()
          .order('created_at', ascending: false);

      final list = res as List<dynamic>;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return AdminUserModel.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('Supabase fetchUsers note: $e');
      return [];
    }
  }

  static Future<bool> upsertUser(Map<String, dynamic> userMap) async {
    final cli = client;
    if (cli == null) return false;
    try {
      final nowIso = DateTime.now().toIso8601String();
      final data = Map<String, dynamic>.from(userMap);
      data['created_at'] = data['created_at'] ?? nowIso;
      data['updated_at'] = nowIso;
      data['is_active'] = data['is_active'] ?? true;
      data['is_verified'] = data['is_verified'] ?? true;
      data['failed_login_attempts'] = data['failed_login_attempts'] ?? 0;
      data['hashed_password'] = data['hashed_password'] ?? 'pbkdf2_sha256\$default';

      await cli.from('users').upsert(data);
      return true;
    } catch (e) {
      debugPrint('Supabase upsertUser error: $e');
      return false;
    }
  }

  // ==========================================
  // CLINICAL RECORDS (Medical Entry Forms)
  // ==========================================

  static Future<Map<String, dynamic>?> fetchClinicalRecord(String visitId) async {
    final cli = client;
    if (cli == null) return null;
    try {
      final res = await cli
          .from('clinical_records')
          .select()
          .eq('visit_id', visitId)
          .maybeSingle();

      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      debugPrint('Supabase fetchClinicalRecord note: $e');
    }
    return null;
  }

  static Future<bool> upsertClinicalRecord(Map<String, dynamic> recordMap) async {
    final cli = client;
    if (cli == null) return false;
    try {
      final nowIso = DateTime.now().toIso8601String();
      final data = Map<String, dynamic>.from(recordMap);
      data['created_at'] = data['created_at'] ?? nowIso;
      data['updated_at'] = nowIso;
      data['status'] = data['status'] ?? 'COMPLETED';
      data['version'] = data['version'] ?? 1;

      await cli.from('clinical_records').upsert(data);
      return true;
    } catch (e) {
      debugPrint('Supabase upsertClinicalRecord error: $e');
      return false;
    }
  }

  // ==========================================
  // VITAL SIGNS
  // ==========================================

  static Future<Map<String, dynamic>?> fetchVitalSigns(String visitId) async {
    final cli = client;
    if (cli == null) return null;
    try {
      final res = await cli
          .from('vital_signs')
          .select()
          .eq('visit_id', visitId)
          .maybeSingle();

      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      debugPrint('Supabase fetchVitalSigns note: $e');
    }
    return null;
  }

  static Future<bool> upsertVitalSigns(Map<String, dynamic> vitalsMap) async {
    final cli = client;
    if (cli == null) return false;
    try {
      final nowIso = DateTime.now().toIso8601String();
      final data = Map<String, dynamic>.from(vitalsMap);
      data['recorded_at'] = data['recorded_at'] ?? nowIso;
      data['created_at'] = data['created_at'] ?? nowIso;
      data['updated_at'] = nowIso;

      await cli.from('vital_signs').upsert(data);
      return true;
    } catch (e) {
      debugPrint('Supabase upsertVitalSigns error: $e');
      return false;
    }
  }

  // ==========================================
  // PRESCRIPTIONS
  // ==========================================

  static Future<Map<String, dynamic>?> fetchPrescription(String visitId) async {
    final cli = client;
    if (cli == null) return null;
    try {
      final res = await cli
          .from('prescriptions')
          .select('*, prescription_items(*)')
          .eq('visit_id', visitId)
          .maybeSingle();

      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      debugPrint('Supabase fetchPrescription note: $e');
    }
    return null;
  }

  // ==========================================
  // LAB ORDERS
  // ==========================================

  static Future<List<Map<String, dynamic>>> fetchLabOrders(String visitId) async {
    final cli = client;
    if (cli == null) return [];
    try {
      final res = await cli
          .from('lab_orders')
          .select('*, lab_results(*)')
          .eq('visit_id', visitId);

      final list = res as List<dynamic>;
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (e) {
      debugPrint('Supabase fetchLabOrders note: $e');
      return [];
    }
  }
}
