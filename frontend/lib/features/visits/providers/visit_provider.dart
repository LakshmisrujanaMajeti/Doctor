import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/visit_model.dart';
import '../repositories/visit_repository.dart';

final visitRepositoryProvider = Provider<VisitRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return VisitRepository(dioClient);
});

class VisitStatusFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFilter(String? status) => state = status;
}

final visitStatusFilterProvider = NotifierProvider<VisitStatusFilterNotifier, String?>(VisitStatusFilterNotifier.new);

final visitListProvider = FutureProvider<List<OPDVisitModel>>((ref) async {
  final repository = ref.watch(visitRepositoryProvider);
  final status = ref.watch(visitStatusFilterProvider);
  return repository.getVisits(status: status);
});

final patientVisitsProvider = FutureProvider.family<List<OPDVisitModel>, String>((ref, patientId) async {
  final repository = ref.watch(visitRepositoryProvider);
  final all = await repository.getVisits();
  return all.where((v) => v.patientId == patientId).toList();
});
