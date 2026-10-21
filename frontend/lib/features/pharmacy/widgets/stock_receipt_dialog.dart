import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
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
      initialDate: _expiryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final repo = ref.read(pharmacyRepositoryProvider);

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
    setState(() => _isSubmitting = false);

    if (result != null) {
      ref.invalidate(pharmacyInventoryListProvider);
      ref.invalidate(pharmacyStatsProvider);
      ref.invalidate(pharmacyStockMovementsProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully received ${result.availableQuantity} units of ${result.name} (Batch: ${result.batchNumber})'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to receive stock. Please verify the batch details.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
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
                    onPressed: () => Navigator.of(context).pop(),
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
              const SizedBox(height: 16),

              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
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
                        const SizedBox(height: 12),
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
                                decoration: const InputDecoration(labelText: 'Dosage Form'),
                                items: _dosageForms
                                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                                    .toList(),
                                onChanged: (val) => setState(() => _dosageForm = val ?? 'Tablet'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
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
                                    prefixIcon: Icon(Icons.calendar_today, size: 18),
                                  ),
                                  child: Text(
                                    '${_expiryDate.year}-${_expiryDate.month.toString().padLeft(2, '0')}-${_expiryDate.day.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _quantityController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Quantity (Units) *',
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
                                controller: _unitPriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Unit Price (₹ Synthetic) *',
                                  prefixIcon: Icon(Icons.currency_rupee, size: 18),
                                ),
                                validator: (val) {
                                  final d = double.tryParse(val ?? '');
                                  if (d == null || d < 0) return 'Must be >= 0';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _taxClassification,
                                decoration: const InputDecoration(labelText: 'Tax (GST)'),
                                items: _taxClassifications
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t.replaceFirst('GST_', 'GST ')+'%')))
                                    .toList(),
                                onChanged: (val) => setState(() => _taxClassification = val ?? 'GST_12'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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
                                  labelText: 'Purchase Order / Invoice Ref',
                                  prefixIcon: Icon(Icons.receipt_long, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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
      ),
    );
  }
}
