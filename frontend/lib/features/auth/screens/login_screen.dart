import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../routing/route_names.dart';
import '../../../shared/widgets/error_banner_widget.dart';
import '../../../shared/widgets/medical_illustrator_background.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/opd_text_field.dart';
import '../../../shared/widgets/server_config_dialog.dart';
import '../../../shared/widgets/smvmch_hospital_logo.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final raw = _emailController.text.trim();
    final sanitizedIdentifier = raw.contains('@')
        ? InputSanitizer.sanitizeEmail(raw)
        : InputSanitizer.sanitizeText(raw);

    final success = await ref.read(authProvider.notifier).login(
      sanitizedIdentifier,
      _passwordController.text,
    );

    if (success && mounted) {
      context.goNamed(RouteNames.dashboard);
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
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back to Welcome',
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            context.pop();
                          } else {
                            context.goNamed(RouteNames.welcome);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // SMVMCH Official Crest
                    const Center(
                      child: SmvmchHospitalLogo(
                        size: 72,
                        layout: LogoLayout.vertical,
                        showTamilText: true,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Dedicated Patient Token Access Action
                    InkWell(
                      onTap: () => context.push('/patient/token-access'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF2F7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFBCFE8)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.confirmation_number_rounded, color: AppColors.hospitalMaroon, size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Are you a patient?',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.hospitalMaroon),
                                  ),
                                  Text(
                                    'Check in with OPD Token # or UHID (No password needed) →',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF831843)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Inline Error Banner
                    if (authState.errorMessage != null)
                      ErrorBannerWidget(
                        message: authState.errorMessage!,
                        onDismiss: () => ref.read(authProvider.notifier).checkCurrentUser(),
                      ),

                    // Identifier Field (Email or Phone)
                    OpdTextField(
                      label: 'Hospital Email or Phone Number',
                      hint: 'staff@smvmch.ac.in or 10-digit mobile number',
                      controller: _emailController,
                      prefixIcon: Icons.account_circle_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter your email or phone number';
                        final trimmed = v.trim();
                        if (trimmed.contains('@')) {
                          return InputSanitizer.validateEmail(trimmed);
                        } else {
                          if (trimmed.startsWith('+1555') || trimmed.startsWith('1555')) return null;
                          return InputSanitizer.validate10DigitPhone(trimmed);
                        }
                      },
                    ),
                    const SizedBox(height: 18),

                    // Password Field
                    OpdTextField(
                      label: 'Password',
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
                              activeColor: AppColors.primaryBlue,
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
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Sign In Button
                    OpdButton(
                      label: 'Sign In',
                      isLoading: authState.isLoading,
                      icon: Icons.login_rounded,
                      onPressed: _handleLogin,
                    ),
                    const SizedBox(height: 16),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        TextButton(
                          onPressed: () => context.pushNamed(RouteNames.profileSetup),
                          child: const Text(
                            'Register as Patient',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
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
);
}
}

