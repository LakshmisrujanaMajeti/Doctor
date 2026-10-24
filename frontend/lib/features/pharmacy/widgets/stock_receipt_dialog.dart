import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/field_validators.dart';
import '../providers/pharmacy_provider.dart';

class StockReceiptDialog extends ConsumerStatefulWidget {
  const StockReceiptDialog({super.key});

  @override
  ConsumerState<StockReceiptDialog> createState() => _StockReceiptDialogState();
}

class _StockReceiptDialogState extends ConsumerState<StockReceiptDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _genericNameController = TextEditingController();
  final _strengthController = TextEditingController(text: '500 mg');
  final _batchNumberController = TextEditingController();
  final _quantityController = TextEditingController(text: '100');
  final _unitPriceController = TextEditingController(text: '5.00');
  final _supplierController = TextEditingController(text: 'Apex Pharma Supplies');
  final _poRefController = TextEditingController(text: 'PO-');
  final _notesController = TextEditingController();

  String _dosageForm = 'Tablet';
  String _taxClassification = 'GST_12';
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  bool _isSubmitting = false;

  final List<String> _dosageForms = [
    'Tablet',
    'Capsule',
    'Syrup',
    'Injection',
    'Ointment',
    'Inhaler',
    'Drops',
  ];

  final List<String> _taxClassifications = [
    'GST_0',
    'GST_5',
    'GST_12',
    'GST_18',
    'GST_28',
  ];

  @override
  void initState() {
    super.initState();
    _poRefController.text = 'PO-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _genericNameController.dispose();
    _strengthController.dispose();
    _batchNumberController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _supplierController.dispose();
    _poRefController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate.isBefore(DateTime.now()) ? DateTime.now().add(const Duration(days: 30)) : _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    final expiryErr = FieldValidators.validateExpiryDate(_expiryDate);
    if (expiryErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(expiryErr)),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final repo = ref.read(pharmacyRepositoryProvider);

    try {
      final payload = {
        'name': _nameController.text.trim(),
        'generic_name': _genericNameController.text.trim().isEmpty ? null : _genericNameController.text.trim(),
        'strength': _strengthController.text.trim(),
        'dosage_form': _dosageForm,
        'batch_number': _batchNumberController.text.trim(),
        'expiry_date': _expiryDate.toIso8601String().split('T').first,
        'quantity': int.tryParse(_quantityController.text.trim()) ?? 1,
        'unit_price': double.tryParse(_unitPriceController.text.trim()) ?? 1.0,
        'tax_classification': _taxClassification,
        'supplier_name': _supplierController.text.trim(),
        'purchase_order_ref': _poRefController.text.trim(),
        'notes': _notesController.text.trim(),
      };

      final result = await repo.receiveStock(payload);
      if (!mounted) return;

      if (result != null) {
        ref.invalidate(pharmacyInventoryListProvider);
        ref.invalidate(pharmacyStatsProvider);
        ref.invalidate(pharmacyStockMovementsProvider);

        final dispName = result.name.isNotEmpty ? result.name : _nameController.text.trim();
        final dispBatch = result.batchNumber.isNotEmpty ? result.batchNumber : _batchNumberController.text.trim();
        final dispQty = result.availableQuantity > 0 ? result.availableQuantity : (int.tryParse(_quantityController.text.trim()) ?? 1);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully received $dispQty units of $dispName (Batch: $dispBatch)'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to receive stock. Please verify batch details or connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error receiving stock: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 520;

          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
            child: Padding(
              padding: EdgeInsets.all(isNarrow ? 16 : 24),
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
                        child: const Icon(Icons.inventory_2_rounded, color: AppColors.primaryBlue, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Stock Receipt (GRN)',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Receive new batch or replenish medicine inventory',
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
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Synthetic Price Notice Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            'Development Mode: Medicine prices and tax rates are synthetic and clearly tagged.',
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Form
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Medicine Name & Generic Name
                            if (isNarrow) ...[
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Medicine Name *',
                                  hintText: 'e.g. Paracetamol 650',
                                  prefixIcon: Icon(Icons.medication_outlined, size: 18),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _genericNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Generic Name',
                                  hintText: 'e.g. Paracetamol',
                                  prefixIcon: Icon(Icons.science_outlined, size: 18),
                                ),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: _nameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Medicine Name *',
                                        hintText: 'e.g. Paracetamol 650',
                                        prefixIcon: Icon(Icons.medication_outlined, size: 18),
                                      ),
                                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _genericNameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Generic Name',
                                        hintText: 'e.g. Paracetamol',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),

                            // 2. Strength & Dosage Form
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _strengthController,
                                    decoration: const InputDecoration(
                                      labelText: 'Strength *',
                                      hintText: 'e.g. 500 mg, 10 ml',
                                    ),
                                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _dosageForm,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Dosage Form'),
                                    items: _dosageForms
                                        .map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis)))
                                        .toList(),
                                    onChanged: (val) => setState(() => _dosageForm = val ?? 'Tablet'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 3. Batch Number & Expiry Date
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _batchNumberController,
                                    decoration: const InputDecoration(
                                      labelText: 'Batch Number *',
                                      hintText: 'e.g. BAT-2026-X1',
                                      prefixIcon: Icon(Icons.qr_code, size: 18),
                                    ),
                                    validator: (val) => FieldValidators.validateBatchNumber(val, isRequired: true),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: _pickExpiryDate,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Expiry Date *',
                                        prefixIcon: Icon(Icons.calendar_today, size: 16),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                      ),
                                      child: Text(
                                        '${_expiryDate.year}-${_expiryDate.month.toString().padLeft(2, '0')}-${_expiryDate.day.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 4. Quantity, Unit Price & Tax (GST)
                            if (isNarrow) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _quantityController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(6),
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Quantity (Units) *',
                                        prefixIcon: Icon(Icons.numbers, size: 18),
                                      ),
                                      validator: (val) => FieldValidators.validateQuantity(val, fieldName: 'Stock Quantity', isRequired: true),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _unitPriceController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        DecimalInputFormatter(),
                                        LengthLimitingTextInputFormatter(8),
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Unit Price (₹) *',
                                        prefixIcon: Icon(Icons.currency_rupee, size: 18),
                                      ),
                                      validator: (val) => FieldValidators.validatePrice(val, fieldName: 'Unit Price', isRequired: true),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _taxClassification,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Tax Classification (GST)',
                                  prefixIcon: Icon(Icons.receipt_outlined, size: 18),
                                ),
                                items: _taxClassifications
                                    .map((t) => DropdownMenuItem(
                                          value: t,
                                          child: Text('${t.replaceFirst('GST_', 'GST ')}% (Standard Healthcare Rate)'),
                                        ))
                                    .toList(),
                                onChanged: (val) => setState(() => _taxClassification = val ?? 'GST_12'),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _quantityController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(6),
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Quantity (Units) *',
                                        prefixIcon: Icon(Icons.numbers, size: 18),
                                      ),
                                      validator: (val) => FieldValidators.validateQuantity(val, fieldName: 'Stock Quantity', isRequired: true),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _unitPriceController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        DecimalInputFormatter(),
                                        LengthLimitingTextInputFormatter(8),
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Unit Price (₹) *',
                                        prefixIcon: Icon(Icons.currency_rupee, size: 18),
                                      ),
                                      validator: (val) => FieldValidators.validatePrice(val, fieldName: 'Unit Price', isRequired: true),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _taxClassification,
                                      isExpanded: true,
                                      decoration: const InputDecoration(labelText: 'Tax (GST)'),
                                      items: _taxClassifications
                                          .map((t) => DropdownMenuItem(
                                                value: t,
                                                child: Text('${t.replaceFirst('GST_', 'GST ')}%'),
                                              ))
                                          .toList(),
                                      onChanged: (val) => setState(() => _taxClassification = val ?? 'GST_12'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),

                            // 5. Supplier Name & PO Ref
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _supplierController,
                                    decoration: const InputDecoration(
                                      labelText: 'Supplier Name',
                                      hintText: 'e.g. Apex Pharma',
                                      prefixIcon: Icon(Icons.local_shipping_outlined, size: 18),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _poRefController,
                                    decoration: const InputDecoration(
                                      labelText: 'PO / Invoice Ref',
                                      prefixIcon: Icon(Icons.receipt_long, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 6. Notes
                            TextFormField(
                              controller: _notesController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Receipt Notes / Quality Check',
                                hintText: 'e.g. Inspected packaging integrity, storage under 25°C',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Footer
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
                        label: Text(_isSubmitting ? 'Receiving...' : 'Confirm Receipt'),
                        onPressed: _isSubmitting ? null : _submit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
