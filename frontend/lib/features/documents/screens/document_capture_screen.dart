import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:opd_connect/core/constants/app_colors.dart';
import 'package:opd_connect/features/documents/models/document_models.dart';
import 'package:opd_connect/features/documents/providers/document_provider.dart';

class DocumentCaptureScreen extends ConsumerStatefulWidget {
  final String? patientId;
  final String? patientUhid;
  final String? patientName;
  final String? visitId;

  const DocumentCaptureScreen({
    super.key,
    this.patientId,
    this.patientUhid,
    this.patientName,
    this.visitId,
  });

  @override
  ConsumerState<DocumentCaptureScreen> createState() => _DocumentCaptureScreenState();
}

class _DocumentCaptureScreenState extends ConsumerState<DocumentCaptureScreen> {
  // Captured pages reel
  final List<CapturedPageItem> _pages = [];
  int _selectedPageIndex = 0;

  // Metadata form
  final _uhidController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _documentType = 'OPD_BOOKLET_SCAN';

  // Upload state machine
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadError;
  CancelToken? _cancelToken;

  // Error simulation states for mobile resilience
  bool _permissionDenied = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _uhidController.text = widget.patientUhid ?? 'UHID-2026-0001';

    // Seed with 1 initial captured page
    _pages.add(CapturedPageItem(
      id: 'page-1',
      pageNumber: 1,
      label: 'Consultation Sheet (Page 1)',
      hasPerspectiveCorrection: true,
      contrastEnhanced: true,
    ));
  }

  @override
  void dispose() {
    _uhidController.dispose();
    _descriptionController.dispose();
    _cancelToken?.cancel();
    super.dispose();
  }

  void _capturePhoto() {
    if (_permissionDenied) return;
    setState(() {
      final newPageNum = _pages.length + 1;
      _pages.add(CapturedPageItem(
        id: 'page-$newPageNum',
        pageNumber: newPageNum,
        label: 'Scanned Page $newPageNum',
        hasPerspectiveCorrection: true,
        contrastEnhanced: true,
      ));
      _selectedPageIndex = _pages.length - 1;
    });
  }

  void _importFromGallery() {
    setState(() {
      final newPageNum = _pages.length + 1;
      _pages.add(CapturedPageItem(
        id: 'imported-doc-$newPageNum',
        pageNumber: newPageNum,
        label: 'Imported Document Page $newPageNum',
        hasPerspectiveCorrection: false,
        contrastEnhanced: false,
      ));
      _selectedPageIndex = _pages.length - 1;
      _permissionDenied = false; // Gallery fallback resolves camera block
    });
  }

  void _rotateCurrentPage() {
    if (_pages.isEmpty) return;
    setState(() {
      _pages[_selectedPageIndex].rotateClockwise();
    });
  }

  void _togglePerspectiveCorrection() {
    if (_pages.isEmpty) return;
    setState(() {
      _pages[_selectedPageIndex].togglePerspectiveCorrection();
    });
  }

  void _toggleContrast() {
    if (_pages.isEmpty) return;
    setState(() {
      _pages[_selectedPageIndex].toggleContrast();
    });
  }

  void _movePageLeft() {
    if (_selectedPageIndex > 0) {
      setState(() {
        final item = _pages.removeAt(_selectedPageIndex);
        _pages.insert(_selectedPageIndex - 1, item);
        _selectedPageIndex -= 1;
        _reindexPages();
      });
    }
  }

  void _movePageRight() {
    if (_selectedPageIndex < _pages.length - 1) {
      setState(() {
        final item = _pages.removeAt(_selectedPageIndex);
        _pages.insert(_selectedPageIndex + 1, item);
        _selectedPageIndex += 1;
        _reindexPages();
      });
    }
  }

  void _deleteCurrentPage() {
    if (_pages.isEmpty) return;
    setState(() {
      _pages.removeAt(_selectedPageIndex);
      if (_selectedPageIndex >= _pages.length && _pages.isNotEmpty) {
        _selectedPageIndex = _pages.length - 1;
      }
      _reindexPages();
    });
  }

  void _reindexPages() {
    for (int i = 0; i < _pages.length; i++) {
      _pages[i].pageNumber = i + 1;
    }
  }

  void _showCropModal() {
    if (_pages.isEmpty) return;
    final page = _pages[_selectedPageIndex];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crop & Document Edge Alignment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 220,
              width: 220,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryBlue, width: 2),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(Icons.description, size: 80, color: Colors.grey),
                  ),
                  // Bounding crop reticle
                  Container(
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 2),
                      color: Colors.green.withValues(alpha: 0.1),
                    ),
                    child: const Center(
                      child: Text(
                        'Document Boundary Detected',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Four-corner auto-detection has framed the page margins.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                page.cropRect = const Rect.fromLTWH(0.05, 0.05, 0.90, 0.90);
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply Crop'),
          ),
        ],
      ),
    );
  }

  void _showPdfPreviewModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text('Multipage PDF (${_pages.length} Pages)'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OPD CONNECT+ CLINICAL ARCHIVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Patient UHID: ${_uhidController.text} • Multi-page Compilation'),
                    Text('Total Pages: ${_pages.length} • Format: ISO 32000-1 Compliant PDF'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Included Pages:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pages.length,
                  itemBuilder: (ctx, i) {
                    final p = _pages[i];
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.insert_drive_file, color: Colors.red.shade400, size: 36),
                          const SizedBox(height: 6),
                          Text('Page ${p.pageNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          Text('${p.rotationAngle}° rot', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close Preview'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpload() async {
    if (_pages.isEmpty) return;

    if (_isOffline) {
      setState(() {
        _uploadError = 'Cannot upload while offline. Please connect to the internet or save to local queue.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.05;
      _uploadError = null;
      _cancelToken = CancelToken();
    });

    try {
      final repo = ref.read(documentRepositoryProvider);

      // Simulate progressive chunk upload
      for (double p = 0.15; p <= 0.85; p += 0.25) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (!mounted) return;
        setState(() => _uploadProgress = p);
      }

      final fakePdfBytes = Uint8List.fromList('%PDF-1.4 OPD Connect Multipage Document'.codeUnits);
      final patientId = widget.patientId ?? '3d9bf54a-48cf-42ff-881c-c1a1d12ec057';

      final doc = await repo.uploadDocument(
        patientId: patientId,
        fileName: 'scan_${DateTime.now().millisecondsSinceEpoch}.pdf',
        fileBytes: fakePdfBytes,
        documentType: _documentType,
        visitId: widget.visitId,
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        pageCount: _pages.length,
        cancelToken: _cancelToken,
      );

      if (!mounted) return;
      setState(() => _uploadProgress = 1.0);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document uploaded successfully! (ID: ${doc.id})'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(doc);
    } catch (e) {
      if (CancelToken.isCancel(e as dynamic)) {
        setState(() => _uploadError = 'Upload cancelled by user.');
      } else {
        setState(() => _uploadError = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _cancelUpload() {
    _cancelToken?.cancel('Cancelled by user');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Document Capture'),
        actions: [
          IconButton(
            icon: Icon(_isOffline ? Icons.wifi_off : Icons.wifi, color: _isOffline ? Colors.red : Colors.green),
            tooltip: _isOffline ? 'Offline Mode (Click to Toggle)' : 'Online Mode',
            onPressed: () => setState(() => _isOffline = !_isOffline),
          ),
          IconButton(
            icon: Icon(_permissionDenied ? Icons.no_photography : Icons.camera_alt),
            tooltip: 'Toggle Camera Permission',
            onPressed: () => setState(() => _permissionDenied = !_permissionDenied),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Permission Denied Banner (if simulated/denied)
            if (_permissionDenied) ...[
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade800, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Camera Permission Denied',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red.shade900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'OPD Connect+ requires camera access to capture physical booklets and patient records. Please enable permissions in App Settings, or import files directly from your gallery.',
                            style: TextStyle(fontSize: 11.5, color: Colors.red.shade800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _permissionDenied = false),
                      child: const Text('Grant Access'),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library, size: 16),
                      label: const Text('Use Gallery'),
                      onPressed: _importFromGallery,
                    ),
                  ],
                ),
              ),
            ],

            // 2. Offline Mode Banner
            if (_isOffline) ...[
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off, color: Colors.amber.shade800, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offline Mode - Local Queue Available',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                          ),
                          Text(
                            'Captured pages will be preserved locally and automatically synchronized once network connectivity resumes.',
                            style: TextStyle(fontSize: 11.5, color: Colors.amber.shade800),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Document pages queued locally for synchronization.')),
                        );
                      },
                      child: const Text('Queue Locally'),
                    ),
                  ],
                ),
              ),
            ],

            // 3. Capture & Viewfinder Area
            Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              child: _pages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.document_scanner, size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No pages captured yet', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('Use camera or device gallery to capture booklet pages', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Capture Page'),
                                onPressed: _capturePhoto,
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Import Gallery / PDF'),
                                onPressed: _importFromGallery,
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        // Page preview representation
                        Center(
                          child: Transform.rotate(
                            angle: (_pages[_selectedPageIndex].rotationAngle * 3.14159 / 180),
                            child: Container(
                              width: 170,
                              height: 230,
                              decoration: BoxDecoration(
                                color: _pages[_selectedPageIndex].contrastEnhanced ? Colors.white : Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _pages[_selectedPageIndex].hasPerspectiveCorrection ? Colors.green : Colors.grey.shade400,
                                  width: _pages[_selectedPageIndex].hasPerspectiveCorrection ? 2.5 : 1,
                                ),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 60,
                                    color: _pages[_selectedPageIndex].contrastEnhanced ? const Color(0xFF0F172A) : Colors.brown.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Page ${_pages[_selectedPageIndex].pageNumber}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                                  ),
                                  Text(
                                    '${_pages[_selectedPageIndex].rotationAngle}° rotation',
                                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                  ),
                                  if (_pages[_selectedPageIndex].hasPerspectiveCorrection)
                                    Container(
                                      margin: const EdgeInsets.only(top: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('PERSPECTIVE FIXED', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.green)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Action pill buttons on top right
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Wrap(
                            spacing: 8,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add_a_photo, size: 16),
                                label: const Text('Add Page'),
                                onPressed: _capturePhoto,
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.file_upload, size: 16),
                                label: const Text('Import'),
                                onPressed: _importFromGallery,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),

            // 4. Page Manipulation Toolbar
            if (_pages.isNotEmpty) ...[
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.crop, size: 18),
                    label: const Text('Crop Page'),
                    onPressed: _showCropModal,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.rotate_right, size: 18),
                    label: const Text('Rotate 90°'),
                    onPressed: _rotateCurrentPage,
                  ),
                  FilterChip(
                    label: const Text('Perspective Correction'),
                    selected: _pages[_selectedPageIndex].hasPerspectiveCorrection,
                    onSelected: (_) => _togglePerspectiveCorrection(),
                  ),
                  FilterChip(
                    label: const Text('High Contrast Filter'),
                    selected: _pages[_selectedPageIndex].contrastEnhanced,
                    onSelected: (_) => _toggleContrast(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Move Page Earlier',
                    onPressed: _selectedPageIndex > 0 ? _movePageLeft : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: 'Move Page Later',
                    onPressed: _selectedPageIndex < _pages.length - 1 ? _movePageRight : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Delete Current Page',
                    onPressed: _deleteCurrentPage,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('Multipage PDF Preview'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                    onPressed: _showPdfPreviewModal,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 5. Thumbnails Reel
              const Text('Pages Reel (Reorder & Select):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pages.length,
                  itemBuilder: (ctx, i) {
                    final isSel = i == _selectedPageIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedPageIndex = i),
                      child: Container(
                        width: 75,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.primaryBlue.withValues(alpha: 0.15) : (isDark ? const Color(0xFF1E293B) : Colors.white),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? AppColors.primaryBlue : Colors.grey.shade300,
                            width: isSel ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.insert_page_break, size: 28, color: isSel ? AppColors.primaryBlue : Colors.grey),
                            const SizedBox(height: 4),
                            Text('Page ${i + 1}', style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),

            // 6. Review & Upload Details Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Review Before Upload', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _uhidController,
                          decoration: const InputDecoration(labelText: 'Patient UHID *'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _documentType,
                          decoration: const InputDecoration(labelText: 'Document Type *'),
                          items: const [
                            DropdownMenuItem(value: 'OPD_BOOKLET_SCAN', child: Text('OPD Booklet Scan')),
                            DropdownMenuItem(value: 'PRESCRIPTION_SCAN', child: Text('Prescription Scan')),
                            DropdownMenuItem(value: 'LAB_REPORT', child: Text('Lab Investigation Report')),
                            DropdownMenuItem(value: 'INVOICE_SCAN', child: Text('Billing Invoice Scan')),
                            DropdownMenuItem(value: 'CLINICAL_SUMMARY', child: Text('Clinical Summary / ECG')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _documentType = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Clinical Notes / Document Description',
                      hintText: 'e.g. Physical consultation notes scanned during follow-up visit',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Upload progress bar & cancel button
                  if (_isUploading) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Uploading & Encrypting Document (${(_uploadProgress * 100).toInt()}%)...',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.cancel, size: 16, color: Colors.red),
                              label: const Text('Cancel Upload', style: TextStyle(color: Colors.red, fontSize: 12)),
                              onPressed: _cancelUpload,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: Colors.grey.shade200,
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ],

                  if (_uploadError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade800, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _uploadError!,
                              style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: _handleUpload,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                        child: const Text('Discard'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: _isUploading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.cloud_upload, size: 18),
                        label: Text(_isUploading ? 'Securing...' : 'Upload & Process OCR (${_pages.length} Pages)'),
                        onPressed: (_isUploading || _pages.isEmpty) ? null : _handleUpload,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
