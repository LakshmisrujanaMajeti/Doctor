import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import 'package:opd_connect/core/constants/app_colors.dart';
import 'package:opd_connect/features/documents/models/document_models.dart';
import 'package:opd_connect/features/documents/providers/document_provider.dart';
import 'package:opd_connect/features/documents/screens/document_capture_screen.dart';
import 'package:opd_connect/features/documents/screens/document_ocr_verification_screen.dart';
import 'package:opd_connect/features/documents/widgets/barcode_scanner_modal.dart';

class DocumentManagerWorkspaceView extends ConsumerStatefulWidget {
  final String? patientId;
  final String? patientUhid;
  final String? patientName;

  const DocumentManagerWorkspaceView({
    super.key,
    this.patientId,
    this.patientUhid,
    this.patientName,
  });

  @override
  ConsumerState<DocumentManagerWorkspaceView> createState() => _DocumentManagerWorkspaceViewState();
}

class _DocumentManagerWorkspaceViewState extends ConsumerState<DocumentManagerWorkspaceView> {
  String _selectedType = 'ALL';
  String _selectedStatus = 'ALL';
  String _searchQuery = '';

  void _showSignedUrlModal(MedicalDocumentModel doc) async {
    try {
      final repo = ref.read(documentRepositoryProvider);
      final signedUrl = await repo.generateSignedUrl(doc.id, validityMinutes: 15);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.link, color: AppColors.primaryBlue),
              SizedBox(width: 8),
              Text('Short-Lived Signed Preview Link'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  'Access Link Validity: 15 Minutes (HMAC-SHA256 Signed)\n'
                  'Document: ${doc.fileName}\n'
                  'Link expires automatically at ${signedUrl.expiresAt}.',
                  style: TextStyle(fontSize: 11.5, color: Colors.green.shade900),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Expiring URL Token:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              SelectableText(
                signedUrl.previewUrl,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate signed link: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAuditLogsModal(MedicalDocumentModel doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Audit Trail: ${doc.fileName}'),
        content: SizedBox(
          width: 520,
          height: 380,
          child: Consumer(
            builder: (context, ref, _) {
              final logsAsync = ref.watch(documentAuditLogsProvider(doc.id));
              return logsAsync.when(
                data: (logs) {
                  if (logs.isEmpty) {
                    return const Center(child: Text('No audit events recorded yet.'));
                  }
                  return ListView.separated(
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final l = logs[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                          child: const Icon(Icons.history, size: 14, color: AppColors.primaryBlue),
                        ),
                        title: Text(l.action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        subtitle: Text(
                          '${l.createdAt} ${l.ipAddress != null ? "• IP: ${l.ipAddress}" : ""}',
                          style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading audit log: $err')),
              );
            },
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patientId = widget.patientId ?? '3d9bf54a-48cf-42ff-881c-c1a1d12ec057';
    final docsAsync = ref.watch(patientDocumentsProvider(patientId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Dashboard',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.goNamed(RouteNames.dashboard);
            }
          },
        ),
        title: const Text('Medical Documents & OCR Archive'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header & Action Row
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Medical Documents & OCR Archive',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Secure digital document capture, verified clinical OCR, and barcode tracking',
                      style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Scan / Generate Barcode'),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => BarcodeScannerModal(
                            initialResourceId: widget.patientUhid ?? 'UHID-2026-0001',
                          ),
                        );
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Capture / Upload Document'),
                      onPressed: () async {
                        final res = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => DocumentCaptureScreen(
                              patientId: patientId,
                              patientUhid: widget.patientUhid ?? 'UHID-2026-0001',
                              patientName: widget.patientName ?? 'Satya Narayan',
                            ),
                          ),
                        );
                        if (res != null) {
                          ref.invalidate(patientDocumentsProvider(patientId));
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search & Filter Toolbar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Wrap(
                spacing: 14,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'Search documents...',
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _selectedType,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Document Types')),
                      DropdownMenuItem(value: 'OPD_BOOKLET_SCAN', child: Text('OPD Booklet Scans')),
                      DropdownMenuItem(value: 'PRESCRIPTION_SCAN', child: Text('Prescriptions')),
                      DropdownMenuItem(value: 'LAB_REPORT', child: Text('Lab Reports')),
                      DropdownMenuItem(value: 'INVOICE_SCAN', child: Text('Invoices')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedType = val);
                    },
                  ),
                  DropdownButton<String>(
                    value: _selectedStatus,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Verification Statuses')),
                      DropdownMenuItem(value: 'VERIFIED', child: Text('Verified Only')),
                      DropdownMenuItem(value: 'IN_REVIEW', child: Text('In Review')),
                      DropdownMenuItem(value: 'UNVERIFIED', child: Text('Unverified')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatus = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Documents List
            docsAsync.when(
              data: (docs) {
                final filtered = docs.where((d) {
                  if (_selectedType != 'ALL' && d.documentType != _selectedType) return false;
                  if (_selectedStatus != 'ALL' && d.verificationStatus != _selectedStatus) return false;
                  if (_searchQuery.isNotEmpty && !d.fileName.toLowerCase().contains(_searchQuery)) return false;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Icon(Icons.folder_open, size: 54, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('No medical documents match your filters', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Capture a physical booklet or upload an existing file', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final doc = filtered[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.picture_as_pdf, color: AppColors.primaryBlue, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(doc.fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${doc.documentType} • ${doc.pageCount} Pages • ${(doc.fileSizeBytes / 1024).toStringAsFixed(1)} KB',
                                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    ),
                                  ],
                                ),
                              ),
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
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Metadata badges
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                child: Text('SHA-256: ${doc.checksumSha256?.substring(0, 12) ?? "N/A"}...', style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace')),
                              ),
                              if (doc.description != null)
                                Text('• ${doc.description}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Actions Row
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.document_scanner, size: 16),
                                label: const Text('Review OCR Extractions'),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (ctx) => DocumentOcrVerificationScreen(documentId: doc.id),
                                    ),
                                  );
                                },
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.share, size: 16),
                                label: const Text('15-Min Signed Link'),
                                onPressed: () => _showSignedUrlModal(doc),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.history, size: 16),
                                label: const Text('Audit History'),
                                onPressed: () => _showAuditLogsModal(doc),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading documents: $err')),
            ),
          ],
        ),
      ),
    );
  }
}
