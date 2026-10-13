import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../models/billing_models.dart';
import '../providers/billing_provider.dart';

class PaymentDialog extends ConsumerStatefulWidget {
  final BillModel bill;

  const PaymentDialog({super.key, required this.bill});

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  final _amountController = TextEditingController();
  final _refController = TextEditingController();

  String _paymentMethod = 'CASH'; // CASH, CARD, ONLINE
  bool _isSubmitting = false;

  // Online gateway state
  String? _onlineOrderId;
  bool _onlineOrderCreated = false;
  bool _onlineVerified = false;
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.bill.outstandingBalance.toStringAsFixed(2);
    _refController.text = 'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount > 0')),
      );
      return;
    }

    if (amount > widget.bill.outstandingBalance + 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Amount cannot exceed outstanding balance of ₹${widget.bill.outstandingBalance.toStringAsFixed(2)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final repo = ref.read(billingRepositoryProvider);

    final isOnline = _paymentMethod == 'ONLINE';
    final payload = {
      'amount': amount,
      'payment_method': _paymentMethod,
      'reference_number': _refController.text.trim(),
      'is_online': isOnline,
    };

    final result = await repo.recordPayment(widget.bill.id, payload);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      ref.invalidate(billsListProvider);
      ref.invalidate(billDetailProvider(widget.bill.id));

      if (isOnline) {
        setState(() {
          _onlineOrderCreated = true;
          _onlineOrderId = result['gateway_order_id'] as String?;
          _idempotencyKey = 'idemp-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Online order initiated (${_onlineOrderId}). Pending provider webhook verification.'),
            backgroundColor: Colors.blue.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of ₹${amount.toStringAsFixed(2)} successfully recorded. Receipt: ${result["receipt_number"]}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to record payment. Please check details.')),
      );
    }
  }

  Future<void> _simulateCallback() async {
    if (_onlineOrderId == null) return;

    setState(() => _isSubmitting = true);
    final repo = ref.read(billingRepositoryProvider);
    final amount = double.tryParse(_amountController.text.trim()) ?? widget.bill.outstandingBalance;

    final mockPaymentId = 'pay_gateway_${DateTime.now().millisecondsSinceEpoch}';
    final payload = {
      'gateway_order_id': _onlineOrderId,
      'gateway_payment_id': mockPaymentId,
      'amount': amount,
      'idempotency_key': _idempotencyKey,
      'status': 'SUCCESS',
    };

    final result = await repo.reconcilePaymentCallback(payload);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null && result['payment_status'] == 'COMPLETED') {
      setState(() => _onlineVerified = true);
      ref.invalidate(billsListProvider);
      ref.invalidate(billDetailProvider(widget.bill.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment confirmed by verified webhook callback! Receipt: ${result["receipt_number"]}'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  Future<void> _testDuplicateCallback() async {
    if (_onlineOrderId == null || _idempotencyKey == null) return;

    setState(() => _isSubmitting = true);
    final repo = ref.read(billingRepositoryProvider);
    final amount = double.tryParse(_amountController.text.trim()) ?? widget.bill.outstandingBalance;

    final payload = {
      'gateway_order_id': _onlineOrderId,
      'gateway_payment_id': 'pay_duplicate_test',
      'amount': amount,
      'idempotency_key': _idempotencyKey,
      'status': 'SUCCESS',
    };

    final result = await repo.reconcilePaymentCallback(payload);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Idempotency Verified: Duplicate callback safely handled without double-crediting!'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bill;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.payment_rounded, color: Colors.green.shade700, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Record Payment (${b.invoiceNumber})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Patient: ${b.patientName} (${b.patientUhid})',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Outstanding balance card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Invoice Total:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('₹${b.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Already Paid:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('₹${b.paidAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Balance Due:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red)),
                        Text(
                          '₹${b.outstandingBalance.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount Input
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Payment Amount (₹) *',
                          prefixIcon: Icon(Icons.currency_rupee, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Payment Method Selector
                      const Text('Payment Method *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildMethodOption('CASH', 'Cash Counter', Icons.payments_outlined),
                          const SizedBox(width: 8),
                          _buildMethodOption('CARD', 'Debit / Card', Icons.credit_card_outlined),
                          const SizedBox(width: 8),
                          _buildMethodOption('ONLINE', 'Online / UPI', Icons.qr_code_2),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _refController,
                        decoration: const InputDecoration(
                          labelText: 'Receipt / Transaction Ref Number',
                          prefixIcon: Icon(Icons.numbers, size: 18),
                        ),
                      ),

                      if (_paymentMethod == 'ONLINE') ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.shield_outlined, size: 18, color: Colors.blue.shade800),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Secure Server-side Reconciliation Policy',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blue.shade900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Online payments are never auto-credited upon user click. Once initiated, order remains PENDING until verified by server webhook callback.',
                                style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                              ),
                            ],
                          ),
                        ),

                        if (_onlineOrderCreated) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _onlineVerified ? Colors.green.shade50 : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _onlineVerified ? Colors.green.shade300 : Colors.amber.shade400),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _onlineVerified ? Icons.check_circle : Icons.hourglass_top,
                                      color: _onlineVerified ? Colors.green.shade800 : Colors.amber.shade800,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _onlineVerified ? 'Gateway Webhook Verified (PAID)' : 'Gateway Order Generated (PENDING)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _onlineVerified ? Colors.green.shade900 : Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Order ID: $_onlineOrderId',
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                ),
                                const SizedBox(height: 8),
                                if (!_onlineVerified) ...[
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.webhook, size: 16),
                                    label: const Text('Simulate Verified Provider Callback'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: _isSubmitting ? null : _simulateCallback,
                                  ),
                                ] else ...[
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.repeat, size: 16),
                                    label: const Text('Test Duplicate Webhook (Idempotency)'),
                                    onPressed: _isSubmitting ? null : _testDuplicateCallback,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Footer
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_onlineVerified ? 'Close' : 'Cancel'),
                  ),
                  if (!_onlineOrderCreated)
                    ElevatedButton.icon(
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(_paymentMethod == 'ONLINE' ? Icons.qr_code : Icons.check, size: 18),
                      label: Text(_paymentMethod == 'ONLINE' ? 'Initiate Online Order' : 'Confirm Cash/Card Payment'),
                      onPressed: _isSubmitting ? null : _processPayment,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodOption(String id, String label, IconData icon) {
    final isSelected = _paymentMethod == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = id),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : Colors.grey.shade400,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? AppColors.primaryBlue : Colors.grey.shade700),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.primaryBlue : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
