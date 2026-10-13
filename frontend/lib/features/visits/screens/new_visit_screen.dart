import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/opd_constants.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/triage_chip.dart';
import '../../patients/models/patient_model.dart';
import '../../patients/providers/patient_provider.dart';
import '../providers/visit_provider.dart';

class NewVisitScreen extends ConsumerStatefulWidget {
  final PatientModel? initialPatient;

  const NewVisitScreen({super.key, this.initialPatient});

  @override
  ConsumerState<NewVisitScreen> createState() => _NewVisitScreenState();
}

class _NewVisitScreenState extends ConsumerState<NewVisitScreen> {
  PatientModel? _selectedPatient;
  String _selectedDepartment = 'General Medicine';
  String _triagePriority = 'NORMAL';
  final _feeController = TextEditingController(text: '500.00');
  final _notesController = TextEditingController();
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    _selectedPatient = widget.initialPatient;
  }

  @override
  void dispose() {
    _feeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleBookVisit() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient')),
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      final createdVisit = await ref.read(visitRepositoryProvider).createVisit(
        patientId: _selectedPatient!.id,
        doctorId: 'default',
        departmentId: _selectedDepartment,
        triagePriority: _triagePriority,
        consultationFee: double.tryParse(_feeController.text.trim()) ?? 500.0,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      ref.invalidate(visitListProvider);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.primaryTeal),
                SizedBox(width: 8),
                Text('OPD Token Generated!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('TOKEN NUMBER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryTeal)),
                      const SizedBox(height: 4),
                      Text(
                        '#${createdVisit.queueToken}',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.primaryTeal),
                      ),
                      Text('Visit Slip: ${createdVisit.visitNumber}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Patient: ${_selectedPatient!.fullName}'),
                Text('UHID: ${_selectedPatient!.uhid}'),
                Text('Department: $_selectedDepartment'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Priority: '),
                    TriageChip(priority: _triagePriority, compact: true),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pop();
                },
                child: const Text('Return to Queue'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pushReplacement('/visits/${createdVisit.id}/vitals', extra: createdVisit);
                },
                child: const Text('Record Vitals Now'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book OPD Visit & Issue Token'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Selector
                const Text(
                  '1. Select Patient *',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                if (_selectedPatient != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.primaryTeal,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedPatient!.fullName,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              Text(
                                '${_selectedPatient!.uhid} • ${_selectedPatient!.gender} • ${_selectedPatient!.phone}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _selectedPatient = null),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  )
                else
                  patientsAsync.when(
                    data: (patients) => DropdownButtonFormField<PatientModel>(
                      hint: const Text('Select existing patient or register new'),
                      items: patients.map((p) => DropdownMenuItem(
                        value: p,
                        child: Text('${p.fullName} (${p.uhid})'),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedPatient = val),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_search_rounded),
                      ),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (err, stack) => const Text('Error loading patients'),
                  ),
                const SizedBox(height: 24),

                // Department
                const Text(
                  '2. OPD Department & Doctor',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDepartment,
                  items: OpdConstants.departments
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDepartment = val);
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.domain_rounded),
                  ),
                ),
                const SizedBox(height: 24),

                // Triage Priority
                const Text(
                  '3. Triage Priority Level',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _priorityRadio('NORMAL', 'Normal Routine', AppColors.triageNormal),
                    const SizedBox(width: 8),
                    _priorityRadio('PRIORITY', 'Priority Urgent', AppColors.triagePriority),
                    const SizedBox(width: 8),
                    _priorityRadio('EMERGENCY', 'Emergency', AppColors.triageEmergency),
                  ],
                ),
                const SizedBox(height: 24),

                // Consultation Fee & Notes
                const Text(
                  '4. Visit Details & Chief Notes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _feeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Consultation Fee (\$)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Initial Symptoms / Chief Complaint summary',
                    hintText: 'e.g. High fever with throat congestion for 2 days',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 36),

                // Book Button
                OpdButton(
                  label: 'Generate Token & Print OPD Slip',
                  isLoading: _isBooking,
                  icon: Icons.confirmation_number_rounded,
                  width: double.infinity,
                  onPressed: _handleBookVisit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _priorityRadio(String val, String label, Color color) {
    final isSelected = _triagePriority == val;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _triagePriority = val),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : null,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
