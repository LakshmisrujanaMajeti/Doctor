import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/opd_constants.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../core/utils/responsive.dart';
import '../../../routing/route_names.dart';
import '../../../shared/widgets/error_banner_widget.dart';
import '../../../shared/widgets/medical_illustrator_background.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/opd_text_field.dart';
import '../../../shared/widgets/smvmch_hospital_logo.dart';
import '../providers/auth_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Core Identity Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  // Role: Doctor
  final _qualificationController = TextEditingController(text: 'MBBS, MD');
  final _specializationController = TextEditingController(text: 'General Medicine');
  final _docRegNumController = TextEditingController();
  final _roomNumberController = TextEditingController(text: 'OPD Room 101');
  final _consultationFeeController = TextEditingController(text: '500.00');

  // Role: Nurse
  final _nursingCouncilController = TextEditingController();
  final _wardAssignedController = TextEditingController(text: 'OPD Triage Desk');

  // Role: Pharmacist
  final _pharmacyLicenseController = TextEditingController();
  final _dispensingUnitController = TextEditingController(text: 'Pharmacy Unit-I (24 Hours)');

  // Role: Laboratory Technician
  final _labCouncilController = TextEditingController();
  final _labSectionController = TextEditingController(text: 'Clinical Biochemistry & Hematology');

  // Role: Receptionist & Billing
  final _counterNumberController = TextEditingController(text: 'Counter #1');
  final _employeeCodeController = TextEditingController();

  // Role: Hospital Administrator
  final _designationController = TextEditingController(text: 'Medical Superintendent');

  // Role: Patient
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController(text: 'Spouse / Parent');

  String _selectedRole = 'patient';
  String _selectedDepartment = 'General Medicine';
  String _selectedGender = 'MALE';
  String _selectedBloodGroup = 'O+';
  bool _isSaving = false;
  bool _isEditMode = false;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _genders = ['MALE', 'FEMALE', 'OTHER'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null && mounted) {
        setState(() {
          _isEditMode = true;
          _selectedRole = user.roleName.toLowerCase();
          _nameController.text = user.fullName;
          _emailController.text = user.email;
          _phoneController.text = user.phone ?? '';
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();

    _qualificationController.dispose();
    _specializationController.dispose();
    _docRegNumController.dispose();
    _roomNumberController.dispose();
    _consultationFeeController.dispose();

    _nursingCouncilController.dispose();
    _wardAssignedController.dispose();

    _pharmacyLicenseController.dispose();
    _dispensingUnitController.dispose();

    _labCouncilController.dispose();
    _labSectionController.dispose();

    _counterNumberController.dispose();
    _employeeCodeController.dispose();
    _designationController.dispose();

    _ageController.dispose();
    _addressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final rawEmail = _emailController.text.trim();
    if (_selectedRole != 'patient' && rawEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.triageEmergency,
          content: Text('Staff registration requires a valid email address.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authNotifier = ref.read(authProvider.notifier);
      final cleanName = InputSanitizer.sanitizeText(_nameController.text);
      final cleanPhone = InputSanitizer.sanitizePhone(_phoneController.text);
      final cleanEmail = rawEmail.isNotEmpty ? InputSanitizer.sanitizeEmail(rawEmail) : null;

      if (_isEditMode) {
        final newPass = _passwordController.text.trim();
        final success = await authNotifier.updateProfile(
          fullName: cleanName,
          phone: cleanPhone.isNotEmpty ? cleanPhone : null,
          newPassword: newPass.isNotEmpty ? newPass : null,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.statusCompleted,
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Profile and credentials for $cleanName updated successfully!',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            context.goNamed(RouteNames.dashboard);
          }
        }
        return;
      }

      final bool success;

      if (_selectedRole == 'patient') {
        final parsedAge = int.tryParse(_ageController.text.trim());
        success = await authNotifier.registerPatient(
          fullName: cleanName,
          phone: cleanPhone,
          email: cleanEmail,
          password: _passwordController.text,
          gender: _selectedGender,
          ageYears: parsedAge ?? 30,
          bloodGroup: _selectedBloodGroup,
          address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        );
      } else {
        // Collect role-specific metadata
        final Map<String, dynamic> metadata = {};

        if (_selectedRole == 'doctor') {
          metadata['qualification'] = _qualificationController.text.trim();
          metadata['specialization'] = _specializationController.text.trim();
          metadata['registration_number'] = _docRegNumController.text.trim().isNotEmpty
              ? _docRegNumController.text.trim()
              : 'MCI-2026-${(DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(5, '0')}';
          metadata['department_name'] = _selectedDepartment;
          metadata['room_number'] = _roomNumberController.text.trim();
          metadata['consultation_fee'] = _consultationFeeController.text.trim();
        } else if (_selectedRole == 'nurse') {
          metadata['nursing_council_reg'] = _nursingCouncilController.text.trim();
          metadata['ward_assigned'] = _wardAssignedController.text.trim();
          metadata['department_name'] = _selectedDepartment;
        } else if (_selectedRole == 'pharmacist') {
          metadata['pharmacy_license_number'] = _pharmacyLicenseController.text.trim();
          metadata['dispensing_unit'] = _dispensingUnitController.text.trim();
        } else if (_selectedRole == 'laboratory' || _selectedRole == 'lab_tech') {
          metadata['lab_council_reg'] = _labCouncilController.text.trim();
          metadata['lab_section'] = _labSectionController.text.trim();
        } else if (_selectedRole == 'billing') {
          metadata['counter_number'] = _counterNumberController.text.trim();
          metadata['employee_id'] = _employeeCodeController.text.trim();
        } else if (_selectedRole == 'receptionist') {
          metadata['counter_number'] = _counterNumberController.text.trim();
          metadata['employee_id'] = _employeeCodeController.text.trim();
          metadata['department_name'] = _selectedDepartment;
        } else if (_selectedRole == 'admin') {
          metadata['designation'] = _designationController.text.trim();
          metadata['employee_id'] = _employeeCodeController.text.trim();
        }

        success = await authNotifier.registerStaff(
          fullName: cleanName,
          email: cleanEmail ?? '',
          password: _passwordController.text,
          roleName: _selectedRole,
          phone: cleanPhone.isNotEmpty ? cleanPhone : null,
          roleMetadata: metadata,
        );
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusCompleted,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Profile created for $_selectedRole: $cleanName! Logging in...',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
        context.goNamed(RouteNames.dashboard);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.maybePop(context),
                )
              : const SmvmchHospitalLogo(size: 28),
        ),
        title: Text(_isEditMode ? 'Edit Profile & Credentials' : 'Hospital Profile Setup'),
      ),
      body: MedicalIllustratorBackground(
        variant: MedicalBackgroundVariant.portal,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                              child: Icon(
                                _getRoleIcon(_selectedRole),
                                size: 26,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isEditMode ? 'Update Profile & Login Credentials' : _getRoleTitle(_selectedRole),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isEditMode
                                        ? 'Modify your hospital identity details, phone number, and password.'
                                        : _getRoleDescription(_selectedRole),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (authState.errorMessage != null)
                        ErrorBannerWidget(
                          message: authState.errorMessage!,
                          onDismiss: () => ref.read(authProvider.notifier).checkCurrentUser(),
                        ),

                      // Section 1: Role Selector (Only for new registrations)
                      if (!_isEditMode) ...[
                        _buildSectionHeader('1. Authorized Role *'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'patient', child: Text('Patient (Self-Service UHID)')),
                            DropdownMenuItem(value: 'doctor', child: Text('Consulting Doctor (MD / Specialist)')),
                            DropdownMenuItem(value: 'nurse', child: Text('Clinical Nurse / Triage Specialist')),
                            DropdownMenuItem(value: 'receptionist', child: Text('Front Desk / Receptionist')),
                            DropdownMenuItem(value: 'billing', child: Text('Billing Counter / Cashier')),
                            DropdownMenuItem(value: 'pharmacist', child: Text('Pharmacist / Dispensing Unit')),
                            DropdownMenuItem(value: 'laboratory', child: Text('Laboratory Staff / Lab Tech')),
                            DropdownMenuItem(value: 'admin', child: Text('Hospital Administrator')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedRole = v);
                          },
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.badge_rounded, color: AppColors.primaryBlue),
                            labelText: 'Hospital Role Assignment',
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Section 2: Universal Account Credentials
                      _buildSectionHeader(_isEditMode ? 'Account Details & Credentials' : '2. Account Credentials & Contact'),
                      const SizedBox(height: 10),
                      OpdTextField(
                        label: 'Full Name *',
                        hint: _selectedRole == 'doctor' ? 'e.g. Dr. A. Ramanathan, MD' : 'Full legal name',
                        controller: _nameController,
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                      ),
                      const SizedBox(height: 14),
                      OpdTextField(
                        label: _isEditMode ? 'Work Email Address' : (_selectedRole == 'patient' ? 'Email Address (Optional)' : 'Work Email Address *'),
                        hint: 'name@opdconnect.com',
                        controller: _emailController,
                        readOnly: _isEditMode,
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => _isEditMode ? null : InputSanitizer.validateEmail(v, isRequired: _selectedRole != 'patient'),
                      ),
                      const SizedBox(height: 14),
                      OpdTextField(
                        label: 'Mobile Phone (10 Digits) *',
                        hint: 'e.g. 9876543210 (10 digits)',
                        controller: _phoneController,
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) => InputSanitizer.validate10DigitPhone(v, isRequired: true, fieldName: 'Mobile Phone'),
                      ),
                      const SizedBox(height: 14),
                      OpdTextField(
                        label: _isEditMode ? 'New Password (Optional)' : 'Secure Password *',
                        hint: _isEditMode ? 'Leave blank to keep existing password' : 'At least 8 chars (Aa-Zz, 0-9, special char)',
                        controller: _passwordController,
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: true,
                        enablePasswordToggle: true,
                        validator: (v) {
                          if (_isEditMode && (v == null || v.trim().isEmpty)) return null;
                          return InputSanitizer.validateStrongPassword(v);
                        },
                      ),
                      const SizedBox(height: 22),

                      // Section 3: Dynamic Role-Specific Hospital Fields (if not patient in edit mode)
                      if (!_isEditMode || _selectedRole != 'patient') ...[
                        _buildSectionHeader(_isEditMode ? 'Role-Specific Professional Info' : '3. ${_getRoleSpecificSectionTitle(_selectedRole)}'),
                        const SizedBox(height: 10),
                        _buildRoleSpecificFields(isDark),
                        const SizedBox(height: 32),
                      ],

                      // Submit Button
                      OpdButton(
                        label: _isEditMode ? 'Save Profile & Credentials' : 'Complete Registration & Launch Portal',
                        isLoading: _isSaving,
                        icon: _isEditMode ? Icons.check_circle_outline_rounded : Icons.rocket_launch_rounded,
                        width: double.infinity,
                        onPressed: _handleSave,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
    );
  }

  Widget _buildRoleSpecificFields(bool isDark) {
    switch (_selectedRole) {
      case 'doctor':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedDepartment,
              isExpanded: true,
              items: OpdConstants.departments
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedDepartment = v ?? 'General Medicine'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.domain_rounded, color: AppColors.primaryBlue),
                labelText: 'Clinical Department *',
              ),
            ),
            const SizedBox(height: 14),
            OpdTextField(
              label: 'Medical Council Reg. Number *',
              hint: 'e.g. MCI-2026-8841',
              controller: _docRegNumController,
              prefixIcon: Icons.verified_user_outlined,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Medical council registration is required' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OpdTextField(
                    label: 'Qualifications *',
                    hint: 'MBBS, MD, MS',
                    controller: _qualificationController,
                    prefixIcon: Icons.school_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OpdTextField(
                    label: 'Specialization *',
                    hint: 'Cardiology, etc.',
                    controller: _specializationController,
                    prefixIcon: Icons.health_and_safety_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OpdTextField(
                    label: 'Consultation Room',
                    hint: 'Room 101',
                    controller: _roomNumberController,
                    prefixIcon: Icons.meeting_room_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OpdTextField(
                    label: 'Consultation Fee (₹)',
                    hint: '500.00',
                    controller: _consultationFeeController,
                    prefixIcon: Icons.currency_rupee_rounded,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'nurse':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedDepartment,
              isExpanded: true,
              items: OpdConstants.departments
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedDepartment = v ?? 'General Medicine'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.domain_rounded, color: AppColors.primaryBlue),
                labelText: 'Assigned Department / Ward *',
              ),
            ),
            const SizedBox(height: 14),
            OpdTextField(
              label: 'Nursing Council Registration Number *',
              hint: 'e.g. NC-PY-2024-0981',
              controller: _nursingCouncilController,
              prefixIcon: Icons.badge_outlined,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nursing council registration is required' : null,
            ),
            const SizedBox(height: 14),
            OpdTextField(
              label: 'Triage / Ward Assignment',
              hint: 'e.g. OPD Triage Station A',
              controller: _wardAssignedController,
              prefixIcon: Icons.local_hospital_outlined,
            ),
          ],
        );

      case 'pharmacist':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OpdTextField(
              label: 'Pharmacy License / Reg. Number *',
              hint: 'e.g. RLF20PY2024000071',
              controller: _pharmacyLicenseController,
              prefixIcon: Icons.medication_outlined,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Pharmacy license registration is required' : null,
            ),
            const SizedBox(height: 14),
            OpdTextField(
              label: 'Dispensing Unit Assignment *',
              hint: 'Pharmacy Unit-I (24 Hours)',
              controller: _dispensingUnitController,
              prefixIcon: Icons.store_mall_directory_outlined,
            ),
          ],
        );

      case 'laboratory':
      case 'lab_tech':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OpdTextField(
              label: 'Paramedical / Lab Council Reg. Number *',
              hint: 'e.g. MLT-PY-2024-4412',
              controller: _labCouncilController,
              prefixIcon: Icons.biotech_outlined,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Council registration is required' : null,
            ),
            const SizedBox(height: 14),
            OpdTextField(
              label: 'Diagnostic Lab Section',
              hint: 'e.g. Biochemistry, Hematology, Pathology',
              controller: _labSectionController,
              prefixIcon: Icons.science_outlined,
            ),
          ],
        );

      case 'billing':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OpdTextField(
                    label: 'Billing Counter Number *',
                    hint: 'e.g. Counter #1 (OPD)',
                    controller: _counterNumberController,
                    prefixIcon: Icons.receipt_long_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OpdTextField(
                    label: 'Cashier Employee ID *',
                    hint: 'e.g. BILL-102',
                    controller: _employeeCodeController,
                    prefixIcon: Icons.badge_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
          ],
        );

      case 'receptionist':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OpdTextField(
                    label: 'Front Desk Counter',
                    hint: 'e.g. Desk A - Main Lobby',
                    controller: _counterNumberController,
                    prefixIcon: Icons.desk_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OpdTextField(
                    label: 'Employee Staff ID',
                    hint: 'e.g. REC-204',
                    controller: _employeeCodeController,
                    prefixIcon: Icons.badge_outlined,
                  ),
                ),
              ],
            ),
          ],
        );

      case 'admin':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OpdTextField(
                    label: 'Administrative Designation',
                    hint: 'e.g. Medical Superintendent',
                    controller: _designationController,
                    prefixIcon: Icons.admin_panel_settings_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OpdTextField(
                    label: 'Admin Code / ID',
                    hint: 'e.g. ADM-001',
                    controller: _employeeCodeController,
                    prefixIcon: Icons.badge_outlined,
                  ),
                ),
              ],
            ),
          ],
        );

      case 'patient':
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OpdTextField(
                    label: 'Age in Years *',
                    hint: 'e.g. 35',
                    controller: _ageController,
                    prefixIcon: Icons.calendar_today_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Age required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (v) => setState(() => _selectedGender = v ?? 'MALE'),
                    decoration: const InputDecoration(
                      labelText: 'Gender *',
                      prefixIcon: Icon(Icons.people_outline_rounded, color: AppColors.primaryBlue),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedBloodGroup,
              items: _bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
              onChanged: (v) => setState(() => _selectedBloodGroup = v ?? 'O+'),
              decoration: const InputDecoration(
                labelText: 'Blood Group',
                prefixIcon: Icon(Icons.bloodtype_outlined, color: AppColors.triageEmergency),
              ),
            ),
            const SizedBox(height: 14),
            OpdTextField(
              label: 'Residential Address',
              hint: 'e.g. No. 14, Main Road, Puducherry',
              controller: _addressController,
              prefixIcon: Icons.home_outlined,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OpdTextField(
                    label: 'Emergency Contact Name',
                    hint: 'Contact Person',
                    controller: _emergencyNameController,
                    prefixIcon: Icons.contact_emergency_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OpdTextField(
                    label: 'Emergency Phone (10 Digits)',
                    hint: 'e.g. 9876543210',
                    controller: _emergencyPhoneController,
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) => InputSanitizer.validate10DigitPhone(v, isRequired: false, fieldName: 'Emergency Phone'),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'doctor':
        return Icons.medical_services_rounded;
      case 'nurse':
        return Icons.monitor_heart_rounded;
      case 'pharmacist':
        return Icons.medication_rounded;
      case 'laboratory':
      case 'lab_tech':
        return Icons.biotech_rounded;
      case 'billing':
        return Icons.receipt_long_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'receptionist':
        return Icons.desk_rounded;
      case 'patient':
      default:
        return Icons.person_rounded;
    }
  }

  String _getRoleTitle(String role) {
    switch (role) {
      case 'doctor':
        return 'Medical Doctor / Specialist';
      case 'nurse':
        return 'Clinical Nurse & Triage';
      case 'pharmacist':
        return 'Hospital Pharmacist';
      case 'laboratory':
      case 'lab_tech':
        return 'Laboratory Technician';
      case 'billing':
        return 'Billing Counter & Cashier';
      case 'admin':
        return 'Hospital Administrator';
      case 'receptionist':
        return 'Front Desk & Registration';
      case 'patient':
      default:
        return 'Patient Self-Service Account';
    }
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'doctor':
        return 'Manage consultation sheets, diagnostic orders, and e-prescriptions.';
      case 'nurse':
        return 'Capture patient vitals, triage emergency ratings, and queue patients.';
      case 'pharmacist':
        return 'Review orders, verify formulary stock, and dispense medicines.';
      case 'laboratory':
      case 'lab_tech':
        return 'Collect specimens, enter diagnostic results, and flag abnormal findings.';
      case 'billing':
        return 'Generate official invoices, collect payments, and print GST cash bills.';
      case 'admin':
        return 'Hospital operations, audit log governance, and staff provisioning.';
      case 'receptionist':
        return 'Create patient UHIDs, issue OPD slips, and manage waiting queues.';
      case 'patient':
      default:
        return 'Instant access to token queue, OPD booklet, lab tests & bills.';
    }
  }

  String _getRoleSpecificSectionTitle(String role) {
    switch (role) {
      case 'doctor':
        return 'Doctor Credentials & Department';
      case 'nurse':
        return 'Nursing Council & Ward Details';
      case 'pharmacist':
        return 'Pharmacy License & Dispensing Unit';
      case 'laboratory':
      case 'lab_tech':
        return 'Laboratory Council & Section';
      case 'billing':
        return 'Cashier & Counter Assignment';
      case 'admin':
        return 'Administrative Credentials';
      case 'receptionist':
        return 'Front Desk Station Details';
      case 'patient':
      default:
        return 'Patient Demographics & Emergency Info';
    }
  }
}
