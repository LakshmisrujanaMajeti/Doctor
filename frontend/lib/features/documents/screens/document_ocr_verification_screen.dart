import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import 'package:opd_connect/core/constants/app_colors.dart';
import 'package:opd_connect/features/documents/models/document_models.dart';
import 'package:opd_connect/features/documents/providers/document_provider.dart';

class DocumentOcrVerificationScreen extends ConsumerStatefulWidget {
  final String documentId;

  const DocumentOcrVerificationScreen({
    super.key,
    required this.documentId,
  });

  @override
  ConsumerState<DocumentOcrVerificationScreen> createState() => _DocumentOcrVerificationScreenState();
}

class _DocumentOcrVerificationScreenState extends ConsumerState<DocumentOcrVerificationScreen> {
  String? _selectedFieldId;
  bool _isProcessing = false;
  String? _actionMessage;

  void _showEditFieldModal(DocumentOcrFieldModel field) {
    final controller = TextEditingController(text: field.verifiedValue ?? field.normalizedValue ?? field.rawText);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Verify / Edit Field: ${field.fieldName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Raw OCR Output: "${field.rawText}"', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              'Confidence: ${(field.confidence * 100).toInt()}% • ${field.isHandwritten ? "Handwritten Clinician Script" : "Printed Text"}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: field.confidence >= 0.80 ? Colors.green.shade700 : Colors.amber.shade800,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Corrected / Verified Clinical Value *',
                hintText: 'Enter exact reviewed value',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _updateFieldStatus(field.id, 'REJECTED', null, 'Rejected by clinician during manual review');
            },
            child: const Text('Reject Field', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = controller.text.trim();
              Navigator.of(ctx).pop();
              await _updateFieldStatus(field.id, 'CONFIRMED', val.isNotEmpty ? val : null, null);
            },
            child: const Text('Confirm & Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateFieldStatus(String fieldId, String status, String? verifiedValue, String? rejectionReason) async {
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.verifyField(
        documentId: widget.documentId,
        extractionId: fieldId,
        status: status,
        verifiedValue: verifiedValue,
        rejectionReason: rejectionReason,
      );
      ref.invalidate(documentOcrFieldsProvider(widget.documentId));
      ref.invalidate(documentDetailProvider(widget.documentId));
      setState(() => _actionMessage = 'Field updated successfully');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleVerifyAll() async {
    final notesController = TextEditingController(text: 'Verified by clinician against original physical document scan');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clinician Sign-off & Final Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'By signing off, you confirm that all clinical observations, patient demographics, and prescription dosages '
              'have been verified against the physical source document.',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Clinician Verification Notes *'),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign-off & Finalize'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.verifyAllFields(widget.documentId, clinicianNotes: notesController.text.trim());
      ref.invalidate(documentDetailProvider(widget.documentId));
      ref.invalidate(documentOcrFieldsProvider(widget.documentId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document verified and signed off successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleApplyToVisit(String visitId) async {
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(documentRepositoryProvider);
      final res = await repo.applyToVisit(
        documentId: widget.documentId,
        visitId: visitId,
        applyVitals: true,
        applyComplaints: true,
        applyDiagnosis: true,
        applyPrescriptions: true,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transferred verified data to visit record! Status: ${res["status"]}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Safety block: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docAsync = ref.watch(documentDetailProvider(widget.documentId));
    final fieldsAsync = ref.watch(documentOcrFieldsProvider(widget.documentId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.goNamed(RouteNames.documents);
            }
          },
        ),
        title: const Text('OCR Clinical Verification'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-run OCR Extraction',
            onPressed: _isProcessing
                ? null
                : () async {
                    setState(() => _isProcessing = true);
                    try {
                      await ref.read(documentRepositoryProvider).triggerOcr(widget.documentId);
                      ref.invalidate(documentOcrFieldsProvider(widget.documentId));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    } finally {
                      setState(() => _isProcessing = false);
                    }
                  },
          ),
        ],
      ),
      body: docAsync.when(
        data: (doc) {
          return fieldsAsync.when(
            data: (fields) {
              final unverifiedCount = fields.where((f) => f.isPendingReview).length;
              final confirmedCount = fields.where((f) => f.isConfirmed).length;
              final hasHandwrittenUnconfirmed = fields.any((f) => f.isHandwritten && !f.isConfirmed);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Mandatory Safety Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade400),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.health_and_safety_rounded, color: Colors.amber.shade900, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Clinical Safety Requirement: Manual Clinician Review Mandatory',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Never silently convert uncertain OCR into verified medical data. '
                                  'Handwritten medication names and dosages must be reviewed and confirmed by an authorized clinician.',
                                  style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Document Metadata Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(doc.fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(
                                'Type: ${doc.documentType} • SHA-256: ${doc.checksumSha256?.substring(0, 16) ?? "N/A"}...',
                                style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: doc.isVerified ? Colors.green.shade100 : Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  doc.verificationStatus,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: doc.isVerified ? Colors.green.shade800 : Colors.amber.shade900,
                                  ),
                                ),
                              ),
                              Text(
                                '$confirmedCount of ${fields.length} Fields Confirmed',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Side-by-side or stacked layout: Document Preview + Extracted Fields
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 900;

                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left: Scan Preview with interactive overlays
                              Expanded(
                                flex: 5,
                                child: _buildDocumentScanViewer(doc, fields, isDark),
                              ),
                              const SizedBox(width: 20),
                              // Right: Field Cards
                              Expanded(
                                flex: 6,
                                child: _buildFieldCardsList(fields, isDark),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildDocumentScanViewer(doc, fields, isDark),
                              const SizedBox(height: 20),
                              _buildFieldCardsList(fields, isDark),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // 4. Bottom Final Actions
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back to Documents'),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.verified, size: 18),
                          label: const Text('Clinician Sign-off & Finalize'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                          onPressed: _isProcessing ? null : _handleVerifyAll,
                        ),
                        if (doc.visitId != null)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            label: const Text('Transfer to Patient Visit Record'),
                            onPressed: (_isProcessing || hasHandwrittenUnconfirmed) ? null : () => _handleApplyToVisit(doc.visitId!),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading OCR fields: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading document: $err')),
      ),
    );
  }

  Widget _buildDocumentScanViewer(MedicalDocumentModel doc, List<DocumentOcrFieldModel> fields, bool isDark) {
    return Container(
      height: 480,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Stack(
        children: [
          // Simulated page document scan
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.brown.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OPD CONNECT+ CLINICAL CONSULTATION SHEET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const Divider(),
                    Text('Patient UHID: UHID-2026-0001 • Date: 2026-10-12', style: TextStyle(fontSize: 11, color: Colors.brown.shade800)),
                    const SizedBox(height: 8),
                    const Text('Vitals: BP 120/80 mmHg, Pulse 76, Temp 98.6 F, SpO2 99%', style: TextStyle(fontSize: 11)),
                    const SizedBox(height: 6),
                    const Text('Chief Complaints: Persistent dry cough x 3 days', style: TextStyle(fontSize: 11)),
                    const SizedBox(height: 6),
                    const Text('Diagnosis: Acute Viral Bronchitis', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade400),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rx (Handwritten Clinician Script):', style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic)),
                          Text('1. Tab. Paracetamol 500mg - 1 tab TID x 3 days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Text('2. Tab. Cetirizine 10mg - 1 tab HS x 5 days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(6)),
              child: const Text('Source Document Scan (Original Preserved)', style: TextStyle(fontSize: 10, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldCardsList(List<DocumentOcrFieldModel> fields, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Extracted Clinical Fields & Confidence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: fields.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final f = fields[i];
            final isUncertain = f.isUncertain || f.confidence < 0.80;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: f.isConfirmed
                      ? Colors.green.shade400
                      : (isUncertain ? Colors.amber.shade400 : Colors.grey.shade300),
                  width: f.isConfirmed || isUncertain ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          f.fieldCategory,
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f.fieldName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      // Confidence Score Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isUncertain ? Colors.amber.shade100 : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${(f.confidence * 100).toInt()}% Conf',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isUncertain ? Colors.amber.shade900 : Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Raw text: "${f.rawText}"', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                  if (f.verifiedValue != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Verified: ${f.verifiedValue}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                    ),
                  ],

                  // Safety warning for handwritten medication
                  if (f.isHandwritten) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit_note, color: Colors.red.shade800, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Handwritten Medication - Clinician Sign-Off Required',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Actions row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!f.isConfirmed) ...[
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text('Edit / Verify', style: TextStyle(fontSize: 11.5)),
                          onPressed: () => _showEditFieldModal(f),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('Confirm', style: TextStyle(fontSize: 11.5)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                          onPressed: () => _updateFieldStatus(f.id, 'CONFIRMED', f.normalizedValue, null),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                            const SizedBox(width: 4),
                            Text('Confirmed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _showEditFieldModal(f),
                              child: const Text('Edit', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
