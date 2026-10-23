import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../models/billing_models.dart';
import '../providers/billing_provider.dart';
import '../widgets/create_bill_dialog.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/refund_dialog.dart';

class BillingWorkspaceView extends ConsumerStatefulWidget {
  const BillingWorkspaceView({super.key});

  @override
  ConsumerState<BillingWorkspaceView> createState() => _BillingWorkspaceViewState();
}

class _BillingWorkspaceViewState extends ConsumerState<BillingWorkspaceView> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _statusFilters = ['All', 'ISSUED', 'PARTIAL', 'PAID', 'CANCELLED', 'REFUNDED'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateBill() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateBillDialog(),
    );
  }

  void _openPaymentDialog(BillModel bill) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentDialog(bill: bill),
    );
  }

  void _openRefundDialog(BillModel bill) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RefundDialog(bill: bill),
    );
  }

  Future<void> _cancelBill(BillModel bill) async {
    final reasonController = TextEditingController();
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Invoice ${bill.invoiceNumber}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cancelling an invoice is irreversible and audited. Please provide a cancellation justification:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Auditable Cancellation Reason *',
                hintText: 'e.g. Registered under incorrect patient file',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Back')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (shouldCancel == true && mounted) {
      final repo = ref.read(billingRepositoryProvider);
      final result = await repo.cancelBill(bill.id, reason: reasonController.text.trim());
      if (result != null) {
        ref.invalidate(billsListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice ${bill.invoiceNumber} cancelled successfully.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billsListProvider);
    final filter = ref.watch(billingFilterProvider);
    final filterNotifier = ref.read(billingFilterProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. KPI Cards Row
        billsAsync.when(
          data: (bills) => _buildKpiRow(bills, isDark),
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator())),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),

        // 2. Action Toolbar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, toolbarConstraints) {
              final isNarrow = toolbarConstraints.maxWidth < 720;

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search invoice #, patient, UHID...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        filterNotifier.setSearch('');
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
                            onChanged: (val) => filterNotifier.setSearch(val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Refresh Invoices',
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: () {
                            ref.invalidate(billsListProvider);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _statusFilters.map((st) {
                          final isSelected = filter.status == st;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(st == 'All' ? 'All Invoices' : st),
                              selected: isSelected,
                              onSelected: (_) => filterNotifier.setStatus(st),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('+ New Bill'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: _openCreateBill,
                    ),
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Search field
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search invoice #, patient, UHID...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  filterNotifier.setSearch('');
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
                      onChanged: (val) => filterNotifier.setSearch(val),
                    ),
                  ),

                  // Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _statusFilters.map((st) {
                        final isSelected = filter.status == st;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(st == 'All' ? 'All Invoices' : st),
                            selected: isSelected,
                            onSelected: (_) => filterNotifier.setStatus(st),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('+ New Bill'),
                        onPressed: _openCreateBill,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Refresh Invoices',
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: () {
                          ref.invalidate(billsListProvider);
                        },
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // 3. Invoices List
        billsAsync.when(
          data: (bills) {
            if (bills.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'No Bills Found Matching Filter',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          filterNotifier.reset();
                        },
                        child: const Text('Reset Filters'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bills.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final bill = bills[index];

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
                      // Top Area: Responsive Layout for Mobile and Desktop
                      LayoutBuilder(
                        builder: (context, cardConstraints) {
                          final isNarrow = cardConstraints.maxWidth < 680;

                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Mobile Header: Invoice # & Status badge on left, actions menu on right
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryBlue.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            bill.invoiceNumber,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primaryBlue),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildStatusBadge(bill.paymentStatus),
                                      ],
                                    ),
                                    PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.more_vert, size: 20),
                                      onSelected: (val) {
                                        if (val == 'refund') {
                                          _openRefundDialog(bill);
                                        } else if (val == 'cancel') {
                                          _cancelBill(bill);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        if (bill.paidAmount > 0)
                                          const PopupMenuItem(value: 'refund', child: Text('Process Refund')),
                                        if (bill.status != 'CANCELLED' && bill.paidAmount == 0)
                                          const PopupMenuItem(value: 'cancel', child: Text('Cancel Bill', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Full width patient name and visit details
                                Text(
                                  '${bill.patientName} (${bill.patientUhid})',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                  softWrap: true,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Visit: ${bill.visitNumber} • Dept: ${bill.departmentName} • ${bill.billedAt.split("T").first}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                  softWrap: true,
                                ),
                                const SizedBox(height: 12),

                                // Action buttons row on mobile
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.print_outlined, size: 16),
                                        label: const Text('Print Receipt'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 9),
                                        ),
                                        onPressed: () {
                                          context.push('/billing/invoice/${bill.id}');
                                        },
                                      ),
                                    ),
                                    if (bill.outstandingBalance > 0 && bill.status != 'CANCELLED') ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.payment, size: 16),
                                          label: const Text('Pay'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 9),
                                          ),
                                          onPressed: () => _openPaymentDialog(bill),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            );
                          }

                          // Desktop Wide Row: Invoice #, Status, Patient, Actions
                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  bill.invoiceNumber,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primaryBlue),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(bill.paymentStatus),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${bill.patientName} (${bill.patientUhid})',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                                    ),
                                    Text(
                                      'Visit: ${bill.visitNumber} • Dept: ${bill.departmentName} • ${bill.billedAt.split("T").first}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.print_outlined, size: 16),
                                    label: const Text('Print Receipt'),
                                    onPressed: () {
                                      context.push('/billing/invoice/${bill.id}');
                                    },
                                  ),
                                  if (bill.outstandingBalance > 0 && bill.status != 'CANCELLED') ...[
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.payment, size: 16),
                                      label: const Text('Pay'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                                      onPressed: () => _openPaymentDialog(bill),
                                    ),
                                  ],
                                  const SizedBox(width: 4),
                                  PopupMenuButton<String>(
                                    onSelected: (val) {
                                      if (val == 'refund') {
                                        _openRefundDialog(bill);
                                      } else if (val == 'cancel') {
                                        _cancelBill(bill);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      if (bill.paidAmount > 0)
                                        const PopupMenuItem(value: 'refund', child: Text('Process Refund')),
                                      if (bill.status != 'CANCELLED' && bill.paidAmount == 0)
                                        const PopupMenuItem(value: 'cancel', child: Text('Cancel Bill', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const Divider(height: 20),

                      // Itemized pills
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: bill.items.map((it) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${it.description} x${it.quantity} (₹${it.totalAmount.toStringAsFixed(2)})',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Financial summary row
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Subtotal: ₹${bill.subtotal.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              ),
                              if (bill.discountAmount > 0)
                                Text(
                                  '• Disc: -₹${bill.discountAmount.toStringAsFixed(2)} (${bill.discountReason})',
                                  style: TextStyle(fontSize: 11.5, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                                ),
                              Text(
                                '• Tax: ₹${bill.totalTaxAmount.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Total: ₹${bill.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              Text(
                                'Paid: ₹${bill.paidAmount.toStringAsFixed(2)}',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.green.shade700),
                              ),
                              Text(
                                'Balance: ₹${bill.outstandingBalance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: bill.outstandingBalance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                ),
                              ),
                            ],
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
          error: (err, _) => Center(child: Text('Error loading bills: $err')),
        ),
      ],
    );
  }

  Widget _buildKpiRow(List<BillModel> bills, bool isDark) {
    double totalBilled = 0.0;
    double totalCollected = 0.0;
    double totalOutstanding = 0.0;

    for (final b in bills) {
      if (b.status != 'CANCELLED') {
        totalBilled += b.totalAmount;
        totalCollected += b.paidAmount;
        totalOutstanding += b.outstandingBalance;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVerySmall = constraints.maxWidth < 480;
        final isCompact = constraints.maxWidth < 820;

        return GridView.count(
          crossAxisCount: isCompact ? 2 : 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isVerySmall ? 1.85 : (isCompact ? 2.1 : 2.3),
          children: [
            _buildStatCard(
              title: 'Total Invoiced',
              value: '₹${totalBilled.toStringAsFixed(2)}',
              subtitle: '${bills.length} invoices generated',
              icon: Icons.receipt_long,
              color: AppColors.primaryBlue,
              isDark: isDark,
            ),
            _buildStatCard(
              title: 'Total Collected',
              value: '₹${totalCollected.toStringAsFixed(2)}',
              subtitle: 'Settled payments',
              icon: Icons.check_circle_outline,
              color: Colors.green.shade700,
              isDark: isDark,
            ),
            _buildStatCard(
              title: 'Outstanding Balance',
              value: '₹${totalOutstanding.toStringAsFixed(2)}',
              subtitle: 'Pending collection',
              icon: Icons.pending_actions_rounded,
              color: Colors.red.shade700,
              isDark: isDark,
            ),
            _buildStatCard(
              title: 'Invoices Count',
              value: '${bills.length}',
              subtitle: 'Active OPD records',
              icon: Icons.analytics_outlined,
              color: Colors.purple.shade700,
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.2,
        ),
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
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'PAID':
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        break;
      case 'PARTIAL':
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        break;
      case 'CANCELLED':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
      case 'REFUNDED':
        bg = Colors.purple.shade100;
        fg = Colors.purple.shade900;
        break;
      default:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 10)),
    );
  }
}
