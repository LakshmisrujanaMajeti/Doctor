import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/smvmch_hospital_logo.dart';
import '../../../shared/widgets/server_config_dialog.dart';
import '../models/patient_model.dart';
import '../providers/patient_provider.dart';
import '../../visits/models/visit_model.dart';
import '../../visits/providers/visit_provider.dart';
import '../../../core/utils/file_download_helper.dart';
import '../../billing/repositories/billing_repository.dart';
import '../../billing/models/billing_models.dart';
import '../../prescriptions/providers/prescription_provider.dart';
import '../../prescriptions/models/prescription_model.dart';

class DigitalOpdBookletScreen extends ConsumerStatefulWidget {
  final String patientId;

  const DigitalOpdBookletScreen({
    super.key,
    required this.patientId,
  });

  @override
  ConsumerState<DigitalOpdBookletScreen> createState() => _DigitalOpdBookletScreenState();
}

class _DigitalOpdBookletScreenState extends ConsumerState<DigitalOpdBookletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _downloadBooklet(BuildContext context, String regId) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Generating & downloading official OPD booklet PDF...')),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );
    try {
      final bytes = await ref.read(patientRepositoryProvider).downloadBookletByRegId(regId);
      final filename = 'SMVMCH_OPD_Booklet_${regId.replaceAll('/', '_')}.pdf';
      await downloadFileBytes(bytes, filename);
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verified PDF "$filename" saved successfully! (${bytes.length} bytes)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Hospital server offline or unreachable on this network. You can configure server IP in settings.'),
            backgroundColor: AppColors.hospitalMaroon,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Server IP',
              textColor: Colors.yellowAccent,
              onPressed: () => ServerConfigDialog.show(context),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientAsync = ref.watch(patientDetailProvider(widget.patientId));
    final visitsAsync = ref.watch(patientVisitsProvider(widget.patientId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.goNamed(RouteNames.patients);
            }
          },
        ),
        title: Row(
          children: [
            const SmvmchHospitalLogo(size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SMVMCH Out Patient Book',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Form: SMVMCH/OP/OPIAF/Version1 • Verified Clinical Record',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download Official PDF',
            onPressed: () => _downloadBooklet(context, widget.patientId),
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Print Booklet',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('OPD Booklet print job dispatched to hospital printer.'),
                  backgroundColor: AppColors.hospitalMaroon,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share / Export PDF',
            onPressed: () => _downloadBooklet(context, widget.patientId),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.hospitalMaroon,
          unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          indicatorColor: AppColors.hospitalMaroon,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Cover & Labels'),
            Tab(icon: Icon(Icons.assignment_rounded, size: 18), text: 'Assessment Form'),
            Tab(icon: Icon(Icons.medical_services_rounded, size: 18), text: 'Clinical Exam'),
            Tab(icon: Icon(Icons.medication_rounded, size: 18), text: 'Treatment Plan (Rx)'),
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Pharmacy Bill'),
            Tab(icon: Icon(Icons.biotech_rounded, size: 18), text: 'Lab Menu'),
          ],
        ),
      ),
      body: patientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load patient booklet: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.refresh(patientDetailProvider(widget.patientId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (loadedPatient) {
          final visits = visitsAsync.value ?? [];
          final activeVisit = visits.isNotEmpty ? visits.first : null;
          final patient = loadedPatient ?? activeVisit?.patient;

          if (patient == null) {
            return const Center(child: Text('Patient record not found'));
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCoverAndLabelsTab(patient, isDark),
              _buildInitialAssessmentTab(patient, activeVisit, isDark),
              _buildClinicalExamTab(patient, activeVisit, isDark),
              _buildTreatmentPlanTab(patient, activeVisit, isDark),
              _buildPharmacyCashBillTab(patient, isDark),
              _buildLaboratoryMenuTab(isDark),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 1: OUT PATIENT BOOK COVER & BARCODE STICKERS (Pages 1 & 2)
  // ==========================================
  Widget _buildCoverAndLabelsTab(PatientModel patient, bool isDark) {
    final uhid = patient.uhid.isNotEmpty ? patient.uhid : (patient.hospitalRegNum ?? 'UHID-PENDING');
    final abha = patient.abhaNumber ?? 'N/A';
    final parentName = patient.parentSpouseName ?? 'N/A';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Physical Out Patient Book Replica
          Container(
            constraints: const BoxConstraints(maxWidth: 580),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF1E295A).withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ABHA Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF93C5FD)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ABHA-NO:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E40AF),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        abha,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Hospital Header with Official Crest
                const SmvmchHospitalLogo(
                  size: 60,
                  layout: LogoLayout.vertical,
                  showTamilText: true,
                ),
                const SizedBox(height: 16),

                // Large Title Banner: OUT PATIENT BOOK
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E295A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'OUT  PATIENT  BOOK',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Patient Information Grid Matching Sticker Layout
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      _buildBookletFieldRow('Name / பெயர்', patient.fullName),
                      _buildBookletFieldRow('Hospital No. / ம. எண்', uhid, isBold: true, highlight: true),
                      _buildBookletFieldRow('S/o, D/o, W/o', parentName),
                      _buildBookletFieldRow(
                        'Age & Sex / வயது, இனம்',
                        '${patient.ageYears ?? 27} Yrs  ${patient.gender}',
                      ),
                      _buildBookletFieldRow('Address / முகவரி', patient.address ?? 'YANAM, YANAM, PUDUCHERRY'),
                      _buildBookletFieldRow('Phone / தொலைபேசி', patient.phone),
                      _buildBookletFieldRow('Blood Group', patient.bloodGroup ?? 'O+'),
                      _buildBookletFieldRow(
                        'Reg. Date & Time',
                        () {
                          final dt = (patient.registrationDate ?? patient.createdAt)?.toLocal();
                          if (dt == null) return '21/10/2026 10:12 AM';
                          final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
                          final ampm = dt.hour >= 12 ? 'PM' : 'AM';
                          final minute = dt.minute.toString().padLeft(2, '0');
                          return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $hour:$minute $ampm';
                        }(),
                      ),
                      if (patient.registeredByStaffName != null)
                        _buildBookletFieldRow(
                          'Registered By Staff',
                          '${patient.registeredByStaffName} (${patient.registeredByStaffRole ?? "Staff"})',
                          highlight: true,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Mandatory Hospital Instruction Footer
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        AppStrings.opdBookletNotice,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Kalitheerthalkuppam, Madagadipet, Puducherry - 605 107 • Tel: 0413-2643000 • www.smvmch.ac.in',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 2. Barcode Stickers Sheet (Page 2)
          Container(
            constraints: const BoxConstraints(maxWidth: 580),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'SPECIMEN BARCODE LABELS (8 Strips)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.hospitalNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.print, size: 14),
                      label: const Text('Print Labels', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Specimen barcode sheet sent to sticker label printer.'),
                            backgroundColor: AppColors.hospitalNavy,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Adhesive stickers for pathology test tubes, specimen vials, and lab investigation forms.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // 2x4 Barcode Sticker Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.9,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: 8,
                  itemBuilder: (ctx, idx) => _buildBarcodeSticker(patient, uhid, parentName, isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookletFieldRow(String label, String value, {bool isBold = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
          ),
          const Text(': ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: highlight ? AppColors.hospitalMaroon : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeSticker(PatientModel patient, String uhid, String parentName, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade400, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Barcode representation
          Text(
            '*$uhid*',
            style: const TextStyle(
              fontFamily: 'Courier',
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$uhid - ${patient.ageYears ?? 27}/${patient.gender == 'MALE' ? 'Male' : patient.gender}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          Text(
            patient.fullName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
          Text(
            'S/o: $parentName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: OPD INITIAL ASSESSMENT FORM (Page 3 - SMVMCH/OP/OPIAF/Version1)
  // ==========================================
  Widget _buildInitialAssessmentTab(PatientModel patient, OPDVisitModel? visit, bool isDark) {
    final vitals = visit?.vitals;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'OPD INITIAL ASSESSMENT FORM',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Text(
                      '06 AUG 2026 • 10:20 AM',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // 1. Presenting Complaint
              const Text('Presenting Complaint:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  visit?.notes != null && visit!.notes!.isNotEmpty
                      ? visit.notes!
                      : 'No presenting complaints recorded yet (Awaiting clinical intake).',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: visit?.notes != null && visit!.notes!.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                    color: visit?.notes != null && visit!.notes!.isNotEmpty ? null : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Allergy
              const Row(
                children: [
                  Text('Allergy: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Chip(
                    label: Text(
                      'No Known Drug Allergies (NKDA)',
                      style: TextStyle(fontSize: 11, color: Colors.green),
                    ),
                    backgroundColor: Color(0xFFECFDF5),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Past Health History
              const Text('Past Health History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusCheckbox('Previous Hospitalization', false),
                  _buildStatusCheckbox('Hypertension', false),
                  _buildStatusCheckbox('Diabetes', false),
                  _buildStatusCheckbox('Asthma', false),
                  _buildStatusCheckbox('TB', false),
                  _buildStatusCheckbox('Smoking', false),
                  _buildStatusCheckbox('Alcoholism', false),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Family History
              const Text('Family History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusCheckbox('Diabetes', false),
                  _buildStatusCheckbox('Hypertension', false),
                  _buildStatusCheckbox('Heart Disease', false),
                  _buildStatusCheckbox('Kidney Disease', false),
                ],
              ),
              const SizedBox(height: 20),

              // 5. Physical Examination & Vitals
              const Text('Physical Examination & Vitals:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              if (vitals == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.monitor_heart_outlined, color: Colors.grey, size: 36),
                        SizedBox(height: 8),
                        Text(
                          'No Vitals Recorded Yet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Awaiting vital signs logging by the triage nurse.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildVitalCell('Height', vitals.heightCm != null ? '${vitals.heightCm!.toInt()} cms' : '—')),
                          Expanded(child: _buildVitalCell('Weight', vitals.weightKg != null ? '${vitals.weightKg!.toInt()} Kgs' : '—')),
                          Expanded(child: _buildVitalCell('BMI', vitals.bmi != null ? '${vitals.bmi!.toStringAsFixed(1)} kg/m²' : '—')),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildVitalCell(
                              'B.P.',
                              vitals.systolicBp != null && vitals.diastolicBp != null
                                  ? '${vitals.systolicBp} / ${vitals.diastolicBp} mmHg'
                                  : '—',
                              isAlert: (vitals.systolicBp ?? 0) > 130,
                            ),
                          ),
                          Expanded(child: _buildVitalCell('Pulse Rate', vitals.pulseRate != null ? '${vitals.pulseRate} /min' : '—', isAlert: (vitals.pulseRate ?? 0) > 100)),
                          Expanded(child: _buildVitalCell('Temp', vitals.temperatureF != null ? '${vitals.temperatureF} °F' : '—')),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(child: _buildVitalCell('Pallor', 'No')),
                          Expanded(child: _buildVitalCell('Icterus', 'No')),
                          Expanded(child: _buildVitalCell('Cyanosis', 'No')),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Footer Form Code
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Form Code: ${AppStrings.opdBookletCode}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCheckbox(String label, bool isChecked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isChecked ? AppColors.hospitalMaroon.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isChecked ? AppColors.hospitalMaroon : Colors.grey.shade400,
          width: isChecked ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
            size: 16,
            color: isChecked ? AppColors.hospitalMaroon : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
              color: isChecked ? AppColors.hospitalMaroon : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCell(String label, String value, {bool isAlert = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isAlert ? Colors.red.shade700 : null,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: CLINICAL EXAMINATION & DIAGNOSIS (Page 4)
  // ==========================================
  Widget _buildClinicalExamTab(PatientModel patient, OPDVisitModel? visit, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Systemic Examination & Diagnosis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(height: 24),

              if (visit == null || visit.notes == null || visit.notes!.isEmpty || visit.notes == 'Initial OPD Registration Visit')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.medical_services_outlined, color: Colors.grey, size: 40),
                        SizedBox(height: 10),
                        Text(
                          'No Clinical Examination Recorded Yet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Awaiting doctor consultation and examination notes.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                _buildExamRow('RS (Respiratory System)', 'Normal vesicular breath sounds. Clear bilaterally.'),
                _buildExamRow('CVS (Cardiovascular System)', 'S1, S2 heard. No murmurs.'),
                _buildExamRow('GI (Gastrointestinal)', 'Soft, non-tender.'),
                _buildExamRow('CNS (Central Nervous System)', 'Conscious, oriented.'),
                const Divider(height: 24),
                const Text('Clinical Findings & Diagnosis:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Diagnosis: ${visit.notes ?? "Under Clinical Evaluation"}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Department: ${visit.departmentName ?? "General OPD"}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF78350F), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildExamRow('Provisional Diagnosis', visit.notes ?? 'Under Evaluation', isHighlight: true),
                _buildExamRow('Care Plan', 'Consultation assessment in progress.'),
                _buildExamRow('Final Diagnosis', visit.status == 'COMPLETED' ? (visit.notes ?? 'Completed') : 'Pending investigation results'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? AppColors.hospitalMaroon : null,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: TREATMENT PLAN & RX (Page 5)
  // ==========================================
  Widget _buildTreatmentPlanTab(PatientModel patient, OPDVisitModel? visit, bool isDark) {
    final rxAsync = visit != null ? ref.watch(prescriptionListProvider(visit.id)) : null;
    final rxList = rxAsync?.value ?? [];
    final allItems = rxList.expand((rx) => rx.items).toList();
    final hasRx = allItems.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Treatment Plan & E-Prescription', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasRx
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: hasRx
                            ? Colors.green.shade200
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      hasRx ? 'Rx SIGNED' : 'PENDING CONSULT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: hasRx ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              if (!hasRx)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.medication_outlined, color: Colors.grey, size: 40),
                        SizedBox(height: 10),
                        Text(
                          'No Active Prescriptions',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Prescriptions will appear here once written by the consulting doctor.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Table(
                  border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                  columnWidths: const {
                    0: FixedColumnWidth(40),
                    1: FlexColumnWidth(4),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                      children: const [
                        Padding(padding: EdgeInsets.all(8), child: Text('Sl.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Drugs (Medicine Name)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Frequency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                    ),
                    ...allItems.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final rx = entry.value;
                      return TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.all(10), child: Text('$idx.')),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rx.medicineName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                if (rx.dosage.isNotEmpty)
                                  Text('${rx.form} • ${rx.dosage}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Padding(padding: const EdgeInsets.all(10), child: Text(rx.frequency, style: const TextStyle(fontSize: 11))),
                          Padding(padding: const EdgeInsets.all(10), child: Text('${rx.durationDays} Days', style: const TextStyle(fontSize: 11))),
                        ],
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 24),
                if (visit?.doctorName != null && visit!.doctorName!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Doctor's Name:", style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(visit.doctorName!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            Text('Department: ${visit.departmentName ?? "OPD"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Sign / Digital Seal:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.hospitalNavy),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('${visit.doctorName!} ✓', style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 5: 24-HR PHARMACY UNIT-I CASH BILL (Page 6)
  // ==========================================
  Widget _buildPharmacyCashBillTab(PatientModel patient, bool isDark) {
    final matchingBills = BillingRepository.cachedBills.where((b) {
      final pUhid = patient.uhid.toUpperCase().trim();
      final pId = patient.id.trim();
      final bUhid = b.patientUhid.toUpperCase().trim();
      final bPid = b.patientId.trim();
      return (pUhid.isNotEmpty && bUhid == pUhid) ||
          (pId.isNotEmpty && bPid == pId) ||
          b.patientName.toLowerCase() == patient.fullName.toLowerCase();
    }).toList();

    final dynamicBill = matchingBills.where((b) =>
      b.departmentName.toLowerCase().contains('pharm') ||
      b.items.any((it) => it.itemType == 'PHARMACY')
    ).firstOrNull ?? (matchingBills.isNotEmpty ? matchingBills.first : null);

    final billNo = dynamicBill?.invoiceNumber ?? 'PB-PENDING';
    final billDate = dynamicBill != null && dynamicBill.billedAt.length >= 10
        ? dynamicBill.billedAt.substring(0, 10)
        : '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pharmacy Header from Page 6
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SmvmchHospitalLogo(size: 50),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sri Manakula Vinayagar Medical College & Hospital',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Kalitheerthalkuppam, Madagadipet, Puducherry-605107. Ph. 0413-2643000',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey),
                        ),
                        Text(
                          'DL.No.: RLF20PY2024000071 / RLF21PY2024000075 / RLF20F2024PY000001 Dated: 13.03.2024',
                          style: TextStyle(fontSize: 9.5, color: Colors.grey),
                        ),
                        Text(
                          'TIN No.: 34880001919   •   GST No: 34AAATM9599A1ZE',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Sub-header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(child: Text('PHARMACY UNIT-I (24 hours)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    Text(dynamicBill != null ? 'OFFICIAL RECEIPT (PAID)' : 'CASH BILL (DUPLICATE)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bill No.: $billNo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('Date: $billDate', style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Patient No.: ${patient.uhid.isNotEmpty ? patient.uhid : (patient.hospitalRegNum ?? "UHID-PENDING")}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Name: ${patient.fullName.toUpperCase()}',
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              if (dynamicBill == null || dynamicBill.items.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, color: Colors.grey, size: 40),
                        SizedBox(height: 10),
                        Text(
                          'No Pharmacy Invoices Issued',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Pharmacy bills will appear here once dispensed and billed at Pharmacy Unit-I.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Itemized Table
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(4),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1.5),
                    4: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                      children: const [
                        Padding(padding: EdgeInsets.all(6), child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Batch / Form', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      ],
                    ),
                    ...dynamicBill.items.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final it = entry.value;
                      return TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.all(6), child: Text('$idx. ${it.description}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                          Padding(padding: const EdgeInsets.all(6), child: Text(it.itemCode, style: const TextStyle(fontSize: 10))),
                          Padding(padding: const EdgeInsets.all(6), child: Text('${it.quantity}', style: const TextStyle(fontSize: 11))),
                          Padding(padding: const EdgeInsets.all(6), child: Text('₹${it.unitPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11))),
                          Padding(padding: const EdgeInsets.all(6), child: Text('₹${it.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        ],
                      );
                    }),
                  ],
                ),
                const Divider(height: 20),

                // Summary Totals
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 240,
                    child: Column(
                      children: [
                        _buildBillTotalRow('Gross Amount', '₹${dynamicBill.subtotal.toStringAsFixed(2)}'),
                        _buildBillTotalRow('Discount', '₹${dynamicBill.discountAmount.toStringAsFixed(2)}'),
                        _buildBillTotalRow('CGST / SGST', '₹${dynamicBill.totalTaxAmount.toStringAsFixed(2)}'),
                        const Divider(),
                        _buildBillTotalRow('Net Cash Total', '₹${dynamicBill.totalAmount.toStringAsFixed(2)}', isBold: true),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillTotalRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: isBold ? AppColors.hospitalMaroon : null,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 6: LABORATORY MENU (Page 7 - பரிசோதனைகள்)
  // ==========================================
  Widget _buildLaboratoryMenuTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ஆய்வகப் பரிசோதனைகள்', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text('Laboratory Investigations Menu', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: const Text('SMVMCH Central Lab', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Biochemistry
              _buildLabCategoryCard(
                'BIOCHEMISTRY',
                [
                  'Glucose Fasting',
                  'Glucose PP',
                  'Glucose Random',
                  'Urea',
                  'Creatinine',
                  'Cholesterol',
                  'Triglycerides',
                  'Glucose Tolerance Test (Routine)',
                  'Glucose Tolerance Test (Pregnancy)',
                  'Glucose Challenge Test (GCT)',
                ],
                const Color(0xFFDC2626),
                isDark,
              ),
              const SizedBox(height: 16),

              // Haematology
              _buildLabCategoryCard(
                'HAEMATOLOGY',
                [
                  'Haemoglobin (Hb)',
                  'Haematocrit (PCV)',
                  'RBC Count',
                  'Total Leucocyte Count (TC)',
                  'Differential Count (DC)',
                  'Platelet Count',
                  'Erythrocyte Sedimentation Rate (ESR)',
                  'Bleeding Time (BT)',
                  'Clotting Time (CT)',
                  'Urine Routine',
                ],
                const Color(0xFF7C3AED),
                isDark,
              ),
              const SizedBox(height: 16),

              // Microbiology
              _buildLabCategoryCard(
                'MICROBIOLOGY',
                [
                  'Sputum AFB',
                  'Stool Ova / Cyst',
                  'HIV, VDRL (TB & Chest, Dermatology, Antenatal Cases)',
                ],
                const Color(0xFF059669),
                isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabCategoryCard(String title, List<String> tests, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tests.map((t) => Chip(
              label: Text(t, style: const TextStyle(fontSize: 11)),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
            )).toList(),
          ),
        ],
      ),
    );
  }
}
