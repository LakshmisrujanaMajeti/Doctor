import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../models/patient_portal_models.dart';
import '../providers/patient_portal_provider.dart';

class PatientPortalWorkspaceView extends ConsumerStatefulWidget {
  const PatientPortalWorkspaceView({super.key});

  @override
  ConsumerState<PatientPortalWorkspaceView> createState() => _PatientPortalWorkspaceViewState();
}

class _PatientPortalWorkspaceViewState extends ConsumerState<PatientPortalWorkspaceView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(patientProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Portal & Health Records'),
        actions: [
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
        ],
      ),
      body: profileAsync.when(
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

              // 2. Navigation Tabs
              Container(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppColors.primaryBlue,
                  unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  indicatorColor: AppColors.primaryBlue,
                  tabs: const [
                    Tab(icon: Icon(Icons.calendar_month, size: 18), text: 'Appointments'),
                    Tab(icon: Icon(Icons.medication, size: 18), text: 'Prescriptions'),
                    Tab(icon: Icon(Icons.biotech, size: 18), text: 'Lab Reports'),
                    Tab(icon: Icon(Icons.folder_shared, size: 18), text: 'Medical Documents'),
                    Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Bills & Receipts'),
                    Tab(icon: Icon(Icons.timeline, size: 18), text: 'Visit History'),
                    Tab(icon: Icon(Icons.contact_support, size: 18), text: 'Support & Inquiries'),
                  ],
                ),
              ),

              // 3. Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
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
    );
  }

  Widget _buildProfileHeader(
    dynamic patient,
    List<DependentProfile> dependents,
    PatientPortalProfile profile,
    bool isDark,
  ) {
    final selectedId = ref.watch(selectedPortalPatientIdProvider);
    final isViewingDependent = selectedId != null && selectedId != patient.id;
    final activeDependent = isViewingDependent
        ? dependents.firstWhere((d) => d.id == selectedId, orElse: () => dependents.first)
        : null;

    final displayName = isViewingDependent ? activeDependent!.fullName : patient.fullName;
    final displayUhid = isViewingDependent ? activeDependent!.uhid : patient.uhid;
    final displayAge = isViewingDependent
        ? activeDependent!.ageDisplay
        : (patient.ageYears != null ? '${patient.ageYears} Y' : 'N/A');
    final displayGender = isViewingDependent ? activeDependent!.gender : patient.gender;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: isViewingDependent ? AppColors.accentTeal : AppColors.primaryBlue,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P',
                  style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        if (isViewingDependent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Dependent (${activeDependent?.relation ?? "Child"})',
                              style: const TextStyle(fontSize: 11, color: AppColors.accentTeal, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'UHID: $displayUhid • Age: $displayAge • Gender: $displayGender • Phone: ${patient.phone}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Active Token Live Banner
              if (profile.hasActiveToken) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade600),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.confirmation_number, color: Colors.amber, size: 20),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Token: ${profile.activeTokenNumber}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                          ),
                          Text(
                            'Status: ${profile.activeTokenQueueStatus}',
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Profile Switcher Bar
          Row(
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
              ActionChip(
                avatar: const Icon(Icons.person_add, size: 16),
                label: const Text('Add Dependent', style: TextStyle(fontSize: 12)),
                onPressed: () => _showAddDependentDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsTab(bool isDark) {
    final apptsAsync = ref.watch(patientAppointmentsProvider);

    return apptsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading appointments: $e')),
      data: (appts) {
        if (appts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_available, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('No upcoming appointments or follow-up reminders scheduled.'),
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
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today, color: AppColors.primaryBlue, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Scheduled Review: ${a.scheduledDate}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  a.isCompleted ? 'Completed' : 'Upcoming Follow-up',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Clinician: ${a.doctorName} • ${a.departmentName}', style: const TextStyle(fontSize: 13)),
                          if (a.followUpReason != null) ...[
                            const SizedBox(height: 4),
                            Text('Reason: ${a.followUpReason}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                          if (a.carePlan != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Doctor\'s Advice: ${a.carePlan}', style: const TextStyle(fontSize: 12)),
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
    );
  }

  Widget _buildPrescriptionsTab(bool isDark) {
    final rxAsync = ref.watch(patientPrescriptionsProvider);

    return rxAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading prescriptions: $e')),
      data: (prescriptions) {
        if (prescriptions.isEmpty) {
          return const Center(child: Text('No active prescriptions found.'));
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Prescription signed by ${rx.doctorName}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                                  ),
                                  Text(
                                    'Dosage: ${item.frequency} for ${item.durationDays} days • Route: ${item.route} • Qty: ${item.quantity}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (item.timing != null || item.instructions != null) ...[
                                    Text(
                                      'Instructions: ${item.timing ?? ""} ${item.instructions ?? ""}'.trim(),
                                      style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
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
          return const Center(child: Text('No released laboratory reports available.'));
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
                title: Text(r.testName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Text('Category: ${r.testCategory} • Released: ${r.completedAt ?? r.orderedAt}'),
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
                          const Text('Test completed and verified by clinical pathologist.')
                        else
                          for (final res in r.results) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(res.parameterName, style: const TextStyle(fontSize: 13)),
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
                              Text('Ref Range: ${res.referenceRange}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
          return const Center(child: Text('No medical documents archived.'));
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
                title: Text(d['file_name'] ?? 'Medical Document', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Type: ${d['document_type']} • Pages: ${d['page_count']} • Uploaded: ${d['created_at']}'),
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
          return const Center(child: Text('No itemized bills found.'));
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
                title: Text('Invoice #${b.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Date: ${b.billedAt} • Items: ${b.itemsCount} • Receipt: ${b.receiptNumber ?? "None"}'),
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
          return const Center(child: Text('No OPD visit records found.'));
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Visit ${v['visit_number']} • Token #${v['queue_token']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${v['status']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Doctor: ${v['doctor_name']} • Department: ${v['department_name']} • Date: ${v['visit_date']}'),
                    if (v['diagnosis'] != null) ...[
                      const SizedBox(height: 6),
                      Text('Diagnosis: ${v['diagnosis']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                    if (vitals != null && (vitals['bp'] != null || vitals['pulse'] != null)) ...[
                      const Divider(height: 16),
                      Row(
                        children: [
                          if (vitals['bp'] != null) Text('BP: ${vitals['bp']} mmHg  •  ', style: const TextStyle(fontSize: 12)),
                          if (vitals['pulse'] != null) Text('Pulse: ${vitals['pulse']} bpm  •  ', style: const TextStyle(fontSize: 12)),
                          if (vitals['temp'] != null) Text('Temp: ${vitals['temp']} °F  •  ', style: const TextStyle(fontSize: 12)),
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
              const Text('Hospital Desk Inquiries & Assistance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            error: (e, _) => Center(child: Text('Error loading tickets: $e')),
            data: (tickets) {
              if (tickets.isEmpty) {
                return const Center(child: Text('No support inquiries submitted yet.'));
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(t.subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                          Text('Category: ${t.category} • Submitted: ${t.createdAt}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Text(t.message, style: const TextStyle(fontSize: 13)),
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
                                  Text(t.adminResponse!, style: const TextStyle(fontSize: 12)),
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

  void _showAddDependentDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final relationCtrl = TextEditingController(text: 'Son');
    final ageCtrl = TextEditingController();
    String gender = 'MALE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add Permitted Dependent Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: relationCtrl.text,
                  decoration: const InputDecoration(labelText: 'Relationship to Primary Patient *'),
                  items: const [
                    DropdownMenuItem(value: 'Son', child: Text('Son')),
                    DropdownMenuItem(value: 'Daughter', child: Text('Daughter')),
                    DropdownMenuItem(value: 'Mother', child: Text('Mother')),
                    DropdownMenuItem(value: 'Father', child: Text('Father')),
                    DropdownMenuItem(value: 'Spouse', child: Text('Spouse')),
                    DropdownMenuItem(value: 'Ward', child: Text('Ward / Guardian')),
                  ],
                  onChanged: (v) => setDlgState(() => relationCtrl.text = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: gender,
                  decoration: const InputDecoration(labelText: 'Gender *'),
                  items: const [
                    DropdownMenuItem(value: 'MALE', child: Text('Male')),
                    DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (v) => setDlgState(() => gender = v!),
                ),
                const SizedBox(height: 8),
                TextField(controller: ageCtrl, decoration: const InputDecoration(labelText: 'Age (Years) *'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                try {
                  final repo = ref.read(patientPortalRepositoryProvider);
                  await repo.addDependent(
                    fullName: nameCtrl.text.trim(),
                    relation: relationCtrl.text.trim(),
                    gender: gender,
                    ageYears: int.tryParse(ageCtrl.text),
                  );
                  Navigator.pop(ctx);
                  ref.invalidate(patientProfileProvider);
                  ref.invalidate(patientDependentsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dependent registered successfully!')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Register Dependent'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewSupportTicketDialog(BuildContext context) {
    final subCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String category = 'GENERAL';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Submit Support Request / Inquiry'),
          content: SingleChildScrollView(
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
                TextField(controller: subCtrl, decoration: const InputDecoration(labelText: 'Subject *')),
                const SizedBox(height: 8),
                TextField(controller: msgCtrl, decoration: const InputDecoration(labelText: 'Details / Description *'), maxLines: 4),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (subCtrl.text.trim().isEmpty || msgCtrl.text.trim().isEmpty) return;
                try {
                  final repo = ref.read(patientPortalRepositoryProvider);
                  final selectedId = ref.read(selectedPortalPatientIdProvider);
                  await repo.createSupportTicket(
                    subject: subCtrl.text.trim(),
                    category: category,
                    message: msgCtrl.text.trim(),
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
