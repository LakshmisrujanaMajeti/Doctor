import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/billing_models.dart';
import '../repositories/billing_repository.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return BillingRepository(dioClient);
});

final servicesCatalogueProvider = FutureProvider<List<ServiceCatalogueItem>>((ref) async {
  final repo = ref.watch(billingRepositoryProvider);
  return repo.getServicesCatalogue();
});

class BillingFilterState {
  final String status;
  final String paymentStatus;
  final String search;

  const BillingFilterState({
    this.status = 'All',
    this.paymentStatus = 'All',
    this.search = '',
  });

  BillingFilterState copyWith({
    String? status,
    String? paymentStatus,
    String? search,
  }) {
    return BillingFilterState(
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      search: search ?? this.search,
    );
  }
}

class BillingFilterNotifier extends Notifier<BillingFilterState> {
  @override
  BillingFilterState build() => const BillingFilterState();

  void setStatus(String status) {
    state = state.copyWith(status: status);
  }

  void setPaymentStatus(String paymentStatus) {
    state = state.copyWith(paymentStatus: paymentStatus);
  }

  void setSearch(String q) {
    state = state.copyWith(search: q);
  }

  void reset() {
    state = const BillingFilterState();
  }
}

final billingFilterProvider =
    NotifierProvider<BillingFilterNotifier, BillingFilterState>(
  BillingFilterNotifier.new,
);

final billsListProvider = FutureProvider<List<BillModel>>((ref) async {
  final repo = ref.watch(billingRepositoryProvider);
  final filter = ref.watch(billingFilterProvider);

  final bills = await repo.getBills(
    status: filter.status != 'All' ? filter.status : null,
    paymentStatus: filter.paymentStatus != 'All' ? filter.paymentStatus : null,
  );

  if (filter.search.trim().isEmpty) {
    return bills;
  }

  final query = filter.search.toLowerCase().trim();
  return bills.where((b) {
    return b.invoiceNumber.toLowerCase().contains(query) ||
        b.patientName.toLowerCase().contains(query) ||
        b.patientUhid.toLowerCase().contains(query) ||
        b.visitNumber.toLowerCase().contains(query);
  }).toList();
});

final billDetailProvider = FutureProvider.family<BillModel?, String>((ref, billId) async {
  final repo = ref.watch(billingRepositoryProvider);
  return repo.getBillById(billId);
});
