import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../models/laboratory_models.dart';
import '../providers/laboratory_provider.dart';

class ResultEntryDialog extends ConsumerStatefulWidget {
  final LabOrderModel order;

  const ResultEntryDialog({super.key, required this.order});

  @override
  ConsumerState<ResultEntryDialog> createState() => _ResultEntryDialogState();
}

class _ResultRowData {
  final TextEditingController paramController;
  final TextEditingController valueController;
  final TextEditingController unitController;
  final TextEditingController refRangeController;
  String flag; // NORMAL, ABNORMAL, CRITICAL
  bool isCritical;

  _ResultRowData({
    required String param,
    String value = '',
    String unit = '',
    String refRange = '',
    this.flag = 'NORMAL',
    this.isCritical = false,
  })  : paramController = TextEditingController(text: param),
        valueController = TextEditingController(text: value),
        unitController = TextEditingController(text: unit),
        refRangeController = TextEditingController(text: refRange);

  void dispose() {
    paramController.dispose();
    valueController.dispose();
    unitController.dispose();
    refRangeController.dispose();
  }
}

class _ResultEntryDialogState extends ConsumerState<ResultEntryDialog> {
  final List<_ResultRowData> _rows = [];
  bool _flagReview = false;
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initParameters();
  }

  void _initParameters() {
    // If order already has results, load them
    if (widget.order.results.isNotEmpty) {
      for (final r in widget.order.results) {
        _rows.add(_ResultRowData(
          param: r.parameterName,
          value: r.valueText,
          unit: r.unit,
          refRange: r.referenceRange,
          flag: r.flag,
          isCritical: r.isCritical,
        ));
      }
      _flagReview = widget.order.requiresReview;
      _initialized = true;
    } else {
      // Otherwise, load from catalogue definition
      _loadFromCatalogue();
    }
  }

  Future<void> _loadFromCatalogue() async {
    final repo = ref.read(laboratoryRepositoryProvider);
    final items = await repo.getCatalogue();
    final match = items.firstWhere(
      (item) => item.testName.toLowerCase() == widget.order.testName.toLowerCase(),
      orElse: () => LabCatalogueItem(
        id: '',
        category: widget.order.department,
        testName: widget.order.testName,
        sampleType: widget.order.specimenType,
        specimenTube: '',
      ),
    );

    if (match.parameters.isNotEmpty) {
      for (final p in match.parameters) {
        _rows.add(_ResultRowData(
          param: p.name,
          unit: p.defaultUnit,
          refRange: p.referenceRange,
        ));
      }
    } else {
      // Default to single test result row
      _rows.add(_ResultRowData(
        param: widget.order.testName,
        unit: '',
        refRange: '',
      ));
    }
    if (mounted) setState(() => _initialized = true);
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addNewRow() {
    setState(() {
      _rows.add(_ResultRowData(param: ''));
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      final removed = _rows.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _submit() async {
    // Validate that at least one value is entered
    final validEntries = _rows.where((r) => r.valueController.text.trim().isNotEmpty).toList();
    if (validEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter test results before submitting'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = _rows.map((r) {
        final isCrit = r.flag == 'CRITICAL';
        final isAbn = r.flag == 'ABNORMAL' || isCrit;
        return LabResultItemModel(
          parameterName: r.paramController.text.trim().isNotEmpty
              ? r.paramController.text.trim()
              : widget.order.testName,
          valueText: r.valueController.text.trim(),
          unit: r.unitController.text.trim(),
          referenceRange: r.refRangeController.text.trim(),
          isAbnormal: isAbn,
          isCritical: isCrit,
          flag: r.flag,
        );
      }).toList();

      // If any parameter is abnormal or critical, auto-flag for review
      final shouldReview = _flagReview || results.any((r) => r.isAbnormal || r.isCritical);

      final repo = ref.read(laboratoryRepositoryProvider);
      await repo.enterResults(
        orderId: widget.order.id,
        results: results,
        flagReview: shouldReview,
      );

      ref.invalidate(labOrdersListProvider);
      ref.invalidate(labDashboardStatsProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test results saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.biotech_rounded, color: AppColors.primaryBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter Results: ${widget.order.testName}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Patient: ${widget.order.patientName} (${widget.order.uhid}) | Ord: ${widget.order.orderNumber}',
                        style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const Divider(height: 20),

            // Content
            if (!_initialized)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Parameters table header
                      Row(
                        children: const [
                          Expanded(flex: 3, child: Text('Parameter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 6),
                          Expanded(flex: 2, child: Text('Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 6),
                          Expanded(flex: 2, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 6),
                          Expanded(flex: 2, child: Text('Ref Range', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 6),
                          Expanded(flex: 2, child: Text('Flag', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 28),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Rows
                      ..._rows.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final row = entry.value;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Parameter Name
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: row.paramController,
                                  style: const TextStyle(fontSize: 12.5),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    hintText: 'Parameter',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Value
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: row.valueController,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    hintText: 'Value',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Unit
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: row.unitController,
                                  style: const TextStyle(fontSize: 12),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    hintText: 'Unit',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Reference Range
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: row.refRangeController,
                                  style: const TextStyle(fontSize: 11.5),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    hintText: 'Configured Ref',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Flag Dropdown
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: row.flag,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'NORMAL',
                                      child: Text('Norm', style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                                    ),
                                    DropdownMenuItem(
                                      value: 'ABNORMAL',
                                      child: Text('Abn', style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                                    ),
                                    DropdownMenuItem(
                                      value: 'CRITICAL',
                                      child: Text('Crit', style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        row.flag = val;
                                        if (val != 'NORMAL') _flagReview = true;
                                      });
                                    }
                                  },
                                ),
                              ),

                              // Remove button
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.redAccent),
                                onPressed: _rows.length > 1 ? () => _removeRow(idx) : null,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        );
                      }),

                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Test Parameter', style: TextStyle(fontSize: 12)),
                        onPressed: _addNewRow,
                      ),

                      const SizedBox(height: 12),
                      const Divider(),

                      // Flag for review checkbox
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _flagReview,
                        title: const Text(
                          'Flag for Authorized Review by Pathologist',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Flags specimen for senior clinical verification prior to publishing to patient record',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                        onChanged: (val) {
                          setState(() => _flagReview = val ?? false);
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // Footer
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Results'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
