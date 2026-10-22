import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../models/billing_models.dart';
import '../providers/billing_provider.dart';

class RefundDialog extends ConsumerStatefulWidget {
  final BillModel bill;

  const RefundDialog({super.key, required this.bill});

  @override
  ConsumerState<RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends ConsumerState<RefundDialog> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  String _policyCategory = 'Service cancelled before execution';
  bool _isSubmitting = false;

  final List<String> _policyCategories = [
    'Service cancelled before execution',
    'Billing error / Duplicate charge reconciliation',
    'Early patient discharge',
    'Specialist clinician waiver approved',
    'Patient financial hardship concession',
  ];

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.bill.paidAmount.toStringAsFixed(2);
    _reasonController.text = _policyCategory;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitRefund() async {
    final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund amount must be greater than zero')),
      );
      return;
    }

    if (amt > widget.bill.paidAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot refund ₹$amt. Maximum refundable amount is ₹${widget.bill.paidAmount.toStringAsFixed(2)}.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auditable hospital policy reason is mandatory')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final repo = ref.read(billingRepositoryProvider);

    final payload = {
      'refund_amount': amt,
      'reason': _reasonController.text.trim(),
    };

    final result = await repo.processRefund(widget.bill.id, payload);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      ref.invalidate(billsListProvider);
      ref.invalidate(billDetailProvider(widget.bill.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refund of ₹${amt.toStringAsFixed(2)} processed successfully.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to process refund. Check policy constraints.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bill;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade600.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.currency_exchange_rounded, color: Colors.purple.shade700, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Process Refund (${b.invoiceNumber})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Patient: ${b.patientName} • Paid: ₹${b.paidAmount.toStringAsFixed(2)}',
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
              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Refund Amount (₹) *',
                          prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                          helperText: 'Maximum refundable: ₹${b.paidAmount.toStringAsFixed(2)}',
                        ),
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _policyCategory,
                        decoration: const InputDecoration(labelText: 'Hospital Policy Refund Reason *'),
                        items: _policyCategories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _policyCategory = val;
                              _reasonController.text = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _reasonController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Auditable Remarks & Justification *',
                          hintText: 'e.g. Procedure was rescheduled upon doctor recommendation',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 18),
                    label: Text(_isSubmitting ? 'Processing...' : 'Authorize Refund'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSubmitting ? null : _submitRefund,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
