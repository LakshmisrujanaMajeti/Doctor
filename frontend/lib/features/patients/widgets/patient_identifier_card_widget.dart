import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/file_download_helper.dart';
import '../../../shared/widgets/smvmch_hospital_logo.dart';
import '../models/patient_model.dart';
import '../repositories/patient_repository.dart';

class PatientIdentifierCardWidget extends StatelessWidget {
  final PatientModel patient;
  final bool isCompact;
  final VoidCallback? onDownloadBooklet;

  const PatientIdentifierCardWidget({
    super.key,
    required this.patient,
    this.isCompact = false,
    this.onDownloadBooklet,
  });

  static void showCardDialog(BuildContext context, PatientModel patient, {PatientRepository? repository}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PatientIdentifierCardWidget(
                    patient: patient,
                    onDownloadBooklet: repository != null
                        ? () async {
                            final scaffold = ScaffoldMessenger.of(context);
                            scaffold.showSnackBar(
                              const SnackBar(
                                content: Text('Generating & downloading official 7-page OPD booklet PDF...'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            try {
                              final bytes = await repository.downloadBookletByRegId(patient.uhid);
                              final filename = 'SMVMCH_OPD_Booklet_${patient.uhid}.pdf';
                              await downloadFileBytes(bytes, filename);
                              scaffold.showSnackBar(
                                SnackBar(
                                  content: Text('Verified PDF "$filename" saved successfully! (${bytes.length} bytes)'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              scaffold.showSnackBar(
                                SnackBar(
                                  content: Text('Download failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barcode = patient.barcodeValue ?? 'BAR-${patient.uhid}';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hospital Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.hospitalMaroon,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const SmvmchHospitalLogo(size: 38, showTamilText: false),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SRI MANAKULA VINAYAGAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Text(
                        'MEDICAL COLLEGE AND HOSPITAL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'Out Patient Department • Patient ID Card',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Card Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Patient Name + Blood Group Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                      child: Text(
                        patient.fullName.isNotEmpty ? patient.fullName[0].toUpperCase() : 'P',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient.fullName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (patient.parentSpouseName != null && patient.parentSpouseName!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${patient.parentSpouseRelation ?? "S/o"}: ${patient.parentSpouseName}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            '${patient.gender} • ${patient.ageYears ?? "--"} Yrs • Ph: ${patient.phone}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (patient.bloodGroup != null && patient.bloodGroup!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.water_drop_rounded, size: 14, color: Colors.redAccent),
                            const SizedBox(width: 2),
                            Text(
                              patient.bloodGroup!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // UHID & Reg No Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'UNIQUE HEALTH ID (UHID)',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[600],
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              patient.uhid,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                                fontFamily: 'monospace',
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 28, color: Colors.grey[300]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HOSPITAL REG NO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[600],
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              patient.hospitalRegNum ?? 'REG-PENDING',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Barcode & QR Code Section
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.qr_code_2, size: 76, color: Color(0xFF1E293B)),
                        const SizedBox(height: 4),
                        Text(
                          barcode,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 2,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (patient.address != null && patient.address!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${patient.address!}${patient.city != null ? ", ${patient.city}" : ""}${patient.postalCode != null ? " - ${patient.postalCode}" : ""}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // Action Buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.auto_stories_rounded, size: 15),
                      label: const Text('Open 7-Page Booklet'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.hospitalMaroon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => context.push('/patients/${patient.id}/booklet'),
                    ),
                    if (onDownloadBooklet != null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 15),
                        label: const Text('Download Booklet (PDF)'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: onDownloadBooklet,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
