import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../routing/route_names.dart';
import '../../../shared/widgets/smvmch_hospital_logo.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();

    // Exactly 2-second splash screen presentation before directing to the Login portal
    _timer = Timer(const Duration(seconds: 2), _handleNavigation);
  }

  Future<void> _handleNavigation() async {
    if (!mounted) return;
    try {
      // Always direct user to Login page first; clear any stale session so access requires explicit sign-in
      await ref.read(authProvider.notifier).logout();
    } catch (_) {}
    if (mounted && GoRouter.maybeOf(context) != null) {
      context.goNamed(RouteNames.login);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleNavigation,
        child: SafeArea(
          child: Center(
            child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Official Hospital Logo
                    const SmvmchHospitalLogo(size: 130),
                    const SizedBox(height: 24),

                    // Official Hospital Title
                    const Text(
                      'SRI MANAKULA VINAYAGAR\nMEDICAL COLLEGE & HOSPITAL',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.hospitalMaroon,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // App Name
                    const Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Tamil Title & Subtitle
                    Text(
                      'ஸ்ரீ மணக்குள விநாயகர் மருத்துவக் கல்லூரி மற்றும் மருத்துவமனை',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Tagline
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primaryTeal.withOpacity(0.3)),
                      ),
                      child: const Text(
                        AppStrings.tagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // 5-Second Linear Progress Loader
                    SizedBox(
                      width: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(
                          minHeight: 4,
                          backgroundColor: Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryTeal),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Kalitheerthalkuppam, Puducherry - 605 107',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                    ),
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
}
