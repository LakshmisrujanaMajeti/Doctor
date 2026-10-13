import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/pharmacy_models.dart';
import '../repositories/pharmacy_repository.dart';

final pharmacyRepositoryProvider = Provider<PharmacyRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return PharmacyRepository(dioClient);
});

final pharmacyStatsProvider = FutureProvider<InventoryStats>((ref) async {
  final repo = ref.watch(pharmacyRepositoryProvider);
  return repo.getInventoryStats();
});

class PharmacyInventoryFilterState {
  final String query;
  final String dosageForm;
  final bool lowStockOnly;
  final bool expiringSoonOnly;

  const PharmacyInventoryFilterState({
    this.query = '',
    this.dosageForm = 'All',
    this.lowStockOnly = false,
    this.expiringSoonOnly = false,
  });

  PharmacyInventoryFilterState copyWith({
    String? query,
    String? dosageForm,
    bool? lowStockOnly,
    bool? expiringSoonOnly,
  }) {
    return PharmacyInventoryFilterState(
      query: query ?? this.query,
      dosageForm: dosageForm ?? this.dosageForm,
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
      expiringSoonOnly: expiringSoonOnly ?? this.expiringSoonOnly,
    );
  }
}

class PharmacyInventoryFilterNotifier extends Notifier<PharmacyInventoryFilterState> {
  @override
  PharmacyInventoryFilterState build() => const PharmacyInventoryFilterState();

  void setQuery(String q) {
    state = state.copyWith(query: q);
  }

  void setDosageForm(String form) {
    state = state.copyWith(dosageForm: form);
  }

  void toggleLowStock(bool val) {
    state = state.copyWith(lowStockOnly: val);
  }

  void toggleExpiringSoon(bool val) {
    state = state.copyWith(expiringSoonOnly: val);
  }

  void reset() {
    state = const PharmacyInventoryFilterState();
  }
}

final pharmacyInventoryFilterProvider =
    NotifierProvider<PharmacyInventoryFilterNotifier, PharmacyInventoryFilterState>(
  PharmacyInventoryFilterNotifier.new,
);

final pharmacyInventoryListProvider = FutureProvider<List<MedicineInventoryItem>>((ref) async {
  final repo = ref.watch(pharmacyRepositoryProvider);
  final filter = ref.watch(pharmacyInventoryFilterProvider);

  return repo.getInventory(
    query: filter.query.isNotEmpty ? filter.query : null,
    dosageForm: filter.dosageForm != 'All' ? filter.dosageForm : null,
    lowStock: filter.lowStockOnly ? true : null,
    expiringSoon: filter.expiringSoonOnly ? true : null,
  );
});

final prescriptionsForDispensingProvider = FutureProvider<List<PrescriptionForDispensing>>((ref) async {
  final repo = ref.watch(pharmacyRepositoryProvider);
  return repo.getPrescriptionsForDispensing();
});

final pharmacyDispensesHistoryProvider = FutureProvider<List<PharmacyDispenseRecord>>((ref) async {
  final repo = ref.watch(pharmacyRepositoryProvider);
  return repo.getDispensesHistory();
});

final pharmacyStockMovementsProvider = FutureProvider<List<StockMovementItem>>((ref) async {
  final repo = ref.watch(pharmacyRepositoryProvider);
  return repo.getStockMovements();
});
