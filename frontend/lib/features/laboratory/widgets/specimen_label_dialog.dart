import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/laboratory_models.dart';

class SpecimenLabelDialog extends StatelessWidget {
  final LabOrderModel order;

  const SpecimenLabelDialog({super.key, required this.order});

  Color _getTubeColor(String testName) {
    final lower = testName.toLowerCase();
    if (lower.contains('glucose') || lower.contains('gct') || lower.contains('tolerance')) {
      return Colors.grey.shade400; // Grey - Fluoride
    } else if (lower.contains('haemoglobin') ||
        lower.contains('rbc') ||
        lower.contains('tc') ||
        lower.contains('dc') ||
        lower.contains('platelet') ||
        lower.contains('esr') ||
        lower.contains('pcv') ||
        lower.contains('haematocrit')) {
      return Colors.purple.shade400; // Lavender - EDTA
    } else if (lower.contains('urea') ||
        lower.contains('creatinine') ||
        lower.contains('cholesterol') ||
        lower.contains('triglycerides') ||
        lower.contains('hiv') ||
        lower.contains('vdrl')) {
      return Colors.amber.shade700; // Yellow/Gold - SST Gel
    } else if (lower.contains('bleeding') || lower.contains('clotting')) {
      return Colors.lightBlue.shade400; // Light Blue - Sodium Citrate
    } else {
      return Colors.teal.shade600; // Green / Sterile Container
    }
  }

  String _getTubeName(String testName) {
    final lower = testName.toLowerCase();
    if (lower.contains('glucose') || lower.contains('gct') || lower.contains('tolerance')) {
      return 'Grey Top (Fluoride Vacutainer)';
    } else if (lower.contains('haemoglobin') ||
        lower.contains('rbc') ||
        lower.contains('tc') ||
        lower.contains('dc') ||
        lower.contains('platelet') ||
        lower.contains('esr') ||
        lower.contains('pcv') ||
        lower.contains('haematocrit')) {
      return 'Lavender Top (K2/K3 EDTA)';
    } else if (lower.contains('urea') ||
        lower.contains('creatinine') ||
        lower.contains('cholesterol') ||
        lower.contains('triglycerides') ||
        lower.contains('hiv') ||
        lower.contains('vdrl')) {
      return 'Gold/Yellow Top (SST Clot Activator)';
    } else if (lower.contains('bleeding') || lower.contains('clotting')) {
      return 'Light Blue Top (3.2% Citrate)';
    } else if (lower.contains('urine')) {
      return 'Sterile Urine Container (Yellow Cap)';
    } else if (lower.contains('sputum') || lower.contains('stool')) {
      return 'Wide-mouth Sterile Container';
    } else {
      return 'Standard Laboratory Container';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tubeColor = _getTubeColor(order.testName);
    final tubeName = _getTubeName(order.testName);
    final specimenId = order.specimenId ?? 'SPEC-PENDING';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                  child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryBlue, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Specimen Barcode Label',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Barcode Label Card (Simulates adhesive thermal tube label)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade400, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label Top Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'OPD CONNECT+ LAB',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tubeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: tubeColor, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: tubeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  order.specimenType.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: tubeColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 12, thickness: 1, color: Colors.black26),

                  // Patient Demographics on label
                  Text(
                    order.patientName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'UHID: ${order.uhid}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${order.patientAge ?? "--"}Y / ${order.patientGender ?? "--"}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TEST: ${order.testName}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Barcode Visual Representation
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    color: Colors.grey.shade50,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            26,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              width: (index % 4 == 0 || index % 7 == 0) ? 3.0 : 1.5,
                              height: 36,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          specimenId,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ORD: ${order.orderNumber}',
                        style: const TextStyle(fontSize: 9.5, color: Colors.black54),
                      ),
                      Text(
                        order.urgency == 'STAT' ? '⚡ STAT URGENT' : 'ROUTINE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: order.urgency == 'STAT' ? Colors.red : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            // Tube Guidance note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.science_outlined, size: 16, color: Colors.blueGrey.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Container: $tubeName',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Print Label'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Specimen label queued to thermal barcode printer ($specimenId)'),
                          backgroundColor: AppColors.primaryBlue,
                        ),
                      );
                    },
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
