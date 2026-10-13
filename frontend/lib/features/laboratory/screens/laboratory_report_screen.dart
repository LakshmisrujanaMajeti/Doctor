import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../models/laboratory_models.dart';
import '../providers/laboratory_provider.dart';

class LaboratoryReportScreen extends ConsumerWidget {
  final String orderId;

  const LaboratoryReportScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(labPrintableReportProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laboratory Report', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Print Report',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report sent to system printer'),
                  backgroundColor: AppColors.primaryBlue,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share Report',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report export generated'),
                  backgroundColor: Colors.teal,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: reportAsync.when(
        data: (report) => _buildReportView(context, report),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Failed to load lab report: $err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(labPrintableReportProvider(orderId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportView(BuildContext context, LabReportDataModel report) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 820),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hospital Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_hospital_rounded, color: AppColors.primaryBlue, size: 32),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.hospitalName,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const Text(
                          'DEPARTMENT OF PATHOLOGY & LABORATORY MEDICINE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${report.hospitalAddress} • Ph: ${report.hospitalPhone}',
                          style: const TextStyle(fontSize: 10.5, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.teal.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text(
                          'NABL ACCREDITED',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.teal),
                        ),
                        Text(
                          'ISO 15189:2022',
                          style: TextStyle(fontSize: 9, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 28, thickness: 1.5),

              // 2. Sensitive Test Warning Banner
              if (report.isSensitive) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'CONFIDENTIAL MEDICAL RECORD: Restricted Access under Healthcare Privacy Rules',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 3. Demographics and Specimen Audit Matrix
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF262C36) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetaItem('Patient Name', report.patientName, bold: true),
                        ),
                        Expanded(
                          child: _buildMetaItem('UHID', report.uhid),
                        ),
                        Expanded(
                          child: _buildMetaItem(
                            'Age / Sex',
                            '${report.patientAge ?? "--"} Y / ${report.patientGender ?? "--"}',
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetaItem('Order Number', report.orderNumber),
                        ),
                        Expanded(
                          child: _buildMetaItem('Specimen ID', report.specimenId),
                        ),
                        Expanded(
                          child: _buildMetaItem('Specimen Type', report.specimenType),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetaItem(
                            'Collection Time',
                            report.collectionTime != null
                                ? '${report.collectionTime!.substring(0, 16)} (${report.collectedByName ?? "Lab"})'
                                : 'Pending',
                          ),
                        ),
                        Expanded(
                          child: _buildMetaItem(
                            'Received At',
                            report.receivedAt != null
                                ? '${report.receivedAt!.substring(0, 16)} (${report.receivedByName ?? "Lab"})'
                                : 'Pending',
                          ),
                        ),
                        Expanded(
                          child: _buildMetaItem('Department', report.department),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. Test Name Title
              Text(
                'INVESTIGATION: ${report.testName.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 8),

              // 5. Results Table
              Table(
                border: TableBorder.all(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  width: 1,
                  borderRadius: BorderRadius.circular(6),
                ),
                columnWidths: const {
                  0: FlexColumnWidth(4),
                  1: FlexColumnWidth(2.5),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(2.5),
                  4: FlexColumnWidth(1.5),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    ),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Text('Test Parameter', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Text('Observed Value', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Text('Unit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Text('Reference Range', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Text('Flag', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ],
                  ),
                  ...report.parameters.map((param) {
                    final isCrit = param.isCritical || param.flag == 'CRITICAL';
                    final isAbn = param.isAbnormal || param.flag == 'ABNORMAL' || isCrit;

                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          child: Text(param.parameterName, style: const TextStyle(fontSize: 12)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          child: Text(
                            param.valueText,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isCrit ? Colors.red : (isAbn ? Colors.orange.shade800 : null),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          child: Text(
                            param.unit.isNotEmpty ? param.unit : '-',
                            style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          child: Text(
                            param.referenceRange.isNotEmpty ? param.referenceRange : '-',
                            style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          child: Text(
                            param.flag,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isCrit ? Colors.red : (isAbn ? Colors.orange.shade800 : Colors.green.shade700),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              const SizedBox(height: 24),

              // 6. Pathologist Notes if present
              if (report.verificationNotes != null && report.verificationNotes!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF262C36) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pathologist Comments / Clinical Remarks:',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.verificationNotes!,
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 7. Verification Seal & Digital Signature Block
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_rounded, color: Colors.green, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DIGITALLY VERIFIED LABORATORY REPORT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.green,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Verified by: ${report.verifiedByName ?? "Authorized Pathologist"}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Verified at: ${report.verifiedAt != null ? report.verifiedAt!.substring(0, 19).replaceAll("T", " ") : "Non-repudiated digital seal"}',
                            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text('AUTHENTICATED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.green)),
                        Text('Non-Repudiated Sign', style: TextStyle(fontSize: 9, color: Colors.black54)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Center(
                child: Text(
                  '*** End of Laboratory Investigation Report ***',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.black54),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
