import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../shared/widgets/medical_illustrator_background.dart';
import '../../../shared/widgets/opd_text_field.dart';
import '../models/patient_model.dart';
import '../providers/patient_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../admin_portal/providers/admin_portal_provider.dart';

class PatientRegistrationScreen extends ConsumerStatefulWidget {
  const PatientRegistrationScreen({super.key});

  @override
  ConsumerState<PatientRegistrationScreen> createState() => _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState extends ConsumerState<PatientRegistrationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Section 1: Demographics & Identity
  final _hospitalRegController = TextEditingController();
  final _nameController = TextEditingController();
  final _parentSpouseController = TextEditingController();
  String _parentRelation = 'S/o'; // S/o, D/o, W/o, H/o, Care of
  DateTime? _selectedDob;
  final _dobController = TextEditingController();
  final _ageYearsController = TextEditingController();
  final _ageMonthsController = TextEditingController();
  String _gender = 'MALE'; // MALE, FEMALE, OTHER, PREFER_NOT_TO_SAY

  // Section 2: Contact & Address
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController(text: 'Metro City');
  final _stateController = TextEditingController(text: 'State Health Region');
  final _postalCodeController = TextEditingController();

  // Section 3: Clinical & Emergency
  String? _bloodGroup = 'O+';
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  String _emergencyRelation = 'Spouse';

  bool _isSaving = false;
  bool _isCheckingDuplicate = false;

  final List<String> _genderOptions = ['MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY'];
  final List<String> _relationOptions = ['S/o', 'D/o', 'W/o', 'H/o', 'Care of'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hospitalRegController.dispose();
    _nameController.dispose();
    _parentSpouseController.dispose();
    _dobController.dispose();
    _ageYearsController.dispose();
    _ageMonthsController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  void _calculateAgeFromDob(DateTime dob) {
    final now = DateTime.now();
    int years = now.year - dob.year;
    int months = now.month - dob.month;
    if (now.day < dob.day) months--;
    if (months < 0) {
      years--;
      months += 12;
    }
    _ageYearsController.text = years >= 0 ? years.toString() : '0';
    _ageMonthsController.text = months >= 0 ? months.toString() : '0';
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryTeal,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
      _calculateAgeFromDob(picked);
    }
  }

