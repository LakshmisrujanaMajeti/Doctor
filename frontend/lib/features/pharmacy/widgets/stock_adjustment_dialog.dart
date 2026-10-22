import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../models/pharmacy_models.dart';
import '../providers/pharmacy_provider.dart';

class StockAdjustmentDialog extends ConsumerStatefulWidget {
  final MedicineInventoryItem? initialItem;

  const StockAdjustmentDialog({super.key, this.initialItem});

  @override
  ConsumerState<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();

  MedicineInventoryItem? _selectedItem;
  String _adjustmentType = 'SUBTRACT';
  final _quantityController = TextEditingController(text: '5');
  final _reasonController = TextEditingController();
  final _referenceController = TextEditingController();
  String _reasonCategory = 'Damaged packaging';
  bool _isSubmitting = false;

  final List<String> _reasonOptions = [
    'Damaged packaging',
    'Stocktake discrepancy reconciliation',
    'Expired batch write-off',
    'Spill or breakage loss',
    'Clinical trial return',
    'Other audit adjustment',
  ];

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.initialItem;
    _reasonController.text = _reasonCategory;
    _referenceController.text = 'ADJ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an inventory item to adjust')),
      );
      return;
    }

    final qty = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (_adjustmentType == 'SUBTRACT' && qty > _selectedItem!.availableQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot subtract $qty units. Available stock is only ${_selectedItem!.availableQuantity}.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final repo = ref.read(pharmacyRepositoryProvider);

    final payload = {
      'inventory_id': _selectedItem!.id,
      'adjustment_type': _adjustmentType,
      'quantity': qty,
      'reason': _reasonController.text.trim(),
      'reference_number': _referenceController.text.trim(),
    };

    final result = await repo.adjustStock(payload);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      ref.invalidate(pharmacyInventoryListProvider);
      ref.invalidate(pharmacyStatsProvider);
      ref.invalidate(pharmacyStockMovementsProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock adjusted for ${_selectedItem!.name}. New balance: ${result["available_quantity"]} units'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adjustment failed. Please check parameters and try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(pharmacyInventoryListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
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
                      color: Colors.amber.shade600.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.tune_rounded, color: Colors.amber.shade800, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stock Adjustment & Audit',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Record audited inventory additions or deductions',
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

              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Medicine Select
                        if (widget.initialItem == null) ...[
                          inventoryAsync.when(
                            data: (items) => DropdownButtonFormField<String>(
                              value: _selectedItem?.id,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Select Medicine Batch *',
                                prefixIcon: Icon(Icons.medication_outlined, size: 18),
                              ),
                              items: items.map((item) {
                                return DropdownMenuItem(
                                  value: item.id,
                                  child: Text(
                                    '${item.name} (Batch: ${item.batchNumber}) • Stock: ${item.availableQuantity}',
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (id) {
                                setState(() {
                                  _selectedItem = items.firstWhere((i) => i.id == id);
                                });
                              },
                              validator: (val) => val == null ? 'Please select a batch' : null,
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (_, __) => const Text('Error loading inventory'),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.medication, color: AppColors.primaryBlue),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedItem!.name,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                      Text(
                                        'Batch: ${_selectedItem!.batchNumber} • Current Stock: ${_selectedItem!.availableQuantity} units',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Adjustment Type Toggle
                        const Text('Adjustment Action *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _adjustmentType = 'SUBTRACT'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: _adjustmentType == 'SUBTRACT'
                                        ? Colors.red.shade600.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _adjustmentType == 'SUBTRACT' ? Colors.red.shade600 : Colors.grey.shade400,
                                      width: _adjustmentType == 'SUBTRACT' ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.remove_circle_outline,
                                          color: _adjustmentType == 'SUBTRACT' ? Colors.red.shade700 : Colors.grey, size: 18),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Deduct Stock (-)',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: _adjustmentType == 'SUBTRACT' ? Colors.red.shade700 : Colors.grey.shade700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _adjustmentType = 'ADD'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: _adjustmentType == 'ADD'
                                        ? Colors.green.shade600.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _adjustmentType == 'ADD' ? Colors.green.shade600 : Colors.grey.shade400,
                                      width: _adjustmentType == 'ADD' ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_circle_outline,
                                          color: _adjustmentType == 'ADD' ? Colors.green.shade700 : Colors.grey, size: 18),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Add Stock (+)',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: _adjustmentType == 'ADD' ? Colors.green.shade700 : Colors.grey.shade700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Quantity & Audit Reference Layout
                        LayoutBuilder(
                          builder: (context, qConstraints) {
                            if (qConstraints.maxWidth < 440) {
                              // Stack vertically on narrow mobile screens
                              return Column(
                                children: [
                                  TextFormField(
                                    controller: _quantityController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Quantity to Adjust *',
                                      prefixIcon: Icon(Icons.numbers, size: 18),
                                    ),
                                    validator: (val) {
                                      final n = int.tryParse(val ?? '');
                                      if (n == null || n <= 0) return 'Quantity must be > 0';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _referenceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Audit Reference #',
                                      prefixIcon: Icon(Icons.receipt_outlined, size: 18),
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _quantityController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Quantity *',
                                      prefixIcon: Icon(Icons.numbers, size: 18),
                                    ),
                                    validator: (val) {
                                      final n = int.tryParse(val ?? '');
                                      if (n == null || n <= 0) return 'Must be > 0';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _referenceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Audit Reference #',
                                      prefixIcon: Icon(Icons.receipt_outlined, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        DropdownButtonFormField<String>(
                          value: _reasonCategory,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Standard Reason Category *'),
                          items: _reasonOptions.map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _reasonCategory = val;
                                _reasonController.text = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _reasonController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Specific Clinical / Audit Explanation *',
                            hintText: 'e.g. Blister seals broken during shelf reorganization',
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Explanation required' : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Actions
              LayoutBuilder(
                builder: (context, btnConstraints) {
                  if (btnConstraints.maxWidth < 420) {
                    return Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            icon: _isSubmitting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check, size: 18),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(_isSubmitting ? 'Adjusting...' : 'Save Adjustment'),
                            ),
                            onPressed: _isSubmitting ? null : _submit,
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
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
                        label: Text(_isSubmitting ? 'Adjusting...' : 'Save Adjustment'),
                        onPressed: _isSubmitting ? null : _submit,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
