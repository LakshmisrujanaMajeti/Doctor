import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/opd_text_field.dart';
import '../../../shared/widgets/triage_chip.dart';
import '../../visits/models/visit_model.dart';
import '../../visits/models/vitals_model.dart';
import '../../visits/providers/visit_provider.dart';
import '../../visits/repositories/visit_repository.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../dashboard/providers/doctor_dashboard_provider.dart';
import '../../patients/providers/patient_provider.dart';
import '../models/clinical_record_model.dart';
import '../providers/clinical_provider.dart';
import '../models/consultation_context_model.dart';
import '../providers/consultation_context_provider.dart';

class ConsultationSheetScreen extends ConsumerStatefulWidget {
  final String visitId;
  final OPDVisitModel? visit;

  const ConsultationSheetScreen({
    super.key,
    required this.visitId,
    this.visit,
  });

  @override
  ConsumerState<ConsultationSheetScreen> createState() => _ConsultationSheetScreenState();
}

class _ConsultationSheetScreenState extends ConsumerState<ConsultationSheetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // 1. Initial Assessment
  final _presentingComplaintController = TextEditingController();
  final _hpiController = TextEditingController();
  final _allergiesController = TextEditingController(text: 'No known drug allergies (NKDA)');
  final _pastHistoryController = TextEditingController();
  final _priorHospitalizationController = TextEditingController();
  final _hypertensionHistoryController = TextEditingController();
  final _diabetesHistoryController = TextEditingController();
  final _asthmaHistoryController = TextEditingController();
  final _tuberculosisHistoryController = TextEditingController();
  final _smokingHistoryController = TextEditingController(text: 'Non-smoker');
  final _alcoholHistoryController = TextEditingController(text: 'None');
  final _familyHistoryController = TextEditingController();

  // 2. Systemic Examination
  final _generalExamController = TextEditingController(text: 'Conscious, oriented, afebrile. No pallor, icterus, cyanosis, clubbing, lymphadenopathy, or edema.');
  final _respiratoryExamController = TextEditingController();
  final _cardiovascularExamController = TextEditingController();
  final _giExamController = TextEditingController();
  final _cnsExamController = TextEditingController();
  final _otherExamController = TextEditingController();

  // 3. Clinical Plan & Diagnoses
  final _provisionalDiagController = TextEditingController();
  final _finalDiagController = TextEditingController();
  final _icd10Controller = TextEditingController();
  final _carePlanController = TextEditingController();
  final _investigationsController = TextEditingController();
  final _dietaryAdviceController = TextEditingController();
  final _followUpController = TextEditingController();
  final _referralController = TextEditingController();

  // 4. Clinical Vitals Controllers (Mandatory if nurse didn't take them)
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _pulseController = TextEditingController();
  final _tempController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _respRateController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  bool _doctorEditingVitals = false;

  bool _isSaving = false;
  bool _isLoaded = false;
  bool _contextExpanded = true;
  ClinicalRecordModel? _currentRecord;
  List<ClinicalAmendmentModel> _amendments = [];

  bool get _hasNurseVitals {
    final v = widget.visit?.vitals;
    return v != null &&
        v.systolicBp != null &&
        v.diastolicBp != null &&
        v.pulseRate != null &&
        v.temperatureF != null &&
        v.spo2Percent != null;
  }

  bool get _hasCompleteVitals {
    if (_hasNurseVitals && !_doctorEditingVitals) return true;

    final sys = int.tryParse(_systolicController.text.trim());
    final dia = int.tryParse(_diastolicController.text.trim());
    final pulse = int.tryParse(_pulseController.text.trim());
    final temp = double.tryParse(_tempController.text.trim());
    final spo2 = int.tryParse(_spo2Controller.text.trim());

    return sys != null && sys > 0 &&
           dia != null && dia > 0 &&
           pulse != null && pulse > 0 &&
           temp != null && temp > 0 &&
           spo2 != null && spo2 > 0;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final v = widget.visit?.vitals;
    if (v != null) {
      if (v.systolicBp != null) _systolicController.text = v.systolicBp.toString();
      if (v.diastolicBp != null) _diastolicController.text = v.diastolicBp.toString();
      if (v.pulseRate != null) _pulseController.text = v.pulseRate.toString();
      if (v.temperatureF != null) _tempController.text = v.temperatureF.toString();
      if (v.spo2Percent != null) _spo2Controller.text = v.spo2Percent.toString();
      if (v.respiratoryRate != null) _respRateController.text = v.respiratoryRate.toString();
      if (v.weightKg != null) _weightController.text = v.weightKg.toString();
      if (v.heightCm != null) _heightController.text = v.heightCm.toString();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _presentingComplaintController.dispose();
    _hpiController.dispose();
    _allergiesController.dispose();
    _pastHistoryController.dispose();
    _priorHospitalizationController.dispose();
    _hypertensionHistoryController.dispose();
    _diabetesHistoryController.dispose();
    _asthmaHistoryController.dispose();
    _tuberculosisHistoryController.dispose();
    _smokingHistoryController.dispose();
    _alcoholHistoryController.dispose();
    _familyHistoryController.dispose();
    _generalExamController.dispose();
    _respiratoryExamController.dispose();
    _cardiovascularExamController.dispose();
    _giExamController.dispose();
    _cnsExamController.dispose();
    _otherExamController.dispose();
    _provisionalDiagController.dispose();
    _finalDiagController.dispose();
    _icd10Controller.dispose();
    _carePlanController.dispose();
    _investigationsController.dispose();
    _dietaryAdviceController.dispose();
    _followUpController.dispose();
    _referralController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _pulseController.dispose();
    _tempController.dispose();
    _spo2Controller.dispose();
    _respRateController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _populate(ClinicalRecordModel record) {
    if (_isLoaded) return;
    _currentRecord = record;
    _presentingComplaintController.text = record.presentingComplaint;
    if (record.historyOfPresentIllness != null) _hpiController.text = record.historyOfPresentIllness!;
    if (record.allergies != null) _allergiesController.text = record.allergies!;
    if (record.pastMedicalHistory != null) _pastHistoryController.text = record.pastMedicalHistory!;
    if (record.priorHospitalization != null) _priorHospitalizationController.text = record.priorHospitalization!;
    if (record.hypertensionHistory != null) _hypertensionHistoryController.text = record.hypertensionHistory!;
    if (record.diabetesHistory != null) _diabetesHistoryController.text = record.diabetesHistory!;
    if (record.asthmaHistory != null) _asthmaHistoryController.text = record.asthmaHistory!;
    if (record.tuberculosisHistory != null) _tuberculosisHistoryController.text = record.tuberculosisHistory!;
    if (record.smokingHistory != null) _smokingHistoryController.text = record.smokingHistory!;
    if (record.alcoholHistory != null) _alcoholHistoryController.text = record.alcoholHistory!;
    if (record.familyHistory != null) _familyHistoryController.text = record.familyHistory!;

    if (record.generalExamination != null) _generalExamController.text = record.generalExamination!;
    if (record.respiratoryExamination != null) _respiratoryExamController.text = record.respiratoryExamination!;
    if (record.cardiovascularExamination != null) _cardiovascularExamController.text = record.cardiovascularExamination!;
    if (record.gastrointestinalExamination != null) _giExamController.text = record.gastrointestinalExamination!;
    if (record.cnsExamination != null) _cnsExamController.text = record.cnsExamination!;
    if (record.otherExaminationFindings != null) _otherExamController.text = record.otherExaminationFindings!;

    if (record.provisionalDiagnosis != null) _provisionalDiagController.text = record.provisionalDiagnosis!;
    if (record.finalDiagnosis != null) _finalDiagController.text = record.finalDiagnosis!;
    if (record.icd10Code != null) _icd10Controller.text = record.icd10Code!;
    if (record.carePlan != null) _carePlanController.text = record.carePlan!;
    if (record.investigationsRequested != null) _investigationsController.text = record.investigationsRequested!;
    if (record.dietaryAdvice != null) _dietaryAdviceController.text = record.dietaryAdvice!;
    if (record.followUpDate != null) _followUpController.text = record.followUpDate!;
    if (record.referralDepartment != null) _referralController.text = record.referralDepartment!;

    _amendments = record.amendments;
    _isLoaded = true;
  }

  bool get _isFinalized => _currentRecord != null && (_currentRecord!.status == 'FINALIZED' || _currentRecord!.status == 'AMENDED');

  ClinicalRecordModel _buildModel({required String status}) {
    return ClinicalRecordModel(
      id: _currentRecord?.id ?? '',
      visitId: widget.visitId,
      patientId: widget.visit?.patientId ?? '',
      doctorId: widget.visit?.doctorId ?? '',
      presentingComplaint: _presentingComplaintController.text.trim().isNotEmpty
          ? _presentingComplaintController.text.trim()
          : 'Consultation Assessment',
      historyOfPresentIllness: _hpiController.text.trim().isNotEmpty ? _hpiController.text.trim() : null,
      allergies: _allergiesController.text.trim().isNotEmpty ? _allergiesController.text.trim() : null,
      pastMedicalHistory: _pastHistoryController.text.trim().isNotEmpty ? _pastHistoryController.text.trim() : null,
      priorHospitalization: _priorHospitalizationController.text.trim().isNotEmpty ? _priorHospitalizationController.text.trim() : null,
      hypertensionHistory: _hypertensionHistoryController.text.trim().isNotEmpty ? _hypertensionHistoryController.text.trim() : null,
      diabetesHistory: _diabetesHistoryController.text.trim().isNotEmpty ? _diabetesHistoryController.text.trim() : null,
      asthmaHistory: _asthmaHistoryController.text.trim().isNotEmpty ? _asthmaHistoryController.text.trim() : null,
      tuberculosisHistory: _tuberculosisHistoryController.text.trim().isNotEmpty ? _tuberculosisHistoryController.text.trim() : null,
      smokingHistory: _smokingHistoryController.text.trim().isNotEmpty ? _smokingHistoryController.text.trim() : null,
      alcoholHistory: _alcoholHistoryController.text.trim().isNotEmpty ? _alcoholHistoryController.text.trim() : null,
      familyHistory: _familyHistoryController.text.trim().isNotEmpty ? _familyHistoryController.text.trim() : null,
      generalExamination: _generalExamController.text.trim().isNotEmpty ? _generalExamController.text.trim() : null,
      respiratoryExamination: _respiratoryExamController.text.trim().isNotEmpty ? _respiratoryExamController.text.trim() : null,
      cardiovascularExamination: _cardiovascularExamController.text.trim().isNotEmpty ? _cardiovascularExamController.text.trim() : null,
      gastrointestinalExamination: _giExamController.text.trim().isNotEmpty ? _giExamController.text.trim() : null,
      cnsExamination: _cnsExamController.text.trim().isNotEmpty ? _cnsExamController.text.trim() : null,
      otherExaminationFindings: _otherExamController.text.trim().isNotEmpty ? _otherExamController.text.trim() : null,
      provisionalDiagnosis: _provisionalDiagController.text.trim().isNotEmpty ? _provisionalDiagController.text.trim() : null,
      finalDiagnosis: _finalDiagController.text.trim().isNotEmpty ? _finalDiagController.text.trim() : null,
      icd10Code: _icd10Controller.text.trim().isNotEmpty ? _icd10Controller.text.trim() : null,
      carePlan: _carePlanController.text.trim().isNotEmpty ? _carePlanController.text.trim() : null,
      investigationsRequested: _investigationsController.text.trim().isNotEmpty ? _investigationsController.text.trim() : null,
      dietaryAdvice: _dietaryAdviceController.text.trim().isNotEmpty ? _dietaryAdviceController.text.trim() : null,
      followUpDate: _followUpController.text.trim().isNotEmpty ? _followUpController.text.trim() : null,
      referralDepartment: _referralController.text.trim().isNotEmpty ? _referralController.text.trim() : null,
      status: status,
      version: _currentRecord?.version ?? 1,
    );
  }

  Future<void> _handleSaveDraft() async {
    setState(() => _isSaving = true);
    try {
      final record = _buildModel(status: 'DRAFT');
      final saved = await ref.read(clinicalRepositoryProvider).saveRecord(record);
      setState(() => _currentRecord = saved);
      ref.invalidate(clinicalRecordProvider(widget.visitId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primaryTeal,
            content: Text('Consultation sheet draft saved successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.triageEmergency, content: Text('Save error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleFinalizeAndSign() async {
    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete required assessment & diagnosis fields.')),
      );
      return;
    }

    if (!_hasCompleteVitals) {
      _tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.triageEmergency,
          duration: Duration(seconds: 4),
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Mandatory Vitals Missing: Please record BP, Pulse, Temperature, and SpO2 before finalizing.'),
              ),
            ],
          ),
        ),
      );
      return;
    }

    _showReviewBeforeSubmit();
  }

  void _showReviewBeforeSubmit() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Review OPD Consultation Sheet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              _buildReviewRow('Chief Complaint', _presentingComplaintController.text.trim()),
              _buildReviewRow('Allergies', _allergiesController.text.trim()),
              _buildReviewRow('Past Medical History', _pastHistoryController.text.trim()),
              _buildReviewRow('HTN & Diabetes', 'HTN: ${_hypertensionHistoryController.text.trim()} | DM: ${_diabetesHistoryController.text.trim()}'),
              _buildReviewRow('Provisional Diagnosis', _provisionalDiagController.text.trim()),
              _buildReviewRow('Final Diagnosis', '${_finalDiagController.text.trim()} (${_icd10Controller.text.trim()})'),
              _buildReviewRow('Care Plan', _carePlanController.text.trim()),
              _buildReviewRow('Investigations', _investigationsController.text.trim()),
              _buildReviewRow('Follow-up Date', _followUpController.text.trim()),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_clock, color: Colors.amber, size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Signing finalizes this clinical consultation sheet and marks the OPD visit as COMPLETED. Further changes require non-repudiation amendments.',
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Back to Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _executeFinalizeAndSign();
                      },
                      child: const Text('Sign & Finalize Record', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executeFinalizeAndSign() async {
    setState(() => _isSaving = true);
    try {
      // 1. If doctor entered or edited vitals, save them to the visit
      if (!_hasNurseVitals || _doctorEditingVitals) {
        final sys = int.tryParse(_systolicController.text.trim());
        final dia = int.tryParse(_diastolicController.text.trim());
        final pulse = int.tryParse(_pulseController.text.trim());
        final temp = double.tryParse(_tempController.text.trim());
        final spo2 = double.tryParse(_spo2Controller.text.trim());
        final rr = int.tryParse(_respRateController.text.trim());
        final wt = double.tryParse(_weightController.text.trim());
        final ht = double.tryParse(_heightController.text.trim());

        if (sys != null && dia != null && pulse != null && temp != null && spo2 != null) {
          final doctorVitals = VitalSignsModel(
            id: widget.visit?.vitals?.id ?? 'vit-${widget.visitId}',
            visitId: widget.visitId,
            systolicBp: sys,
            diastolicBp: dia,
            pulseRate: pulse,
            temperatureF: temp,
            spo2Percent: spo2,
            respiratoryRate: rr,
            weightKg: wt,
            heightCm: ht,
            recordedAt: DateTime.now(),
            notes: 'Recorded by Consulting Physician in OPD Chamber',
          );
          await ref.read(visitRepositoryProvider).recordVitals(doctorVitals);
        }
      }

      // 2. Save and finalize clinical consultation sheet
      final record = _buildModel(status: 'FINALIZED');
      final saved = await ref.read(clinicalRepositoryProvider).saveRecord(record);
      setState(() => _currentRecord = saved);

      // 3. Mark OPD visit as COMPLETED across all portals (Doctor, Patient, Admin)
      await ref.read(visitRepositoryProvider).updateVisitStatus(widget.visitId, 'COMPLETED');

      // 4. Invalidate all dashboard, queue, and patient providers for instant real-time sync
      ref.invalidate(clinicalRecordProvider(widget.visitId));
      ref.invalidate(visitListProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(doctorDashboardProvider);
      ref.invalidate(patientListProvider);
      ref.invalidate(doctorAssignedPatientsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primaryTeal,
            content: Text('OPD Clinical Sheet signed & finalized! Visit updated to COMPLETED across all portals.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.triageEmergency, content: Text('Finalization error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAmendmentDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppColors.primaryTeal),
            SizedBox(width: 8),
            Text('Amend Clinical Sheet'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A non-repudiation audit snapshot of version ${_currentRecord?.version ?? 1} will be archived. Please state the clinical rationale for this amendment:',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Clinical Amendment Reason *',
                hintText: 'e.g. Lab results arrived, updated final diagnosis and dosage',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Amendment reason is required')),
                );
                return;
              }
              Navigator.pop(ctx);
              await _executeAmendment(reason);
            },
            child: const Text('Confirm Amendment', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeAmendment(String reason) async {
    if (_currentRecord == null) return;
    setState(() => _isSaving = true);
    try {
      final updatedFields = {
        'presenting_complaint': _presentingComplaintController.text.trim(),
        'history_of_present_illness': _hpiController.text.trim(),
        'allergies': _allergiesController.text.trim(),
        'past_medical_history': _pastHistoryController.text.trim(),
        'prior_hospitalization': _priorHospitalizationController.text.trim(),
        'hypertension_history': _hypertensionHistoryController.text.trim(),
        'diabetes_history': _diabetesHistoryController.text.trim(),
        'asthma_history': _asthmaHistoryController.text.trim(),
        'tuberculosis_history': _tuberculosisHistoryController.text.trim(),
        'smoking_history': _smokingHistoryController.text.trim(),
        'alcohol_history': _alcoholHistoryController.text.trim(),
        'family_history': _familyHistoryController.text.trim(),
        'general_examination': _generalExamController.text.trim(),
        'respiratory_examination': _respiratoryExamController.text.trim(),
        'cardiovascular_examination': _cardiovascularExamController.text.trim(),
        'gastrointestinal_examination': _giExamController.text.trim(),
        'cns_examination': _cnsExamController.text.trim(),
        'other_examination_findings': _otherExamController.text.trim(),
        'provisional_diagnosis': _provisionalDiagController.text.trim(),
        'final_diagnosis': _finalDiagController.text.trim(),
        'icd10_code': _icd10Controller.text.trim(),
        'care_plan': _carePlanController.text.trim(),
        'investigations_requested': _investigationsController.text.trim(),
        'dietary_advice': _dietaryAdviceController.text.trim(),
        'follow_up_date': _followUpController.text.trim(),
        'referral_department': _referralController.text.trim(),
      };

      final amended = await ref.read(clinicalRepositoryProvider).amendRecord(
        _currentRecord!.id,
        reason: reason,
        updateFields: updatedFields,
        fallbackCurrent: _currentRecord,
      );

      setState(() {
        _currentRecord = amended;
        _amendments = amended.amendments;
      });
      ref.invalidate(clinicalRecordProvider(widget.visitId));
      ref.invalidate(visitListProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(doctorDashboardProvider);
      ref.invalidate(patientListProvider);
      ref.invalidate(doctorAssignedPatientsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primaryTeal,
            content: Text('Record amended to version ${amended.version} with audit trail archived!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.triageEmergency, content: Text('Amendment error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          const SizedBox(width: 8),
          Expanded(child: Text(value.isNotEmpty ? value : '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordAsync = ref.watch(clinicalRecordProvider(widget.visitId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go('/queue');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('OPD Consultation Sheet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              'Visit: ${widget.visit?.visitNumber ?? widget.visitId.substring(0, 8)} • Token #${widget.visit?.queueToken ?? 1}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (_currentRecord != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Chip(
                backgroundColor: _currentRecord!.status == 'FINALIZED'
                    ? AppColors.triageNormal.withOpacity(0.2)
                    : (_currentRecord!.status == 'AMENDED' ? Colors.purple.withOpacity(0.2) : Colors.amber.withOpacity(0.2)),
                label: Text(
                  '${_currentRecord!.status} v${_currentRecord!.version}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _currentRecord!.status == 'FINALIZED'
                        ? AppColors.triageNormal
                        : (_currentRecord!.status == 'AMENDED' ? Colors.purple : Colors.amber.shade900),
                  ),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black87,
          indicatorColor: AppColors.primaryTeal,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87),
          tabs: const [
            Tab(icon: Icon(Icons.history_edu, color: Colors.black87), text: 'Assessment & Vitals'),
            Tab(icon: Icon(Icons.accessibility_new, color: Colors.black87), text: 'Systemic Exam'),
            Tab(icon: Icon(Icons.assignment, color: Colors.black87), text: 'Diagnoses & Plan'),
            Tab(icon: Icon(Icons.history, color: Colors.black87), text: 'Audit History'),
          ],
        ),
      ),
      body: recordAsync.when(
        data: (record) {
          if (record != null) _populate(record);
          return Column(
            children: [
              if (_isFinalized)
                Container(
                  color: Colors.blue.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 18, color: AppColors.secondaryNavy),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Record is ${_currentRecord?.status} (v${_currentRecord?.version}). Tap "Amend Record" to record audited revisions.',
                          style: const TextStyle(fontSize: 12, color: AppColors.secondaryNavy, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Amend'),
                        onPressed: _showAmendmentDialog,
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAssessmentTab(),
                      _buildSystemicExamTab(),
                      _buildDiagnosesAndPlanTab(),
                      _buildAuditTab(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading consultation record: $err')),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving || _isFinalized ? null : _handleSaveDraft,
                  icon: const Icon(Icons.save_as_outlined, size: 18),
                  label: const Text('Save Draft'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                  onPressed: _isSaving
                      ? null
                      : (_isFinalized ? _showAmendmentDialog : _handleFinalizeAndSign),
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(_isFinalized ? Icons.edit_note : Icons.check_circle_outline, size: 18, color: Colors.white),
                  label: Text(
                    _isFinalized ? 'Amend Record' : 'Sign & Finalize',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentTab() {
    final vitals = widget.visit?.vitals;
    final contextAsync = ref.watch(consultationContextProvider(widget.visitId));

    return SingleChildScrollView(
      key: const PageStorageKey('assessment_tab'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 0. Patient Demographics & Previous History Context Banner
          _buildPatientHistoryAndContextCard(contextAsync.value),
          const SizedBox(height: 16),

          // Vitals Observation Panel & Mandatory Entry Section
          _buildVitalsObservationAndEntrySection(vitals),
          const SizedBox(height: 16),

          OPDTextField(
            controller: _presentingComplaintController,
            label: 'Presenting Complaint & Duration *',
            hint: 'e.g. Fever with chills for 3 days and dry cough',
            maxLines: 2,
            prefixIcon: const Icon(Icons.sick_outlined),
            validator: (v) => v == null || v.trim().isEmpty ? 'Chief complaint is required' : null,
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _hpiController,
            label: 'History of Present Illness (HPI)',
            hint: 'Onset, progression, aggravating and relieving factors...',
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _allergiesController,
            label: 'Allergies (Drug / Food / Environment)',
            hint: 'e.g. NKDA or Penicillin causes rash',
            prefixIcon: const Icon(Icons.warning_amber_rounded),
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _pastHistoryController,
            label: 'Past Medical & Surgical History',
            hint: 'Prior illnesses, past surgeries, blood transfusions...',
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _priorHospitalizationController,
            label: 'Prior Hospitalization History',
            hint: 'Dates, reasons, hospital name...',
          ),
          const SizedBox(height: 16),
          const Text('Specific Chronic Disease Histories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OPDTextField(
                  controller: _hypertensionHistoryController,
                  label: 'Hypertension History',
                  hint: 'Status, duration, therapy',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OPDTextField(
                  controller: _diabetesHistoryController,
                  label: 'Diabetes History',
                  hint: 'Type, duration, HbA1c',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OPDTextField(
                  controller: _asthmaHistoryController,
                  label: 'Asthma / Reactive Airway',
                  hint: 'Inhaler use, attacks',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OPDTextField(
                  controller: _tuberculosisHistoryController,
                  label: 'Tuberculosis History',
                  hint: 'Contact or past ATT',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Personal & Family History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OPDTextField(
                  controller: _smokingHistoryController,
                  label: 'Smoking History',
                  hint: 'Non-smoker / packs/day',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OPDTextField(
                  controller: _alcoholHistoryController,
                  label: 'Alcohol History',
                  hint: 'None / units/week',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _familyHistoryController,
            label: 'Family History',
            hint: 'CAD, Diabetes, Hypertension, Asthma in parents/siblings',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsObservationAndEntrySection(VitalSignsModel? vitals) {
    if (_hasNurseVitals && !_doctorEditingVitals) {
      final v = vitals!;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryTeal.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_rounded, color: AppColors.primaryTeal, size: 18),
                    SizedBox(width: 6),
                    Text('Clinical Observations & Vitals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade300),
                  ),
                  child: const Text('✓ Triage Recorded by Nurse', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (v.bmi != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('BMI: ${v.bmi} kg/m² (${v.bmiCategory})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryTeal)),
                  )
                else
                  const SizedBox.shrink(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 16, color: AppColors.primaryBlue),
                  label: const Text('Re-measure / Edit', style: TextStyle(fontSize: 11, color: AppColors.primaryBlue)),
                  onPressed: () => setState(() => _doctorEditingVitals = true),
                ),
              ],
            ),
            const Divider(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _buildVitalMetric('BP', v.bloodPressureDisplay),
                _buildVitalMetric('Pulse', v.pulseRate != null ? '${v.pulseRate} bpm' : '--'),
                _buildVitalMetric('Temp', v.temperatureF != null ? '${v.temperatureF} °F' : '--'),
                _buildVitalMetric('SpO2', v.spo2Percent != null ? '${v.spo2Percent}%' : '--'),
                _buildVitalMetric('Resp Rate', v.respiratoryRate != null ? '${v.respiratoryRate} /min' : '--'),
                _buildVitalMetric('Wt/Ht', '${v.weightKg ?? "--"} kg / ${v.heightCm ?? "--"} cm'),
                _buildVitalMetric('Blood Glucose', v.bloodGlucoseMgDl != null ? '${v.bloodGlucoseMgDl} mg/dL' : '--'),
              ],
            ),
          ],
        ),
      );
    }

    // Nurse did not record vitals or Doctor is re-measuring -> Doctor MUST take basic vitals
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade600, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                !_hasNurseVitals ? Icons.warning_amber_rounded : Icons.medical_information_rounded,
                color: Colors.amber.shade900,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !_hasNurseVitals
                          ? 'MANDATORY CLINICAL VITALS (Nurse Triage Pending)'
                          : 'DOCTOR CLINICAL VITALS ENTRY (Consultation Room)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: Colors.amber.shade900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !_hasNurseVitals
                          ? 'Hospital protocol requires vital signs before clinical finalization. Because nursing triage was not completed for this visit, the consulting physician must record basic vitals.'
                          : 'Update the patient vital signs observed in the doctor chamber.',
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              if (_doctorEditingVitals && _hasNurseVitals)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Cancel Edit',
                  onPressed: () => setState(() => _doctorEditingVitals = false),
                ),
            ],
          ),
          const Divider(height: 18),

          // Basic Mandatory Vitals: BP, Pulse, Temperature, SpO2
          Row(
            children: [
              Expanded(
                child: OPDTextField(
                  controller: _systolicController,
                  label: 'Systolic BP (mmHg) *',
                  hint: 'e.g. 120',
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OPDTextField(
                  controller: _diastolicController,
                  label: 'Diastolic BP (mmHg) *',
                  hint: 'e.g. 80',
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OPDTextField(
                  controller: _pulseController,
                  label: 'Pulse (bpm) *',
                  hint: 'e.g. 74',
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OPDTextField(
                  controller: _tempController,
                  label: 'Temperature (°F) *',
                  hint: 'e.g. 98.6',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OPDTextField(
                  controller: _spo2Controller,
                  label: 'SpO2 (%) *',
                  hint: 'e.g. 98',
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OPDTextField(
                  controller: _respRateController,
                  label: 'Resp Rate (/min)',
                  hint: 'e.g. 18',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OPDTextField(
                  controller: _weightController,
                  label: 'Weight (kg)',
                  hint: 'e.g. 68.0',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OPDTextField(
                  controller: _heightController,
                  label: 'Height (cm)',
                  hint: 'e.g. 172',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSystemicExamTab() {
    return SingleChildScrollView(
      key: const PageStorageKey('systemic_tab'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OPDTextField(
            controller: _generalExamController,
            label: 'General Examination (P/I/C/C/L/E)',
            hint: 'Pallor, Icterus, Cyanosis, Clubbing, Lymphadenopathy, Edema...',
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _respiratoryExamController,
            label: 'Respiratory System Examination (RS)',
            hint: 'Bilateral breath sounds, wheezing, rhonchi, crepitations...',
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _cardiovascularExamController,
            label: 'Cardiovascular System Examination (CVS)',
            hint: 'S1 S2 heard, murmurs, gallop, rhythm...',
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _giExamController,
            label: 'Gastrointestinal Examination (P/A)',
            hint: 'Abdomen soft, tender/non-tender, hepatosplenomegaly, bowel sounds...',
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _cnsExamController,
            label: 'Central Nervous System Examination (CNS)',
            hint: 'Consciousness, orientation, cranial nerves, motor/sensory...',
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _otherExamController,
            label: 'Other Examination Findings / Local Exam',
            hint: 'ENT, throat injection, skin lesions, musculo-skeletal...',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosesAndPlanTab() {
    return SingleChildScrollView(
      key: const PageStorageKey('plan_tab'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OPDTextField(
            controller: _provisionalDiagController,
            label: 'Provisional Diagnosis *',
            hint: 'e.g. Acute Bronchitis / Viral Pharyngitis',
            prefixIcon: const Icon(Icons.psychology_alt_outlined),
            validator: (v) => v == null || v.trim().isEmpty ? 'Provisional diagnosis required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OPDTextField(
                  controller: _finalDiagController,
                  label: 'Final Diagnosis',
                  hint: 'Confirmed medical diagnosis',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OPDTextField(
                  controller: _icd10Controller,
                  label: 'ICD-10 Code',
                  hint: 'e.g. J02.9',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _carePlanController,
            label: 'Care & Management Plan',
            hint: 'Medication advice, home care, precautions...',
            maxLines: 3,
            prefixIcon: const Icon(Icons.healing_outlined),
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _investigationsController,
            label: 'Investigations Requested (Lab & Radiology)',
            hint: 'e.g. CBC, ESR, Chest X-Ray PA view, Urine Routine',
            maxLines: 2,
            prefixIcon: const Icon(Icons.biotech_outlined),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryTeal,
                side: const BorderSide(color: AppColors.primaryTeal),
              ),
              icon: const Icon(Icons.science_outlined, size: 16),
              label: const Text('Order Formal Lab Investigation'),
              onPressed: _showOrderLabDialog,
            ),
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _dietaryAdviceController,
            label: 'Dietary & Lifestyle Advice',
            hint: 'Low salt, bland diet, adequate hydration...',
            prefixIcon: const Icon(Icons.restaurant_outlined),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OPDTextField(
                  controller: _followUpController,
                  label: 'Follow-Up Date',
                  hint: 'YYYY-MM-DD',
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OPDTextField(
                  controller: _referralController,
                  label: 'Referral Department',
                  hint: 'e.g. Cardiology OPD',
                  prefixIcon: const Icon(Icons.forward_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryNavy,
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.medication, color: Colors.white),
            label: const Text('Prescribe Medicines (Safety Checked)', style: TextStyle(color: Colors.white)),
            onPressed: () {
              context.push('/visits/${widget.visitId}/prescriptions', extra: widget.visit);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTab() {
    return SingleChildScrollView(
      key: const PageStorageKey('audit_tab'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBackgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Data Integrity & Authorship', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Text('Record Status: ${_currentRecord?.status ?? "DRAFT"}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('Current Version: v${_currentRecord?.version ?? 1}', style: const TextStyle(fontSize: 12)),
                if (_currentRecord?.signedAt != null)
                  Text('Signed Timestamp: ${_currentRecord?.signedAt?.toLocal()}', style: const TextStyle(fontSize: 12, color: AppColors.primaryTeal)),
                if (_currentRecord?.amendmentReason != null)
                  Text('Latest Amendment: ${_currentRecord?.amendmentReason}', style: const TextStyle(fontSize: 12, color: Colors.purple)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Clinical Amendment History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (_amendments.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: const Text('No amendments recorded. This is the original version.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _amendments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final a = _amendments[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Amendment #${_amendments.length - i}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 13)),
                          Text(a.amendedAt.toLocal().toString().substring(0, 16), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Reason: ${a.reason}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Archived Snapshot JSON', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              content: SingleChildScrollView(
                                child: Text(a.previousSnapshotJson, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                              ],
                            ),
                          );
                        },
                        child: const Text('View Prior Snapshot', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showOrderLabDialog() {
    final tests = [
      {'name': 'Brain MRI Scan with Contrast', 'category': 'RADIOLOGY'},
      {'name': 'MRI Lumbar Spine / Knee Joint', 'category': 'RADIOLOGY'},
      {'name': 'CT Scan Brain / Chest HRCT', 'category': 'RADIOLOGY'},
      {'name': 'Ultrasound Whole Abdomen (USG)', 'category': 'RADIOLOGY'},
      {'name': 'Chest X-Ray PA View', 'category': 'RADIOLOGY'},
      {'name': '12-Lead Electrocardiogram (ECG)', 'category': 'CARDIOLOGY'},
      {'name': 'Complete Blood Count (CBC)', 'category': 'HEMATOLOGY'},
      {'name': 'Fasting Blood Sugar & HbA1c', 'category': 'BIOCHEMISTRY'},
      {'name': 'Liver Function Test (LFT)', 'category': 'BIOCHEMISTRY'},
      {'name': 'Renal Function Test (KFT / Creatinine)', 'category': 'BIOCHEMISTRY'},
      {'name': 'Lipid Profile', 'category': 'BIOCHEMISTRY'},
      {'name': 'Serum Electrolytes (Na+, K+, Cl-)', 'category': 'BIOCHEMISTRY'},
      {'name': 'Urine Routine & Microscopy', 'category': 'CLINICAL_PATHOLOGY'},
      {'name': 'Thyroid Stimulating Hormone (TSH)', 'category': 'ENDOCRINOLOGY'},
      {'name': 'C-Reactive Protein (CRP)', 'category': 'IMMUNOLOGY'},
    ];

    String selectedTest = tests[0]['name']!;
    String selectedCategory = tests[0]['category']!;
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.science_outlined, color: AppColors.primaryTeal),
              SizedBox(width: 8),
              Text('Order Laboratory Investigation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Investigation Test:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedTest,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: tests.map((t) => DropdownMenuItem(value: t['name'], child: Text(t['name']!, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedTest = val;
                        selectedCategory = tests.firstWhere((t) => t['name'] == val)['category']!;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                Text('Category: $selectedCategory', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Clinical Indication / Notes',
                    hintText: 'e.g. Rule out bacterial infection, follow up glycemic control',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      try {
                        final dioClient = ref.read(dioClientProvider);
                        await dioClient.dio.post(
                          ApiEndpoints.labOrders,
                          data: {
                            'visit_id': widget.visitId,
                            'test_name': selectedTest,
                            'test_category': selectedCategory,
                            'clinical_indication': notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                          },
                        );

                        if (mounted) {
                          if (_investigationsController.text.trim().isEmpty) {
                            _investigationsController.text = selectedTest;
                          } else if (!_investigationsController.text.contains(selectedTest)) {
                            _investigationsController.text = '${_investigationsController.text}, $selectedTest';
                          }
                          Navigator.pop(dialogCtx);
                          ref.invalidate(consultationContextProvider(widget.visitId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.primaryTeal,
                              content: Text("Laboratory test '$selectedTest' ordered successfully!"),
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('⚠️ [LAB ORDER] Error ordering lab test: $e');
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          String userMessage = 'Unable to reach laboratory services. Please verify network connection and retry.';
                          if (e is DioException) {
                            if (e.response?.data is Map && e.response?.data['message'] != null) {
                              userMessage = e.response!.data['message'].toString();
                            } else if (e.type == DioExceptionType.connectionTimeout ||
                                e.type == DioExceptionType.receiveTimeout) {
                              userMessage = 'Laboratory service request timed out. Please retry.';
                            } else if (e.response?.statusCode == 403) {
                              userMessage = 'Unauthorized: Doctor or Administrator authorization required for formal lab orders.';
                            }
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.triageEmergency,
                              behavior: SnackBarBehavior.floating,
                              content: Text(userMessage),
                              action: SnackBarAction(
                                label: 'Retry',
                                textColor: Colors.white,
                                onPressed: () {},
                              ),
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm Order', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientHistoryAndContextCard(ConsultationContextModel? contextData) {
    final patient = contextData?.patient ?? {};
    final history = contextData?.medicalHistory;
    final prevVisits = contextData?.previousVisits ?? [];
    final investigations = contextData?.availableInvestigations ?? [];
    final patientName = patient['full_name'] ?? widget.visit?.patient?.fullName ?? 'Authorized Patient';
    final hospitalNo = patient['hospital_number'] ?? widget.visit?.patient?.hospitalRegNum ?? widget.visit?.patient?.uhid ?? 'OPD-N/A';
    final age = patient['age'] ?? widget.visit?.patient?.ageYears ?? '--';
    final sex = patient['sex'] ?? widget.visit?.patient?.gender ?? '--';
    final phone = patient['phone'] ?? widget.visit?.patient?.phone ?? '--';
    final allergiesText = history?.allergies ?? patient['allergies']?.toString() ?? 'NKDA';
    final hasActiveAllergies = allergiesText.isNotEmpty &&
        !allergiesText.toLowerCase().contains('nkda') &&
        !allergiesText.toLowerCase().contains('no known');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasActiveAllergies ? AppColors.triagePriority.withOpacity(0.5) : AppColors.borderLight,
          width: hasActiveAllergies ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _contextExpanded = !_contextExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryTeal.withOpacity(0.12),
                    radius: 18,
                    child: const Icon(Icons.folder_shared_outlined, color: AppColors.primaryTeal, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              patientName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryNavy.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                hospitalNo,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondaryNavy),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Age: $age yrs • Sex: $sex • Phone: $phone',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _contextExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_contextExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Allergy Alert Banner
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: hasActiveAllergies ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasActiveAllergies ? Colors.red.shade300 : Colors.green.shade300,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          hasActiveAllergies ? Icons.warning_rounded : Icons.check_circle_outline,
                          color: hasActiveAllergies ? Colors.red.shade700 : Colors.green.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasActiveAllergies ? 'KNOWN PATIENT ALLERGIES' : 'NO KNOWN DRUG ALLERGIES (NKDA)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: hasActiveAllergies ? Colors.red.shade900 : Colors.green.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                allergiesText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: hasActiveAllergies ? Colors.red.shade900 : Colors.green.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasActiveAllergies && _allergiesController.text.contains('NKDA'))
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              setState(() {
                                _allergiesController.text = allergiesText;
                              });
                            },
                            child: const Text('Sync', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),

                  // Medical History Summary
                  if (history != null) ...[
                    const SizedBox(height: 10),
                    const Text('Past Medical & Chronic History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (history.hypertensionHistory != null)
                          _buildHistoryChip('HTN: ${history.hypertensionHistory}'),
                        if (history.diabetesHistory != null)
                          _buildHistoryChip('DM: ${history.diabetesHistory}'),
                        if (history.asthmaHistory != null)
                          _buildHistoryChip('Asthma: ${history.asthmaHistory}'),
                        if (history.tuberculosisHistory != null)
                          _buildHistoryChip('TB: ${history.tuberculosisHistory}'),
                        if (history.priorHospitalization != null)
                          _buildHistoryChip('Prior Hosp: ${history.priorHospitalization}'),
                      ],
                    ),
                  ],

                  // Previous Visits
                  if (prevVisits.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Previous Visits (${prevVisits.length}):',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    ...prevVisits.take(3).map((pv) => Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackgroundLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.history, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${pv.visitNumber} • ${pv.visitDate.toString().substring(0, 10)} • ${pv.finalDiagnosis ?? pv.provisionalDiagnosis ?? pv.chiefComplaint ?? "OPD Consultation"}',
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (pv.doctorName != null)
                                Text(
                                  pv.doctorName!,
                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                        )),
                  ],

                  // Available Lab Investigations
                  if (investigations.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Available Lab Investigations (${investigations.length}):',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    ...investigations.take(3).map((inv) => Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackgroundLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.biotech, size: 14, color: AppColors.primaryTeal),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${inv['test_name'] ?? 'Lab Order'} • Status: ${inv['status'] ?? 'PENDING'}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.secondaryNavy.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.secondaryNavy)),
    );
  }
}
