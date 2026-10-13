import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/triage_chip.dart';
import '../providers/visit_provider.dart';

class OpdQueueScreen extends ConsumerWidget {
  const OpdQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(visitListProvider);
    final currentFilter = ref.watch(visitStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live OPD Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(visitListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Book Visit'),
        onPressed: () => context.push('/visits/new'),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _filterChip(ref, null, 'All Visits', currentFilter == null),
                const SizedBox(width: 8),
                _filterChip(ref, 'REGISTERED', 'Waiting Triage', currentFilter == 'REGISTERED'),
                const SizedBox(width: 8),
                _filterChip(ref, 'TRIAGED', 'Ready for Doctor', currentFilter == 'TRIAGED'),
                const SizedBox(width: 8),
                _filterChip(ref, 'IN_CONSULTATION', 'In Consultation', currentFilter == 'IN_CONSULTATION'),
                const SizedBox(width: 8),
                _filterChip(ref, 'COMPLETED', 'Completed', currentFilter == 'COMPLETED'),
              ],
            ),
          ),

          // Visits List
          Expanded(
            child: visitsAsync.when(
              data: (visits) {
                if (visits.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.queue_rounded, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text(
                          'No visits in this queue',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Select another filter or tap "+ Book Visit" to generate a token.',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: visits.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final visit = visits[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              children: [
                                // Token Number
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTeal.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primaryTeal.withOpacity(0.3)),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '#${visit.queueToken}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: AppColors.primaryTeal,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        visit.patient?.fullName ?? 'Patient ${visit.visitNumber}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${visit.patient?.uhid ?? "UHID Pending"} • ${visit.departmentName}',
                                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    TriageChip(priority: visit.triagePriority),
                                    const SizedBox(height: 6),
                                    StatusBadge(status: visit.status),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 24),

                            // Doctor & Vitals Info
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_pin_rounded, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      visit.doctorName ?? 'Consulting Doctor',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                if (visit.vitals != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'BP: ${visit.vitals!.bloodPressureDisplay} • SpO2: ${visit.vitals!.spo2Percent ?? "--"}%',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal),
                                    ),
                                  )
                                else
                                  Text(
                                    'Vitals Pending',
                                    style: TextStyle(fontSize: 12, color: Colors.amber[800], fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Action Buttons Row
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.monitor_heart_rounded, size: 16),
                                    label: Text(visit.vitals == null ? 'Record Vitals' : 'Edit Vitals'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => context.push('/visits/${visit.id}/vitals', extra: visit),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                                    label: const Text('OPD Sheet'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryTeal,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => context.push('/visits/${visit.id}/consultation', extra: visit),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading queue: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(WidgetRef ref, String? status, String label, bool isSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        ref.read(visitStatusFilterProvider.notifier).setFilter(status);
      },
    );
  }
}
