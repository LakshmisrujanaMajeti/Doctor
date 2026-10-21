import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../routing/route_names.dart';
import '../../../shared/widgets/error_banner_widget.dart';
import '../../../shared/widgets/medical_illustrator_background.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/opd_text_field.dart';
import '../../../shared/widgets/smvmch_hospital_logo.dart';
import '../models/auth_state.dart';
import '../providers/auth_provider.dart';
import '../../patient_portal/providers/patient_portal_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // 0 = Hospital Staff (Email & Password), 1 = Patient Portal (Mobile # / UHID)
  int _selectedTab = 0;

  // Staff Form
  final _staffFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;

  // Patient Form
  final _patientIdentifierController = TextEditingController();
  bool _isPatientLoading = false;
  String? _patientErrorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _patientIdentifierController.dispose();
    super.dispose();
  }

  Future<void> _handleStaffLogin() async {
    if (!_staffFormKey.currentState!.validate()) return;

    final raw = _emailController.text.trim();
    final sanitizedIdentifier = raw.contains('@')
        ? InputSanitizer.sanitizeEmail(raw)
        : InputSanitizer.sanitizeText(raw);

    final success = await ref.read(authProvider.notifier).login(
      sanitizedIdentifier,
      _passwordController.text,
    );

    if (success && mounted) {
      final role = ref.read(authProvider).user?.roleName.toLowerCase() ?? '';
      if (role == 'patient') {
        context.goNamed(RouteNames.patientPortal);
      } else {
        context.goNamed(RouteNames.dashboard);
      }
    }
  }

  Future<void> _handlePatientLogin() async {
    final rawId = _patientIdentifierController.text.trim();
    if (rawId.isEmpty) {
      setState(() => _patientErrorMessage = 'Please enter your registered mobile number or UHID.');
      return;
    }

    final cleanDigits = rawId.replaceAll(RegExp(r'\D'), '');
    final isLooseToken = (rawId.startsWith('#') || cleanDigits == rawId) && cleanDigits.length <= 4;
    if (isLooseToken) {
      setState(() => _patientErrorMessage = 'For patient security and privacy, token numbers (#1, #2) cannot be used to log in.\nPlease enter your registered 10-digit mobile number or unique UHID.');
      return;
    }

    setState(() {
      _isPatientLoading = true;
      _patientErrorMessage = null;
    });

    Map<String, dynamic>? data;

    // 1. Try FastAPI backend
    try {
      final dio = ref.read(dioClientProvider);
      final response = await dio.dio.post(
        '/patient-portal/quick-access',
        data: {'identifier': rawId},
      ).timeout(const Duration(seconds: 10));

      if (response.data is Map && response.data['status'] == 'success') {
        data = response.data['data'] as Map<String, dynamic>;
      }
    } catch (_) {}

    // 2. Try Supabase Cloud direct query if FastAPI was unreachable
    if (data == null) {
      try {
        final cleanDigits = rawId.replaceAll(RegExp(r'\D'), '');
        final last10 = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;

        final res = await Supabase.instance.client
            .from('patients')
            .select('*, opd_visits(*)')
            .or('uhid.ilike.%$rawId%,hospital_reg_num.ilike.%$rawId%,phone.ilike.%$last10%')
            .limit(1)
            .timeout(const Duration(milliseconds: 2500));

        if (res.isNotEmpty) {
          final pat = res.first;
          final visits = (pat['opd_visits'] as List?) ?? [];
          final visitRecord = visits.isNotEmpty ? visits.first : null;
          data = {
            'access_token': 'patient-token-${pat['id'] ?? pat['uhid'] ?? 'pat'}',
            'token_type': 'bearer',
            'expires_in': 86400,
            'patient': pat,
            'active_visit': visitRecord,
          };
        }
      } catch (_) {}
    }

    // 3. Fallback to Local Offline Cache
    if (data == null) {
      try {
        final rawPatients = await SecureStorageService.getPatientsJson();
        final rawVisits = await SecureStorageService.getVisitsJson();
        List<dynamic> localPatients = rawPatients != null ? jsonDecode(rawPatients) : [];
        List<dynamic> localVisits = rawVisits != null ? jsonDecode(rawVisits) : [];

        final q = rawId.toLowerCase().trim();
        final cleanDigits = rawId.replaceAll(RegExp(r'\D'), '');
        final last10 = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;

        final matchedPatient = localPatients.firstWhere(
          (p) {
            final uhid = p['uhid']?.toString().toLowerCase() ?? '';
            final reg = p['hospital_reg_num']?.toString().toLowerCase() ?? '';
            final phone = p['phone']?.toString().trim() ?? '';
            final name = p['full_name']?.toString().toLowerCase() ?? '';
            return uhid == q || uhid.contains(q) || reg == q || reg.contains(q) ||
                (last10.isNotEmpty && phone.contains(last10)) || name.contains(q);
          },
          orElse: () => null,
        );

        if (matchedPatient != null) {
          final matchedVisit = localVisits.firstWhere(
            (v) => v['patient_id'] == matchedPatient['id'],
            orElse: () => null,
          );
          data = {
            'access_token': 'patient-token-${matchedPatient['id'] ?? 'pat'}',
            'token_type': 'bearer',
            'expires_in': 86400,
            'patient': matchedPatient,
            'active_visit': matchedVisit,
          };
        }
      } catch (_) {}
    }

    if (data != null && mounted) {
      final token = data['access_token'] as String?;
      final patient = data['patient'] as Map<String, dynamic>?;

      if (token != null && token.isNotEmpty) {
        await DioClient.saveTokens(
          accessToken: token,
          refreshToken: 'patient-quick-refresh',
          role: 'patient',
        );
        if (patient != null) {
          final userMap = {
            'id': patient['id'] ?? 'pat-quick',
            'patient_id': patient['id'] ?? 'pat-quick',
            'uhid': patient['uhid'] ?? 'UHID-NEW',
            'full_name': patient['full_name'] ?? 'Patient',
            'phone': patient['phone'] ?? '',
            'email': patient['email'] ?? 'patient@smvmch.ac.in',
            'gender': patient['gender'] ?? 'OTHER',
            'age_years': patient['age_years'] ?? 0,
            'role_name': 'patient',
          };
          await SecureStorageService.saveUserData(userMap);

          final user = UserModel(
            id: patient['id'] as String? ?? 'pat-quick',
            email: patient['email'] as String? ?? 'patient@smvmch.ac.in',
            fullName: patient['full_name'] as String? ?? 'Patient',
            phone: patient['phone'] as String? ?? '',
            roleName: 'patient',
          );
          ref.read(authProvider.notifier).setSimulatedUser(user);
        }

        DioClient.clearCache();
        ref.invalidate(patientProfileProvider);
        ref.invalidate(selectedPortalPatientIdProvider);
        ref.invalidate(patientVisitsProvider);
        ref.invalidate(patientAppointmentsProvider);
        ref.invalidate(patientPrescriptionsProvider);
        ref.invalidate(patientLabReportsProvider);
        ref.invalidate(patientBillsProvider);
        ref.invalidate(patientDocumentsProvider);
        ref.invalidate(patientSupportTicketsProvider);
      }

      setState(() => _isPatientLoading = false);
      if (mounted) {
        context.goNamed(RouteNames.patientPortal);
      }
    } else {
      if (mounted) {
        setState(() {
          _isPatientLoading = false;
          _patientErrorMessage = 'No registered patient found matching "$rawId".\nNew patients must be registered at the Front Desk / Reception upon arrival.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark ? AppColors.darkBg : Colors.white,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        body: MedicalIllustratorBackground(
          variant: MedicalBackgroundVariant.auth,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // SMVMCH Official Crest
                      const Center(
                        child: SmvmchHospitalLogo(
                          size: 72,
                          layout: LogoLayout.vertical,
                          showTamilText: true,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          AppStrings.appName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.hospitalMaroon,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Role Switcher: Hospital Staff vs Patient Portal
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _selectedTab = 0),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 0
                                        ? AppColors.hospitalMaroon
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: _selectedTab == 0
                                        ? [
                                            BoxShadow(
                                              color: AppColors.hospitalMaroon.withOpacity(0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.medical_services_rounded,
                                        size: 17,
                                        color: _selectedTab == 0
                                            ? Colors.white
                                            : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Hospital Staff',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: _selectedTab == 0
                                              ? Colors.white
                                              : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _selectedTab = 1),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 1
                                        ? AppColors.primaryTeal
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: _selectedTab == 1
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primaryTeal.withOpacity(0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_rounded,
                                        size: 17,
                                        color: _selectedTab == 1
                                            ? Colors.white
                                            : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Patient Portal',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: _selectedTab == 1
                                              ? Colors.white
                                              : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tab View Rendering
                      if (_selectedTab == 0)
                        _buildStaffLoginForm(authState, isDark)
                      else
                        _buildPatientLoginForm(isDark),
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

  // 1. HOSPITAL STAFF LOGIN (EMAIL + PASSWORD ONLY)
  Widget _buildStaffLoginForm(AuthState authState, bool isDark) {
    return Form(
      key: _staffFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_person_rounded, color: AppColors.hospitalMaroon, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Hospital Staff Sign In',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Authorized personnel only: Doctors, Nurses, Reception, Pharmacy, Lab, Cashier & Admin.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          // Inline Error Banner
          if (authState.errorMessage != null)
            ErrorBannerWidget(
              message: authState.errorMessage!,
              onDismiss: () => ref.read(authProvider.notifier).checkCurrentUser(),
            ),

          // Staff Email Field
          OpdTextField(
            label: 'Hospital Staff Email',
            hint: 'staff@smvmch.ac.in',
            controller: _emailController,
            prefixIcon: Icons.badge_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter your hospital email address';
              return InputSanitizer.validateEmail(v.trim());
            },
          ),
          const SizedBox(height: 16),

          // Password Field
          OpdTextField(
            label: 'Staff Password',
            hint: '••••••••',
            controller: _passwordController,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            enablePasswordToggle: true,
            validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
          ),
          const SizedBox(height: 12),

          // Remember Me & Forgot Password
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    activeColor: AppColors.hospitalMaroon,
                    onChanged: (val) => setState(() => _rememberMe = val ?? true),
                  ),
                  const Text('Remember me', style: TextStyle(fontSize: 13)),
                ],
              ),
              TextButton(
                onPressed: () => context.pushNamed(RouteNames.forgotPassword),
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.hospitalMaroon,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sign In Button
          OpdButton(
            label: 'Sign In as Staff',
            isLoading: authState.isLoading,
            icon: Icons.login_rounded,
            onPressed: _handleStaffLogin,
          ),
          const SizedBox(height: 16),

          // Informational note
          Center(
            child: Text(
              'Patients: switch to the "Patient Portal" tab above to log in.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[500] : Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  // 2. PATIENT LOGIN (REGISTERED MOBILE NUMBER OR UHID ONLY - NO PASSWORD)
  Widget _buildPatientLoginForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.badge_rounded, color: AppColors.primaryTeal, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Patient Portal Login',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Log in with your registered mobile phone number or unique UHID. No password needed.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),

        // Patient Error Banner
        if (_patientErrorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _patientErrorMessage!,
                    style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

        // Identifier Field (Mobile Phone or UHID)
        TextField(
          controller: _patientIdentifierController,
          keyboardType: TextInputType.text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'Registered Mobile Number or UHID',
            hintText: 'e.g. 9876543210 or UHID-2026-00001',
            prefixIcon: const Icon(Icons.phone_android_rounded, color: AppColors.primaryTeal),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: _patientIdentifierController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _patientIdentifierController.clear()),
                  )
                : null,
          ),
          onSubmitted: (_) => _handlePatientLogin(),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),

        // Front Desk Registration Guidance Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryTeal.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryTeal.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_hospital_rounded, color: AppColors.primaryTeal, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Hospital Registration Policy',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '• New Patients: Registration is completed exclusively at the Hospital Front Desk / Reception upon arrival.\n• Once registered, your unique UHID and mobile number grant instant access to your records anytime.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Patient Login Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryTeal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _isPatientLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.login_rounded),
          label: Text(
            _isPatientLoading ? 'Verifying Patient Records...' : 'Log In to Patient Portal',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          onPressed: _isPatientLoading ? null : _handlePatientLogin,
        ),
      ],
    );
  }
}
