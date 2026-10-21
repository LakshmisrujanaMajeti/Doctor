import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/laboratory_models.dart';
import '../providers/laboratory_provider.dart';

class SpecimenCollectionDialog extends ConsumerStatefulWidget {
  final LabOrderModel order;

  const SpecimenCollectionDialog({super.key, required this.order});

  @override
  ConsumerState<SpecimenCollectionDialog> createState() => _SpecimenCollectionDialogState();
}

class _SpecimenCollectionDialogState extends ConsumerState<SpecimenCollectionDialog> {
  late TextEditingController _collectorController;
  late String _specimenType;
  bool _isLoading = false;

  final List<String> _types = [
    'Blood',
    'Serum',
    'Plasma',
    'Urine',
    'Sputum',
    'Stool',
    'Swab',
  ];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _collectorController = TextEditingController(text: user?.fullName ?? 'Phlebotomist');
    _specimenType = widget.order.specimenType.isNotEmpty ? widget.order.specimenType : 'Blood';
  }

  @override
  void dispose() {
    _collectorController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(laboratoryRepositoryProvider);
      await repo.collectSpecimen(
        orderId: widget.order.id,
        specimenType: _specimenType,
        collectorName: _collectorController.text.trim(),
      );

      ref.invalidate(labOrdersListProvider);
      ref.invalidate(labDashboardStatsProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Specimen collection recorded successfully'),
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.colorize_rounded, color: AppColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Record Specimen Collection',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test: ${widget.order.testName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              'Patient: ${widget.order.patientName} (${widget.order.uhid})',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const Divider(height: 20),
            const Text(
              'Specimen Type',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _types.contains(_specimenType) ? _specimenType : _types.first,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: _types
                  .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _specimenType = val);
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'Phlebotomist / Collector Name',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _collectorController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirm Collection'),
        ),
      ],
    );
  }
}

class SpecimenReceiptDialog extends ConsumerStatefulWidget {
  final LabOrderModel order;

  const SpecimenReceiptDialog({super.key, required this.order});

  @override
  ConsumerState<SpecimenReceiptDialog> createState() => _SpecimenReceiptDialogState();
}

class _SpecimenReceiptDialogState extends ConsumerState<SpecimenReceiptDialog> {
  late TextEditingController _receiverController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _receiverController = TextEditingController(text: user?.fullName ?? 'Lab Technician');
  }

  @override
  void dispose() {
    _receiverController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(laboratoryRepositoryProvider);
      await repo.receiveSpecimen(
        orderId: widget.order.id,
        receivedByName: _receiverController.text.trim(),
      );

      ref.invalidate(labOrdersListProvider);
      ref.invalidate(labDashboardStatsProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Specimen received into laboratory processing'),
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Receive Specimen in Lab', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirm specimen accession for ${widget.order.testName} (${widget.order.specimenId ?? "--"})',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 14),
          const Text('Received By (Lab Staff)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _receiverController,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Accept & Process'),
        ),
      ],
    );
  }
}

class SpecimenRejectionDialog extends ConsumerStatefulWidget {
  final LabOrderModel order;

  const SpecimenRejectionDialog({super.key, required this.order});

  @override
  ConsumerState<SpecimenRejectionDialog> createState() => _SpecimenRejectionDialogState();
}

class _SpecimenRejectionDialogState extends ConsumerState<SpecimenRejectionDialog> {
  final _reasonController = TextEditingController();
  String _selectedReason = 'Hemolyzed specimen';
  bool _isLoading = false;

  final List<String> _rejectionReasons = [
    'Hemolyzed specimen',
    'Clotted whole blood in EDTA tube',
    'Insufficient specimen volume (QNS)',
    'Specimen in incorrect container/additive',
    'Mislabeled / Unlabeled tube',
    'Delayed transit exceeding stability limit',
    'Leaked / Compromised container',
    'Other clinical rejection criteria',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reasonText = _selectedReason == 'Other clinical rejection criteria'
        ? _reasonController.text.trim()
        : _selectedReason;

    if (reasonText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rejection reason'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(laboratoryRepositoryProvider);
      await repo.rejectSpecimen(
        orderId: widget.order.id,
        reason: reasonText,
      );

      ref.invalidate(labOrdersListProvider);
      ref.invalidate(labDashboardStatsProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Specimen marked as REJECTED'),
            backgroundColor: Colors.orange,
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.cancel_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 8),
          const Text('Reject Specimen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specimen: ${widget.order.specimenId ?? widget.order.orderNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text('Clinical Rejection Reason', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedReason,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: _rejectionReasons
                  .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12.5))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedReason = val);
              },
            ),
            if (_selectedReason == 'Other clinical rejection criteria') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  hintText: 'Enter specific reason...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirm Rejection'),
        ),
      ],
    );
  }
}
