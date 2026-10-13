import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/opd_text_field.dart';
import '../repositories/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  late final AuthRepository _authRepository;
  bool _isLoading = false;
  bool _isSent = false;
  String? _serverMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authRepository = AuthRepository(DioClient());
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final identifier = _emailController.text.trim();
      final message = await _authRepository.forgotPassword(identifier);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSent = true;
          _serverMessage = message;
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
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          size: 48,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Forgot Password?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Enter your verified hospital work or patient email address. We will verify and process your secure recovery request.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (_errorMessage != null && !_isSent)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),

                    if (_isSent) ...[
                      // Success Confirmation Banner
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.triageNormal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.triageNormal.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.mark_email_read_rounded, color: AppColors.triageNormal, size: 36),
                            const SizedBox(height: 12),
                            const Text(
                              'Recovery Dispatched!',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.triageNormal),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _serverMessage ??
                                  'A recovery token has been processed for ${_emailController.text.trim()}. Please check your communication channel to reset your password.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      OpdButton(
                        label: 'Return to Sign In',
                        width: double.infinity,
                        onPressed: () => context.pop(),
                      ),
                    ] else ...[
                      // Input Form
                      OpdTextField(
                        label: 'Work or Patient Email / Phone',
                        hint: 'name@opdconnect.com or phone',
                        controller: _emailController,
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your registered email or phone' : null,
                      ),
                      const SizedBox(height: 28),

                      OpdButton(
                        label: 'Send Recovery Link',
                        isLoading: _isLoading,
                        icon: Icons.send_rounded,
                        width: double.infinity,
                        onPressed: _handleReset,
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
