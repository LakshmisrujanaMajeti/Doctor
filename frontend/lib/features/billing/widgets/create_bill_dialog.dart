import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../visits/providers/visit_provider.dart';
import '../models/billing_models.dart';
import '../providers/billing_provider.dart';

class CreateBillDialog extends ConsumerStatefulWidget {
  final String? initialVisitId;

  const CreateBillDialog({super.key, this.initialVisitId});

  @override
  ConsumerState<CreateBillDialog> createState() => _CreateBillDialogState();
}

class _CreateBillDialogState extends ConsumerState<CreateBillDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedVisitId;
  String _discountType = 'NONE'; // NONE, PERCENTAGE, FLAT
  final _discountRateController = TextEditingController(text: '0');
  final _discountReasonController = TextEditingController();

  final List<Map<String, dynamic>> _billItems = [];
  bool _isSubmitting = false;

  final List<String> _discountReasons = [
    'Senior Citizen Concession (10%)',
    'Hospital Staff & Dependent Welfare',
    'BPL / Social Healthcare Scheme',
    'Clinical Research Trial Participant',
    'Administrative Courtesy Concession',
  ];

  @override
  void initState() {
    super.initState();
    _selectedVisitId = widget.initialVisitId;

    // Add default consultation item
    _billItems.add({
      'item_type': 'CONSULTATION',
      'item_code': 'SRV-CONS-GEN',
      'description': 'General OPD Consultation',
      'unit_price': 300.0,
      'quantity': 1,
      'tax_rate_percent': 0.0,
    });
  }

  @override
  void dispose() {
    _discountRateController.dispose();
    _discountReasonController.dispose();
    super.dispose();
  }

  double get _subtotal {
    double sum = 0.0;
    for (final it in _billItems) {
      final p = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
      final q = (it['quantity'] as num?)?.toInt() ?? 1;
      sum += p * q;
    }
    return sum;
  }

  double get _discountAmount {
    final sub = _subtotal;
    if (_discountType == 'PERCENTAGE') {
      final rate = double.tryParse(_discountRateController.text) ?? 0.0;
      return double.parse(((sub * rate) / 100).toStringAsFixed(2));
    } else if (_discountType == 'FLAT') {
      final amt = double.tryParse(_discountRateController.text) ?? 0.0;
      return amt > sub ? sub : amt;
    }
    return 0.0;
  }

  double get _taxableAmount => double.parse((_subtotal - _discountAmount).toStringAsFixed(2));

  double get _totalTax {
    double tax = 0.0;
    final sub = _subtotal;
    final disc = _discountAmount;
    final ratio = sub > 0 ? (sub - disc) / sub : 1.0;

    for (final it in _billItems) {
      final p = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
      final q = (it['quantity'] as num?)?.toInt() ?? 1;
      final t = (it['tax_rate_percent'] as num?)?.toDouble() ?? 0.0;
      final lineSub = p * q;
      final lineTaxable = lineSub * ratio;
      tax += lineTaxable * (t / 100.0);
    }
    return double.parse(tax.toStringAsFixed(2));
  }

  double get _cgst => double.parse((_totalTax / 2.0).toStringAsFixed(2));
  double get _sgst => double.parse((_totalTax / 2.0).toStringAsFixed(2));
  double get _grandTotal => double.parse((_taxableAmount + _totalTax).toStringAsFixed(2));

  void _addItemFromCatalogue(ServiceCatalogueItem service) {
    setState(() {
      _billItems.add({
        'item_type': service.category,
        'item_code': service.code,
        'description': service.name,
        'unit_price': service.basePrice,
        'quantity': 1,
        'tax_rate_percent': service.taxRatePercent,
      });
    });
  }

  Future<void> _submit() async {
    if (_selectedVisitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an active patient visit')),
      );
      return;
    }
    if (_billItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item to the bill')),
      );
      return;
    }
    if (_discountType != 'NONE' && _discountReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount reason is mandatory when discount is configured')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final repo = ref.read(billingRepositoryProvider);

    final payload = {
      'visit_id': _selectedVisitId,
      'discount_type': _discountType,
      'discount_rate': double.tryParse(_discountRateController.text.trim()) ?? 0.0,
      'discount_reason': _discountReasonController.text.trim(),
      'payment_method': 'CASH',
      'paid_amount': 0.0,
      'items': _billItems,
    };

    final result = await repo.createBill(payload);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      ref.invalidate(billsListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice ${result.invoiceNumber} generated for ${result.patientName}. Total: ₹${result.totalAmount.toStringAsFixed(2)}'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).pop(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate invoice. Please check visit details.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(visitListProvider);
    final catalogueAsync = ref.watch(servicesCatalogueProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 820),
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
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryBlue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Generate Itemized OPD Bill',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Configure itemized services, medicines, taxes, and auditable discounts',
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
              const SizedBox(height: 10),

              // Synthetic notice
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade500.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade600.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Synthetic Pricing Environment: All service tariffs and tax slabs are synthetic for development.',
                        style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Visit Selector
                      visitsAsync.when(
                        data: (visits) => DropdownButtonFormField<String>(
                          value: _selectedVisitId ?? (visits.isNotEmpty ? visits.first.id : null),
                          decoration: const InputDecoration(
                            labelText: 'Patient Visit *',
                            prefixIcon: Icon(Icons.person_pin, size: 20),
                          ),
                          items: visits.map((v) {
                            return DropdownMenuItem(
                              value: v.id,
                              child: Text(
                                '${v.patient?.fullName ?? "Patient"} (${v.patient?.uhid ?? ""}) • Visit: ${v.visitNumber} • Dept: ${v.departmentName ?? "General"}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (id) => setState(() => _selectedVisitId = id),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Failed to load patient visits'),
                      ),
                      const SizedBox(height: 16),

                      // Quick Service Catalogue Chips
                      const Text(
                        'Add From Configured Service Catalogue',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      catalogueAsync.when(
                        data: (services) => Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: services.map((s) {
                            return ActionChip(
                              avatar: const Icon(Icons.add, size: 15),
                              label: Text('${s.name} (₹${s.basePrice.toStringAsFixed(0)})'),
                              onPressed: () => _addItemFromCatalogue(s),
                            );
                          }).toList(),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),

                      // Line Items Table
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Itemized Line Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Custom Item'),
                            onPressed: () {
                              setState(() {
                                _billItems.add({
                                  'item_type': 'SERVICE',
                                  'item_code': 'SRV-CUSTOM-${_billItems.length + 1}',
                                  'description': 'Additional Clinical Service',
                                  'unit_price': 100.0,
                                  'quantity': 1,
                                  'tax_rate_percent': 5.0,
                                });
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _billItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final item = _billItems[idx];

                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    initialValue: item['description'] as String,
                                    decoration: const InputDecoration(isDense: true, labelText: 'Description'),
                                    onChanged: (v) => item['description'] = v,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    initialValue: '${item['quantity']}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(isDense: true, labelText: 'Qty'),
                                    onChanged: (v) {
                                      item['quantity'] = int.tryParse(v) ?? 1;
                                      setState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: '${item['unit_price']}',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(isDense: true, labelText: 'Price (₹)'),
                                    onChanged: (v) {
                                      item['unit_price'] = double.tryParse(v) ?? 0.0;
                                      setState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<double>(
                                    value: (item['tax_rate_percent'] as num).toDouble(),
                                    decoration: const InputDecoration(isDense: true, labelText: 'Tax %'),
                                    items: const [
                                      DropdownMenuItem(value: 0.0, child: Text('0% (Exempt)')),
                                      DropdownMenuItem(value: 5.0, child: Text('5% (GST)')),
                                      DropdownMenuItem(value: 12.0, child: Text('12% (GST)')),
                                      DropdownMenuItem(value: 18.0, child: Text('18% (GST)')),
                                    ],
                                    onChanged: (v) {
                                      item['tax_rate_percent'] = v ?? 0.0;
                                      setState(() {});
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () {
                                    setState(() => _billItems.removeAt(idx));
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Discount Configuration
                      const Text('Auditable Discount & Concessions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _discountType,
                              decoration: const InputDecoration(labelText: 'Discount Scheme'),
                              items: const [
                                DropdownMenuItem(value: 'NONE', child: Text('No Discount (0%)')),
                                DropdownMenuItem(value: 'PERCENTAGE', child: Text('Percentage Discount (%)')),
                                DropdownMenuItem(value: 'FLAT', child: Text('Flat Amount Discount (₹)')),
                              ],
                              onChanged: (v) => setState(() => _discountType = v ?? 'NONE'),
                            ),
                          ),
                          if (_discountType != 'NONE') ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _discountRateController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: _discountType == 'PERCENTAGE' ? 'Discount Rate (%)' : 'Discount Amount (₹)',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_discountType != 'NONE') ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Select Policy Reason *'),
                          items: _discountReasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              _discountReasonController.text = v;
                              if (v.contains('10%')) {
                                _discountRateController.text = '10';
                              }
                              setState(() {});
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _discountReasonController,
                          decoration: const InputDecoration(
                            labelText: 'Auditable Reason Explanation *',
                            hintText: 'e.g. Approved under Senior Citizen Concession guidelines',
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Arithmetic Summary Table
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildSummaryRow('Subtotal Base Price:', '₹${_subtotal.toStringAsFixed(2)}'),
                            if (_discountAmount > 0)
                              _buildSummaryRow(
                                'Discount Applied (${_discountType == "PERCENTAGE" ? "${_discountRateController.text}%" : "Flat"}):',
                                '- ₹${_discountAmount.toStringAsFixed(2)}',
                                color: Colors.green.shade700,
                              ),
                            _buildSummaryRow('Taxable Amount:', '₹${_taxableAmount.toStringAsFixed(2)}'),
                            const Divider(height: 12),
                            _buildSummaryRow('CGST (Central Tax):', '₹${_cgst.toStringAsFixed(2)}'),
                            _buildSummaryRow('SGST (State Tax):', '₹${_sgst.toStringAsFixed(2)}'),
                            _buildSummaryRow('Total GST Components:', '₹${_totalTax.toStringAsFixed(2)}'),
                            const Divider(height: 14),
                            _buildSummaryRow(
                              'NET INVOICE TOTAL:',
                              '₹${_grandTotal.toStringAsFixed(2)}',
                              isBold: true,
                              fontSize: 16,
                              color: AppColors.primaryBlue,
                            ),
                          ],
                        ),
                      ),
                    ],
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
                        : const Icon(Icons.check_circle, size: 18),
                    label: Text(_isSubmitting ? 'Generating...' : 'Issue Invoice (₹${_grandTotal.toStringAsFixed(2)})'),
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

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500)),
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
