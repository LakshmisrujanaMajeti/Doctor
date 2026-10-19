import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
export 'route_names.dart';

import '../features/auth/models/auth_state.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/profile_setup_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/welcome_screen.dart';
import '../features/clinical_records/screens/consultation_sheet_screen.dart';
import '../features/dashboard/screens/role_dashboard_shell.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/patients/models/patient_model.dart';
import '../features/patients/screens/patient_list_screen.dart';
import '../features/patients/screens/patient_registration_screen.dart';
import '../features/prescriptions/screens/prescription_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/visits/models/visit_model.dart';
import '../features/visits/screens/new_visit_screen.dart';
import '../features/visits/screens/opd_queue_screen.dart';
import '../features/visits/screens/record_vitals_screen.dart';
import '../features/visits/screens/visit_detail_screen.dart';
import '../features/laboratory/screens/laboratory_report_screen.dart';
import '../features/laboratory/screens/laboratory_workspace_view.dart';
import '../features/pharmacy/screens/pharmacy_workspace_view.dart';
import '../features/billing/screens/billing_workspace_view.dart';
import '../features/billing/screens/printable_invoice_screen.dart';
import '../features/documents/screens/document_manager_workspace_view.dart';
import '../features/documents/screens/document_capture_screen.dart';
import '../features/documents/screens/document_ocr_verification_screen.dart';
import '../features/patient_portal/screens/patient_portal_workspace_view.dart';
import '../features/admin_portal/screens/hospital_admin_workspace_view.dart';
import '../features/auth/screens/patient_token_access_screen.dart';
import '../features/patients/screens/digital_opd_booklet_screen.dart';
import '../routing/route_names.dart';
import '../shared/screens/empty_screen.dart';
import '../shared/screens/loading_screen.dart';
import '../shared/screens/not_found_screen.dart';
import '../shared/widgets/smvmch_hospital_logo.dart';
import '../shared/screens/offline_screen.dart';
import '../shared/screens/unauthorized_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuth = authState.isAuthenticated;
      final path = state.matchedLocation;

      // 1. NEVER redirect /splash! Splash screen must always display for 5s with app icon
      if (path == '/splash') {
        return null;
      }

      // 2. Allow user on /login to stay on /login to sign in or switch accounts
      if (path == '/login') {
        return null;
      }

      // 3. Prevent authenticated users from returning to welcome / onboarding
      if (isAuth && (path == '/welcome' || path == '/onboarding')) {
        return '/dashboard';
      }

      // 4. Allow public / system utility routes without authentication
      const publicRoutes = [
        '/splash',
        '/onboarding',
        '/welcome',
        '/login',
        '/forgot-password',
        '/profile-setup',
        '/patient/token-access',
        '/queue',
        '/loading',
        '/offline',
        '/unauthorized',
        '/empty',
        '/404',
      ];

      final isPublic = publicRoutes.contains(path) ||
          (path.startsWith('/patients/') && path.endsWith('/booklet'));
      if (!isAuth && !isPublic) {
        return '/login';
      }

      // 5. RBAC Route Access Enforcement for Authenticated Users
      if (isAuth) {
        final role = authState.user?.roleName.toLowerCase() ?? 'patient';

        // Patients: View-only access to their portal, token, visits, booklet, invoices
        if (role == 'patient') {
          final isAllowedForPatient = path == '/dashboard' ||
              path == '/patient/portal' ||
              path == '/queue' ||
              path == '/notifications' ||
              path == '/settings' ||
              (path.startsWith('/patients/') && path.endsWith('/booklet')) ||
              (path.startsWith('/visits/') && !path.contains('/consultation') && !path.contains('/vitals')) ||
              path.startsWith('/billing/invoice/') ||
              path == '/unauthorized';

          if (!isAllowedForPatient) {
            return '/patient/portal';
          }
        }

        // Doctors: Clinical Sheet & Prescriptions, restricted from Admin, Billing & Pharmacy
        if (role == 'doctor') {
          if (path.startsWith('/admin') || path == '/billing' || path == '/pharmacy') {
            return '/unauthorized';
          }
        }

        // Nurses: Triage & Vitals assessment, restricted from Admin, Diagnosis Consultation, Billing, Pharmacy, Lab
        if (role == 'nurse') {
          if (path.startsWith('/admin') ||
              path.contains('/consultation') ||
              path == '/billing' ||
              path == '/pharmacy' ||
              path == '/laboratory') {
            return '/unauthorized';
          }
        }

        // Receptionists: Front desk registration & token issuance, restricted from Clinical, Lab, Billing, Pharmacy, Admin
        if (role == 'receptionist') {
          if (path.startsWith('/admin') ||
              path.contains('/consultation') ||
              path.contains('/vitals') ||
              path == '/billing' ||
              path == '/pharmacy' ||
              path == '/laboratory') {
            return '/unauthorized';
          }
        }

        // Pharmacists: Pharmacy dispensing & formulary, restricted from Clinical editing, Intake, Billing, Lab, Admin
        if (role == 'pharmacist') {
          if (path.startsWith('/admin') ||
              path.contains('/consultation') ||
              path.contains('/vitals') ||
              path == '/patients/new' ||
              path == '/visits/new' ||
              path == '/billing' ||
              path == '/laboratory') {
            return '/unauthorized';
          }
        }

        // Laboratory Technicians: Diagnostics & report entry, restricted from Clinical notes, Registration, Billing, Pharmacy, Admin
        if (role == 'laboratory' || role == 'lab_tech') {
          if (path.startsWith('/admin') ||
              path.contains('/consultation') ||
              path.contains('/vitals') ||
              path == '/patients/new' ||
              path == '/visits/new' ||
              path == '/billing' ||
              path == '/pharmacy') {
            return '/unauthorized';
          }
        }

        // Billing Cashiers: Fee collection & invoices, restricted from Clinical sheets, Vitals, Intake, Pharmacy, Lab, Admin
        if (role == 'billing') {
          if (path.startsWith('/admin') ||
              path.contains('/consultation') ||
              path.contains('/vitals') ||
              path == '/patients/new' ||
              path == '/visits/new' ||
              path == '/pharmacy' ||
              path == '/laboratory') {
            return '/unauthorized';
          }
        }
      }

      return null;
    },
    errorBuilder: (context, state) => NotFoundScreen(path: state.uri.path),
    routes: [
      GoRoute(
        name: RouteNames.splash,
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        name: RouteNames.onboarding,
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        name: RouteNames.welcome,
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        name: RouteNames.login,
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        name: RouteNames.forgotPassword,
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        name: RouteNames.profileSetup,
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),

      // Core Role-Aware Dashboard Shell
      GoRoute(
        name: RouteNames.dashboard,
        path: '/dashboard',
        builder: (context, state) => const RoleDashboardShell(),
      ),

      // Hospital Alerts & Notifications
      GoRoute(
        name: RouteNames.notifications,
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // Profile & Settings
      GoRoute(
        name: RouteNames.settings,
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      // Patients Management
      GoRoute(
        name: RouteNames.patients,
        path: '/patients',
        builder: (context, state) => const PatientListScreen(),
        routes: [
          GoRoute(
            name: RouteNames.newPatient,
            path: 'new',
            builder: (context, state) => const PatientRegistrationScreen(),
          ),
          GoRoute(
            name: RouteNames.digitalOpdBooklet,
            path: ':id/booklet',
            builder: (context, state) {
              final patientId = state.pathParameters['id'] ?? '';
              return DigitalOpdBookletScreen(patientId: patientId);
            },
          ),
        ],
      ),
      GoRoute(
        name: RouteNames.patientTokenAccess,
        path: '/patient/token-access',
        builder: (context, state) => const PatientTokenAccessScreen(),
      ),

      // OPD Token Queue
      GoRoute(
        name: RouteNames.queue,
        path: '/queue',
        builder: (context, state) => const OpdQueueScreen(),
      ),

      // Visits & Clinical Sheet Workflows
      GoRoute(
        name: RouteNames.newVisit,
        path: '/visits/new',
        builder: (context, state) {
          final patient = state.extra as PatientModel?;
          return NewVisitScreen(initialPatient: patient);
        },
      ),
      GoRoute(
        name: RouteNames.visitDetail,
        path: '/visits/:id',
        builder: (context, state) {
          final visitId = state.pathParameters['id'] ?? '';
          final visit = state.extra as OPDVisitModel?;
          return VisitDetailScreen(visitId: visitId, visit: visit);
        },
      ),
      GoRoute(
        name: RouteNames.recordVitals,
        path: '/visits/:id/vitals',
        builder: (context, state) {
          final visitId = state.pathParameters['id'] ?? '';
          final visit = state.extra as OPDVisitModel?;
          return RecordVitalsScreen(visitId: visitId, visit: visit);
        },
      ),
      GoRoute(
        name: RouteNames.consultation,
        path: '/visits/:id/consultation',
        builder: (context, state) {
          final visitId = state.pathParameters['id'] ?? '';
          final visit = state.extra as OPDVisitModel?;
          return ConsultationSheetScreen(visitId: visitId, visit: visit);
        },
      ),
      GoRoute(
        name: RouteNames.prescriptions,
        path: '/visits/:id/prescriptions',
        builder: (context, state) {
          final visitId = state.pathParameters['id'] ?? '';
          final visit = state.extra as OPDVisitModel?;
          return PrescriptionScreen(visitId: visitId, visit: visit);
        },
      ),
      GoRoute(
        name: RouteNames.labReport,
        path: '/laboratory/report/:id',
        builder: (context, state) {
          final orderId = state.pathParameters['id'] ?? '';
          return LaboratoryReportScreen(orderId: orderId);
        },
      ),
      GoRoute(
        name: RouteNames.laboratory,
        path: '/laboratory',
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to Dashboard',
              onPressed: () {
                if (Navigator.canPop(context)) {
                  context.pop();
                } else {
                  context.goNamed(RouteNames.dashboard);
                }
              },
            ),
            title: const Row(
              children: [
                SmvmchHospitalLogo(size: 26),
                SizedBox(width: 8),
                Text('Diagnostic Laboratory Desk'),
              ],
            ),
          ),
          body: const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: LaboratoryWorkspaceView(),
          ),
        ),
      ),
      GoRoute(
        name: RouteNames.pharmacy,
        path: '/pharmacy',
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to Dashboard',
              onPressed: () {
                if (Navigator.canPop(context)) {
                  context.pop();
                } else {
                  context.goNamed(RouteNames.dashboard);
                }
              },
            ),
            title: const Row(
              children: [
                SmvmchHospitalLogo(size: 26),
                SizedBox(width: 8),
                Text('Pharmacy Inventory & Dispensing'),
              ],
            ),
          ),
          body: const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: PharmacyWorkspaceView(),
          ),
        ),
      ),
      GoRoute(
        name: RouteNames.billing,
        path: '/billing',
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to Dashboard',
              onPressed: () {
                if (Navigator.canPop(context)) {
                  context.pop();
                } else {
                  context.goNamed(RouteNames.dashboard);
                }
              },
            ),
            title: const Row(
              children: [
                SmvmchHospitalLogo(size: 26),
                SizedBox(width: 8),
                Text('OPD Billing & Payments Counter'),
              ],
            ),
          ),
          body: const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: BillingWorkspaceView(),
          ),
        ),
      ),
      GoRoute(
        name: RouteNames.billingInvoice,
        path: '/billing/invoice/:id',
        builder: (context, state) {
          final billId = state.pathParameters['id'] ?? '';
          return PrintableInvoiceScreen(billId: billId);
        },
      ),
      GoRoute(
        name: RouteNames.documents,
        path: '/documents',
        builder: (context, state) => const DocumentManagerWorkspaceView(),
      ),
      GoRoute(
        name: RouteNames.documentCapture,
        path: '/documents/capture',
        builder: (context, state) => const DocumentCaptureScreen(),
      ),
      GoRoute(
        name: RouteNames.documentOcr,
        path: '/documents/verify/:id',
        builder: (context, state) {
          final docId = state.pathParameters['id'] ?? '';
          return DocumentOcrVerificationScreen(documentId: docId);
        },
      ),
      GoRoute(
        name: RouteNames.patientPortal,
        path: '/patient/portal',
        builder: (context, state) => const PatientPortalWorkspaceView(),
      ),
      GoRoute(
        name: RouteNames.adminPortal,
        path: '/admin/portal',
        builder: (context, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return HospitalAdminWorkspaceView(initialTabIndex: tab);
        },
      ),

      // Reusable System State Screens
      GoRoute(
        name: RouteNames.loading,
        path: '/loading',
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(
        name: RouteNames.offline,
        path: '/offline',
        builder: (context, state) => const OfflineScreen(),
      ),
      GoRoute(
        name: RouteNames.unauthorized,
        path: '/unauthorized',
        builder: (context, state) => const UnauthorizedScreen(),
      ),
      GoRoute(
        path: '/empty',
        builder: (context, state) => const EmptyScreen(),
      ),
      GoRoute(
        name: RouteNames.notFound,
        path: '/404',
        builder: (context, state) => const NotFoundScreen(),
      ),
    ],
  );
});
