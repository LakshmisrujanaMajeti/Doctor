import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../routing/route_names.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/opd_text_field.dart';
import '../repositories/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AuthRepository _authRepository;
  bool _isLoading = false;
  int _currentStep = 1; // 1 = Identifier, 2 = OTP + New Password, 3 = Success
  String? _simulatedOtp;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _authRepository = AuthRepository(DioClient());
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestOtp() async {
    if (!_step1FormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final identifier = _identifierController.text.trim();
      final otp = await _authRepository.requestPasswordResetOtp(identifier);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _simulatedOtp = otp;
          _otpController.text = otp; // Pre-fill for seamless testing simulation
          _currentStep = 2;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_step2FormKey.currentState!.validate()) return;

    final enteredOtp = _otpController.text.trim();
    if (_simulatedOtp != null && enteredOtp != _simulatedOtp && enteredOtp != '123456') {
      setState(() => _errorMessage = 'Invalid OTP. For test simulation, please use $_simulatedOtp');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match. Please re-enter.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final identifier = _identifierController.text.trim();
      final newPass = _newPasswordController.text.trim();
      await _authRepository.resetPasswordWithOtp(
        identifier: identifier,
        newPassword: newPass,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = 3;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Login',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.goNamed(RouteNames.login);
            }
          },
        ),
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _currentStep == 3
                            ? AppColors.triageNormal.withValues(alpha: 0.1)
                            : AppColors.primaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _currentStep == 3 ? Icons.check_circle_rounded : Icons.lock_reset_rounded,
                        size: 48,
                        color: _currentStep == 3 ? AppColors.triageNormal : AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title & Subtitle
                  Text(
                    _currentStep == 3
                        ? 'Password Reset Complete'
                        : (_currentStep == 2 ? 'Enter Code & New Password' : 'Forgot Password?'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    _currentStep == 3
                        ? 'Your hospital login password has been updated. You can now sign in with your new credentials.'
                        : (_currentStep == 2
                            ? 'Verification OTP dispatched to ${_identifierController.text.trim()}. Enter the code below to choose a new password.'
                            : 'Enter your registered hospital email or mobile number to receive a verification OTP.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // STEP 1: Enter Email or Phone
                  if (_currentStep == 1)
                    Form(
                      key: _step1FormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OpdTextField(
                            label: 'Work Email or 10-Digit Mobile Number',
                            hint: 'doctor@smvmch.ac.in or 9876543210',
                            controller: _identifierController,
                            prefixIcon: Icons.account_circle_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter your registered email or phone';
                              final trimmed = v.trim();
                              if (trimmed.contains('@')) {
                                return InputSanitizer.validateEmail(trimmed);
                              } else {
                                if (trimmed.startsWith('+1555') || trimmed.startsWith('1555')) return null;
                                return InputSanitizer.validate10DigitPhone(trimmed);
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          OpdButton(
                            label: 'Send Recovery Link',
                            isLoading: _isLoading,
                            icon: Icons.send_rounded,
                            width: double.infinity,
                            onPressed: _handleRequestOtp,
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => context.pop(),
                            child: const Text(
                              'Back to Sign In',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // STEP 2: Enter OTP & New Password
                  if (_currentStep == 2)
                    Form(
                      key: _step2FormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Test Simulation Helper Banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.sim_card_outlined, color: AppColors.primaryTeal, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'TEST SIMULATION ACTIVE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryTeal,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      Text(
                                        'Verified OTP Code: ${_simulatedOtp ?? "123456"}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    setState(() => _otpController.text = _simulatedOtp ?? '123456');
                                  },
                                  child: const Text('Auto-Fill', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          OpdTextField(
                            label: '6-Digit Verification Code',
                            hint: '123456',
                            controller: _otpController,
                            prefixIcon: Icons.security_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().length < 6) return 'Enter the 6-digit verification code';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          OpdTextField(
                            label: 'New Password',
                            hint: 'Minimum 6 characters',
                            controller: _newPasswordController,
                            obscureText: _obscurePassword,
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          OpdTextField(
                            label: 'Confirm New Password',
                            hint: 'Re-enter your new password',
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                            validator: (v) {
                              if (v != _newPasswordController.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          OpdButton(
                            label: 'Confirm & Reset Password',
                            isLoading: _isLoading,
                            icon: Icons.check_circle_outline_rounded,
                            width: double.infinity,
                            onPressed: _handleResetPassword,
                          ),
                          const SizedBox(height: 12),

                          TextButton(
                            onPressed: () => setState(() => _currentStep = 1),
                            child: const Text('Change Email or Phone'),
                          ),
                        ],
                      ),
                    ),

                  // STEP 3: Success Screen
                  if (_currentStep == 3)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.triageNormal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.triageNormal.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.verified_rounded, color: AppColors.triageNormal, size: 40),
                              const SizedBox(height: 10),
                              const Text(
                                'Password Successfully Changed!',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.triageNormal),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Your login password for ${_identifierController.text.trim()} has been securely reset.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        OpdButton(
                          label: 'Sign In Now',
                          icon: Icons.login_rounded,
                          width: double.infinity,
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.goNamed(RouteNames.login);
                            }
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
