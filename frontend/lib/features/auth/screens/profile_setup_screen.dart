import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/opd_constants.dart';
import '../../../routing/route_names.dart';
import '../../../shared/widgets/error_banner_widget.dart';
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

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _staffIdController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = 'patient';
  String _selectedDepartment = 'General Medicine';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _staffIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    if (_selectedRole != 'patient' && email.isEmpty) {
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
      final bool success;

      if (_selectedRole == 'patient') {
        success = await authNotifier.registerPatient(
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: email.isNotEmpty ? email : null,
          password: _passwordController.text,
        );
      } else {
        success = await authNotifier.registerStaff(
          fullName: _nameController.text.trim(),
          email: email,
          password: _passwordController.text,
          roleName: _selectedRole,
          phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        );
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primaryBlue,
            content: Text('Registration complete! Welcome, ${_nameController.text.trim()}.'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Profile Setup'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Upload Placeholder
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                            child: const Icon(
                              Icons.person_rounded,
                              size: 52,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primaryBlue,
                              child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Upload Hospital ID / Photo',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 28),

                    if (authState.errorMessage != null)
                      ErrorBannerWidget(
                        message: authState.errorMessage!,
                        onDismiss: () => ref.read(authProvider.notifier).checkCurrentUser(),
                      ),

                    // Role Selector
                    const Text('1. Authorized Role *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'patient', child: Text('Patient (Self-Service UHID)')),
                        DropdownMenuItem(value: 'doctor', child: Text('Consulting Doctor (MD / Specialist)')),
                        DropdownMenuItem(value: 'receptionist', child: Text('Front Desk / Receptionist')),
                        DropdownMenuItem(value: 'laboratory', child: Text('Laboratory Staff / Lab Tech')),
                        DropdownMenuItem(value: 'pharmacist', child: Text('Pharmacist / Dispensing')),
                        DropdownMenuItem(value: 'admin', child: Text('Hospital Administrator')),
                      ],
                      onChanged: (v) => setState(() => _selectedRole = v ?? 'patient'),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.badge_rounded, color: AppColors.primaryBlue),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Personal Demographics
                    const Text('2. Personal & Professional Info', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 10),
                    OpdTextField(
                      label: 'Full Name *',
                      hint: 'e.g. Johnathan Reynolds',
                      controller: _nameController,
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    OpdTextField(
                      label: 'Work or Personal Email Address',
                      hint: 'name@opdconnect.com',
                      controller: _emailController,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    OpdTextField(
                      label: 'Contact Phone *',
                      hint: 'e.g. +1 555-444-3333',
                      controller: _phoneController,
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().length < 7) ? 'Valid phone number required' : null,
                    ),
                    const SizedBox(height: 20),

                    // Department & Staff ID
                    const Text('3. Department Assignment & Registration', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDepartment,
                      isExpanded: true,
                      items: OpdConstants.departments
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedDepartment = v ?? 'General Medicine'),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.domain_rounded, color: AppColors.primaryBlue),
                        labelText: 'Hospital Department',
                      ),
                    ),
                    const SizedBox(height: 16),
                    OpdTextField(
                      label: _selectedRole == 'doctor' ? 'Medical Council Reg. Number' : 'Hospital Staff ID / UHID',
                      hint: _selectedRole == 'doctor' ? 'e.g. MED-REG-2024-8841' : 'e.g. STF-0042',
                      controller: _staffIdController,
                      prefixIcon: Icons.assignment_ind_outlined,
                    ),
                    const SizedBox(height: 16),
                    OpdTextField(
                      label: 'Account Password *',
                      hint: '••••••••',
                      controller: _passwordController,
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: true,
                      enablePasswordToggle: true,
                      validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                    ),
                    const SizedBox(height: 36),

                    // Submit
                    OpdButton(
                      label: 'Complete Profile & Launch Portal',
                      isLoading: _isSaving,
                      icon: Icons.rocket_launch_rounded,
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
    );
  }
}
