import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../models/laboratory_models.dart';
import '../providers/laboratory_provider.dart';
import '../widgets/specimen_label_dialog.dart';
import '../widgets/specimen_action_dialogs.dart';
import '../widgets/result_entry_dialog.dart';
import '../widgets/verification_dialog.dart';
import 'laboratory_report_screen.dart';

class LaboratoryWorkspaceView extends ConsumerStatefulWidget {
  const LaboratoryWorkspaceView({super.key});

  @override
  ConsumerState<LaboratoryWorkspaceView> createState() => _LaboratoryWorkspaceViewState();
}

class _LaboratoryWorkspaceViewState extends ConsumerState<LaboratoryWorkspaceView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _departments = ['All', 'Biochemistry', 'Haematology', 'Microbiology'];
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
                  ref.read(labOrdersFilterProvider.notifier).setSearch(val);
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
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No laboratory orders match this filter',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
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
            // Top row: IDs, Urgency, Status
            Row(
              children: [
                // Tube indicator
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
                const Spacer(),
                if (order.isSensitive) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 6),
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
                ],
                if (order.urgency == 'STAT') ...[
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('STAT', style: TextStyle(fontSize: 9.5, color: Colors.red, fontWeight: FontWeight.w900)),
                  ),
                ],
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

            const SizedBox(height: 8),

            // Middle row: Test name, Department, Patient Details
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.testName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryBlue),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${order.department} • Specimen: ${order.specimenType}',
                        style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      order.patientName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      '${order.uhid} • ${order.patientAge ?? "--"}Y / ${order.patientGender ?? "--"}',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ],
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
