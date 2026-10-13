import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/laboratory_models.dart';
import '../repositories/laboratory_repository.dart';

final laboratoryRepositoryProvider = Provider<LaboratoryRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return LaboratoryRepository(dioClient);
});

final labCatalogueProvider = FutureProvider.family<List<LabCatalogueItem>, String?>((ref, category) async {
  final repo = ref.watch(laboratoryRepositoryProvider);
  return repo.getCatalogue(category: category);
});

final labDashboardStatsProvider = FutureProvider<LabDashboardStatsModel>((ref) async {
  final repo = ref.watch(laboratoryRepositoryProvider);
  return repo.getDashboardStats();
});

class LabOrdersFilterState {
  final String department;
  final String specimenStatus;
  final String search;
  final String? date;

  const LabOrdersFilterState({
    this.department = 'All',
    this.specimenStatus = 'All',
    this.search = '',
    this.date,
  });

  LabOrdersFilterState copyWith({
    String? department,
    String? specimenStatus,
    String? search,
    String? date,
    bool clearDate = false,
  }) {
    return LabOrdersFilterState(
      department: department ?? this.department,
      specimenStatus: specimenStatus ?? this.specimenStatus,
      search: search ?? this.search,
      date: clearDate ? null : (date ?? this.date),
    );
  }
}

class LabOrdersFilterNotifier extends Notifier<LabOrdersFilterState> {
  @override
  LabOrdersFilterState build() => const LabOrdersFilterState();

  void setDepartment(String dept) {
    state = state.copyWith(department: dept);
  }

  void setSpecimenStatus(String status) {
    state = state.copyWith(specimenStatus: status);
  }

  void setSearch(String query) {
    state = state.copyWith(search: query);
  }

  void setDate(String? date) {
    if (date == null) {
      state = state.copyWith(clearDate: true);
    } else {
      state = state.copyWith(date: date);
    }
  }

  void reset() {
    state = const LabOrdersFilterState();
  }
}

final labOrdersFilterProvider =
    NotifierProvider<LabOrdersFilterNotifier, LabOrdersFilterState>(LabOrdersFilterNotifier.new);

final labOrdersListProvider = FutureProvider<List<LabOrderModel>>((ref) async {
  final repo = ref.watch(laboratoryRepositoryProvider);
  final filter = ref.watch(labOrdersFilterProvider);

  return repo.getOrders(
    department: filter.department,
    specimenStatus: filter.specimenStatus,
    search: filter.search,
    date: filter.date,
  );
});

final labOrderDetailProvider = FutureProvider.family<LabOrderModel?, String>((ref, id) async {
  final repo = ref.watch(laboratoryRepositoryProvider);
  return repo.getOrderById(id);
});

final labPrintableReportProvider = FutureProvider.family<LabReportDataModel, String>((ref, orderId) async {
  final repo = ref.watch(laboratoryRepositoryProvider);
  return repo.getPrintableReport(orderId);
});

final labOrdersByVisitProvider = FutureProvider.family<List<LabOrderModel>, String>((ref, visitId) async {
  final repo = ref.watch(laboratoryRepositoryProvider);
  return repo.getOrdersByVisit(visitId);
});
