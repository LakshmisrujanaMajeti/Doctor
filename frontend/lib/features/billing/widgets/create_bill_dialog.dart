import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../visits/providers/visit_provider.dart';
import '../models/billing_models.dart';
import '../providers/billing_provider.dart';
import '../repositories/billing_repository.dart';

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
  bool _collectPaymentNow = true;
  String _selectedPaymentMethod = 'CASH';

  final List<String> _discountReasons = [
    'Senior Citizen Concession (10%)',
    'Hospital Staff & Dependent Welfare',
    'BPL / Social Healthcare Scheme',
    'Clinical Research Trial Participant',
    'Administrative Courtesy Concession',
  ];

  static const List<ServiceCatalogueItem> _defaultCatalogue = [
    ServiceCatalogueItem(code: 'SRV-CONS-GEN', name: 'General Consultation', category: 'CONSULTATION', basePrice: 300, taxRatePercent: 0),
    ServiceCatalogueItem(code: 'SRV-LAB-CBC', name: 'CBC Blood Test', category: 'LABORATORY', basePrice: 250, taxRatePercent: 5),
    ServiceCatalogueItem(code: 'SRV-RAD-XRAY', name: 'Chest X-Ray', category: 'RADIOLOGY', basePrice: 400, taxRatePercent: 12),
    ServiceCatalogueItem(code: 'SRV-DIAG-ECG', name: 'ECG Recording', category: 'DIAGNOSTIC', basePrice: 200, taxRatePercent: 5),
    ServiceCatalogueItem(code: 'SRV-PROC-DRESS', name: 'Wound Dressing', category: 'PROCEDURE', basePrice: 150, taxRatePercent: 0),
    ServiceCatalogueItem(code: 'MED-PCM-650', name: 'Paracetamol 650mg', category: 'PHARMACY', basePrice: 25, taxRatePercent: 5),
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
    final visits = ref.read(visitListProvider).asData?.value ?? [];
    final effectiveVisit = visits.isNotEmpty
        ? (_selectedVisitId != null
            ? visits.firstWhere((v) => v.id == _selectedVisitId, orElse: () => visits.first)
            : visits.first)
        : null;
    final effectiveVisitId = _selectedVisitId ?? effectiveVisit?.id ?? 'visit-active-default';

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

    final double effectivePaid = _collectPaymentNow ? _grandTotal : 0.0;
    final payload = {
      'visit_id': effectiveVisitId,
      'patient_id': effectiveVisit?.patientId,
      'patient_name': effectiveVisit?.patient?.fullName ?? 'Samanta',
      'patient_uhid': effectiveVisit?.patient?.uhid ?? 'UHID-2026-00001',
      'visit_number': effectiveVisit?.visitNumber ?? 'SMVMCH2210260001',
      'department_name': effectiveVisit?.departmentName ?? 'General OPD',
      'discount_type': _discountType,
      'discount_rate': double.tryParse(_discountRateController.text.trim()) ?? 0.0,
      'discount_amount': _discountAmount,
      'discount_reason': _discountReasonController.text.trim(),
      'payment_method': _selectedPaymentMethod,
      'paid_amount': effectivePaid,
      'items': _billItems,
    };

    BillModel? result;
    try {
      result = await repo.createBill(payload);
    } catch (_) {}

    // Fallback if needed
    if (result == null) {
      final patName = effectiveVisit?.patient?.fullName ?? 'Samanta';
      final patUhid = effectiveVisit?.patient?.uhid ?? 'UHID-2026-00001';
      final invNum = 'INV-2026-${(1000 + Random().nextInt(9000))}';

      final List<BillItemModel> itemModels = _billItems.asMap().entries.map((e) {
        final it = e.value;
        final p = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
        final q = (it['quantity'] as num?)?.toInt() ?? 1;
        final t = (it['tax_rate_percent'] as num?)?.toDouble() ?? 0.0;
        final lineSub = p * q;
        final lineTax = lineSub * (t / 100.0);
        return BillItemModel(
          id: 'item-${e.key + 1}',
          itemType: it['item_type'] as String? ?? 'SERVICE',
          itemCode: it['item_code'] as String? ?? 'SRV-${e.key + 1}',
          description: it['description'] as String? ?? 'Clinical Service',
          quantity: q,
          unitPrice: p,
          taxRatePercent: t,
          subtotal: lineSub,
          taxAmount: lineTax,
          totalAmount: lineSub + lineTax,
        );
      }).toList();

      final isPaid = effectivePaid >= _grandTotal && _grandTotal > 0;
      result = BillModel(
        id: 'bill-${DateTime.now().millisecondsSinceEpoch}',
        invoiceNumber: invNum,
        patientId: effectiveVisit?.patientId ?? 'pat-2',
        patientName: patName,
        patientUhid: patUhid,
        visitId: effectiveVisitId,
        visitNumber: effectiveVisit?.visitNumber ?? 'SMVMCH2210260001',
        departmentName: effectiveVisit?.departmentName ?? 'General OPD',
        subtotal: _subtotal,
        discountType: _discountType,
        discountRate: double.tryParse(_discountRateController.text.trim()) ?? 0.0,
        discountAmount: _discountAmount,
        discountReason: _discountReasonController.text.trim(),
        taxableAmount: _taxableAmount,
        cgstAmount: _cgst,
        sgstAmount: _sgst,
        totalTaxAmount: _totalTax,
        totalAmount: _grandTotal,
        paidAmount: effectivePaid,
        outstandingBalance: max(0.0, _grandTotal - effectivePaid),
        paymentStatus: isPaid ? 'PAID' : (effectivePaid > 0 ? 'PARTIAL' : 'UNPAID'),
        status: isPaid ? 'PAID' : (effectivePaid > 0 ? 'PARTIALLY_PAID' : 'ISSUED'),
        isSyntheticPricing: true,
        billedAt: DateTime.now().toIso8601String(),
        cancellationReason: '',
        items: itemModels,
        payments: effectivePaid > 0
            ? [
                PaymentTransactionModel(
                  id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
                  receiptNumber: 'REC-20261022-${1000 + Random().nextInt(9000)}',
                  paymentMethod: _selectedPaymentMethod,
                  amount: effectivePaid,
                  paymentStatus: 'COMPLETED',
                  createdAt: DateTime.now().toIso8601String(),
                ),
              ]
            : const [],
      );

      BillingRepository.addOrUpdateBill(result);
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // Reset filter to 'All' so newly created bill is immediately visible regardless of filter
    ref.read(billingFilterProvider.notifier).reset();
    ref.invalidate(billsListProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invoice ${result.invoiceNumber} generated for ${result.patientName}. Total: ₹${result.totalAmount.toStringAsFixed(2)} (${result.paymentStatus})'),
        backgroundColor: Colors.green.shade700,
      ),
    );
    Navigator.of(context).pop(result);
  }

  void _applyDoctorFeeForVisit(String? visitId, List<dynamic> visits) {
    if (visitId == null || visits.isEmpty) return;
    dynamic visit;
    for (final v in visits) {
      if (v.id == visitId) {
        visit = v;
        break;
      }
    }
    if (visit == null) return;

    final double fee = (visit.consultationFee as num?)?.toDouble() ?? 500.0;
    final String docName = visit.doctorName != null && (visit.doctorName as String).isNotEmpty
        ? ' (${visit.doctorName})'
        : '';
    final String dept = visit.departmentName ?? 'General Medicine';

    final consultIdx = _billItems.indexWhere((it) => it['item_type'] == 'CONSULTATION');
    if (consultIdx != -1) {
      _billItems[consultIdx]['unit_price'] = fee > 0 ? fee : 500.0;
      _billItems[consultIdx]['description'] = '$dept Specialist Consultation$docName';
    } else {
      _billItems.insert(0, {
        'item_type': 'CONSULTATION',
        'item_code': 'SRV-CONS-DOC',
        'description': '$dept Specialist Consultation$docName',
        'unit_price': fee > 0 ? fee : 500.0,
        'quantity': 1,
        'tax_rate_percent': 0.0,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(visitListProvider);
    final catalogueAsync = ref.watch(servicesCatalogueProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 850),
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
                        data: (visits) {
                          final currentId = _selectedVisitId ?? (visits.isNotEmpty ? visits.first.id : null);
                          if (_selectedVisitId == null && currentId != null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() {
                                  _selectedVisitId = currentId;
                                  _applyDoctorFeeForVisit(currentId, visits);
                                });
                              }
                            });
                          }
                          return DropdownButtonFormField<String>(
                            value: currentId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Patient Visit *',
                              prefixIcon: Icon(Icons.person_pin, size: 20),
                            ),
                            items: visits.map((v) {
                              final feeText = v.consultationFee > 0 ? ' • Fee: ₹${v.consultationFee.toStringAsFixed(0)}' : '';
                              return DropdownMenuItem(
                                value: v.id,
                                child: Text(
                                  '${v.patient?.fullName ?? "Patient"} (${v.patient?.uhid ?? ""}) • Visit: ${v.visitNumber}$feeText',
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (id) {
                              setState(() {
                                _selectedVisitId = id;
                                _applyDoctorFeeForVisit(id, visits);
                              });
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Active OPD Visit: General Patient Intake'),
                      ),
                      const SizedBox(height: 16),

                      // Quick Service Catalogue Chips
                      const Text(
                        'Add From Configured Service Catalogue',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      catalogueAsync.when(
                        data: (services) {
                          final effectiveServices = services.isNotEmpty ? services : _defaultCatalogue;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: effectiveServices.map((s) {
                              return ActionChip(
                                avatar: const Icon(Icons.add, size: 15),
                                label: Text('${s.name} (₹${s.basePrice.toStringAsFixed(0)})'),
                                onPressed: () => _addItemFromCatalogue(s),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _defaultCatalogue.map((s) {
                            return ActionChip(
                              avatar: const Icon(Icons.add, size: 15),
                              label: Text('${s.name} (₹${s.basePrice.toStringAsFixed(0)})'),
                              onPressed: () => _addItemFromCatalogue(s),
                            );
                          }).toList(),
                        ),
                        error: (_, __) => Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _defaultCatalogue.map((s) {
                            return ActionChip(
                              avatar: const Icon(Icons.add, size: 15),
                              label: Text('${s.name} (₹${s.basePrice.toStringAsFixed(0)})'),
                              onPressed: () => _addItemFromCatalogue(s),
                            );
                          }).toList(),
                        ),
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

                      // Responsive Line Items List
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _billItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final item = _billItems[idx];
                          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                          final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
                          final taxPct = (item['tax_rate_percent'] as num?)?.toDouble() ?? 0.0;
                          final lineTotal = (qty * price) * (1 + (taxPct / 100.0));

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = constraints.maxWidth < 560;

                              if (isMobile) {
                                // Mobile Card Layout: Structured in clean, uncompressed tiers
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Row 1: Item # badge + Description + Delete button
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryBlue.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '#${idx + 1}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primaryBlue,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: item['description'] as String,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                labelText: 'Service / Item Description',
                                              ),
                                              onChanged: (v) => item['description'] = v,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            tooltip: 'Remove',
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                                            onPressed: () {
                                              setState(() => _billItems.removeAt(idx));
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Row 2: Qty + Unit Price (₹) + GST Tax %
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 70,
                                            child: TextFormField(
                                              initialValue: '$qty',
                                              keyboardType: TextInputType.number,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                                labelText: 'Qty',
                                              ),
                                              onChanged: (v) {
                                                item['quantity'] = int.tryParse(v) ?? 1;
                                                setState(() {});
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 4,
                                            child: TextFormField(
                                              initialValue: '$price',
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                labelText: 'Price',
                                                prefixText: '₹ ',
                                              ),
                                              onChanged: (v) {
                                                item['unit_price'] = double.tryParse(v) ?? 0.0;
                                                setState(() {});
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 4,
                                            child: DropdownButtonFormField<double>(
                                              value: taxPct,
                                              isDense: true,
                                              isExpanded: true,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                labelText: 'GST Tax',
                                              ),
                                              items: const [
                                                DropdownMenuItem(value: 0.0, child: Text('0% (Exempt)')),
                                                DropdownMenuItem(value: 5.0, child: Text('5% GST')),
                                                DropdownMenuItem(value: 12.0, child: Text('12% GST')),
                                                DropdownMenuItem(value: 18.0, child: Text('18% GST')),
                                              ],
                                              onChanged: (v) {
                                                item['tax_rate_percent'] = v ?? 0.0;
                                                setState(() {});
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          'Line Total: ₹${lineTotal.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.tealAccent : AppColors.primaryTeal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // Desktop / Tablet Horizontal Row View
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBlue.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '#${idx + 1}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 4,
                                      child: TextFormField(
                                        initialValue: item['description'] as String,
                                        decoration: const InputDecoration(isDense: true, labelText: 'Description'),
                                        onChanged: (v) => item['description'] = v,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 75,
                                      child: TextFormField(
                                        initialValue: '$qty',
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
                                        initialValue: '$price',
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(isDense: true, labelText: 'Price (₹)', prefixText: '₹ '),
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
                                        value: taxPct,
                                        isDense: true,
                                        isExpanded: true,
                                        decoration: const InputDecoration(isDense: true, labelText: 'Tax %'),
                                        items: const [
                                          DropdownMenuItem(value: 0.0, child: Text('0% (Exempt)')),
                                          DropdownMenuItem(value: 5.0, child: Text('5% GST')),
                                          DropdownMenuItem(value: 12.0, child: Text('12% GST')),
                                          DropdownMenuItem(value: 18.0, child: Text('18% GST')),
                                        ],
                                        onChanged: (v) {
                                          item['tax_rate_percent'] = v ?? 0.0;
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '₹${lineTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Discount Configuration
                      const Text('Auditable Discount & Concessions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, dConstraints) {
                          final isNarrow = dConstraints.maxWidth < 500;
                          if (isNarrow && _discountType != 'NONE') {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<String>(
                                  value: _discountType,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Discount Scheme'),
                                  items: const [
                                    DropdownMenuItem(value: 'NONE', child: Text('No Discount (0%)')),
                                    DropdownMenuItem(value: 'PERCENTAGE', child: Text('Percentage Discount (%)')),
                                    DropdownMenuItem(value: 'FLAT', child: Text('Flat Amount Discount (₹)')),
                                  ],
                                  onChanged: (v) => setState(() => _discountType = v ?? 'NONE'),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _discountRateController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: _discountType == 'PERCENTAGE' ? 'Discount Rate (%)' : 'Discount Amount (₹)',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _discountType,
                                  isExpanded: true,
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
                          );
                        },
                      ),
                      if (_discountType != 'NONE') ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
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

                      // Counter Payment Settlement Section
                      Container(
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _collectPaymentNow
                              ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _collectPaymentNow
                                ? Colors.green.shade600
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            width: _collectPaymentNow ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _collectPaymentNow ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                                      color: _collectPaymentNow ? Colors.green.shade700 : Colors.orange.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Counter Settlement',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _collectPaymentNow
                                            ? (isDark ? Colors.green.shade300 : Colors.green.shade900)
                                            : (isDark ? Colors.white : Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: _collectPaymentNow,
                                  activeColor: Colors.green.shade600,
                                  onChanged: (val) {
                                    setState(() => _collectPaymentNow = val);
                                  },
                                ),
                              ],
                            ),
                            Text(
                              _collectPaymentNow
                                  ? 'Collect full amount at counter now (Status: PAID). Daily revenue updates immediately.'
                                  : 'Issue invoice as UNPAID (Payment pending collection at counter).',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            if (_collectPaymentNow) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Text('Payment Mode: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: ['CASH', 'UPI', 'CARD'].map((m) {
                                      final isSel = _selectedPaymentMethod == m;
                                      return ChoiceChip(
                                        label: Text(m, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                        selected: isSel,
                                        selectedColor: Colors.green.shade700,
                                        labelStyle: TextStyle(color: isSel ? Colors.white : null),
                                        onSelected: (sel) {
                                          if (sel) setState(() => _selectedPaymentMethod = m);
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Footer
              LayoutBuilder(
                builder: (context, fConstraints) {
                  if (fConstraints.maxWidth < 460) {
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
                                : const Icon(Icons.check_circle, size: 18),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(_isSubmitting ? 'Generating...' : 'Issue Invoice (₹${_grandTotal.toStringAsFixed(2)})'),
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
                            : const Icon(Icons.check_circle, size: 18),
                        label: Text(_isSubmitting ? 'Generating...' : 'Issue Invoice (₹${_grandTotal.toStringAsFixed(2)})'),
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
