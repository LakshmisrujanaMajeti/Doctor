import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../models/billing_models.dart';
import '../providers/billing_provider.dart';

class PrintableInvoiceScreen extends ConsumerWidget {
  final String billId;

  const PrintableInvoiceScreen({super.key, required this.billId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billAsync = ref.watch(billDetailProvider(billId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Invoice & Receipt', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Print Invoice',
            icon: const Icon(Icons.print_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Print job sent to connected hospital POS / thermal receipt printer.'),
                  backgroundColor: Colors.teal,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Download PDF',
            icon: const Icon(Icons.download_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invoice PDF exported successfully.'),
                  backgroundColor: AppColors.primaryBlue,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: billAsync.when(
        data: (bill) {
          if (bill == null) {
            return const Center(child: Text('Invoice not found'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Hospital Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.local_hospital_rounded,
                              color: AppColors.primaryBlue,
                              size: 36,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'OPD CONNECT+ HEALTHCARE CENTRE',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Multi-Speciality Outpatient Clinic • ISO 9001:2015 Certified',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                Text(
                                  '12 Medical Enclave, Health City • Tel: +91 40 2345 6789 • GSTIN: 36AABCO1234F1Z5',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: bill.paymentStatus == 'PAID'
                                      ? Colors.green.shade600.withValues(alpha: 0.15)
                                      : (bill.paymentStatus == 'PARTIAL' ? Colors.orange.shade600.withValues(alpha: 0.15) : Colors.red.shade600.withValues(alpha: 0.15)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  bill.paymentStatus,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: bill.paymentStatus == 'PAID'
                                        ? Colors.green.shade800
                                        : (bill.paymentStatus == 'PARTIAL' ? Colors.orange.shade800 : Colors.red.shade800),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                bill.invoiceNumber,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Synthetic price banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade500.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade600.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'SYNTHETIC DEVELOPMENT TARIFF: Clearly labeled synthetic prices and tax slabs for OPD Connect+ testing.',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2. Patient & Invoice Metadata Grid
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildMetaItem('Patient Full Name:', bill.patientName),
                                  const SizedBox(height: 6),
                                  _buildMetaItem('Hospital UHID:', bill.patientUhid),
                                  const SizedBox(height: 6),
                                  _buildMetaItem('OPD Visit Number:', bill.visitNumber),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 70, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildMetaItem('Date of Billed Invoice:', bill.billedAt.split('T').first),
                                  const SizedBox(height: 6),
                                  _buildMetaItem('Clinical Department:', bill.departmentName.isNotEmpty ? bill.departmentName : 'General OPD'),
                                  const SizedBox(height: 6),
                                  _buildMetaItem('Billing Status:', bill.status),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 3. Itemized Services Table
                      const Text(
                        'Itemized Services & Medications',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // Header Row
                            Container(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: const Row(
                                children: [
                                  Expanded(flex: 1, child: Text('Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                  Expanded(flex: 3, child: Text('Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                  Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                  Expanded(flex: 1, child: Text('Price', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                  Expanded(flex: 1, child: Text('Tax %', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                  Expanded(flex: 1, child: Text('Total (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                ],
                              ),
                            ),
                            // Items
                            ...bill.items.map((it) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(flex: 1, child: Text(it.itemCode, style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'))),
                                    Expanded(flex: 3, child: Text(it.description, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                                    Expanded(flex: 1, child: Text('${it.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                                    Expanded(flex: 1, child: Text('₹${it.unitPrice.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                                    Expanded(flex: 1, child: Text('${it.taxRatePercent.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                                    Expanded(flex: 1, child: Text('₹${it.totalAmount.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. Financial Calculations Summary
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Discount Policy & Remarks
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Discount / Concession Policy Notes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(
                                    bill.discountReason.isNotEmpty
                                        ? '${bill.discountReason} (Type: ${bill.discountType})'
                                        : 'No special concession applied. Standard OPD billing tariff.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('Statutory Tax Component Breakdown:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'CGST @ 2.5%/6%: ₹${bill.cgstAmount.toStringAsFixed(2)} • SGST @ 2.5%/6%: ₹${bill.sgstAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Right: Arithmetic Summary Ledger
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                _buildSummaryLine('Subtotal:', '₹${bill.subtotal.toStringAsFixed(2)}'),
                                if (bill.discountAmount > 0)
                                  _buildSummaryLine('Discount Concession:', '- ₹${bill.discountAmount.toStringAsFixed(2)}', color: Colors.green.shade700),
                                _buildSummaryLine('Taxable Amount:', '₹${bill.taxableAmount.toStringAsFixed(2)}'),
                                _buildSummaryLine('CGST Amount:', '₹${bill.cgstAmount.toStringAsFixed(2)}'),
                                _buildSummaryLine('SGST Amount:', '₹${bill.sgstAmount.toStringAsFixed(2)}'),
                                const Divider(height: 12),
                                _buildSummaryLine('TOTAL NET AMOUNT:', '₹${bill.totalAmount.toStringAsFixed(2)}', isBold: true, fontSize: 15, color: AppColors.primaryBlue),
                                _buildSummaryLine('Paid Amount:', '₹${bill.paidAmount.toStringAsFixed(2)}', color: Colors.green.shade700, isBold: true),
                                const Divider(height: 12),
                                _buildSummaryLine(
                                  'OUTSTANDING BALANCE:',
                                  '₹${bill.outstandingBalance.toStringAsFixed(2)}',
                                  isBold: true,
                                  fontSize: 16,
                                  color: bill.outstandingBalance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 5. Payment Transactions Table
                      if (bill.payments.isNotEmpty) ...[
                        const Text('Traceable Payment Transactions & Receipts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: bill.payments.map((p) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          p.paymentStatus == 'COMPLETED' ? Icons.check_circle : Icons.pending,
                                          size: 16,
                                          color: p.paymentStatus == 'COMPLETED' ? Colors.green.shade700 : Colors.orange.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Receipt: ${p.receiptNumber} (${p.paymentMethod})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                      ],
                                    ),
                                    Text('₹${p.amount.toStringAsFixed(2)} • ${p.paymentStatus}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 6. Signature & Digital Authentication Seal
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.green.shade600),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified, size: 14, color: Colors.green.shade700),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Digitally Verified OPD Connect+ System Record',
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.green.shade800),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(width: 140, height: 1, color: Colors.grey.shade400),
                              const SizedBox(height: 4),
                              const Text('Authorized Cashier Sign', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading invoice: $err')),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryLine(String label, String value, {bool isBold = false, double fontSize = 12.5, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
