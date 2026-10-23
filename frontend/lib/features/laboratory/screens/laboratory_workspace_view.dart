import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../models/laboratory_models.dart';
import '../providers/laboratory_provider.dart';
import '../widgets/specimen_label_dialog.dart';
import '../widgets/specimen_action_dialogs.dart';
import '../widgets/result_entry_dialog.dart';
import '../widgets/verification_dialog.dart';
import 'laboratory_report_screen.dart';
import '../../billing/repositories/billing_repository.dart';
import '../../billing/providers/billing_provider.dart';
import '../../patient_portal/providers/patient_portal_provider.dart';
import '../../admin_portal/providers/admin_portal_provider.dart';

class LaboratoryWorkspaceView extends ConsumerStatefulWidget {
  const LaboratoryWorkspaceView({super.key});

  @override
  ConsumerState<LaboratoryWorkspaceView> createState() => _LaboratoryWorkspaceViewState();
}

class _LaboratoryWorkspaceViewState extends ConsumerState<LaboratoryWorkspaceView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _departments = ['All', 'Biochemistry', 'Haematology', 'Microbiology', 'Radiology'];
  String _selectedDepartment = 'All';

  final List<String> _tabLabels = [
    'All Orders',
    'To Collect',
    'In-Lab Processing',
    'To Verify',
    'Completed',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final filterNotifier = ref.read(labOrdersFilterProvider.notifier);

    switch (_tabController.index) {
      case 0: // All
        filterNotifier.setSpecimenStatus('All');
        break;
      case 1: // To Collect
        filterNotifier.setSpecimenStatus('ORDERED');
        break;
      case 2: // In-Lab Processing
        filterNotifier.setSpecimenStatus('RECEIVED');
        break;
      case 3: // To Verify
        filterNotifier.setSpecimenStatus('PROCESSING');
        break;
      case 4: // Completed
        filterNotifier.setSpecimenStatus('COMPLETED');
        break;
      case 5: // Rejected
        filterNotifier.setSpecimenStatus('REJECTED');
        break;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _getTubeColor(String testName) {
    final lower = testName.toLowerCase();
    if (lower.contains('glucose') || lower.contains('gct') || lower.contains('tolerance')) {
      return Colors.grey.shade400; // Grey - Fluoride
    } else if (lower.contains('haemoglobin') ||
        lower.contains('rbc') ||
        lower.contains('tc') ||
        lower.contains('dc') ||
        lower.contains('platelet') ||
        lower.contains('esr') ||
        lower.contains('pcv') ||
        lower.contains('haematocrit')) {
      return Colors.purple.shade400; // Lavender - EDTA
    } else if (lower.contains('urea') ||
        lower.contains('creatinine') ||
        lower.contains('cholesterol') ||
        lower.contains('triglycerides') ||
        lower.contains('hiv') ||
        lower.contains('vdrl')) {
      return Colors.amber.shade700; // Yellow/Gold - SST Gel
    } else if (lower.contains('bleeding') || lower.contains('clotting')) {
      return Colors.lightBlue.shade400; // Light Blue - Citrate
    } else {
      return Colors.teal.shade600; // Container
    }
  }

  void _showCatalogueDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final catAsync = ref.watch(labCatalogueProvider(null));
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.menu_book_rounded, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                const Text('OPD Test Catalogue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 450,
              child: catAsync.when(
                data: (items) {
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: _getTubeColor(item.testName),
                          child: item.isSensitive
                              ? const Icon(Icons.lock, size: 12, color: Colors.white)
                              : null,
                        ),
                        title: Text(item.testName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text(
                          '${item.category} • ${item.sampleType} • ${item.specimenTube}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: item.isSensitive
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: const Text('Sensitive', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                              )
                            : null,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  final Set<String> _billedOrderIds = {};

  double _getTestTariff(String testName) {
    final lower = testName.toLowerCase();
    if (lower.contains('mri') && lower.contains('contrast')) return 4500.0;
    if (lower.contains('mri')) return 3500.0;
    if (lower.contains('ct scan') || lower.contains('hrct') || lower.contains('ct brain')) return 2500.0;
    if (lower.contains('ultrasound') || lower.contains('usg')) return 900.0;
    if (lower.contains('x-ray') || lower.contains('xray')) return 300.0;
    if (lower.contains('ecg')) return 250.0;
    if (lower.contains('lft') || lower.contains('liver')) return 650.0;
    if (lower.contains('kft') || lower.contains('renal') || lower.contains('kidney')) return 550.0;
    if (lower.contains('lipid')) return 500.0;
    if (lower.contains('tsh') || lower.contains('thyroid')) return 350.0;
    if (lower.contains('glucose') || lower.contains('hba1c')) return 300.0;
    if (lower.contains('urine')) return 150.0;
    if (lower.contains('cbc') || lower.contains('blood')) return 250.0;
    return 450.0;
  }

  Future<void> _openLabBillingDialog(BuildContext context, LabOrderModel order) async {
    final tariff = _getTestTariff(order.testName);
    String selectedPaymentMethod = 'CASH';
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final isScan = order.testName.toLowerCase().contains('mri') ||
              order.testName.toLowerCase().contains('ct') ||
              order.testName.toLowerCase().contains('scan') ||
              order.testName.toLowerCase().contains('x-ray') ||
              order.testName.toLowerCase().contains('usg');

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isScan ? Icons.document_scanner_rounded : Icons.biotech_rounded,
                    color: Colors.indigo.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isScan ? 'Bill Radiology / Imaging Scan' : 'Bill Laboratory Investigation',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Direct Hospital Invoicing & Instant Receipt Generation',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Patient Name:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(order.patientName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('UHID / Order #:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text('${order.uhid} • ${order.orderNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Investigation:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Expanded(
                              child: Text(
                                order.testName,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Official Hospital Tariff:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text(
                              '₹${tariff.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.green),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Payment Mode:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['CASH', 'UPI', 'CARD'].map((m) {
                      final isSel = selectedPaymentMethod == m;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: isSubmitting ? null : () => setDialogState(() => selectedPaymentMethod = m),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? Colors.indigo.shade700 : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isSel ? Colors.indigo.shade700 : Colors.grey.shade300),
                              ),
                              child: Center(
                                child: Text(
                                  m,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSel ? Colors.white : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: isSubmitting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 16),
                label: Text(isSubmitting ? 'Invoicing...' : 'Bill & Collect ₹${tariff.toStringAsFixed(0)}'),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        try {
                          final billingRepo = ref.read(billingRepositoryProvider);
                          await billingRepo.createBill({
                            'patient_id': order.patientId,
                            'patient_name': order.patientName,
                            'patient_uhid': order.uhid,
                            'visit_id': order.visitId,
                            'visit_number': order.visitId,
                            'department_name': isScan ? 'Radiology & Imaging' : 'Laboratory Diagnostic',
                            'discount_type': 'NONE',
                            'discount_rate': 0.0,
                            'discount_amount': 0.0,
                            'paid_amount': tariff,
                            'payment_status': 'PAID',
                            'payment_method': selectedPaymentMethod,
                            'notes': 'Billed directly in ${isScan ? "Radiology / Imaging" : "Laboratory"} Portal for Order #${order.orderNumber}',
                            'items': [
                              {
                                'item_type': 'LAB',
                                'item_code': 'DIAG-${order.orderNumber}',
                                'description': '${order.testName} (${order.orderNumber})',
                                'quantity': 1,
                                'unit_price': tariff,
                                'tax_rate_percent': 0.0,
                              }
                            ],
                          });

                          setState(() {
                            _billedOrderIds.add(order.id);
                            _billedOrderIds.add(order.orderNumber);
                          });

                          ref.invalidate(billsListProvider);
                          ref.invalidate(patientBillsProvider);
                          ref.invalidate(adminDashboardSummaryProvider);

                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Official Hospital Bill generated and marked PAID for ${order.testName} (₹${tariff.toStringAsFixed(0)}). Updated in Patient Portal & Admin Revenue!'),
                                backgroundColor: Colors.green.shade700,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to generate bill: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(labDashboardStatsProvider);
    final ordersAsync = ref.watch(labOrdersListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Bar with Catalogue Action
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Laboratory Operations Portal',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                  Text(
                    'Specimen Accession, Investigation Tracking & Non-Repudiation Sign-off',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                foregroundColor: AppColors.primaryBlue,
                elevation: 0,
              ),
              icon: const Icon(Icons.menu_book_rounded, size: 16),
              label: const Text('Catalogue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _showCatalogueDialog(context),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 2. KPI Metrics Bar
        statsAsync.when(
          data: (stats) => _buildKpiGrid(context, stats),
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
          error: (_, __) => const SizedBox(),
        ),

        const SizedBox(height: 16),

        // 3. Department Filters Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _departments.map((dept) {
              final isSelected = _selectedDepartment == dept;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(dept),
                  selected: isSelected,
                  selectedColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primaryBlue,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? AppColors.primaryBlue : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  onSelected: (val) {
                    setState(() => _selectedDepartment = dept);
                    ref.read(labOrdersFilterProvider.notifier).setDepartment(dept);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // 4. Search & Date Filter Bar
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by UHID, patient name, test, order or specimen ID...',
                  hintStyle: const TextStyle(fontSize: 12.5),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(labOrdersFilterProvider.notifier).setSearch('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) {
                  final cleaned = InputSanitizer.sanitizeSearchQuery(val);
                  ref.read(labOrdersFilterProvider.notifier).setSearch(cleaned);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Filter by Date',
              icon: const Icon(Icons.calendar_today_rounded, size: 20),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2025),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  final formatted =
                      '${picked.year}-${picked.month.toString().padLeft(2, "0")}-${picked.day.toString().padLeft(2, "0")}';
                  ref.read(labOrdersFilterProvider.notifier).setDate(formatted);
                }
              },
            ),
            IconButton.filledTonal(
              tooltip: 'Reset Filters',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() => _selectedDepartment = 'All');
                ref.read(labOrdersFilterProvider.notifier).reset();
              },
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 5. Status Queue Tabs
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primaryBlue,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _tabLabels.map((t) => Tab(text: t)).toList(),
        ),

        const SizedBox(height: 12),

        // 6. Orders Queue List
        ordersAsync.when(
          data: (orders) {
            if (orders.isEmpty) {
              return const EmptyStateWidget(
                title: 'No Orders in Queue',
                message: 'No laboratory orders match the active department or status queue filters.',
                icon: Icons.biotech_outlined,
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final order = orders[index];
                return _buildOrderCard(context, order);
              },
            );
          },
          loading: () => const Center(
            child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error loading orders: $err', style: const TextStyle(color: Colors.red)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid(BuildContext context, LabDashboardStatsModel stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 650;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildKpiCard('To Collect', stats.pendingCollection, Colors.blue, Icons.colorize_rounded, isWide),
            _buildKpiCard('In-Lab', stats.inLabReceived, Colors.teal, Icons.science_rounded, isWide),
            _buildKpiCard('Processing', stats.processing, Colors.purple, Icons.biotech_rounded, isWide),
            _buildKpiCard('To Verify', stats.pendingVerification, Colors.orange, Icons.fact_check_rounded, isWide),
            _buildKpiCard('Completed', stats.completedToday, Colors.green, Icons.check_circle_rounded, isWide),
            _buildKpiCard('Rejected', stats.rejectedCount, Colors.red, Icons.cancel_rounded, isWide),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(String label, int count, Color color, IconData icon, bool isWide) {
    return Container(
      width: isWide ? 105 : 95,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 16, color: color),
              Text(
                count.toString(),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, LabOrderModel order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tubeColor = _getTubeColor(order.testName);

    Color statusColor;
    switch (order.specimenStatus) {
      case 'ORDERED':
        statusColor = Colors.blue;
        break;
      case 'COLLECTED':
        statusColor = Colors.amber.shade800;
        break;
      case 'RECEIVED':
        statusColor = Colors.teal;
        break;
      case 'PROCESSING':
        statusColor = Colors.purple;
        break;
      case 'COMPLETED':
        statusColor = Colors.green;
        break;
      case 'REJECTED':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    final isBilled = _billedOrderIds.contains(order.id) ||
        _billedOrderIds.contains(order.orderNumber) ||
        BillingRepository.cachedBills.any((b) =>
            (b.patientUhid.toUpperCase() == order.uhid.toUpperCase() || b.patientId == order.patientId) &&
            b.items.any((it) => it.description.contains(order.orderNumber) || it.description.contains(order.testName)));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: IDs, Urgency, Status using Wrap so it never overflows
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: tubeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order.orderNumber,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.2),
                    ),
                    if (order.specimenId != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '• ${order.specimenId}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54, fontFamily: 'monospace'),
                      ),
                    ],
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (order.isSensitive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.lock, size: 10, color: Colors.red),
                            SizedBox(width: 3),
                            Text('SENSITIVE', style: TextStyle(fontSize: 9.5, color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    if (order.urgency == 'STAT')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('STAT', style: TextStyle(fontSize: 9.5, color: Colors.red, fontWeight: FontWeight.w900)),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Text(
                        order.specimenStatus,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Middle row: Test name, Department, Patient Details responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 460;
                final testInfo = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.testName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryBlue),
                      softWrap: true,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${order.department} • Specimen: ${order.specimenType}',
                      style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                      softWrap: true,
                    ),
                  ],
                );

                final patientInfo = Column(
                  crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: [
                    Text(
                      order.patientName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      softWrap: true,
                    ),
                    Text(
                      '${order.uhid} • ${order.patientAge ?? "--"}Y / ${order.patientGender ?? "--"}',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                      softWrap: true,
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      testInfo,
                      const SizedBox(height: 6),
                      patientInfo,
                    ],
                  );
                } else {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: testInfo),
                      const SizedBox(width: 12),
                      patientInfo,
                    ],
                  );
                }
              },
            ),

            if (order.rejectionReason != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel, size: 14, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Rejected: ${order.rejectionReason}',
                        style: TextStyle(fontSize: 11, color: Colors.red.shade900, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Bottom action row based on lifecycle state
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Print specimen label
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.qr_code_2, size: 15),
                  label: const Text('Specimen Label', style: TextStyle(fontSize: 11.5)),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => SpecimenLabelDialog(order: order),
                    );
                  },
                ),

                // Direct Lab / Scan Billing Action
                if (isBilled) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade600),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'BILLED & PAID (₹${_getTestTariff(order.testName).toStringAsFixed(0)})',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 15),
                    label: Text(
                      'Bill Scan/Test (₹${_getTestTariff(order.testName).toStringAsFixed(0)})',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _openLabBillingDialog(context, order),
                  ),
                ],

                // If ORDERED -> Collect
                if (order.specimenStatus == 'ORDERED') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.colorize_rounded, size: 15),
                    label: const Text('Collect Specimen', style: TextStyle(fontSize: 11.5)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => SpecimenCollectionDialog(order: order),
                      );
                    },
                  ),
                ],

                // If COLLECTED -> Receive in Lab or Reject
                if (order.specimenStatus == 'COLLECTED') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.science_rounded, size: 15),
                    label: const Text('Receive in Lab', style: TextStyle(fontSize: 11.5)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => SpecimenReceiptDialog(order: order),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.red,
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 15),
                    label: const Text('Reject', style: TextStyle(fontSize: 11.5)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => SpecimenRejectionDialog(order: order),
                      );
                    },
                  ),
                ],

                // If RECEIVED or PROCESSING -> Enter Results or Reject
                if (order.specimenStatus == 'RECEIVED' || order.specimenStatus == 'PROCESSING') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: Text(
                      order.results.isNotEmpty ? 'Edit Results' : 'Enter Results',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => ResultEntryDialog(order: order),
                      );
                    },
                  ),

                  // If has results -> Verify
                  if (order.results.isNotEmpty) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.verified_user_rounded, size: 15),
                      label: const Text('Verify & Publish', style: TextStyle(fontSize: 11.5)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => VerificationDialog(order: order),
                        );
                      },
                    ),
                  ],

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.red,
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 15),
                    label: const Text('Reject', style: TextStyle(fontSize: 11.5)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => SpecimenRejectionDialog(order: order),
                      );
                    },
                  ),
                ],

                // If COMPLETED -> View Report
                if (order.specimenStatus == 'COMPLETED') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.green.shade800,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.print_rounded, size: 15),
                    label: const Text('Printable Report', style: TextStyle(fontSize: 11.5)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LaboratoryReportScreen(orderId: order.id),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
