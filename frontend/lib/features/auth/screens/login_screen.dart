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
import '../../../core/config/app_config.dart';
import '../../../shared/widgets/server_config_dialog.dart';
import '../../patients/repositories/patient_repository.dart';
import '../../visits/repositories/visit_repository.dart';
import '../../../core/storage/initial_hospital_data.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // 0 = Hospital Staff, 1 = Patient Portal
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

  // --- STAFF AUTH HANDLER ---
  Future<void> _handleStaffLogin() async {
    if (ref.read(authProvider).isLoading) return;
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

  // --- PATIENT AUTH HANDLER ---
  Future<void> _handlePatientLogin() async {
    final rawId = _patientIdentifierController.text.trim();
    if (rawId.isEmpty) {
      setState(() => _patientErrorMessage = 'Please enter your registered mobile number or UHID.');
      return;
    }

    final cleanDigits = rawId.replaceAll(RegExp(r'\D'), '');
    final isLooseToken = (rawId.startsWith('#') || cleanDigits == rawId) && cleanDigits.length <= 4;
    if (isLooseToken) {
      setState(() => _patientErrorMessage =
          'For patient security and privacy, token numbers (#1, #2) cannot be used to log in.\nPlease enter your registered 10-digit mobile number or unique UHID.');
      return;
    }

    setState(() {
      _isPatientLoading = true;
      _patientErrorMessage = null;
    });

    Map<String, dynamic>? data;

    // 1. Try FastAPI backend with responsive timeout
    try {
      final dio = ref.read(dioClientProvider);
      final response = await dio.dio.post(
        '/patient-portal/quick-access',
        data: {'identifier': rawId},
      ).timeout(const Duration(milliseconds: 2500));

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
            .timeout(const Duration(milliseconds: 1800));

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

    // 2b. Canonical Database Instant Resolution (0ms latency fallback across all 25 canonical hospital patients)
    if (data == null) {
      final cleanDigits = rawId.replaceAll(RegExp(r'\D'), '');
      final last10 = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;
      final q = rawId.trim().toLowerCase();

      // Collect all candidate patients
      final Map<String, Map<String, dynamic>> allPatientsById = {};

      // 1. From InitialHospitalData
      try {
        final snap = jsonDecode(InitialHospitalData.jsonSnapshot) as Map<String, dynamic>;
        final list = (snap['patients'] as List?) ?? [];
        for (final item in list) {
          final m = item as Map<String, dynamic>;
          final id = m['id']?.toString() ?? '';
          if (id.isNotEmpty) allPatientsById[id] = m;
        }
      } catch (_) {}

      // 2. From SecureStorageService
      try {
        final rawPats = await SecureStorageService.getPatientsJson();
        if (rawPats != null && rawPats.isNotEmpty) {
          final list = jsonDecode(rawPats) as List<dynamic>;
          for (final item in list) {
            final m = item as Map<String, dynamic>;
            final id = m['id']?.toString() ?? '';
            if (id.isNotEmpty) allPatientsById[id] = m;
          }
        }
      } catch (_) {}

      // 3. From PatientRepository
      for (final p in PatientRepository.cachedPatients) {
        allPatientsById[p.id] = p.toJson();
      }

      // Match patient accurately
      Map<String, dynamic>? matchedPatient;
      for (final p in allPatientsById.values) {
        final pUhid = p['uhid']?.toString().toLowerCase() ?? '';
        final pReg = p['hospital_reg_num']?.toString().toLowerCase() ?? '';
        final pPhone = p['phone']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
        final pLast10 = pPhone.length >= 10 ? pPhone.substring(pPhone.length - 10) : pPhone;
        final pName = p['full_name']?.toString().toLowerCase() ?? '';

        if (pUhid == q ||
            pReg == q ||
            (cleanDigits.isNotEmpty && pPhone == cleanDigits) ||
            (last10.isNotEmpty && pLast10 == last10) ||
            (cleanDigits.isNotEmpty && pPhone.contains(cleanDigits)) ||
            (q.length >= 3 && pName == q)) {
          matchedPatient = p;
          break;
        }
      }

      if (matchedPatient != null) {
        // Collect all visits
        final Map<String, Map<String, dynamic>> allVisitsById = {};
        try {
          final snap = jsonDecode(InitialHospitalData.jsonSnapshot) as Map<String, dynamic>;
          final list = (snap['visits'] as List?) ?? [];
          for (final item in list) {
            final m = item as Map<String, dynamic>;
            final id = m['id']?.toString() ?? '';
            if (id.isNotEmpty) allVisitsById[id] = m;
          }
        } catch (_) {}
        for (final v in VisitRepository.cachedVisits) {
          allVisitsById[v.id] = v.toJson();
        }

        final patId = matchedPatient['id']?.toString() ?? '';
        final patUhid = matchedPatient['uhid']?.toString() ?? '';

        Map<String, dynamic>? activeVisit;
        for (final v in allVisitsById.values) {
          final vPid = v['patient_id']?.toString();
          if (vPid == patId || vPid == patUhid) {
            activeVisit = v;
            break;
          }
        }

        data = {
          'access_token': 'patient-token-${matchedPatient['uhid'] ?? patId}',
          'token_type': 'bearer',
          'expires_in': 86400,
          'patient': matchedPatient,
          'active_visit': activeVisit,
        };
      }
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
          _patientErrorMessage =
              'No registered patient found matching "$rawId".\nNew patients must be registered at the Hospital Front Desk / Reception upon arrival.';
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
        backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF8FAFC),
        body: MedicalIllustratorBackground(
          variant: MedicalBackgroundVariant.auth,
          child: SafeArea(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 440,
                      minHeight: 577,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Server Endpoint Indicator & Host Configuration
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              InkWell(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (ctx) => const Dialog(
                                    backgroundColor: Colors.transparent,
                                    insetPadding: EdgeInsets.all(16),
                                    child: ServerConfigDialog(),
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.dns_rounded, size: 12, color: AppColors.primaryTeal),
                                      const SizedBox(width: 4),
                                      Text(
                                        AppConfig.apiBaseUrl
                                            .replaceFirst('http://', '')
                                            .replaceFirst('/api/v1', ''),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // SMVMCH Official Crest & Hospital Title
                          const Center(
                            child: SmvmchHospitalLogo(
                              size: 46,
                              layout: LogoLayout.vertical,
                              showTamilText: true,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: (_selectedTab == 0 ? AppColors.hospitalMaroon : AppColors.primaryTeal).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                AppStrings.appName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _selectedTab == 0 ? AppColors.hospitalMaroon : AppColors.primaryTeal,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Role Switcher: Hospital Staff vs Patient Portal (ONLY TWO PRIMARY TABS)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _HoverableTabButton(
                                    label: 'Hospital Staff',
                                    icon: Icons.medical_services_rounded,
                                    isSelected: _selectedTab == 0,
                                    activeColor: AppColors.hospitalMaroon,
                                    onTap: () => setState(() => _selectedTab = 0),
                                  ),
                                ),
                                Expanded(
                                  child: _HoverableTabButton(
                                    label: 'Patient Portal',
                                    icon: Icons.person_rounded,
                                    isSelected: _selectedTab == 1,
                                    activeColor: AppColors.primaryTeal,
                                    onTap: () => setState(() => _selectedTab = 1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Form Content (Fits cleanly with equalized height across both tabs)
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 316),
                            child: _selectedTab == 0
                                ? _buildStaffLoginForm(authState, isDark)
                                : _buildPatientLoginForm(isDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 1. HOSPITAL STAFF LOGIN (EMAIL / IDENTIFIER + PASSWORD)
  // =========================================================================
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
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Inline Error Banner
          if (authState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ErrorBannerWidget(
                message: authState.errorMessage!,
                onDismiss: () => ref.read(authProvider.notifier).checkCurrentUser(),
              ),
            ),

          // Staff Email Field
          OpdTextField(
            label: 'Hospital Staff Email or ID',
            hint: 'staff@smvmch.ac.in',
            controller: _emailController,
            prefixIcon: Icons.badge_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter your hospital email address';
              return null;
            },
          ),
          const SizedBox(height: 12),

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
          const SizedBox(height: 8),

          // Remember Me & Forgot Password
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: AppColors.hospitalMaroon,
                      onChanged: (val) => setState(() => _rememberMe = val ?? true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Remember me', style: TextStyle(fontSize: 12.5)),
                ],
              ),
              TextButton(
                onPressed: () => context.pushNamed(RouteNames.forgotPassword),
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.hospitalMaroon,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Sign In Button
          OpdButton(
            label: 'Sign In to Hospital Portal',
            isLoading: authState.isLoading,
            icon: Icons.login_rounded,
            color: AppColors.hospitalMaroon,
            onPressed: _handleStaffLogin,
          ),
          const SizedBox(height: 12),

          // Institutional Security Notice
          Center(
            child: Text(
              'Hospital staff accounts are provisioned exclusively by Administration.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. PATIENT PORTAL LOGIN (REGISTERED MOBILE NUMBER OR UHID - NO PASSWORD)
  // =========================================================================
  Widget _buildPatientLoginForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.badge_rounded, color: AppColors.primaryTeal, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Patient Portal Access',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Patient Error Banner
        if (_patientErrorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ErrorBannerWidget(
              message: _patientErrorMessage!,
              onDismiss: () => setState(() => _patientErrorMessage = null),
            ),
          ),

        // Identifier Field (Mobile Phone or UHID)
        OpdTextField(
          label: 'Registered Mobile Number or UHID',
          hint: 'e.g. 8374477999 or UHID-2026-00001',
          controller: _patientIdentifierController,
          prefixIcon: Icons.phone_android_rounded,
          keyboardType: TextInputType.text,
          suffixIcon: _patientIdentifierController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() => _patientIdentifierController.clear()),
                )
              : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        // Direct Patient Verification Container (matches height of Password field ~73px)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_user_rounded, color: AppColors.primaryTeal, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Direct Patient Verification',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Access clinical records & tokens directly without passwords.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Remember Me & Need Assistance? (matches Staff form row)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _rememberMe,
                    activeColor: AppColors.primaryTeal,
                    onChanged: (val) => setState(() => _rememberMe = val ?? true),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Remember me', style: TextStyle(fontSize: 12.5)),
              ],
            ),
            TextButton(
              onPressed: () => _showPatientHelpDialog(context, isDark),
              child: const Text(
                'Need Assistance?',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryTeal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Patient Login Button
        OpdButton(
          label: _isPatientLoading ? 'Verifying Patient Records...' : 'Access Health Records',
          isLoading: _isPatientLoading,
          icon: Icons.login_rounded,
          color: AppColors.primaryTeal,
          onPressed: _isPatientLoading ? null : _handlePatientLogin,
        ),
        const SizedBox(height: 12),

        // First Visit Notice
        Center(
          child: Text(
            'First visit? Front Desk registration required upon hospital arrival.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  void _showPatientHelpDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppColors.primaryTeal),
            SizedBox(width: 8),
            Text('Patient Access Help', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How to sign in to SMVMCH Patient Portal:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Enter your registered 10-digit mobile number (e.g. 8374477999) or your hospital UHID (e.g. UHID-2026-00001).',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            const Text(
              '• No password is required. Verification happens instantly with hospital records.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            const Text(
              '• First-time patients should visit the OPD Registration Desk at Ground Floor to generate a UHID.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.call_rounded, size: 16, color: AppColors.primaryTeal),
                  SizedBox(width: 8),
                  Text('Helpline: +91 413 2643000', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hoverable Top Tab Button
// ---------------------------------------------------------------------------
class _HoverableTabButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _HoverableTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  State<_HoverableTabButton> createState() => _HoverableTabButtonState();
}

class _HoverableTabButtonState extends State<_HoverableTabButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    if (widget.isSelected) {
      bg = widget.activeColor;
    } else if (_isHovered) {
      bg = widget.activeColor.withOpacity(0.12);
    } else {
      bg = Colors.transparent;
    }

    Color fg;
    if (widget.isSelected) {
      fg = Colors.white;
    } else if (_isHovered) {
      fg = widget.activeColor;
    } else {
      fg = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.activeColor.withOpacity(0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 16, color: fg),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
