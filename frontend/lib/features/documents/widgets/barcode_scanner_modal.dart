import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opd_connect/core/constants/app_colors.dart';
import 'package:opd_connect/features/documents/models/document_models.dart';
import 'package:opd_connect/features/documents/providers/document_provider.dart';

class BarcodeScannerModal extends ConsumerStatefulWidget {
  final String? initialResourceId;
  final String? initialType;

  const BarcodeScannerModal({
    super.key,
    this.initialResourceId,
    this.initialType,
  });

  @override
  ConsumerState<BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends ConsumerState<BarcodeScannerModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Generator state
  String _selectedType = 'PATIENT';
  final _resourceIdController = TextEditingController();
  final _labelController = TextEditingController();
  BarcodeIdentifierModel? _generatedBarcode;
  bool _isGenerating = false;
  String? _generateError;

  // Scanner state
  final _manualScanController = TextEditingController();
  BarcodeScanResultModel? _scanResult;
  bool _isScanning = false;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedType = widget.initialType ?? 'PATIENT';
    _resourceIdController.text = widget.initialResourceId ?? 'UHID-2026-0001';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _resourceIdController.dispose();
    _labelController.dispose();
    _manualScanController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    final resId = _resourceIdController.text.trim();
    if (resId.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _generateError = null;
    });

    try {
      final repo = ref.read(documentRepositoryProvider);
      final result = await repo.generateBarcode(
        identifierType: _selectedType,
        resourceId: resId,
        labelText: _labelController.text.trim().isNotEmpty ? _labelController.text.trim() : null,
      );
      setState(() => _generatedBarcode = result);
    } catch (e) {
      setState(() => _generateError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _handleScan(String payload) async {
    if (payload.trim().isEmpty) return;

    setState(() {
      _isScanning = true;
      _scanError = null;
      _scanResult = null;
    });

    try {
      final repo = ref.read(documentRepositoryProvider);
      final result = await repo.scanBarcode(payload.trim());
      setState(() => _scanResult = result);
    } catch (e) {
      setState(() => _scanError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
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
                    child: const Icon(Icons.qr_code_scanner, color: AppColors.primaryBlue, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Barcode & QR Identifier Manager',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Scan and generate non-sensitive reference identifiers for registrations, visits, and specimens',
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
              const SizedBox(height: 16),

              // Tab Bar
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(icon: Icon(Icons.qr_code, size: 18), text: 'Generate Identifier'),
                    Tab(icon: Icon(Icons.center_focus_strong, size: 18), text: 'Scan Barcode / QR'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGeneratorTab(isDark),
                    _buildScannerTab(isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratorTab(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Security disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 20, color: Colors.blue.shade800),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Non-sensitive Identifier Policy: QR codes encode reference tokens only (e.g. UHID:xxxx). '
                    'Confidential medical histories, clinical diagnoses, or payment credentials are never embedded directly in QR codes.',
                    style: TextStyle(fontSize: 11.5, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Identifier Type selector
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _selectedType,
            decoration: const InputDecoration(labelText: 'Identifier Target Type *'),
            items: const [
              DropdownMenuItem(value: 'PATIENT', child: Text('Patient Registration (UHID)')),
              DropdownMenuItem(value: 'VISIT', child: Text('OPD Visit Slip (VIS)')),
              DropdownMenuItem(value: 'LAB_ORDER', child: Text('Laboratory Order (LAB)')),
              DropdownMenuItem(value: 'SPECIMEN', child: Text('Specimen Tube Label (SPEC)')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedType = val);
            },
          ),
          const SizedBox(height: 14),

          // Resource ID input
          TextField(
            controller: _resourceIdController,
            decoration: const InputDecoration(
              labelText: 'Resource Identifier *',
              hintText: 'e.g. UHID-2026-0001 or VIS-20261012-0001',
            ),
          ),
          const SizedBox(height: 14),

          // Label text
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Display Label (Optional)',
              hintText: 'e.g. Satya Narayan - Male 34Y',
            ),
          ),
          const SizedBox(height: 16),

          if (_generateError != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(_generateError!, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
            ),

          ElevatedButton.icon(
            icon: _isGenerating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.qr_code, size: 18),
            label: const Text('Generate Verified QR Identifier'),
            onPressed: _isGenerating ? null : _handleGenerate,
          ),

          if (_generatedBarcode != null) ...[
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_2, size: 84, color: Color(0xFF0F172A)),
                            const SizedBox(height: 4),
                            Text(
                              _generatedBarcode!.token,
                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _generatedBarcode!.labelText,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    Text(
                      'Format: ${_generatedBarcode!.format} • Non-Sensitive Verified',
                      style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScannerTab(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Viewfinder simulation
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primaryBlue, width: 2.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.center_focus_weak, color: Colors.white54, size: 48),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Position QR or Barcode within reticle',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Quick test barcodes
          const Text('Quick Test Barcodes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                label: const Text('UHID:UHID-2026-0001', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  _manualScanController.text = 'UHID:UHID-2026-0001';
                  _handleScan('UHID:UHID-2026-0001');
                },
              ),
              ActionChip(
                label: const Text('VIS:VIS-20261012-0001', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  _manualScanController.text = 'VIS:VIS-20261012-0001';
                  _handleScan('VIS:VIS-20261012-0001');
                },
              ),
              ActionChip(
                label: const Text('LAB:LAB-ORD-20261012-0001', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  _manualScanController.text = 'LAB:LAB-ORD-20261012-0001';
                  _handleScan('LAB:LAB-ORD-20261012-0001');
                },
              ),
              ActionChip(
                label: const Text('SPEC:SPEC-HAEM-20261012-0001', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  _manualScanController.text = 'SPEC:SPEC-HAEM-20261012-0001';
                  _handleScan('SPEC:SPEC-HAEM-20261012-0001');
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Manual scan input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualScanController,
                  decoration: const InputDecoration(
                    labelText: 'Raw Barcode Payload / Token',
                    hintText: 'e.g. UHID:UHID-2026-0001',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: _isScanning
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search, size: 18),
                label: const Text('Resolve'),
                onPressed: _isScanning ? null : () => _handleScan(_manualScanController.text),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_scanError != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(_scanError!, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
            ),

          if (_scanResult != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.shade400, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _scanResult!.displayTitle,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _scanResult!.identifierType,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Resource ID: ${_scanResult!.resourceId}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: _scanResult!.metadata.entries.map((e) {
                      return Text(
                        '${e.key}: ${e.value}',
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
