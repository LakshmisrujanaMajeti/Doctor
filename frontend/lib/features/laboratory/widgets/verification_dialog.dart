import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/laboratory_models.dart';
import '../providers/laboratory_provider.dart';

class VerificationDialog extends ConsumerStatefulWidget {
  final LabOrderModel order;

  const VerificationDialog({super.key, required this.order});

  @override
  ConsumerState<VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends ConsumerState<VerificationDialog> {
  final _notesController = TextEditingController();
  bool _publishToVisit = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(laboratoryRepositoryProvider);
      await repo.verifyOrder(
        orderId: widget.order.id,
        verificationNotes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        publishToVisit: _publishToVisit,
      );

      ref.invalidate(labOrdersListProvider);
      ref.invalidate(labDashboardStatsProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order verified and published to patient OPD visit record'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAbnormal = widget.order.results.any((r) => r.isAbnormal || r.isCritical);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                    color: Colors.green.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user_rounded, color: Colors.green, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pathologist Verification & Sign-off',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Order: ${widget.order.orderNumber} | Specimen: ${widget.order.specimenId ?? "--"}',
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

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient banner
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Patient: ${widget.order.patientName}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'UHID: ${widget.order.uhid}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Results Summary Card
                    const Text('Test Results Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(3),
                          1: FlexColumnWidth(2),
                          2: FlexColumnWidth(2),
                          3: FlexColumnWidth(2),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.shade100),
                            children: const [
                              Padding(padding: EdgeInsets.all(8), child: Text('Test/Param', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Result', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                            ],
                          ),
                          ...widget.order.results.map((r) {
                            final isCrit = r.isCritical || r.flag == 'CRITICAL';
                            final isAbn = r.isAbnormal || r.flag == 'ABNORMAL' || isCrit;

                            return TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.all(8), child: Text(r.parameterName, style: const TextStyle(fontSize: 12))),
                                Padding(padding: const EdgeInsets.all(8), child: Text(r.valueText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isCrit ? Colors.red : (isAbn ? Colors.orange.shade900 : Colors.black)))),
                                Padding(padding: const EdgeInsets.all(8), child: Text(r.unit.isNotEmpty ? r.unit : '-', style: const TextStyle(fontSize: 11.5, color: Colors.black54))),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    r.flag,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isCrit ? Colors.red : (isAbn ? Colors.orange.shade800 : Colors.green.shade700),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Abnormal warning banner if any
                    if (hasAbnormal)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Alert: Abnormal/Critical values detected. Verify specimen identity and clinical consistency.',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),

                    // Pathologist verification remarks
                    const Text('Verification Remarks / Pathologist Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g., Results verified. Correlated with clinical findings.',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Publish checkbox
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _publishToVisit,
                      title: const Text(
                        'Publish verified results to OPD Visit record',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Authorized clinician will be able to review these results immediately.',
                        style: TextStyle(fontSize: 11.5, color: Colors.black54),
                      ),
                      onChanged: (val) {
                        setState(() => _publishToVisit = val ?? true);
                      },
                    ),
                  ],
                ),
              ),
            ),

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
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Sign & Publish'),
                    onPressed: _isLoading ? null : _submit,
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