  Future<void> _checkDuplicateWorkflow() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number to check duplicate registrations.')),
      );
      return;
    }

    setState(() => _isCheckingDuplicate = true);
    try {
      final repo = ref.read(patientRepositoryProvider);
      final result = await repo.checkDuplicates(
        phone: phone,
        fullName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
        hospitalRegNum: _hospitalRegController.text.trim().isNotEmpty ? _hospitalRegController.text.trim() : null,
      );

      if (mounted) {
        if (result.isDuplicate) {
          _showDuplicateWarningDialog(result);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.triageNormal,
              content: const Text('No duplicate patient records found. You can proceed with registration.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Duplicate check error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingDuplicate = false);
    }
  }

  void _showDuplicateWarningDialog(DuplicateCheckResult result) {
    final cleanCurrentPhone = _phoneController.text.trim();
    final hasIdenticalPhone = result.candidates.any((c) => c.phone.trim() == cleanCurrentPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              hasIdenticalPhone ? Icons.block_rounded : Icons.warning_amber_rounded,
              color: hasIdenticalPhone ? AppColors.triageEmergency : AppColors.triagePriority,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasIdenticalPhone ? 'Duplicate Contact Blocked' : 'Duplicate Warning',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasIdenticalPhone
                    ? 'A patient with this exact contact mobile number ($cleanCurrentPhone) already exists in the hospital database. Duplicate mobile numbers are strictly not accepted.'
                    : 'Found ${result.candidates.length} existing patient record(s) matching contact or identity details:',
                style: TextStyle(
                  fontSize: 13,
                  color: hasIdenticalPhone ? AppColors.triageEmergency : AppColors.textSecondary,
                  fontWeight: hasIdenticalPhone ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: result.candidates.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, i) {
                    final cand = result.candidates[i];
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackgroundLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(cand.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryTeal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(cand.uhid, style: const TextStyle(fontSize: 11, color: AppColors.primaryTeal, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Phone: ${cand.phone} • Reg: ${cand.hospitalRegNum ?? "N/A"} • ${cand.gender}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text('Match Reason: ${cand.matchReason}', style: const TextStyle(fontSize: 11, color: AppColors.triageEmergency, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Edit Contact Info'),
          ),
          if (!hasIdenticalPhone)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
              onPressed: () {
                Navigator.pop(ctx);
                _handleRegistrationSubmit(allowDuplicate: true);
              },
              child: const Text('Proceed (Override Duplicate)', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  void _showReviewBeforeSubmit() {
    if (_nameController.text.trim().isEmpty) {
      _tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Patient Full Name is required in Step 1 (Demographics).'),
        ),
      );
      return;
    }
    if (_phoneController.text.trim().length < 10) {
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('A valid 10-digit Contact Phone Number is required in Step 2 (Contact).'),
        ),
      );
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Residential Street Address is required in Step 2 (Contact & Address).'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete required fields before reviewing.')),
      );
      return;
    }

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
                  const Text('Review Registration Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              _buildReviewRow('Hospital Reg No', _hospitalRegController.text.trim().isNotEmpty ? _hospitalRegController.text.trim() : 'Auto-generated on save'),
              _buildReviewRow('Patient Full Name', _nameController.text.trim()),
              _buildReviewRow('Parent/Spouse', '${_parentRelation} ${_parentSpouseController.text.trim()}'),
              _buildReviewRow('Date of Birth / Age', '${_dobController.text.isNotEmpty ? _dobController.text : "N/A"} (${_ageYearsController.text}y ${_ageMonthsController.text}m)'),
              _buildReviewRow('Gender / Sex', _gender),
              _buildReviewRow('Contact Phone', _phoneController.text.trim()),
              _buildReviewRow('Email', _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : 'N/A'),
              _buildReviewRow('Address', '${_addressController.text.trim()}, ${_cityController.text.trim()}, ${_stateController.text.trim()} - ${_postalCodeController.text.trim()}'),
              _buildReviewRow('Blood Group', _bloodGroup ?? 'Not tested'),
              _buildReviewRow('Emergency Contact', '${_emergencyNameController.text.trim()} (${_emergencyRelation}) - ${_emergencyPhoneController.text.trim()}'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Edit Details'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleRegistrationSubmit();
                      },
                      child: const Text('Confirm & Register', style: TextStyle(color: Colors.white)),
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

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          const SizedBox(width: 8),
          Expanded(child: Text(value.isNotEmpty ? value : '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Future<void> _handleRegistrationSubmit({bool allowDuplicate = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final cleanName = InputSanitizer.sanitizeText(_nameController.text);
      final cleanPhone = InputSanitizer.sanitizePhone(_phoneController.text);
      final cleanEmail = InputSanitizer.sanitizeEmail(_emailController.text);
      final cleanParentSpouse = InputSanitizer.sanitizeText(_parentSpouseController.text);
      final cleanAddress = InputSanitizer.sanitizeText(_addressController.text);
      final cleanCity = InputSanitizer.sanitizeText(_cityController.text);
      final cleanState = InputSanitizer.sanitizeText(_stateController.text);
      final cleanPostal = InputSanitizer.sanitizeText(_postalCodeController.text);
      final cleanEmerName = InputSanitizer.sanitizeText(_emergencyNameController.text);
      final cleanEmerPhone = InputSanitizer.sanitizePhone(_emergencyPhoneController.text);
      final cleanRegNum = InputSanitizer.sanitizeText(_hospitalRegController.text);

      final newPatient = PatientModel(
        id: '',
        uhid: '',
        hospitalRegNum: cleanRegNum.isNotEmpty ? cleanRegNum : null,
        fullName: cleanName,
        parentSpouseName: cleanParentSpouse.isNotEmpty ? cleanParentSpouse : null,
        parentSpouseRelation: _parentRelation,
        dateOfBirth: _dobController.text.trim().isNotEmpty ? _dobController.text.trim() : null,
        ageYears: int.tryParse(_ageYearsController.text.trim()),
        ageMonths: int.tryParse(_ageMonthsController.text.trim()),
        gender: _gender,
        phone: cleanPhone,
        email: cleanEmail.isNotEmpty ? cleanEmail : null,
        address: cleanAddress.isNotEmpty ? cleanAddress : null,
        city: cleanCity.isNotEmpty ? cleanCity : null,
        state: cleanState.isNotEmpty ? cleanState : null,
        postalCode: cleanPostal.isNotEmpty ? cleanPostal : null,
        bloodGroup: _bloodGroup,
        emergencyContactName: cleanEmerName.isNotEmpty ? cleanEmerName : null,
        emergencyContactPhone: cleanEmerPhone.isNotEmpty ? cleanEmerPhone : null,
        emergencyContactRelation: _emergencyRelation,
      );

      final registered = await ref.read(patientRepositoryProvider).registerPatient(
        newPatient,
        allowDuplicate: allowDuplicate,
      );
      ref.read(patientSearchQueryProvider.notifier).setQuery('');
      ref.invalidate(patientListProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(adminDashboardSummaryProvider);
      ref.invalidate(adminRegistrationsReportProvider);
      ref.invalidate(adminBillingReportProvider);

      if (mounted) {
        _showSuccessCard(registered);
      }
    } catch (e) {
      if (mounted) {
        final errText = e.toString().replaceAll('Exception: ', '');
        if (errText.contains('Accidental duplicate prevented')) {
          _checkDuplicateWorkflow();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.triageEmergency,
              content: Text('Registration error: $errText'),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccessCard(PatientModel patient) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.triageNormal, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Registration Completed',
                style: TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient ${patient.fullName} has been registered successfully.', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryTeal.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Patient Unique UHID: ${patient.uhid}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTeal, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Hospital Reg No: ${patient.hospitalRegNum ?? "N/A"}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('Registered Mobile: ${patient.phone}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  const Text(
                    'The patient can use this unique UHID or registered mobile number to log in to the Patient Portal anytime.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.primaryTeal, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Would you like to book an OPD Visit & generate a Token now?', style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('Back to Patients'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/visits/new', extra: patient);
            },
            child: const Text('Book OPD Visit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Patients',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.goNamed(RouteNames.patients);
            }
          },
        ),
        title: Text('OPD Registration (Step ${_tabController.index + 1} of 3)', style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryTeal,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryTeal,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: '1. Demographics'),
            Tab(icon: Icon(Icons.contact_phone), text: '2. Contact & Addr'),
            Tab(icon: Icon(Icons.medical_information), text: '3. Clinical & Emer'),
          ],
        ),
      ),
      body: MedicalIllustratorBackground(
        variant: MedicalBackgroundVariant.clinical,
        child: Form(
          key: _formKey,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDemographicsTab(),
              _buildContactTab(),
              _buildClinicalEmergencyTab(),
            ],
          ),
        ),
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
              if (_tabController.index > 0) ...[
                OutlinedButton.icon(
                  onPressed: () => _tabController.animateTo(_tabController.index - 1),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back'),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                onPressed: _isCheckingDuplicate ? null : _checkDuplicateWorkflow,
                icon: _isCheckingDuplicate
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search, size: 16),
                label: const Text('Check Duplicate'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _tabController.index < 2
                    ? ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                        onPressed: () {
                          if (_tabController.index == 0) {
                            if (_nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.red,
                                  content: Text('Please enter Patient Full Name before proceeding.'),
                                ),
                              );
                              return;
                            }
                            _tabController.animateTo(1);
                          } else if (_tabController.index == 1) {
                            final phone = _phoneController.text.trim();
                            if (phone.length < 10) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.red,
                                  content: Text('Please enter a valid 10-digit Contact Phone Number.'),
                                ),
                              );
                              return;
                            }
                            if (_addressController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.red,
                                  content: Text('Please enter Residential Address before proceeding.'),
                                ),
                              );
                              return;
                            }
                            _tabController.animateTo(2);
                          }
                        },
                        icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                        label: Text(
                          _tabController.index == 0 ? 'Next: Contact Info →' : 'Next: Clinical Info →',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      )
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                        onPressed: _isSaving ? null : _showReviewBeforeSubmit,
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                        label: const Text('Review & Save Registration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDemographicsTab() {
    return SingleChildScrollView(
      key: const PageStorageKey('demographics_tab'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryTeal.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book, color: AppColors.primaryTeal),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'OPD Booklet Header: Demographics, Hospital Reg Number, S/o or Guardian, Age & Respectful Sex options.',
                    style: TextStyle(fontSize: 12, color: AppColors.primaryTeal.withOpacity(0.9)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OPDTextField(
            controller: _hospitalRegController,
            label: 'Hospital Registration Number (Optional)',
            hint: 'Leave blank for auto REG-YYYY-XXXXX',
            prefixIcon: const Icon(Icons.numbers),
          ),
          const SizedBox(height: 12),
          OPDTextField(
            key: const Key('patient_name_input'),
            controller: _nameController,
            label: 'Patient Full Name *',
            hint: 'e.g. Aarav Sharma',
            prefixIcon: const Icon(Icons.person_outline),
            validator: (v) => v == null || v.trim().isEmpty ? 'Patient full name is required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<String>(
                  value: _parentRelation,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Relation',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                  items: _relationOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setState(() => _parentRelation = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OPDTextField(
                  controller: _parentSpouseController,
                  label: 'Parent / Spouse Name',
                  hint: 'e.g. Dev Sharma',
                  prefixIcon: const Icon(Icons.family_restroom),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: _selectDateOfBirth,
                  child: IgnorePointer(
                    child: OPDTextField(
                      controller: _dobController,
                      label: 'Date of Birth',
                      hint: 'YYYY-MM-DD',
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OPDTextField(
                  controller: _ageYearsController,
                  label: 'Age (Y)',
                  hint: 'Years',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OPDTextField(
                  controller: _ageMonthsController,
                  label: 'Months',
                  hint: '0-11',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Sex / Gender *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _genderOptions.map((g) {
              final isSel = _gender == g;
              return ChoiceChip(
                label: Text(g.replaceAll('_', ' ')),
                selected: isSel,
                selectedColor: AppColors.primaryTeal,
                labelStyle: TextStyle(color: isSel ? Colors.white : AppColors.textPrimary, fontSize: 12),
                onSelected: (val) {
                  if (val) setState(() => _gender = g);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(
      key: const PageStorageKey('contact_tab'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OPDTextField(
            key: const Key('patient_phone_input'),
            controller: _phoneController,
            label: 'Contact Phone Number *',
            hint: 'e.g. 9876543210 (10 digits)',
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            prefixIcon: const Icon(Icons.phone_outlined),
            validator: (v) => InputSanitizer.validate10DigitPhone(v, isRequired: true, fieldName: 'Contact Phone Number'),
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _emailController,
            label: 'Email Address (Optional)',
            hint: 'patient@example.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined),
            validator: (v) => InputSanitizer.validateEmail(v, isRequired: false),
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _addressController,
            label: 'Street / Residential Address *',
            hint: 'Flat, Street, Landmark',
            maxLines: 2,
            prefixIcon: const Icon(Icons.home_outlined),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Residential address is mandatory' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OPDTextField(
                  controller: _cityController,
                  label: 'City / District',
                  hint: 'Metro City',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OPDTextField(
                  controller: _stateController,
                  label: 'State / Province',
                  hint: 'State Region',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _postalCodeController,
            label: 'Postal / PIN Code',
            hint: 'e.g. 500081',
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.local_post_office_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalEmergencyTab() {
    return SingleChildScrollView(
      key: const PageStorageKey('clinical_tab'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Blood Group', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _bloodGroups.map((bg) {
              final isSel = _bloodGroup == bg;
              return ChoiceChip(
                label: Text(bg),
                selected: isSel,
                selectedColor: AppColors.primaryTeal,
                labelStyle: TextStyle(color: isSel ? Colors.white : AppColors.textPrimary),
                onSelected: (val) {
                  setState(() => _bloodGroup = val ? bg : null);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          const Text('Emergency Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          OPDTextField(
            controller: _emergencyNameController,
            label: 'Emergency Contact Person *',
            hint: 'Name of guardian / kin',
            prefixIcon: const Icon(Icons.person_pin_outlined),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Emergency contact name is mandatory' : null,
          ),
          const SizedBox(height: 12),
          OPDTextField(
            controller: _emergencyPhoneController,
            label: 'Emergency Phone Number (10 Digits) *',
            hint: 'e.g. 9876543210',
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            prefixIcon: const Icon(Icons.phone_in_talk_outlined),
            validator: (v) => InputSanitizer.validate10DigitPhone(v, isRequired: true, fieldName: 'Emergency Phone Number'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _emergencyRelation,
            decoration: const InputDecoration(
              labelText: 'Emergency Contact Relationship',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Spouse', child: Text('Spouse')),
              DropdownMenuItem(value: 'Parent', child: Text('Parent / Father / Mother')),
              DropdownMenuItem(value: 'Child', child: Text('Son / Daughter')),
              DropdownMenuItem(value: 'Sibling', child: Text('Brother / Sister')),
              DropdownMenuItem(value: 'Guardian', child: Text('Legal Guardian')),
              DropdownMenuItem(value: 'Friend', child: Text('Friend / Relative')),
            ],
            onChanged: (v) => setState(() => _emergencyRelation = v ?? 'Spouse'),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code, size: 36, color: AppColors.primaryTeal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Barcode & QR Code Integration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('UHID barcode & OPDConnect QR identifier are automatically minted and printable upon patient registration.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
