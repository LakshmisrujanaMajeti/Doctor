import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../models/pharmacy_models.dart';
import '../providers/pharmacy_provider.dart';
import '../widgets/stock_receipt_dialog.dart';
import '../widgets/stock_adjustment_dialog.dart';
import '../widgets/dispense_prescription_dialog.dart';

class PharmacyWorkspaceView extends ConsumerStatefulWidget {
  const PharmacyWorkspaceView({super.key});

  @override
  ConsumerState<PharmacyWorkspaceView> createState() => _PharmacyWorkspaceViewState();
}

class _PharmacyWorkspaceViewState extends ConsumerState<PharmacyWorkspaceView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _dosageForms = [
    'All',
    'Tablet',
    'Capsule',
    'Syrup',
    'Injection',
    'Ointment',
    'Inhaler',
    'Drops',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openStockReceipt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const StockReceiptDialog(),
    );
  }

  void _openStockAdjustment([MedicineInventoryItem? item]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StockAdjustmentDialog(initialItem: item),
    );
  }

  void _openDispenseDialog(PrescriptionForDispensing rx) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DispensePrescriptionDialog(prescription: rx),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(pharmacyStatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. KPI Metric Cards
        statsAsync.when(
          data: (stats) => _buildKpiRow(stats, isDark),
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator())),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),

        // 2. Action Toolbar & Search
        _buildActionToolbar(isDark),
        const SizedBox(height: 16),

        // 3. Navigation Tabs
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(
                icon: Icon(Icons.receipt_long_rounded, size: 18),
                text: 'Prescriptions to Dispense',
              ),
              Tab(
                icon: Icon(Icons.inventory_rounded, size: 18),
                text: 'Inventory Catalogue',
              ),
              Tab(
                icon: Icon(Icons.history_rounded, size: 18),
                text: 'Dispensing History',
              ),
              Tab(
                icon: Icon(Icons.sync_alt_rounded, size: 18),
                text: 'Stock Movements Ledger',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Tab Views
        SizedBox(
          height: 640,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPrescriptionsTab(isDark),
              _buildInventoryTab(isDark),
              _buildDispensesTab(isDark),
              _buildMovementsTab(isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiRow(InventoryStats stats, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 800;

        return GridView.count(
          crossAxisCount: isCompact ? 2 : 5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isCompact ? 2.2 : 2.0,
          children: [
            _buildStatCard(
              title: 'Total Stock Units',
              value: '${stats.totalStockUnits}',
              subtitle: '${stats.totalMedicines} medicine lines',
              icon: Icons.inventory_2_outlined,
              color: AppColors.primaryBlue,
              isDark: isDark,
            ),
            _buildStatCard(
              title: 'Low Stock Alerts',
              value: '${stats.lowStockCount}',
              subtitle: 'Below threshold level',
              icon: Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
              isDark: isDark,
              onTap: () {
                final notifier = ref.read(pharmacyInventoryFilterProvider.notifier);
                notifier.toggleLowStock(true);
                _tabController.animateTo(1);
              },
            ),
            _buildStatCard(
              title: 'Expiring Soon',
              value: '${stats.expiringSoonCount}',
              subtitle: 'Within next 60 days',
              icon: Icons.hourglass_bottom_rounded,
              color: Colors.amber.shade800,
              isDark: isDark,
              onTap: () {
                final notifier = ref.read(pharmacyInventoryFilterProvider.notifier);
                notifier.toggleExpiringSoon(true);
                _tabController.animateTo(1);
              },
            ),
            _buildStatCard(
              title: 'Expired Batches',
              value: '${stats.expiredCount}',
              subtitle: 'Quarantined for disposal',
              icon: Icons.block_rounded,
              color: Colors.red.shade700,
              isDark: isDark,
            ),
            _buildStatCard(
              title: "Today's Dispenses",
              value: '${stats.totalDispensesToday}',
              subtitle: 'Prescriptions completed',
              icon: Icons.check_circle_outline,
              color: Colors.green.shade700,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Box with responsive constraints
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 340),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search medicine, batch, UHID...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(pharmacyInventoryFilterProvider.notifier).setQuery('');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                final cleaned = InputSanitizer.sanitizeSearchQuery(val);
                ref.read(pharmacyInventoryFilterProvider.notifier).setQuery(cleaned);
              },
            ),
          ),

          // Actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: const Text('Stock Adjustment'),
                onPressed: () => _openStockAdjustment(),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 17),
                label: const Text('+ Receive Stock'),
                onPressed: _openStockReceipt,
              ),
              IconButton(
                tooltip: 'Refresh Pharmacy Data',
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () {
                  ref.invalidate(pharmacyStatsProvider);
                  ref.invalidate(pharmacyInventoryListProvider);
                  ref.invalidate(prescriptionsForDispensingProvider);
                  ref.invalidate(pharmacyDispensesHistoryProvider);
                  ref.invalidate(pharmacyStockMovementsProvider);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 1: Prescriptions to Dispense
  Widget _buildPrescriptionsTab(bool isDark) {
    final prescriptionsAsync = ref.watch(prescriptionsForDispensingProvider);

    return prescriptionsAsync.when(
      data: (prescriptions) {
        if (prescriptions.isEmpty) {
          return const EmptyStateWidget(
            title: 'No Pending Prescriptions to Dispense',
            message: 'All signed outpatient prescriptions have been fulfilled.',
            icon: Icons.check_circle_outline,
          );
        }

        return ListView.separated(
          itemCount: prescriptions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final rx = prescriptions[index];
            final pendingItems = rx.items.where((i) => !i.isDispensed).toList();

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 500;
                      final infoWidget = Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person_pin, color: AppColors.primaryBlue, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      rx.patientName,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                      softWrap: true,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        rx.patientUhid,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Prescribed by: ${rx.doctorName} • Signed: ${rx.signedAt?.split("T").first ?? "Recent"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                  softWrap: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      final dispenseBtn = ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 16),
                        label: Text('Dispense (${pendingItems.length} items)'),
                        onPressed: () => _openDispenseDialog(rx),
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            infoWidget,
                            const SizedBox(height: 10),
                            SizedBox(width: double.infinity, child: dispenseBtn),
                          ],
                        );
                      } else {
                        return Row(
                          children: [
                            Expanded(child: infoWidget),
                            const SizedBox(width: 12),
                            dispenseBtn,
                          ],
                        );
                      }
                    },
                  ),
                  const Divider(height: 22),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: rx.items.map((item) {
                      final hasStock = item.availableBatches.any((b) => !b.isExpired && b.availableQuantity > 0);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: item.isDispensed
                                ? Colors.grey.shade400
                                : (hasStock ? Colors.green.shade400 : Colors.red.shade400),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.isDispensed ? Icons.check_circle : (hasStock ? Icons.medication : Icons.warning_amber),
                              size: 15,
                              color: item.isDispensed ? Colors.grey : (hasStock ? Colors.green.shade700 : Colors.red.shade700),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${item.medicineName} (${item.dosage}) • Qty: ${item.quantity}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  decoration: item.isDispensed ? TextDecoration.lineThrough : null,
                                ),
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading prescriptions: $err')),
    );
  }

  // TAB 2: Inventory Catalogue
  Widget _buildInventoryTab(bool isDark) {
    final inventoryAsync = ref.watch(pharmacyInventoryListProvider);
    final filter = ref.watch(pharmacyInventoryFilterProvider);
    final filterNotifier = ref.read(pharmacyInventoryFilterProvider.notifier);

    return Column(
      children: [
        // Form filters row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ..._dosageForms.map((form) {
                final isSelected = filter.dosageForm == form;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(form),
                    selected: isSelected,
                    onSelected: (_) => filterNotifier.setDosageForm(form),
                  ),
                );
              }),
              const SizedBox(width: 10),
              FilterChip(
                avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                label: const Text('Low Stock Only'),
                selected: filter.lowStockOnly,
                onSelected: (val) => filterNotifier.toggleLowStock(val),
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: const Icon(Icons.hourglass_bottom_rounded, size: 16),
                label: const Text('Expiring Soon (<60d)'),
                selected: filter.expiringSoonOnly,
                onSelected: (val) => filterNotifier.toggleExpiringSoon(val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Inventory table / list
        Expanded(
          child: inventoryAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return EmptyStateWidget(
                  title: 'No Matching Medicines Found',
                  message: 'No medicines match the selected dosage form or stock threshold filters.',
                  icon: Icons.medication_liquid_outlined,
                  actionLabel: 'Reset Filters',
                  onAction: () => filterNotifier.reset(),
                );
              }

              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final med = items[index];

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: med.isExpired
                            ? Colors.red.shade400
                            : (med.isLowStock ? Colors.orange.shade400 : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: med.isExpired
                                ? Colors.red.shade100
                                : (med.isLowStock ? Colors.orange.shade100 : AppColors.primaryBlue.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            med.isExpired ? Icons.cancel_outlined : Icons.medication,
                            color: med.isExpired
                                ? Colors.red.shade800
                                : (med.isLowStock ? Colors.orange.shade800 : AppColors.primaryBlue),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    med.name,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    softWrap: true,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      med.medicineCode,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  if (med.genericName.isNotEmpty) ...[
                                    Text(
                                      '(${med.genericName})',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontStyle: FontStyle.italic,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                      softWrap: true,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${med.dosageForm} • ${med.strength} • Batch: ${med.batchNumber} • Expiry: ${med.expiryDate}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),

                        // Stock & Price Block
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                Text(
                                  '${med.availableQuantity} units',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: med.isLowStock ? Colors.orange.shade700 : null,
                                  ),
                                ),
                                if (med.isLowStock) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'LOW',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.orange.shade900),
                                    ),
                                  ),
                                ],
                                if (med.isExpired) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'EXPIRED',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.red.shade900),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '₹${med.unitPrice.toStringAsFixed(2)} [SYNTHETIC] • ${med.taxClassification}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                              softWrap: true,
                            ),
                          ],
                        ),

                        const SizedBox(width: 14),
                        PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'adjust') {
                              _openStockAdjustment(med);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'adjust', child: Text('Adjust Stock')),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading inventory: $err')),
          ),
        ),
      ],
    );
  }

  // TAB 3: Dispensing History
  Widget _buildDispensesTab(bool isDark) {
    final dispensesAsync = ref.watch(pharmacyDispensesHistoryProvider);

    return dispensesAsync.when(
      data: (records) {
        if (records.isEmpty) {
          return const EmptyStateWidget(
            title: 'No Dispensing Records',
            message: 'All completed outpatient pharmacy dispensations will be catalogued in this ledger.',
            icon: Icons.history_rounded,
          );
        }

        return ListView.separated(
          itemCount: records.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final rec = records[index];

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              rec.dispenseNumber,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primaryBlue),
                            ),
                          ),
                          Text(
                            '${rec.patientName} (${rec.patientUhid})',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            softWrap: true,
                          ),
                        ],
                      ),
                      Text(
                        '₹${rec.totalAmount.toStringAsFixed(2)} [SYNTHETIC]',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primaryBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dispensed by: ${rec.dispensedByName} • Date: ${rec.dispensedAt.split("T").first} • ${rec.totalItemsDispensed} units dispensed',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    softWrap: true,
                  ),
                  if (rec.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Counseling: ${rec.notes}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      softWrap: true,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  // TAB 4: Stock Movements Ledger
  Widget _buildMovementsTab(bool isDark) {
    final movementsAsync = ref.watch(pharmacyStockMovementsProvider);

    return movementsAsync.when(
      data: (movements) {
        if (movements.isEmpty) {
          return const EmptyStateWidget(
            title: 'No Stock Movements Recorded',
            message: 'Inward stock receipts and dispensation adjustments will appear here.',
            icon: Icons.sync_alt_rounded,
          );
        }

        return ListView.separated(
          itemCount: movements.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final mov = movements[index];
            final isAddition = mov.movementType.contains('RECEIPT') || mov.movementType.contains('ADD');

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isAddition ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isAddition ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isAddition ? Colors.green.shade700 : Colors.red.shade700,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            Text(
                              mov.movementType,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: isAddition ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                            Text(
                              'Ref: ${mov.referenceNumber}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Text(
                          '${mov.reason.isNotEmpty ? mov.reason : "General inventory update"} • Staff: ${mov.performedByName}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isAddition ? "+" : "-"}${mov.quantity} units',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isAddition ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                      Text(
                        'Balance: ${mov.balanceAfter}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}
