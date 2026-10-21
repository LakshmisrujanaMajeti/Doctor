import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../routing/route_names.dart';
import '../../../shared/widgets/error_banner_widget.dart';
import '../../../shared/widgets/medical_illustrator_background.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/opd_text_field.dart';
import '../providers/auth_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Patient Identity & Demographics Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _parentSpouseController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController(text: 'Spouse / Parent');

  String _parentRelation = 'S/o'; // 'S/o', 'D/o', 'W/o', 'H/o', 'C/o'
  String _selectedGender = 'MALE';
  String _selectedBloodGroup = 'O+';
  bool _isSaving = false;
  bool _isEditMode = false;
  String _existingRole = 'patient';

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _genders = ['MALE', 'FEMALE', 'OTHER'];
  final List<String> _relations = ['S/o', 'D/o', 'W/o', 'H/o', 'C/o'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null && mounted) {
        setState(() {
          _isEditMode = true;
          _existingRole = user.roleName.toLowerCase();
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
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _parentSpouseController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final authNotifier = ref.read(authProvider.notifier);
      final cleanName = InputSanitizer.sanitizeText(_nameController.text);
      final cleanPhone = InputSanitizer.sanitizePhone(_phoneController.text);
      final rawEmail = _emailController.text.trim();
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

      // Strictly register as PATIENT (staff registration is exclusively via Admin Portal)
      final parsedAge = int.tryParse(_ageController.text.trim()) ?? 30;
      final parentSpouseFull = _parentSpouseController.text.trim().isNotEmpty
          ? '$_parentRelation ${_parentSpouseController.text.trim()}'
          : null;

      final success = await authNotifier.registerPatient(
        fullName: cleanName,
        phone: cleanPhone,
        email: cleanEmail,
        password: _passwordController.text.trim().isNotEmpty ? _passwordController.text.trim() : null,
        gender: _selectedGender,
        ageYears: parsedAge,
        bloodGroup: _selectedBloodGroup,
        address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : 'Local Patient Address',
        emergencyContactName: _emergencyNameController.text.trim().isNotEmpty ? _emergencyNameController.text.trim() : (parentSpouseFull ?? cleanName),
        emergencyContactPhone: _emergencyPhoneController.text.trim().isNotEmpty ? _emergencyPhoneController.text.trim() : cleanPhone,
        emergencyContactRelation: _emergencyRelationController.text.trim(),
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
                    'Patient $cleanName registered successfully! Permanent UHID generated.',
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.goNamed(RouteNames.welcome);
            }
          },
        ),
        title: Text(_isEditMode ? 'Edit Profile & Credentials' : 'Patient Registration'),
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
                              radius: 26,
                              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                              child: Icon(
                                _isEditMode ? Icons.badge_outlined : Icons.person_add_alt_1_rounded,
                                size: 28,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isEditMode ? 'Update Profile & Login Credentials' : 'New Patient Outpatient Registration',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _isEditMode
                                        ? 'Modify your identity details, mobile phone number, and password.'
                                        : 'Register for your official SMVMCH hospital UHID. Passwords are optional — check in anytime with your phone or UHID.',
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
                      const SizedBox(height: 16),

                      // Staff Notice Banner (explaining that staff are only provisioned by Admin)
                      if (!_isEditMode)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primaryBlue, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Hospital Staff Notice: Doctor, Nurse, Receptionist, Pharmacy, Lab & Cashier accounts are provisioned exclusively through the Hospital Admin Portal.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      if (authState.errorMessage != null) ...[
                        ErrorBannerWidget(
                          message: authState.errorMessage!,
                          onDismiss: () => ref.read(authProvider.notifier).checkCurrentUser(),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Section 1: Personal Demographics
                      _buildSectionHeader('1. Patient Identity & Demographics'),
                      const SizedBox(height: 10),
                      OpdTextField(
                        label: 'Full Legal Name *',
                        hint: 'e.g. Mr. RAVI PRASANTH',
                        controller: _nameController,
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Full legal name is mandatory' : null,
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: OpdTextField(
                              label: 'Mobile Phone (10 Digits) *',
                              hint: 'e.g. 9876543210',
                              controller: _phoneController,
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (v) => InputSanitizer.validate10DigitPhone(v, isRequired: true, fieldName: 'Mobile Phone'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OpdTextField(
                              label: 'Email (Optional)',
                              hint: 'name@example.com',
                              controller: _emailController,
                              readOnly: _isEditMode,
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => _isEditMode ? null : InputSanitizer.validateEmail(v, isRequired: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Age & Gender
                      Row(
                        children: [
                          SizedBox(
                            width: 130,
                            child: OpdTextField(
                              label: 'Age in Years *',
                              hint: 'e.g. 35',
                              controller: _ageController,
                              prefixIcon: Icons.calendar_today_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Age required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Gender *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Row(
                                  children: _genders.map((g) {
                                    final isSelected = _selectedGender == g;
                                    return Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2),
                                        child: ChoiceChip(
                                          label: Text(
                                            g == 'MALE' ? 'Male' : (g == 'FEMALE' ? 'Female' : 'Other'),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: isSelected ? Colors.white : null,
                                            ),
                                          ),
                                          selected: isSelected,
                                          selectedColor: AppColors.primaryBlue,
                                          onSelected: (val) {
                                            if (val) setState(() => _selectedGender = g);
                                          },
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Blood Group Selection Chips
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Blood Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _bloodGroups.map((bg) {
                              final isSelected = _selectedBloodGroup == bg;
                              return ChoiceChip(
                                label: Text(
                                  bg,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : null,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.triageEmergency,
                                onSelected: (val) {
                                  if (val) setState(() => _selectedBloodGroup = bg);
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Section 2: Guardian & Residential Information
                      _buildSectionHeader('2. Guardian & Address Details'),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          SizedBox(
                            width: 105,
                            child: DropdownButtonFormField<String>(
                              value: _parentRelation,
                              isExpanded: true,
                              items: _relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _parentRelation = val);
                              },
                              decoration: const InputDecoration(
                                labelText: 'Relation *',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OpdTextField(
                              label: 'Parent / Spouse / Guardian Name *',
                              hint: 'e.g. SAMBASIVA RAO',
                              controller: _parentSpouseController,
                              prefixIcon: Icons.family_restroom_rounded,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Guardian / Parent name is required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      OpdTextField(
                        label: 'Residential Address *',
                        hint: 'e.g. No. 14, Main Road, Kalitheerthalkuppam, Puducherry',
                        controller: _addressController,
                        prefixIcon: Icons.home_outlined,
                        maxLines: 2,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Residential address is mandatory' : null,
                      ),
                      const SizedBox(height: 20),

                      // Section 3: Emergency Contact
                      _buildSectionHeader('3. Emergency Contact Details'),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: OpdTextField(
                              label: 'Emergency Contact Person *',
                              hint: 'Contact Person / Relative',
                              controller: _emergencyNameController,
                              prefixIcon: Icons.contact_emergency_outlined,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Contact name required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OpdTextField(
                              label: 'Emergency Phone (10 Digits) *',
                              hint: 'e.g. 9876543210',
                              controller: _emergencyPhoneController,
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (v) => InputSanitizer.validate10DigitPhone(v, isRequired: true, fieldName: 'Emergency Contact Phone'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        value: _emergencyRelationController.text.isNotEmpty ? _emergencyRelationController.text : 'Spouse / Parent',
                        items: const [
                          DropdownMenuItem(value: 'Spouse / Parent', child: Text('Spouse / Parent')),
                          DropdownMenuItem(value: 'Father / Mother', child: Text('Father / Mother')),
                          DropdownMenuItem(value: 'Son / Daughter', child: Text('Son / Daughter')),
                          DropdownMenuItem(value: 'Brother / Sister', child: Text('Brother / Sister')),
                          DropdownMenuItem(value: 'Legal Guardian', child: Text('Legal Guardian')),
                          DropdownMenuItem(value: 'Relative / Friend', child: Text('Relative / Friend')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _emergencyRelationController.text = v);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Emergency Contact Relationship',
                          prefixIcon: Icon(Icons.people_alt_outlined, color: AppColors.primaryBlue),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 4: Security Credentials
                      _buildSectionHeader('4. Portal Security (Optional)'),
                      const SizedBox(height: 10),
                      OpdTextField(
                        label: _isEditMode ? 'New Password (Optional)' : 'Portal Password (Optional)',
                        hint: _isEditMode ? 'Leave blank to retain existing password' : 'Leave blank to use fast Phone/UHID check-in',
                        controller: _passwordController,
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: true,
                        enablePasswordToggle: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          return InputSanitizer.validateStrongPassword(v);
                        },
                      ),
                      const SizedBox(height: 28),

                      // Submit Button
                      OpdButton(
                        label: _isEditMode ? 'Save Profile Changes' : 'Register Patient & Generate UHID',
                        isLoading: _isSaving,
                        icon: _isEditMode ? Icons.check_circle_outline_rounded : Icons.how_to_reg_rounded,
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
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
    );
  }
}
