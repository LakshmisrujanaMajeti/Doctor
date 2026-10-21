import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../models/pharmacy_models.dart';
import '../providers/pharmacy_provider.dart';

class DispensePrescriptionDialog extends ConsumerStatefulWidget {
  final PrescriptionForDispensing prescription;

  const DispensePrescriptionDialog({
    super.key,
    required this.prescription,
  });

  @override
  ConsumerState<DispensePrescriptionDialog> createState() => _DispensePrescriptionDialogState();
}

class _DispensePrescriptionDialogState extends ConsumerState<DispensePrescriptionDialog> {
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  // Selected batch inventory ID per prescription item
  final Map<String, String?> _selectedBatches = {};
  // Quantity to dispense per prescription item
  final Map<String, int> _quantities = {};
  // Counseling instructions per prescription item
  final Map<String, String> _instructions = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.prescription.items) {
      if (item.isDispensed) continue;

      // Pick first non-expired batch with stock if available
      final validBatches = item.availableBatches.where((b) => !b.isExpired && b.availableQuantity > 0).toList();
      if (validBatches.isNotEmpty) {
        _selectedBatches[item.id] = validBatches.first.inventoryId;
      }
      _quantities[item.id] = item.quantity > 0 ? item.quantity : 1;
      _instructions[item.id] = item.instructions.isNotEmpty ? item.instructions : '${item.timing} - ${item.dosage}';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _estimatedTotal {
    double total = 0.0;
    for (final item in widget.prescription.items) {
      final invId = _selectedBatches[item.id];
      final qty = _quantities[item.id] ?? 0;
      if (invId != null) {
        final batch = item.availableBatches.where((b) => b.inventoryId == invId).firstOrNull;
        if (batch != null) {
          total += batch.unitPrice * qty;
        }
      }
    }
    return total;
  }

  Future<void> _submitDispense() async {
    // Validate that at least one item has a selected batch and valid quantity
    final itemsToDispense = <Map<String, dynamic>>[];

    for (final item in widget.prescription.items) {
      if (item.isDispensed) continue;

      final invId = _selectedBatches[item.id];
      final qty = _quantities[item.id] ?? 0;

      if (invId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select an active inventory batch for ${item.medicineName}.'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
        return;
      }

      final batch = item.availableBatches.where((b) => b.inventoryId == invId).firstOrNull;
      if (batch == null || batch.isExpired) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot dispense expired batch for ${item.medicineName}.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (qty > batch.availableQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient stock for ${item.medicineName}: requested $qty, available ${batch.availableQuantity}.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      itemsToDispense.add({
        'prescription_item_id': item.id,
        'inventory_id': invId,
        'quantity_to_dispense': qty,
        'instructions': _instructions[item.id] ?? '',
      });
    }

    if (itemsToDispense.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items selected for dispensing.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final repo = ref.read(pharmacyRepositoryProvider);

    final payload = {
      'prescription_id': widget.prescription.id,
      'items': itemsToDispense,
      'notes': _notesController.text.trim(),
    };

    final result = await repo.dispensePrescription(payload);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      ref.invalidate(prescriptionsForDispensingProvider);
      ref.invalidate(pharmacyInventoryListProvider);
      ref.invalidate(pharmacyStatsProvider);
      ref.invalidate(pharmacyDispensesHistoryProvider);
      ref.invalidate(pharmacyStockMovementsProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dispensing ${result.dispenseNumber} successfully recorded with stock deduction.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dispensing failed. Check batch availability and prescription status.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rx = widget.prescription;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
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
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_pharmacy_rounded, color: AppColors.primaryBlue, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            const Text(
                              'Dispense Signed Prescription',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade600.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                rx.status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Patient: ${rx.patientName} (${rx.patientUhid}) • Prescribed by: ${rx.doctorName}',
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
              const SizedBox(height: 12),

              // Synthetic Notice Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade500.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade400.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_outlined, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Authorized clinical prescription. Stock will be deducted in real-time from selected batches.',
                        style: TextStyle(fontSize: 11.5, color: Colors.blue.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Medicine Items List
              Expanded(
                child: ListView.separated(
                  itemCount: rx.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = rx.items[index];
                    final isAlreadyDispensed = item.isDispensed;
                    final validBatches = item.availableBatches.where((b) => !b.isExpired).toList();
                    final selectedBatchId = _selectedBatches[item.id];

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isAlreadyDispensed
                              ? Colors.grey.shade400
                              : (validBatches.isEmpty ? Colors.red.shade300 : AppColors.primaryBlue.withValues(alpha: 0.3)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.medication, size: 18, color: AppColors.primaryBlue),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.medicineName} (${item.dosage})',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    Text(
                                      '${item.form} • ${item.route} • ${item.frequency} • ${item.durationDays} days • Prescribed Qty: ${item.quantity}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isAlreadyDispensed)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Already Dispensed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                          if (!isAlreadyDispensed) ...[
                            const Divider(height: 20),
                            if (item.availableBatches.isEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Out of stock: No matching inventory batches found in pharmacy.',
                                      style: TextStyle(fontSize: 12, color: Colors.red.shade800, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Batch Selector
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      value: selectedBatchId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Select Batch to Deduct *',
                                        isDense: true,
                                      ),
                                      items: item.availableBatches.map((b) {
                                        return DropdownMenuItem(
                                          value: b.inventoryId,
                                          enabled: !b.isExpired && b.availableQuantity > 0,
                                          child: Text(
                                            'Batch: ${b.batchNumber} • Stock: ${b.availableQuantity} • Exp: ${b.expiryDate}${b.isExpired ? " (EXPIRED)" : ""}',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: b.isExpired ? Colors.red : (b.availableQuantity == 0 ? Colors.grey : null),
                                              fontWeight: b.isExpired ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (id) {
                                        setState(() => _selectedBatches[item.id] = id);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Dispense Qty
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      initialValue: '${_quantities[item.id] ?? item.quantity}',
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Dispense Qty',
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        final q = int.tryParse(val) ?? 0;
                                        _quantities[item.id] = q;
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Counseling instructions
                              TextFormField(
                                initialValue: _instructions[item.id] ?? '',
                                decoration: const InputDecoration(
                                  labelText: 'Pharmacist Counseling / Timing Instructions',
                                  isDense: true,
                                  hintText: 'e.g. 1 tab after breakfast and dinner with warm water',
                                ),
                                onChanged: (val) => _instructions[item.id] = val,
                              ),
                            ],
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
              // Pharmacist Notes & Summary Bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Pharmacist Verification & Dispensing Notes',
                        hintText: 'e.g. Patient verified via barcode; allergic history confirmed clear',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Synthetic Medicines Tariff',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                        Text(
                          '₹${_estimatedTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primaryBlue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              // Actions
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
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(_isSubmitting ? 'Dispensing...' : 'Complete Dispensing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSubmitting ? null : _submitDispense,
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
