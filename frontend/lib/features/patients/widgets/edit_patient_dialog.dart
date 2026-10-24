import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/postal_pincode_service.dart';
import '../../../../core/utils/field_validators.dart';
import '../../../../core/utils/input_sanitizer.dart';
import '../../../../core/utils/submission_guard.dart';
import '../../../../shared/widgets/opd_text_field.dart';
import '../models/patient_model.dart';
import '../providers/patient_provider.dart';
import '../repositories/patient_repository.dart';
import '../../dashboard/providers/dashboard_provider.dart';

class EditPatientDialog extends ConsumerStatefulWidget {
  final PatientModel patient;

  const EditPatientDialog({
    super.key,
    required this.patient,
  });

  static Future<PatientModel?> show(BuildContext context, PatientModel patient) {
    return showDialog<PatientModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditPatientDialog(patient: patient),
    );
  }

  @override
  ConsumerState<EditPatientDialog> createState() => _EditPatientDialogState();
}

class _EditPatientDialogState extends ConsumerState<EditPatientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _submissionController = SubmissionController();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _parentSpouseController;
  late String _parentRelation;
  late TextEditingController _dobController;
  late TextEditingController _ageYearsController;
  late TextEditingController _ageMonthsController;
  late String _gender;
  late String? _bloodGroup;

  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _postalCodeController;

  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;
  late String _emergencyRelation;

  bool _isLookingUpPin = false;
  String? _pinLookupMessage;

  final List<String> _genderOptions = ['MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY'];
  final List<String> _relationOptions = ['S/o', 'D/o', 'W/o', 'H/o', 'Care of'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    final p = widget.patient;

    _nameController = TextEditingController(text: p.fullName);
    _phoneController = TextEditingController(text: p.phone);
    _emailController = TextEditingController(text: p.email ?? '');
    _parentSpouseController = TextEditingController(text: p.parentSpouseName ?? '');
    _parentRelation = p.parentSpouseRelation ?? 'S/o';
    _dobController = TextEditingController(text: p.dateOfBirth ?? '');
    _ageYearsController = TextEditingController(text: p.ageYears != null ? '${p.ageYears}' : '');
    _ageMonthsController = TextEditingController(text: p.ageMonths != null ? '${p.ageMonths}' : '');
    _gender = _genderOptions.contains(p.gender.toUpperCase()) ? p.gender.toUpperCase() : 'MALE';
    _bloodGroup = p.bloodGroup;

    _addressController = TextEditingController(text: p.address ?? '');
    _cityController = TextEditingController(text: p.city ?? '');
    _stateController = TextEditingController(text: p.state ?? '');
    _postalCodeController = TextEditingController(text: p.postalCode ?? '');

    _emergencyNameController = TextEditingController(text: p.emergencyContactName ?? '');
    _emergencyPhoneController = TextEditingController(text: p.emergencyContactPhone ?? '');
    _emergencyRelation = p.emergencyContactRelation ?? 'Spouse';

    _nameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _parentSpouseController.addListener(_onFieldChanged);
    _dobController.addListener(_onFieldChanged);
    _ageYearsController.addListener(_onFieldChanged);
    _ageMonthsController.addListener(_onFieldChanged);
    _addressController.addListener(_onFieldChanged);
    _cityController.addListener(_onFieldChanged);
    _stateController.addListener(_onFieldChanged);
    _postalCodeController.addListener(_onFieldChanged);
    _emergencyNameController.addListener(_onFieldChanged);
    _emergencyPhoneController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _parentSpouseController.dispose();
    _dobController.dispose();
    _ageYearsController.dispose();
    _ageMonthsController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _submissionController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  bool get _isFormDirty {
    final p = widget.patient;
    if (_nameController.text.trim() != p.fullName.trim()) return true;
    if (_phoneController.text.trim() != p.phone.trim()) return true;
    if (_emailController.text.trim() != (p.email ?? '').trim()) return true;
    if (_parentSpouseController.text.trim() != (p.parentSpouseName ?? '').trim()) return true;
    if (_parentRelation != (p.parentSpouseRelation ?? 'S/o')) return true;
    if (_dobController.text.trim() != (p.dateOfBirth ?? '').trim()) return true;
    if (_ageYearsController.text.trim() != (p.ageYears != null ? '${p.ageYears}' : '')) return true;
    if (_ageMonthsController.text.trim() != (p.ageMonths != null ? '${p.ageMonths}' : '')) return true;
    if (_gender != p.gender.toUpperCase()) return true;
    if (_bloodGroup != p.bloodGroup) return true;
    if (_addressController.text.trim() != (p.address ?? '').trim()) return true;
    if (_cityController.text.trim() != (p.city ?? '').trim()) return true;
    if (_stateController.text.trim() != (p.state ?? '').trim()) return true;
    if (_postalCodeController.text.trim() != (p.postalCode ?? '').trim()) return true;
    if (_emergencyNameController.text.trim() != (p.emergencyContactName ?? '').trim()) return true;
    if (_emergencyPhoneController.text.trim() != (p.emergencyContactPhone ?? '').trim()) return true;
    if (_emergencyRelation != (p.emergencyContactRelation ?? 'Spouse')) return true;
    return false;
  }

  Future<void> _handlePincodeLookup() async {
    final pin = _postalCodeController.text.trim();
    if (pin.length != 6) {
      setState(() => _pinLookupMessage = 'Please enter a 6-digit Indian PIN code first.');
      return;
    }

    setState(() {
      _isLookingUpPin = true;
      _pinLookupMessage = null;
    });

    try {
      final res = await PostalPincodeService.lookupPincode(pin);
      if (mounted) {
        if (res.isSuccess) {
          setState(() {
            if (res.suggestedDistrict != null && _cityController.text.trim().isEmpty) {
              _cityController.text = res.suggestedDistrict!;
            } else if (res.suggestedDistrict != null) {
              _showConfirmReplaceAddress(res.suggestedDistrict!, res.suggestedState ?? '');
            }
            if (res.suggestedState != null && _stateController.text.trim().isEmpty) {
              _stateController.text = res.suggestedState!;
            }
            _pinLookupMessage = res.message;
          });
        } else {
          setState(() {
            _pinLookupMessage = res.message ?? 'PIN code verification failed. You may enter City/State manually.';
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLookingUpPin = false);
    }
  }

  void _showConfirmReplaceAddress(String newDistrict, String newState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update City & State?'),
        content: Text(
          'PIN code lookup suggests:\nDistrict: $newDistrict\nState: $newState\n\nWould you like to replace current values ("${_cityController.text}", "${_stateController.text}")?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Manual Values'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _cityController.text = newDistrict;
                _stateController.text = newState;
              });
            },
            child: const Text('Apply Suggested', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    // 1. Guard against duplicate rapid clicks
    if (!_submissionController.begin()) return;

    if (!_formKey.currentState!.validate()) {
      _submissionController.completeError('Validation failed');
      return;
    }

    try {
      final cleanName = InputSanitizer.sanitizeText(_nameController.text);
      final cleanPhone = InputSanitizer.sanitizePhone(_phoneController.text);
      final cleanEmail = InputSanitizer.sanitizeEmail(_emailController.text);
      final cleanAddress = InputSanitizer.sanitizeText(_addressController.text);
      final cleanCity = InputSanitizer.sanitizeText(_cityController.text);
      final cleanState = InputSanitizer.sanitizeText(_stateController.text);
      final cleanPostal = InputSanitizer.sanitizeText(_postalCodeController.text);
      final cleanParentSpouse = InputSanitizer.sanitizeText(_parentSpouseController.text);
      final cleanEmerName = InputSanitizer.sanitizeText(_emergencyNameController.text);
      final cleanEmerPhone = InputSanitizer.sanitizePhone(_emergencyPhoneController.text);

      final updated = widget.patient.copyWith(
        fullName: cleanName,
        phone: cleanPhone,
        email: cleanEmail.isNotEmpty ? cleanEmail : null,
        parentSpouseName: cleanParentSpouse.isNotEmpty ? cleanParentSpouse : null,
        parentSpouseRelation: _parentRelation,
        dateOfBirth: _dobController.text.trim().isNotEmpty ? _dobController.text.trim() : null,
        ageYears: int.tryParse(_ageYearsController.text.trim()),
        ageMonths: int.tryParse(_ageMonthsController.text.trim()),
        gender: _gender,
        bloodGroup: _bloodGroup,
        address: cleanAddress.isNotEmpty ? cleanAddress : null,
        city: cleanCity.isNotEmpty ? cleanCity : null,
        state: cleanState.isNotEmpty ? cleanState : null,
        postalCode: cleanPostal.isNotEmpty ? cleanPostal : null,
        emergencyContactName: cleanEmerName.isNotEmpty ? cleanEmerName : null,
        emergencyContactPhone: cleanEmerPhone.isNotEmpty ? cleanEmerPhone : null,
        emergencyContactRelation: _emergencyRelation,
      );

      final result = await ref.read(patientRepositoryProvider).updatePatient(updated);
      ref.invalidate(patientListProvider);
      ref.invalidate(dashboardStatsProvider);

      _submissionController.completeSuccess();

      if (mounted) {
        Navigator.pop(context, result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.triageNormal,
            content: Text('Patient "${result.fullName}" (UHID: ${result.uhid}) updated successfully!'),
          ),
        );
      }
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      _submissionController.completeError(err);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.triageEmergency,
            content: Text('Failed to update patient: $err'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = media.size.width < 600;

    return Dialog(
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 16)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: media.size.height * 0.92,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Edit Patient: ${widget.patient.fullName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'UHID: ${widget.patient.uhid} • Hospital Reg No: ${widget.patient.hospitalRegNum ?? "N/A"}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cancel & Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            body: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Demographics & Identity
                    _buildSectionHeader(Icons.person_rounded, 'Demographics & Personal Details'),
                    const SizedBox(height: 12),
                    OPDTextField(
                      controller: _nameController,
                      label: 'Patient Full Name *',
                      hint: 'e.g. Ramesh Kumar',
                      prefixIcon: const Icon(Icons.person_outline),
                      inputFormatters: [
                        PersonNameInputFormatter(),
                        LengthLimitingTextInputFormatter(100),
                      ],
                      validator: (v) => FieldValidators.validatePersonName(v, fieldName: 'Patient Full Name', isRequired: true),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: DropdownButtonFormField<String>(
                            value: _parentRelation,
                            decoration: const InputDecoration(labelText: 'Rel', isDense: true, border: OutlineInputBorder()),
                            items: _relationOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                            onChanged: (v) => setState(() => _parentRelation = v ?? 'S/o'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OPDTextField(
                            controller: _parentSpouseController,
                            label: 'Father / Spouse Name',
                            hint: 'Name of guardian / spouse',
                            prefixIcon: const Icon(Icons.family_restroom_outlined),
                            inputFormatters: [
                              PersonNameInputFormatter(),
                              LengthLimitingTextInputFormatter(100),
                            ],
                            validator: (v) => FieldValidators.validatePersonName(v, fieldName: 'Father / Spouse Name', isRequired: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OPDTextField(
                            controller: _ageYearsController,
                            label: 'Age (Years)',
                            hint: 'e.g. 35',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            validator: (v) => FieldValidators.validateAge(v, isRequired: false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OPDTextField(
                            controller: _ageMonthsController,
                            label: 'Age (Months)',
                            hint: '0-11',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            validator: (v) => FieldValidators.validateAgeMonths(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _gender,
                            decoration: const InputDecoration(labelText: 'Gender *', isDense: true, border: OutlineInputBorder()),
                            items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (v) => setState(() => _gender = v ?? 'MALE'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _bloodGroup,
                      decoration: const InputDecoration(labelText: 'Blood Group', isDense: true, border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Not Tested / Unknown')),
                        ..._bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))),
                      ],
                      onChanged: (v) => setState(() => _bloodGroup = v),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Section 2: Contact & Address
                    _buildSectionHeader(Icons.home_outlined, 'Contact & Address Information'),
                    const SizedBox(height: 12),
                    OPDTextField(
                      controller: _phoneController,
                      label: 'Contact Phone Number (10 Digits) *',
                      hint: 'e.g. 9876543210',
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (v) => FieldValidators.validateIndianPhone(v, fieldName: 'Contact Phone', isRequired: true),
                    ),
                    const SizedBox(height: 12),
                    OPDTextField(
                      controller: _emailController,
                      label: 'Email Address (Optional)',
                      hint: 'e.g. patient@gmail.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: (v) => FieldValidators.validateEmail(v, isRequired: false),
                    ),
                    const SizedBox(height: 12),
                    OPDTextField(
                      controller: _addressController,
                      label: 'House / Street / Locality *',
                      hint: 'Door No, Street Name, Landmark',
                      maxLines: 2,
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      validator: (v) => FieldValidators.validateAddress(v, fieldName: 'House / Street / Locality', isRequired: true),
                    ),
                    const SizedBox(height: 12),

                    // 6-Digit Indian PIN Code with Verification
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: OPDTextField(
                            controller: _postalCodeController,
                            label: 'Indian PIN Code (6 Digits)',
                            hint: 'e.g. 605107',
                            keyboardType: TextInputType.number,
                            prefixIcon: const Icon(Icons.local_post_office_outlined),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            validator: (v) => FieldValidators.validatePinCode(v, isRequired: false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _isLookingUpPin ? null : _handlePincodeLookup,
                              icon: _isLookingUpPin
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.search_rounded, size: 16),
                              label: const Text('Verify PIN'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_pinLookupMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _pinLookupMessage!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _pinLookupMessage!.contains('Found') || _pinLookupMessage!.contains('Verified')
                              ? AppColors.triageNormal
                              : AppColors.triagePriority,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OPDTextField(
                            controller: _cityController,
                            label: 'City / District',
                            hint: 'e.g. Puducherry',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OPDTextField(
                            controller: _stateController,
                            label: 'State / Region',
                            hint: 'e.g. Puducherry',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Section 3: Emergency Contact
                    _buildSectionHeader(Icons.emergency_outlined, 'Emergency Kin / Contact Person'),
                    const SizedBox(height: 12),
                    OPDTextField(
                      controller: _emergencyNameController,
                      label: 'Emergency Contact Person Name',
                      hint: 'Name of relative / friend',
                      prefixIcon: const Icon(Icons.person_pin_outlined),
                      inputFormatters: [
                        PersonNameInputFormatter(),
                        LengthLimitingTextInputFormatter(100),
                      ],
                      validator: (v) => FieldValidators.validatePersonName(v, fieldName: 'Emergency Contact Person Name', isRequired: false),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OPDTextField(
                            controller: _emergencyPhoneController,
                            label: 'Emergency Phone Number',
                            hint: '10-digit mobile number',
                            keyboardType: TextInputType.phone,
                            prefixIcon: const Icon(Icons.phone_in_talk_outlined),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: (v) => FieldValidators.validateIndianPhone(v, fieldName: 'Emergency Phone Number', isRequired: false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _emergencyRelation,
                            decoration: const InputDecoration(labelText: 'Relationship', isDense: true, border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'Spouse', child: Text('Spouse')),
                              DropdownMenuItem(value: 'Parent', child: Text('Parent')),
                              DropdownMenuItem(value: 'Child', child: Text('Son / Daughter')),
                              DropdownMenuItem(value: 'Sibling', child: Text('Sibling')),
                              DropdownMenuItem(value: 'Guardian', child: Text('Guardian')),
                              DropdownMenuItem(value: 'Friend', child: Text('Friend / Relative')),
                            ],
                            onChanged: (v) => setState(() => _emergencyRelation = v ?? 'Spouse'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ListenableBuilder(
                      listenable: _submissionController,
                      builder: (context, _) {
                        final isSubmitting = _submissionController.isSubmitting;
                        final isDirty = _isFormDirty;

                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryTeal,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: isDirty ? AppColors.primaryTeal.withOpacity(0.5) : Colors.grey.shade400,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: (isDirty && !isSubmitting) ? _handleSave : null,
                          icon: isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(
                            isSubmitting
                                ? 'Saving Changes...'
                                : (!isDirty ? 'No Changes to Save' : 'Save Changes'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryTeal),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primaryTeal),
        ),
      ],
    );
  }
}
