import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/opd_text_field.dart';
import '../models/visit_model.dart';
import '../models/vitals_model.dart';
import '../providers/visit_provider.dart';

class RecordVitalsScreen extends ConsumerStatefulWidget {
  final String visitId;
  final OPDVisitModel? visit;

  const RecordVitalsScreen({
    super.key,
    required this.visitId,
    this.visit,
  });

  @override
  ConsumerState<RecordVitalsScreen> createState() => _RecordVitalsScreenState();
}

class _RecordVitalsScreenState extends ConsumerState<RecordVitalsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _pulseController = TextEditingController();
  final _tempController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _respController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  double? _calculatedBmi;
  String _bmiCategory = '--';
  String _urgencyLevel = 'NORMAL';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.visit?.triagePriority != null && widget.visit!.triagePriority.isNotEmpty) {
      _urgencyLevel = widget.visit!.triagePriority;
    }
    final v = widget.visit?.vitals;
    if (v != null) {
      if (v.systolicBp != null) _systolicController.text = v.systolicBp.toString();
      if (v.diastolicBp != null) _diastolicController.text = v.diastolicBp.toString();
      if (v.pulseRate != null) _pulseController.text = v.pulseRate.toString();
      if (v.temperatureF != null) _tempController.text = v.temperatureF.toString();
      if (v.spo2Percent != null) _spo2Controller.text = v.spo2Percent.toString();
      if (v.respiratoryRate != null) _respController.text = v.respiratoryRate.toString();
      if (v.heightCm != null) _heightController.text = v.heightCm.toString();
      if (v.weightKg != null) _weightController.text = v.weightKg.toString();
      if (v.notes != null) _notesController.text = v.notes!;
      _updateBmi();
    }
  }

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _pulseController.dispose();
    _tempController.dispose();
    _spo2Controller.dispose();
    _respController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateBmi() {
    final h = double.tryParse(_heightController.text.trim());
    final w = double.tryParse(_weightController.text.trim());

    if (h != null && w != null && h > 0) {
      final hm = h / 100.0;
      final bmi = double.parse((w / (hm * hm)).toStringAsFixed(1));
      setState(() {
        _calculatedBmi = bmi;
        if (bmi < 18.5) {
          _bmiCategory = 'Underweight';
        } else if (bmi < 25.0) {
          _bmiCategory = 'Normal Weight';
        } else if (bmi < 30.0) {
          _bmiCategory = 'Overweight';
        } else {
          _bmiCategory = 'Obese';
        }
      });
    } else {
      setState(() {
        _calculatedBmi = null;
        _bmiCategory = '--';
      });
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    try {
      final vitals = VitalSignsModel(
        id: '',
        visitId: widget.visitId,
        systolicBp: int.tryParse(_systolicController.text.trim()),
        diastolicBp: int.tryParse(_diastolicController.text.trim()),
        pulseRate: int.tryParse(_pulseController.text.trim()),
        temperatureF: double.tryParse(_tempController.text.trim()),
        spo2Percent: double.tryParse(_spo2Controller.text.trim()),
        respiratoryRate: int.tryParse(_respController.text.trim()),
        heightCm: double.tryParse(_heightController.text.trim()),
        weightKg: double.tryParse(_weightController.text.trim()),
        bmi: _calculatedBmi,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      await ref.read(visitRepositoryProvider).recordVitals(vitals, triagePriority: _urgencyLevel);
      ref.invalidate(visitListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primaryTeal,
            content: Text('Vital signs recorded successfully! Visit triaged.'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving vitals: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visit = widget.visit;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go('/queue');
            }
          },
        ),
        title: const Text('Nursing Triage & Vitals'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Banner
                  if (visit != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primaryTeal.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTeal,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '#${visit.queueToken}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  visit.patient?.fullName ?? 'Patient ${visit.visitNumber}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                                Text(
                                  'UHID: ${visit.patient?.uhid ?? "UHID"} • ${visit.departmentName}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Blood Pressure
                  const Text('Blood Pressure (BP)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OpdTextField(
                          label: 'Systolic (mmHg)',
                          hint: 'e.g. 120',
                          controller: _systolicController,
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.favorite_border_rounded,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: OpdTextField(
                          label: 'Diastolic (mmHg)',
                          hint: 'e.g. 80',
                          controller: _diastolicController,
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.favorite_border_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Pulse & Temperature
                  Row(
                    children: [
                      Expanded(
                        child: OpdTextField(
                          label: 'Pulse (beats/min)',
                          hint: 'e.g. 72',
                          controller: _pulseController,
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.monitor_heart_outlined,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: OpdTextField(
                          label: 'Temperature (°F)',
                          hint: 'e.g. 98.6',
                          controller: _tempController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          prefixIcon: Icons.thermostat_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // SpO2 & Respiratory Rate
                  Row(
                    children: [
                      Expanded(
                        child: OpdTextField(
                          label: 'SpO2 Oxygen (%)',
                          hint: 'e.g. 98',
                          controller: _spo2Controller,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          prefixIcon: Icons.air_rounded,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: OpdTextField(
                          label: 'Respiratory Rate (/min)',
                          hint: 'e.g. 16',
                          controller: _respController,
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.waves_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Height & Weight & Live BMI
                  Row(
                    children: [
                      Expanded(
                        child: OpdTextField(
                          label: 'Height (cm)',
                          hint: 'e.g. 175',
                          controller: _heightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          prefixIcon: Icons.height_rounded,
                          onChanged: (_) => _updateBmi(),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: OpdTextField(
                          label: 'Weight (kg)',
                          hint: 'e.g. 70',
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          prefixIcon: Icons.fitness_center_rounded,
                          onChanged: (_) => _updateBmi(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // BMI Calculated Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _bmiColor(_bmiCategory).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _bmiColor(_bmiCategory).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.speed_rounded, color: _bmiColor(_bmiCategory)),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Calculated BMI (kg/m²)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(
                                  _calculatedBmi != null ? '$_calculatedBmi' : '--',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: _bmiColor(_bmiCategory),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _bmiColor(_bmiCategory).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _bmiCategory,
                            style: TextStyle(
                              color: _bmiColor(_bmiCategory),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Triage Urgency Level (Protocol)
                  const Text('Triage Urgency Protocol', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Routine (Normal)')),
                          selected: _urgencyLevel == 'NORMAL',
                          selectedColor: AppColors.triageNormal.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: _urgencyLevel == 'NORMAL' ? AppColors.triageNormal : Colors.grey,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _urgencyLevel = 'NORMAL');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Urgent')),
                          selected: _urgencyLevel == 'URGENT',
                          selectedColor: AppColors.triagePriority.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: _urgencyLevel == 'URGENT' ? AppColors.triagePriority : Colors.grey,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _urgencyLevel = 'URGENT');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Emergency')),
                          selected: _urgencyLevel == 'EMERGENCY',
                          selectedColor: AppColors.triageEmergency.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: _urgencyLevel == 'EMERGENCY' ? AppColors.triageEmergency : Colors.grey,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _urgencyLevel = 'EMERGENCY');
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_urgencyLevel == 'EMERGENCY') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.triageEmergency.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.triageEmergency.withOpacity(0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppColors.triageEmergency, size: 24),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'EMERGENCY WARNING SIGNS DETECTED: Escalating immediately to the clinical team. Patient will bypass routine queue wait.',
                              style: TextStyle(
                                color: AppColors.triageEmergency,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Triage Notes
                  OpdTextField(
                    label: 'Triage Nurse Notes',
                    hint: 'Patient remarks, acute pain level, or nursing observations',
                    controller: _notesController,
                    maxLines: 2,
                    prefixIcon: Icons.assignment_outlined,
                  ),
                  const SizedBox(height: 32),

                  // Save
                  OpdButton(
                    label: 'Save Vitals & Complete Triage',
                    isLoading: _isSaving,
                    icon: Icons.check_circle_rounded,
                    width: double.infinity,
                    onPressed: _handleSave,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _bmiColor(String cat) {
    switch (cat) {
      case 'Normal Weight':
        return AppColors.triageNormal;
      case 'Overweight':
        return AppColors.triagePriority;
      case 'Obese':
      case 'Underweight':
        return AppColors.triageEmergency;
      default:
        return Colors.grey;
    }
  }
}
