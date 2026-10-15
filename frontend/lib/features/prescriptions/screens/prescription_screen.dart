import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/opd_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../../visits/models/visit_model.dart';
import '../models/prescription_model.dart';
import '../providers/prescription_provider.dart';

class PrescriptionScreen extends ConsumerStatefulWidget {
  final String visitId;
  final OPDVisitModel? visit;

  const PrescriptionScreen({
    super.key,
    required this.visitId,
    this.visit,
  });

  @override
  ConsumerState<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends ConsumerState<PrescriptionScreen> {
  final List<PrescriptionItemModel> _newItems = [];
  bool _isSaving = false;
  List<AllergyWarningModel> _activeAllergyWarnings = [];
  bool _allergyWarningAcknowledged = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkMedicationAllergies() async {
    final patId = widget.visit?.patientId;
    if (patId == null || _newItems.isEmpty) {
      setState(() => _activeAllergyWarnings = []);
      return;
    }

    final medNames = _newItems.map((e) => e.medicineName).toList();
    try {
      final warnings = await ref.read(prescriptionRepositoryProvider).checkAllergies(
            patientId: patId,
            medicines: medNames,
          );
      if (mounted) {
        setState(() {
          _activeAllergyWarnings = warnings;
          if (warnings.isEmpty) {
            _allergyWarningAcknowledged = true;
          }
        });
      }
    } catch (_) {}
  }

  void _showAddMedicineDialog() async {
    final catalog = await ref.read(prescriptionRepositoryProvider).searchMedicines();

    if (!mounted) return;

    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController(text: '650 mg');
    final durationCtrl = TextEditingController(text: '5');
    final quantityCtrl = TextEditingController(text: '10');
    final instructionsCtrl = TextEditingController();
    String form = 'Tablet';
    String route = 'Oral';
    String frequency = 'BD';
    String timing = 'After Food';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.medication_liquid_rounded, color: AppColors.primaryBlue),
                SizedBox(width: 8),
                Text('Add Medication', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Catalog Autocomplete / Quick Select
                    const Text('Catalog Search & Autocomplete', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Autocomplete<MedicineCatalogItemModel>(
                      displayStringForOption: (item) => item.name,
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return catalog.take(5);
                        }
                        return catalog.where((m) =>
                            m.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                            m.category.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (selected) {
                        setDialogState(() {
                          nameCtrl.text = selected.name;
                          if (selected.commonForms.isNotEmpty) form = selected.commonForms.first;
                          if (selected.commonDosages.isNotEmpty) doseCtrl.text = selected.commonDosages.first;
                          route = selected.defaultRoute;
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Medicine Name *',
                            hintText: 'Type to search (e.g. Paracetamol, Amoxicillin)',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: controller.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      controller.clear();
                                      nameCtrl.clear();
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (val) => nameCtrl.text = val,
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Form & Dosage
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: form,
                            items: OpdConstants.medicineForms
                                .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) => setDialogState(() => form = v ?? 'Tablet'),
                            decoration: const InputDecoration(labelText: 'Form'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: doseCtrl,
                            decoration: const InputDecoration(labelText: 'Dosage *', hintText: '650 mg / 5ml'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Route & Frequency
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: route,
                            items: const [
                              DropdownMenuItem(value: 'Oral', child: Text('Oral')),
                              DropdownMenuItem(value: 'Topical', child: Text('Topical')),
                              DropdownMenuItem(value: 'IV', child: Text('IV Infusion')),
                              DropdownMenuItem(value: 'IM', child: Text('IM Injection')),
                              DropdownMenuItem(value: 'Inhalation', child: Text('Inhalation')),
                              DropdownMenuItem(value: 'Sublingual', child: Text('Sublingual')),
                            ],
                            onChanged: (v) => setDialogState(() => route = v ?? 'Oral'),
                            decoration: const InputDecoration(labelText: 'Route'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: frequency,
                            items: const [
                              DropdownMenuItem(value: 'OD', child: Text('OD (1x Daily)', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'BD', child: Text('BD (2x Daily)', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'TID', child: Text('TID (3x Daily)', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'QID', child: Text('QID (4x Daily)', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'SOS', child: Text('SOS (As Needed)', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'Q4H', child: Text('Q4H (Every 4 hrs)', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (v) => setDialogState(() => frequency = v ?? 'BD'),
                            decoration: const InputDecoration(labelText: 'Frequency'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Duration (Days) & Quantity
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: durationCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Duration (Days)', hintText: '5'),
                            onChanged: (val) {
                              final d = int.tryParse(val) ?? 5;
                              int perDay = 1;
                              if (frequency == 'BD') perDay = 2;
                              if (frequency == 'TID') perDay = 3;
                              if (frequency == 'QID') perDay = 4;
                              quantityCtrl.text = '${d * perDay}';
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: quantityCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Quantity', hintText: '10 units'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Timing
                    DropdownButtonFormField<String>(
                      initialValue: timing,
                      items: const [
                        DropdownMenuItem(value: 'After Food', child: Text('After Food')),
                        DropdownMenuItem(value: 'Before Food', child: Text('Before Food (Empty Stomach)')),
                        DropdownMenuItem(value: 'Bedtime', child: Text('Bedtime (Night)')),
                        DropdownMenuItem(value: 'With Food', child: Text('With Meals')),
                      ],
                      onChanged: (v) => setDialogState(() => timing = v ?? 'After Food'),
                      decoration: const InputDecoration(labelText: 'Timing'),
                    ),
                    const SizedBox(height: 12),

                    // Instructions
                    TextField(
                      controller: instructionsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Instructions / Precaution',
                        hintText: 'e.g. Swallow whole with water, avoid dairy for 1 hour',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add to Prescription'),
                onPressed: () {
                  final finalName = nameCtrl.text.trim();
                  if (finalName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please specify a medication name.')),
                    );
                    return;
                  }

                  setState(() {
                    _newItems.add(PrescriptionItemModel(
                      medicineName: finalName,
                      form: form,
                      dosage: doseCtrl.text.trim().isNotEmpty ? doseCtrl.text.trim() : 'Standard',
                      route: route,
                      frequency: frequency,
                      durationDays: int.tryParse(durationCtrl.text.trim()) ?? 5,
                      quantity: int.tryParse(quantityCtrl.text.trim()) ?? 10,
                      timing: timing,
                      instructions: instructionsCtrl.text.trim().isNotEmpty ? instructionsCtrl.text.trim() : null,
                    ));
                  });
                  Navigator.pop(ctx);
                  _checkMedicationAllergies();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showConfirmSignDialog({required bool isDraft}) {
    if (_newItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one medication to prescribe.')),
      );
      return;
    }

    if (!isDraft && _activeAllergyWarnings.isNotEmpty && !_allergyWarningAcknowledged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Critical Allergy Warning must be acknowledged before signing!'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isDraft ? Icons.save_as_rounded : Icons.verified_rounded,
                color: isDraft ? Colors.amber : AppColors.statusCompleted,
              ),
              const SizedBox(width: 8),
              Text(isDraft ? 'Save Draft Prescription' : 'Sign & Finalize Prescription'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDraft
                      ? 'This prescription will be saved as a draft. It will not be sent to the pharmacy until signed.'
                      : 'You are about to digitally sign and release this prescription to the hospital dispensary and patient record.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                const Divider(),
                Text('Items (${_newItems.length} Drugs):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                for (final item in _newItems)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '• ${item.medicineName} ${item.dosage} (${item.form}) - ${item.frequency} x ${item.durationDays}d',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                if (_activeAllergyWarnings.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                            SizedBox(width: 6),
                            Text('Documented Allergy Alert', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(_activeAllergyWarnings.first.warningMessage, style: const TextStyle(fontSize: 11, color: Colors.red)),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text(
                            'I confirm clinical review and override documented allergy alert',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          value: _allergyWarningAcknowledged,
                          onChanged: (val) {
                            setDialogState(() {
                              _allergyWarningAcknowledged = val ?? false;
                            });
                            setState(() {
                              _allergyWarningAcknowledged = val ?? false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Back'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDraft ? Colors.amber : AppColors.statusCompleted,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _executeSavePrescription(status: isDraft ? 'DRAFT' : 'SIGNED');
              },
              child: Text(isDraft ? 'Save as Draft' : 'Sign & Authorize'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeSavePrescription({required String status}) async {
    setState(() => _isSaving = true);

    try {
      final rx = PrescriptionModel(
        id: '',
        visitId: widget.visitId,
        patientId: widget.visit?.patientId ?? '',
        doctorId: widget.visit?.doctorId ?? '',
        status: status,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        allergyWarningAcknowledged: _allergyWarningAcknowledged,
        items: _newItems,
      );

      await ref.read(prescriptionRepositoryProvider).createPrescription(rx);
      ref.invalidate(prescriptionListProvider(widget.visitId));

      setState(() {
        _newItems.clear();
        _activeAllergyWarnings.clear();
        _notesController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: status == 'SIGNED' ? AppColors.statusCompleted : Colors.amber.shade800,
            content: Text(
              status == 'SIGNED'
                  ? 'Prescription signed and authorized in patient record!'
                  : 'Draft prescription saved successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAmendDialog(PrescriptionModel existingRx) {
    final reasonCtrl = TextEditingController();
    final itemsToAmend = List<PrescriptionItemModel>.from(existingRx.items);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: AppColors.primaryBlue),
              SizedBox(width: 8),
              Text('Amend Prescription (Preserve Audit)'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Clinical amendments increment the prescription version and permanently snapshot the previous state in non-repudiation audit records.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Clinical Reason for Amendment *',
                      hintText: 'e.g. Dosage adjusted due to patient renal clearance report',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Current Items in this Prescription:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  for (int i = 0; i < itemsToAmend.length; i++)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        title: Text('${itemsToAmend[i].medicineName} ${itemsToAmend[i].dosage}'),
                        subtitle: Text('${itemsToAmend[i].frequency} • ${itemsToAmend[i].durationDays}d • Qty: ${itemsToAmend[i].quantity ?? 10}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () {
                            setDialogState(() {
                              itemsToAmend.removeAt(i);
                            });
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
              onPressed: () async {
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an amendment reason.')),
                  );
                  return;
                }
                if (itemsToAmend.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Prescription must have at least one medication.')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                try {
                  await ref.read(prescriptionRepositoryProvider).amendPrescription(
                        existingRx.id,
                        reason: reason,
                        items: itemsToAmend,
                      );
                  ref.invalidate(prescriptionListProvider(widget.visitId));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.primaryBlue,
                        content: Text('Prescription amended and non-repudiation audit snapshot preserved!'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Amendment error: $e')),
                    );
                  }
                }
              },
              child: const Text('Confirm Amendment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(PrescriptionModel existingRx) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Prescription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this prescription? This action will mark it cancelled in the pharmacy queue.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason',
                hintText: 'e.g. Changed clinical course',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(prescriptionRepositoryProvider).cancelPrescription(
                      existingRx.id,
                      reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'Clinician cancelled',
                    );
                ref.invalidate(prescriptionListProvider(widget.visitId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Prescription marked CANCELLED.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Cancel Rx'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rxListAsync = ref.watch(prescriptionListProvider(widget.visitId));
    final authState = ref.watch(authProvider);
    final currentRole = authState.user?.roleName.toLowerCase() ?? 'doctor';
    final isPatient = currentRole == 'patient';
    final isPharmacist = currentRole == 'pharmacist';
    final canPrescribe = currentRole == 'doctor' || currentRole == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isPatient
              ? 'Prescribed Medications (Patient View)'
              : isPharmacist
                  ? 'Dispensary Verification'
                  : 'Doctor Prescription Portal',
        ),
        actions: [
          if (canPrescribe)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Add Drug',
              onPressed: _showAddMedicineDialog,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPatient) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryTeal.withOpacity(0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.primaryTeal, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Patient View (Read-Only): Authorized prescription history and dosages prescribed by your attending doctor.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 1. Patient & Clinician Banner
            if (widget.visit != null) _buildPatientHeaderCard(),
            const SizedBox(height: 16),

            // 2. Critical Allergy Warning Alert (if any active warnings)
            if (canPrescribe && _activeAllergyWarnings.isNotEmpty) _buildAllergyAlertBanner(),
            if (canPrescribe && _activeAllergyWarnings.isNotEmpty) const SizedBox(height: 16),

            // 3. Newly Added Prescription Draft Workspace
            if (canPrescribe && _newItems.isNotEmpty) _buildDraftWorkspaceCard(),
            if (canPrescribe && _newItems.isNotEmpty) const SizedBox(height: 24),

            // 4. Server Prescriptions (Distinguished by DRAFT, SIGNED, AMENDED, CANCELLED)
            const Text(
              'Authorized Prescriptions for Visit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            rxListAsync.when(
              data: (rxList) {
                if (rxList.isEmpty && _newItems.isEmpty) {
                  return _buildEmptyState();
                }

                return Column(
                  children: rxList.map((rx) => _buildPrescriptionCard(rx, canPrescribe: canPrescribe)).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading prescriptions: $err'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientHeaderCard() {
    final pat = widget.visit?.patient;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
              child: const Icon(Icons.person_rounded, color: AppColors.primaryBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pat?.fullName ?? 'Authorized Patient',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'UHID: ${pat?.uhid ?? "UHID"} • Token #${widget.visit?.queueToken ?? 1} • Visit ${widget.visit?.visitNumber ?? ""}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Text(
                    'Clinician: ${widget.visit?.doctorName ?? "Prescribing Clinician"}',
                    style: const TextStyle(fontSize: 11, color: AppColors.primaryTeal, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllergyAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade400, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              Text(
                'CLINICAL ALLERGY ALERT (${_activeAllergyWarnings.length} Detected)',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final w in _activeAllergyWarnings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• ${w.warningMessage}',
                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _allergyWarningAcknowledged,
                activeColor: Colors.red,
                onChanged: (val) {
                  setState(() => _allergyWarningAcknowledged = val ?? false);
                },
              ),
              const Expanded(
                child: Text(
                  'I have reviewed patient allergy history and explicitly confirm clinical override.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDraftWorkspaceCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_document, color: AppColors.primaryBlue),
                    SizedBox(width: 8),
                    Text(
                      'Draft Prescription Workspace',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryBlue),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Text('UNSAVED (${_newItems.length})', style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in _newItems)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: Colors.grey.shade50,
                child: ListTile(
                  dense: true,
                  leading: const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFE0F2FE),
                    child: Icon(Icons.medication_rounded, size: 16, color: AppColors.primaryBlue),
                  ),
                  title: Text('${item.medicineName} ${item.dosage} (${item.form})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${item.frequency} • ${item.durationDays} Days • Qty: ${item.quantity ?? 10} • ${item.timing}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    onPressed: () {
                      setState(() {
                        _newItems.remove(item);
                        _checkMedicationAllergies();
                      });
                    },
                  ),
                ),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Pharmacist / Patient Instructions',
                hintText: 'e.g. Advise patient to drink plenty of fluids',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.save_as_rounded, size: 18),
                    label: const Text('Save Draft'),
                    onPressed: _isSaving ? null : () => _showConfirmSignDialog(isDraft: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusCompleted,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.verified_rounded, size: 18),
                    label: const Text('Sign & Authorize'),
                    onPressed: _isSaving ? null : () => _showConfirmSignDialog(isDraft: false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionCard(PrescriptionModel rx, {bool canPrescribe = true}) {
    Color statusColor = AppColors.statusCompleted;
    String statusLabel = rx.status.toUpperCase();
    if (rx.isDraft) {
      statusColor = Colors.amber.shade700;
    } else if (rx.isAmended) {
      statusColor = const Color(0xFF3B82F6);
    } else if (rx.isCancelled) {
      statusColor = Colors.red;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Version Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Version ${rx.version}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                  ],
                ),
                if (canPrescribe && !rx.isCancelled)
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'sign') {
                        ref.read(prescriptionRepositoryProvider).signPrescription(rx.id).then((_) {
                          ref.invalidate(prescriptionListProvider(widget.visitId));
                        });
                      } else if (val == 'amend') {
                        _showAmendDialog(rx);
                      } else if (val == 'cancel') {
                        _showCancelDialog(rx);
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (rx.isDraft)
                        const PopupMenuItem(value: 'sign', child: Text('Sign Prescription')),
                      if (!rx.isDraft)
                        const PopupMenuItem(value: 'amend', child: Text('Amend Prescription')),
                      const PopupMenuItem(value: 'cancel', child: Text('Cancel Prescription', style: TextStyle(color: Colors.red))),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // OCR Unverified Warning Banner
            if (rx.isOcrExtracted && !rx.isVerifiedByClinician)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.document_scanner_rounded, color: Colors.amber, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'UNVERIFIED OCR EXTRACTION - Must be confirmed by authorized clinician',
                        style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // Prescription Items
            for (final it in rx.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${it.medicineName} ${it.dosage} (${it.form}) • ${it.frequency} • ${it.durationDays}d • ${it.timing}',
                        style: TextStyle(
                          fontSize: 13,
                          decoration: rx.isCancelled ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (rx.notes != null) ...[
              const SizedBox(height: 6),
              Text('Notes: ${rx.notes}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
            ],

            if (rx.signedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Signed by Clinician at ${rx.signedAt?.split("T").first}',
                style: const TextStyle(fontSize: 11, color: AppColors.statusCompleted, fontWeight: FontWeight.w600),
              ),
            ],

            // Amendments Log
            if (rx.amendments.isNotEmpty) ...[
              const Divider(height: 16),
              Text('Amendment History (${rx.amendments.length}):', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              for (final amd in rx.amendments)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('• ${amd.reason} (${amd.amendedAt.split("T").first})', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.medication_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('No medications prescribed yet'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Medication'),
              onPressed: _showAddMedicineDialog,
            ),
          ],
        ),
      ),
    );
  }
}
