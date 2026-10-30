import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/field_validators.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/medical_illustrator_background.dart';
import '../../../shared/widgets/server_config_dialog.dart';
import '../../../core/utils/file_download_helper.dart';
import '../../patients/models/patient_model.dart';
import '../../patients/widgets/patient_identifier_card_widget.dart';
import '../models/patient_portal_models.dart';
import '../providers/patient_portal_provider.dart';
import '../../patients/providers/patient_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../routing/route_names.dart';

class PatientPortalWorkspaceView extends ConsumerStatefulWidget {
  const PatientPortalWorkspaceView({super.key});

  @override
  ConsumerState<PatientPortalWorkspaceView> createState() => _PatientPortalWorkspaceViewState();
}

class _PortalModuleItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _PortalModuleItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _PatientPortalWorkspaceViewState extends ConsumerState<PatientPortalWorkspaceView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<_PortalModuleItem> _portalModules = [
    _PortalModuleItem(
      title: 'Patient ID Card',
      subtitle: 'Digital UHID & Barcode Identification',
      icon: Icons.badge_rounded,
      color: AppColors.primaryBlue,
    ),
    _PortalModuleItem(
      title: 'Appointments',
      subtitle: 'Consultation Reviews & Slot Booking',
      icon: Icons.calendar_month_rounded,
      color: AppColors.accentTeal,
    ),
    _PortalModuleItem(
      title: 'Prescriptions',
      subtitle: 'Medication Orders & Doctor Rx',
      icon: Icons.medication_rounded,
      color: AppColors.hospitalMaroon,
    ),
    _PortalModuleItem(
      title: 'Lab Reports',
      subtitle: 'Diagnostic Investigations & Results',
      icon: Icons.biotech_rounded,
      color: Color(0xFF0284C7),
    ),
    _PortalModuleItem(
      title: 'Medical Documents',
      subtitle: 'Clinical Records & Scans',
      icon: Icons.folder_shared_rounded,
      color: Color(0xFFD97706),
    ),
    _PortalModuleItem(
      title: 'Bills & Receipts',
      subtitle: 'OPD Invoices & Payment Slips',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFF059669),
    ),
    _PortalModuleItem(
      title: 'Visit History',
      subtitle: 'Past Hospital Visits & Timeline',
      icon: Icons.timeline_rounded,
      color: Color(0xFF7C3AED),
    ),
    _PortalModuleItem(
      title: 'Support & Inquiries',
      subtitle: 'Hospital Desk Inquiries & Assistance',
      icon: Icons.contact_support_rounded,
      color: Color(0xFFE11D48),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _tabController.addListener(_onTabChanged);
    Future.microtask(() {
      if (mounted) {
        ref.invalidate(patientProfileProvider);
      }
    });
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _downloadBooklet(BuildContext context, String regId) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Downloading verified digital OPD booklet PDF...')),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );
    try {
      final bytes = await ref.read(patientRepositoryProvider).downloadBookletByRegId(regId);
      final filename = 'SMVMCH_OPD_Booklet_$regId.pdf';
      await downloadFileBytes(bytes, filename);
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verified PDF "$filename" saved successfully! (${bytes.length} bytes)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Hospital server offline or unreachable on this network.'),
            backgroundColor: AppColors.hospitalMaroon,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Server IP',
              textColor: Colors.yellowAccent,
              onPressed: () => ServerConfigDialog.show(context),
            ),
          ),
        );
      }
    }
  }

  void _showBookAppointmentSlotDialog(BuildContext context) {
    DateTime selectedDate = DateTime.now();
    String selectedDept = 'General Medicine';
    String selectedSlot = '10:00 AM - 10:30 AM';
    final complaintCtrl = TextEditingController();
    bool isBooking = false;

    final departments = [
      'General Medicine',
      'Dental Surgery',
      'Pediatrics',
      'Cardiology',
      'Orthopedics',
      'Ophthalmology',
    ];

    final timeSlots = [
      '09:00 AM - 09:30 AM',
      '09:30 AM - 10:00 AM',
      '10:00 AM - 10:30 AM',
      '10:30 AM - 11:00 AM',
      '11:00 AM - 11:30 AM',
      '11:30 AM - 12:00 PM',
      '02:00 PM - 02:30 PM',
      '02:30 PM - 03:00 PM',
      '03:00 PM - 03:30 PM',
      '03:30 PM - 04:00 PM',
      '04:00 PM - 04:30 PM',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final dateStr = '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}';
            final isoDate = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: AppColors.primaryBlue),
                  SizedBox(width: 8),
                  Text('Book Consultation Slot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Calendar Date Selection
                    const Text('Select Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primaryBlue),
                                const SizedBox(width: 8),
                                Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              ],
                            ),
                            const Text('Change Date', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Department Selection
                    const Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedDept,
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedDept = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // 3. Time Slot Choice
                    const Text('Available Time Slots', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: timeSlots.map((slot) {
                        final isSelected = selectedSlot == slot;
                        return ChoiceChip(
                          label: Text(slot, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          selected: isSelected,
                          selectedColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => selectedSlot = slot);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // 4. Chief Complaint
                    const Text('Chief Complaint / Reason (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: complaintCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Tooth ache, Fever, Routine check-up',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isBooking ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
                  onPressed: isBooking
                      ? null
                      : () async {
                          setDialogState(() => isBooking = true);
                          try {
                            final selectedPatientId = ref.read(selectedPortalPatientIdProvider);
                            final profile = ref.read(patientProfileProvider).asData?.value;
                            final effectivePatientId = selectedPatientId ?? profile?.patient.id;
                            final repo = ref.read(patientPortalRepositoryProvider);
                            final idempotencyKey =
                                'book_${effectivePatientId ?? 'portal'}_${isoDate}_${selectedSlot.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';

                            final result = await repo.bookAppointmentSlot(
                              patientId: effectivePatientId,
                              departmentId: selectedDept,
                              slotDate: isoDate,
                              slotTime: selectedSlot,
                              chiefComplaint: complaintCtrl.text.trim().isEmpty ? null : complaintCtrl.text.trim(),
                              idempotencyKey: idempotencyKey,
                            );

                            ref.invalidate(patientAppointmentsProvider);
                            ref.invalidate(patientProfileProvider);

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (context.mounted) {
                              final tokenDisp = result['token_display'] ?? '#${result['queue_token'] ?? 1}';
                              final isDup = result['is_duplicate'] == true;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isDup
                                      ? 'Appointment already confirmed for $dateStr at $selectedSlot! Active Token: $tokenDisp.'
                                      : 'Appointment booked for $dateStr at $selectedSlot! Token: $tokenDisp generated.'),
                                  backgroundColor: isDup ? Colors.blue.shade700 : Colors.green.shade700,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Booking failed: $e'), backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            if (ctx.mounted) {
                              setDialogState(() => isBooking = false);
                            }
                          }
                        },
                  child: isBooking
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            SizedBox(width: 8),
                            Text('Booking Slot...'),
                          ],
                        )
                      : const Text('Confirm & Book Slot'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(patientProfileProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.goNamed(RouteNames.dashboard);
            }
          },
        ),
        title: const Text('Patient Portal & Health Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Modules Menu Bar',
            onPressed: () => _openModulesMenu(context, isDark),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Records',
            onPressed: () {
              ref.invalidate(patientProfileProvider);
              ref.invalidate(patientAppointmentsProvider);
              ref.invalidate(patientPrescriptionsProvider);
              ref.invalidate(patientLabReportsProvider);
              ref.invalidate(patientBillsProvider);
              ref.invalidate(patientDocumentsProvider);
              ref.invalidate(patientVisitsProvider);
              ref.invalidate(patientSupportTicketsProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 21),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.goNamed(RouteNames.welcome);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: MedicalIllustratorBackground(
        variant: MedicalBackgroundVariant.portal,
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Unable to load patient profile: $err'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.refresh(patientProfileProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (profile) {
            final patient = profile.patient;
            final dependents = profile.dependents;

            return Column(
              children: [
                // 1. Patient Profile Header & Dependent Profile Switcher
                _buildProfileHeader(patient, dependents, profile, isDark),

                // 2. Interactive Menu Bar Navigation
                _buildMenuBar(context, isDark),

                // 3. Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildIdCardTab(patient, dependents, isDark),
                      _buildAppointmentsTab(isDark),
                      _buildPrescriptionsTab(isDark),
                      _buildLabReportsTab(isDark),
                      _buildDocumentsTab(isDark),
                      _buildBillsTab(isDark),
                      _buildVisitsTab(isDark),
                      _buildSupportTab(isDark),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _formatPortalDateTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day.toString().padLeft(2, '0')} ${months[local.month - 1]} ${local.year}, $hour:$minute $ampm';
  }

  Widget _buildProfileHeader(
    dynamic patient,
    List<DependentProfile> dependents,
    PatientPortalProfile profile,
    bool isDark,
  ) {
    final selectedId = ref.watch(selectedPortalPatientIdProvider);
    final isViewingDependent = selectedId != null && selectedId != patient.id && dependents.isNotEmpty;
    final activeDependent = isViewingDependent
        ? dependents.firstWhere((d) => d.id == selectedId, orElse: () => dependents.first)
        : null;

    final displayName = (isViewingDependent && activeDependent != null) ? activeDependent.fullName : patient.fullName;
    final displayUhid = (isViewingDependent && activeDependent != null) ? activeDependent.uhid : patient.uhid;
    final displayAge = (isViewingDependent && activeDependent != null)
        ? activeDependent.ageDisplay
        : (patient.ageYears != null ? '${patient.ageYears} Y' : 'N/A');
    final displayGender = (isViewingDependent && activeDependent != null) ? activeDependent.gender : patient.gender;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final tokenWidget = profile.hasActiveToken
                  ? Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFEF3C7),
                        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'TOKEN',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          Text(
                            (profile.activeTokenNumber ?? '').startsWith('#')
                                ? (profile.activeTokenNumber ?? '')
                                : '#${profile.activeTokenNumber ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Color(0xFF92400E),
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    )
                  : null;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isViewingDependent ? AppColors.accentTeal : AppColors.primaryBlue,
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P',
                      style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                                    softWrap: true,
                                  ),
                                  if (isViewingDependent && activeDependent != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentTeal.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '(${activeDependent.relation})',
                                        style: const TextStyle(fontSize: 10, color: AppColors.accentTeal, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (tokenWidget != null) ...[
                              const SizedBox(width: 6),
                              tokenWidget,
                            ] else if (profile.activeTokenQueueStatus?.toLowerCase().contains('complete') == true) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  border: Border.all(color: const Color(0xFF16A34A), width: 1.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF15803D)),
                                    SizedBox(height: 2),
                                    Text(
                                      'Consultation\nCompleted',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF15803D),
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'UHID: $displayUhid • Age: $displayAge • Gender: $displayGender',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          softWrap: true,
                        ),
                        Text(
                          'Phone: ${patient.phone}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        if (patient.registrationDate != null || patient.createdAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Registered: ${_formatPortalDateTime(patient.registrationDate ?? patient.createdAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey.shade300 : const Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (patient.registeredByStaffName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Staff: ${patient.registeredByStaffName}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        // Sleek Compact Action Row
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.badge_rounded, size: 14, color: AppColors.primaryBlue),
                              label: const Text('ID Card', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
                              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.08),
                              side: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _tabController.animateTo(0),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.download_rounded, size: 14, color: AppColors.hospitalMaroon),
                              label: const Text('PDF Booklet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.hospitalMaroon)),
                              backgroundColor: AppColors.hospitalMaroon.withValues(alpha: 0.08),
                              side: BorderSide(color: AppColors.hospitalMaroon.withValues(alpha: 0.3)),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _downloadBooklet(context, displayUhid),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.auto_stories_rounded, size: 14, color: AppColors.hospitalMaroon),
                              label: const Text('7-Page Booklet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.hospitalMaroon)),
                              backgroundColor: AppColors.hospitalMaroon.withValues(alpha: 0.08),
                              side: BorderSide(color: AppColors.hospitalMaroon.withValues(alpha: 0.3)),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                context.pushNamed(
                                  RouteNames.digitalOpdBooklet,
                                  pathParameters: {'registrationId': displayUhid},
                                );
                              },
                            ),
                          ],
                        ),
                        if (profile.activeTokenQueueStatus?.toLowerCase().contains('complete') == true) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_rounded, color: Color(0xFF15803D), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Consultation Completed',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                      Text(
                                        'Doctor consultation concluded. Prescriptions & receipts are available below.',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isDark ? Colors.grey.shade300 : const Color(0xFF166534),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          // Profile Switcher Bar (only shown if patient has dependents)
          if (dependents.isNotEmpty) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  const Text('Active Profile: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Self (${patient.fullName})', style: const TextStyle(fontSize: 12)),
                    selected: selectedId == null || selectedId == patient.id,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(selectedPortalPatientIdProvider.notifier).state = patient.id;
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  for (final dep in dependents) ...[
                    ChoiceChip(
                      label: Text('${dep.fullName} (${dep.relation})', style: const TextStyle(fontSize: 12)),
                      selected: selectedId == dep.id,
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(selectedPortalPatientIdProvider.notifier).state = dep.id;
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIdCardTab(PatientModel patient, List<DependentProfile> dependents, bool isDark) {
    final selectedId = ref.watch(selectedPortalPatientIdProvider);
    final isViewingDependent = selectedId != null && selectedId != patient.id && dependents.isNotEmpty;
    final activeDependent = isViewingDependent
        ? dependents.firstWhere((d) => d.id == selectedId, orElse: () => dependents.first)
        : null;

    final targetPatient = (isViewingDependent && activeDependent != null)
        ? PatientModel(
            id: activeDependent.id,
            uhid: activeDependent.uhid,
            fullName: activeDependent.fullName,
            gender: activeDependent.gender,
            phone: patient.phone,
            bloodGroup: activeDependent.bloodGroup ?? patient.bloodGroup,
            registrationDate: DateTime.tryParse(activeDependent.registrationDate),
          )
        : patient;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: PatientIdentifierCardWidget(
            patient: targetPatient,
            onDownloadBooklet: () => _downloadBooklet(context, targetPatient.uhid),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuBar(BuildContext context, bool isDark) {
    final currentIndex = _tabController.index.clamp(0, _portalModules.length - 1);
    final currentModule = _portalModules[currentIndex];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Menu Bar button
          Material(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openModulesMenu(context, isDark),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_rounded, size: 17, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Menu Bar',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Active Module Dropdown Trigger
          Expanded(
            child: Material(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openModulesMenu(context, isDark),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        currentModule.icon,
                        size: 16,
                        color: currentModule.color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentModule.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.grey.shade900,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${currentIndex + 1}/8',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openModulesMenu(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.apps_rounded, color: AppColors.primaryBlue, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient Portal Menu Bar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.grey.shade900,
                            ),
                          ),
                          Text(
                            'Select any module to access your clinical records',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _portalModules.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, idx) {
                      final item = _portalModules[idx];
                      final isSelected = _tabController.index == idx;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          Navigator.pop(ctx);
                          _tabController.animateTo(idx);
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                    ? AppColors.primaryBlue.withValues(alpha: 0.25)
                                    : AppColors.primaryBlue.withValues(alpha: 0.08))
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryBlue
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: item.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(item.icon, size: 20, color: item.color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected
                                            ? AppColors.primaryBlue
                                            : (isDark ? Colors.white : Colors.grey.shade900),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.subtitle,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 20)
                              else
                                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppointmentsTab(bool isDark) {
    final apptsAsync = ref.watch(patientAppointmentsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Consultations & Reviews',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: const Text('Book Appointment Slot'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _showBookAppointmentSlotDialog(context),
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Consultations & Reviews',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey.shade900,
                    ),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: const Text('Book Appointment Slot'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showBookAppointmentSlotDialog(context),
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: apptsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading appointments: $e')),
            data: (appts) {
              if (appts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const EmptyStateWidget(
                        title: 'No Upcoming Appointments',
                        message: 'You have no scheduled doctor reviews. Book a slot using the interactive calendar.',
                        icon: Icons.event_available,
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: const Text('Book Consultation Slot'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _showBookAppointmentSlotDialog(context),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: appts.length,
                itemBuilder: (context, idx) {
                  final a = appts[idx];
                  return Card(
                    elevation: 1.5,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                    ),
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                            ),
                            child: const Icon(Icons.calendar_today_rounded, color: AppColors.primaryBlue, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Scheduled Review: ${a.scheduledDate}',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: a.isCompleted ? Colors.blue.shade50 : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: a.isCompleted ? Colors.blue.shade400 : Colors.green.shade400,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        a.isCompleted ? 'Completed' : 'Upcoming Follow-up',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: a.isCompleted ? Colors.blue.shade800 : Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Clinician: ${a.doctorName} • ${a.departmentName}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey.shade200 : Colors.grey.shade900,
                                  ),
                                  softWrap: true,
                                ),
                                if (a.followUpReason != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Reason: ${a.followUpReason}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                    softWrap: true,
                                  ),
                                ],
                                if (a.carePlan != null) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      'Doctor\'s Advice: ${a.carePlan}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                                      ),
                                      softWrap: true,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
],
);
}

  Widget _buildPrescriptionsTab(bool isDark) {
    final rxAsync = ref.watch(patientPrescriptionsProvider);

    return rxAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading prescriptions: $e')),
      data: (prescriptions) {
        if (prescriptions.isEmpty) {
          return const EmptyStateWidget(
            title: 'No Prescriptions Found',
            message: 'Your clinician has not issued any active prescription orders for this profile.',
            icon: Icons.medication_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: prescriptions.length,
          itemBuilder: (context, idx) {
            final rx = prescriptions[idx];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Prescription signed by ${rx.doctorName}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          softWrap: true,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Clinician Approved • ${rx.status}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Clinic: ${rx.departmentName} • Signed: ${rx.signedAt ?? "Approved"}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      softWrap: true,
                    ),
                    const Divider(height: 20),
                    const Text('Prescribed Medications & Instructions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    for (final item in rx.items) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.medication, size: 20, color: AppColors.primaryBlue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.medicineName} (${item.form} ${item.dosage})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    softWrap: true,
                                  ),
                                  Text(
                                    'Dosage: ${item.frequency} for ${item.durationDays} days • Route: ${item.route} • Qty: ${item.quantity}',
                                    style: const TextStyle(fontSize: 12),
                                    softWrap: true,
                                  ),
                                  if (item.timing != null || item.instructions != null) ...[
                                    Text(
                                      'Instructions: ${item.timing ?? ""} ${item.instructions ?? ""}'.trim(),
                                      style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                                      softWrap: true,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLabReportsTab(bool isDark) {
    final labAsync = ref.watch(patientLabReportsProvider);

    return labAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading lab reports: $e')),
      data: (reports) {
        if (reports.isEmpty) {
          return const EmptyStateWidget(
            title: 'No Laboratory Reports',
            message: 'Diagnostic test reports will appear here once verified and released by clinical pathology.',
            icon: Icons.biotech_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, idx) {
            final r = reports[idx];
            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                leading: const Icon(Icons.biotech, color: AppColors.primaryBlue),
                title: Text(r.testName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), softWrap: true),
                subtitle: Text('Category: ${r.testCategory} • Released: ${r.completedAt ?? r.orderedAt}', softWrap: true),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Text(r.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Test Parameters & Results:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        if (r.results.isEmpty)
                          const Text('Test completed and verified by clinical pathologist.', softWrap: true)
                        else
                          for (final res in r.results) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(res.parameterName, style: const TextStyle(fontSize: 13), softWrap: true)),
                                Text(
                                  '${res.resultValue} ${res.unit ?? ""}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: res.isAbnormal ? Colors.red : null,
                                  ),
                                ),
                              ],
                            ),
                            if (res.referenceRange != null) ...[
                              Text('Ref Range: ${res.referenceRange}', style: const TextStyle(fontSize: 11, color: Colors.grey), softWrap: true),
                            ],
                            const Divider(height: 12),
                          ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDocumentsTab(bool isDark) {
    final docsAsync = ref.watch(patientDocumentsProvider);

    return docsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading documents: $e')),
      data: (docs) {
        if (docs.isEmpty) {
          return const EmptyStateWidget(
            title: 'No Medical Documents',
            message: 'Historical records, scanned prescriptions, and lab test documents will appear here.',
            icon: Icons.folder_shared_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, idx) {
            final d = docs[idx];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
                title: Text(d['file_name'] ?? 'Medical Document', style: const TextStyle(fontWeight: FontWeight.bold), softWrap: true),
                subtitle: Text('Type: ${d['document_type']} • Pages: ${d['page_count']} • Uploaded: ${d['created_at']}', softWrap: true),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View (15 min)'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Accessing private document with short-lived HMAC link: ${d['preview_url']}')),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBillsTab(bool isDark) {
    final billsAsync = ref.watch(patientBillsProvider);

    return billsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading bills: $e')),
      data: (bills) {
        if (bills.isEmpty) {
          return const EmptyStateWidget(
            title: 'No Itemized Invoices',
            message: 'Hospital pharmacy, consultation, and diagnostic invoices will be logged here.',
            icon: Icons.receipt_long_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bills.length,
          itemBuilder: (context, idx) {
            final b = bills[idx];
            final isPaid = b.paymentStatus == 'PAID';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isPaid ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.receipt_long, color: isPaid ? Colors.green : Colors.orange),
                ),
                title: Text('Invoice #${b.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold), softWrap: true),
                subtitle: Text('Date: ${b.billedAt} • Items: ${b.itemsCount} • Receipt: ${b.receiptNumber ?? "None"}', softWrap: true),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${b.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isPaid ? Colors.green : Colors.orange).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        b.paymentStatus,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPaid ? Colors.green : Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVisitsTab(bool isDark) {
    final visitsAsync = ref.watch(patientVisitsProvider);

    return visitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading visits: $e')),
      data: (visits) {
        if (visits.isEmpty) {
          return const EmptyStateWidget(
            title: 'No OPD Visits Recorded',
            message: 'Past consultations and clinic visit summaries will be automatically archived here.',
            icon: Icons.timeline_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: visits.length,
          itemBuilder: (context, idx) {
            final v = visits[idx];
            final vitals = v['vitals'] as Map<String, dynamic>?;

            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text('Visit ${v['visit_number']} • Token #${v['queue_token']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), softWrap: true),
                        Text('${v['status']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Doctor: ${v['doctor_name']} • Department: ${v['department_name']} • Date: ${v['visit_date']}', softWrap: true),
                    if (v['diagnosis'] != null) ...[
                      const SizedBox(height: 6),
                      Text('Diagnosis: ${v['diagnosis']}', style: const TextStyle(fontWeight: FontWeight.w600), softWrap: true),
                    ],
                    if (vitals != null && (vitals['bp'] != null || vitals['pulse'] != null)) ...[
                      const Divider(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (vitals['bp'] != null) Text('BP: ${vitals['bp']} mmHg', style: const TextStyle(fontSize: 12)),
                          if (vitals['pulse'] != null) Text('Pulse: ${vitals['pulse']} bpm', style: const TextStyle(fontSize: 12)),
                          if (vitals['temp'] != null) Text('Temp: ${vitals['temp']} °F', style: const TextStyle(fontSize: 12)),
                          if (vitals['spo2'] != null) Text('SpO₂: ${vitals['spo2']}%', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSupportTab(bool isDark) {
    final ticketsAsync = ref.watch(patientSupportTicketsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Hospital Desk Inquiries & Assistance',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  softWrap: true,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_comment, size: 16),
                label: const Text('New Inquiry'),
                onPressed: () => _showNewSupportTicketDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: ticketsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.wifi_off_rounded, size: 36, color: AppColors.hospitalMaroon),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Hospital Desk Offline or Delayed',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unable to retrieve inquiries right now. Please check your network connection and retry.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry Connection'),
                      onPressed: () => ref.invalidate(patientSupportTicketsProvider),
                    ),
                  ],
                ),
              ),
            ),
            data: (tickets) {
              if (tickets.isEmpty) {
                return EmptyStateWidget(
                  title: 'No Inquiries Submitted',
                  message: 'Submit questions or assistance requests to our OPD hospital front-desk.',
                  icon: Icons.contact_support_outlined,
                  actionLabel: 'Submit Inquiry',
                  onAction: () => _showNewSupportTicketDialog(context),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tickets.length,
                itemBuilder: (context, idx) {
                  final t = tickets[idx];
                  final isResolved = t.status == 'RESOLVED' || t.status == 'CLOSED';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(t.subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), softWrap: true),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isResolved ? Colors.green : Colors.orange).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(t.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isResolved ? Colors.green : Colors.orange)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Category: ${t.category} • Submitted: ${t.createdAt}', style: const TextStyle(fontSize: 11, color: Colors.grey), softWrap: true),
                          const SizedBox(height: 6),
                          Text(t.message, style: const TextStyle(fontSize: 13), softWrap: true),
                          if (t.adminResponse != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Hospital Desk Response:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green)),
                                  const SizedBox(height: 2),
                                  Text(t.adminResponse!, style: const TextStyle(fontSize: 12), softWrap: true),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }



  void _showNewSupportTicketDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final subCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String category = 'GENERAL';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Submit Support Request / Inquiry'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Inquiry Category'),
                    items: const [
                      DropdownMenuItem(value: 'GENERAL', child: Text('General Question')),
                      DropdownMenuItem(value: 'APPOINTMENT', child: Text('Appointment & Queue')),
                      DropdownMenuItem(value: 'BILLING', child: Text('Billing & Receipts')),
                      DropdownMenuItem(value: 'MEDICAL_RECORDS', child: Text('Medical Records / Lab')),
                      DropdownMenuItem(value: 'PHARMACY', child: Text('Pharmacy & Prescription')),
                    ],
                    onChanged: (v) => setDlgState(() => category = v!),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: subCtrl,
                    decoration: const InputDecoration(labelText: 'Subject *'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Subject is required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: msgCtrl,
                    decoration: const InputDecoration(labelText: 'Details / Description *'),
                    maxLines: 4,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Details are required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final cleanSub = InputSanitizer.sanitizeClinicalNotes(subCtrl.text);
                final cleanMsg = InputSanitizer.sanitizeClinicalNotes(msgCtrl.text);
                try {
                  final repo = ref.read(patientPortalRepositoryProvider);
                  final selectedId = ref.read(selectedPortalPatientIdProvider);
                  await repo.createSupportTicket(
                    subject: cleanSub,
                    category: category,
                    message: cleanMsg,
                    dependentPatientId: selectedId,
                  );
                  Navigator.pop(ctx);
                  ref.invalidate(patientSupportTicketsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inquiry submitted to hospital desk!')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
