import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opd_connect/core/network/dio_client.dart';
import 'package:opd_connect/features/pharmacy/models/pharmacy_models.dart';
import 'package:opd_connect/features/pharmacy/repositories/pharmacy_repository.dart';
import 'package:opd_connect/features/pharmacy/providers/pharmacy_provider.dart';
import 'package:opd_connect/features/pharmacy/screens/pharmacy_workspace_view.dart';
import 'package:opd_connect/features/pharmacy/widgets/dispense_prescription_dialog.dart';
import 'package:opd_connect/features/pharmacy/widgets/stock_receipt_dialog.dart';
import 'package:opd_connect/features/billing/models/billing_models.dart';
import 'package:opd_connect/features/billing/repositories/billing_repository.dart';
import 'package:opd_connect/features/billing/providers/billing_provider.dart';
import 'package:opd_connect/features/billing/screens/billing_workspace_view.dart';
import 'package:opd_connect/features/billing/screens/printable_invoice_screen.dart';
import 'package:opd_connect/features/billing/widgets/payment_dialog.dart';

class MockPharmacyRepository extends PharmacyRepository {
  MockPharmacyRepository() : super(DioClient());

  @override
  Future<InventoryStats> getInventoryStats() async {
    return const InventoryStats(
      totalMedicines: 12,
      totalStockUnits: 850,
      lowStockCount: 2,
      expiringSoonCount: 1,
      expiredCount: 1,
      totalDispensesToday: 8,
    );
  }

  @override
  Future<List<MedicineInventoryItem>> getInventory({
    String? query,
    String? dosageForm,
    bool? lowStock,
    bool? expiringSoon,
    int limit = 100,
    int offset = 0,
  }) async {
    return [
      const MedicineInventoryItem(
        id: 'med-1',
        medicineCode: 'MED-PCM-500',
        name: 'Paracetamol 500mg',
        genericName: 'Paracetamol',
        strength: '500 mg',
        dosageForm: 'Tablet',
        batchNumber: 'BAT-PCM-01',
        expiryDate: '2027-05-30',
        availableQuantity: 120,
        minimumStockLevel: 20,
        unitPrice: 3.50,
        taxClassification: 'GST_12',
      ),
      const MedicineInventoryItem(
        id: 'med-2',
        medicineCode: 'MED-AZI-500',
        name: 'Azithromycin 500mg',
        genericName: 'Azithromycin',
        strength: '500 mg',
        dosageForm: 'Tablet',
        batchNumber: 'BAT-AZI-02',
        expiryDate: '2026-12-15',
        availableQuantity: 8,
        minimumStockLevel: 20,
        unitPrice: 22.00,
        isLowStock: true,
        taxClassification: 'GST_12',
      ),
    ];
  }

  @override
  Future<List<PrescriptionForDispensing>> getPrescriptionsForDispensing({
    String? visitId,
    String? patientId,
  }) async {
    return [
      const PrescriptionForDispensing(
        id: 'rx-test-1',
        visitId: 'vis-1',
        patientId: 'pat-1',
        patientName: 'Satya Narayan',
        patientUhid: 'UHID-2026-0001',
        doctorName: 'Dr. Sarah Chen, MD',
        status: 'SIGNED',
        signedAt: '2026-10-12T10:30:00Z',
        items: [
          PrescriptionReadyItem(
            id: 'item-1',
            medicineName: 'Paracetamol 500mg',
            form: 'Tablet',
            dosage: '500 mg',
            route: 'Oral',
            frequency: 'TID',
            durationDays: 3,
            quantity: 6,
            timing: 'After Food',
            instructions: 'Take with warm water',
            availableBatches: [
              InventoryBatchOption(
                inventoryId: 'med-1',
                batchNumber: 'BAT-PCM-01',
                expiryDate: '2027-05-30',
                availableQuantity: 120,
                unitPrice: 3.50,
              ),
            ],
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<PharmacyDispenseRecord>> getDispensesHistory({
    String? visitId,
    String? patientId,
    int limit = 50,
    int offset = 0,
  }) async {
    return [
      const PharmacyDispenseRecord(
        id: 'disp-1',
        dispenseNumber: 'DISP-20261012-001',
        prescriptionId: 'rx-test-1',
        patientId: 'pat-1',
        patientName: 'Satya Narayan',
        patientUhid: 'UHID-2026-0001',
        visitId: 'vis-1',
        dispensedByName: 'Elena Rostova (Pharmacist)',
        dispensedAt: '2026-10-12T11:00:00Z',
        status: 'COMPLETED',
        totalItemsDispensed: 6,
        totalAmount: 21.00,
      ),
    ];
  }

  @override
  Future<List<StockMovementItem>> getStockMovements({
    String? inventoryId,
    int limit = 100,
    int offset = 0,
  }) async {
    return [
      const StockMovementItem(
        id: 'mov-1',
        inventoryId: 'med-1',
        medicineName: 'Paracetamol 500mg',
        batchNumber: 'BAT-PCM-01',
        movementType: 'RECEIPT',
        quantity: 100,
        balanceAfter: 120,
        referenceNumber: 'PO-2026-001',
        performedByName: 'Elena Rostova',
      ),
    ];
  }
}

class MockBillingRepository extends BillingRepository {
  MockBillingRepository() : super(DioClient());

  @override
  Future<List<ServiceCatalogueItem>> getServicesCatalogue() async {
    return [
      const ServiceCatalogueItem(
        code: 'SRV-CONS-GEN',
        name: 'General OPD Consultation',
        category: 'CONSULTATION',
        basePrice: 300.0,
        taxRatePercent: 0.0,
      ),
      const ServiceCatalogueItem(
        code: 'SRV-PROC-DRESS',
        name: 'Minor Wound Dressing',
        category: 'PROCEDURE',
        basePrice: 150.0,
        taxRatePercent: 5.0,
      ),
    ];
  }

  @override
  Future<List<BillModel>> getBills({
    String? patientId,
    String? visitId,
    String? status,
    String? paymentStatus,
    int limit = 50,
    int offset = 0,
  }) async {
    return [
      const BillModel(
        id: 'bill-test-1',
        invoiceNumber: 'INV-2026-0001',
        patientId: 'pat-1',
        patientName: 'Satya Narayan',
        patientUhid: 'UHID-2026-0001',
        visitId: 'vis-1',
        visitNumber: 'VIS-2026-0001',
        departmentName: 'General Medicine',
        subtotal: 450.0,
        discountType: 'PERCENTAGE',
        discountRate: 10.0,
        discountAmount: 45.0,
        discountReason: 'Senior Citizen Concession (10%)',
        taxableAmount: 405.0,
        cgstAmount: 3.75,
        sgstAmount: 3.75,
        totalTaxAmount: 7.50,
        totalAmount: 412.50,
        paidAmount: 412.50,
        outstandingBalance: 0.0,
        paymentStatus: 'PAID',
        status: 'PAID',
        billedAt: '2026-10-12T10:45:00Z',
        items: [
          BillItemModel(
            id: 'item-1',
            itemType: 'CONSULTATION',
            itemCode: 'SRV-CONS-GEN',
            description: 'General OPD Consultation',
            quantity: 1,
            unitPrice: 300.0,
            taxRatePercent: 0.0,
            subtotal: 300.0,
            taxAmount: 0.0,
            totalAmount: 300.0,
          ),
          BillItemModel(
            id: 'item-2',
            itemType: 'PROCEDURE',
            itemCode: 'SRV-PROC-DRESS',
            description: 'Minor Wound Dressing',
            quantity: 1,
            unitPrice: 150.0,
            taxRatePercent: 5.0,
            subtotal: 150.0,
            taxAmount: 7.50,
            totalAmount: 157.50,
          ),
        ],
        payments: [
          PaymentTransactionModel(
            id: 'pay-1',
            receiptNumber: 'RCP-20261012-0001',
            paymentMethod: 'CASH',
            amount: 412.50,
            paymentStatus: 'COMPLETED',
          ),
        ],
      ),
    ];
  }

  @override
  Future<BillModel?> getBillById(String id) async {
    final bills = await getBills();
    return bills.first;
  }
}

void main() {
  testWidgets('Pharmacy Workspace View renders KPI cards and prescriptions list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pharmacyRepositoryProvider.overrideWithValue(MockPharmacyRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PharmacyWorkspaceView(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify KPI Cards
    expect(find.text('Total Stock Units'), findsOneWidget);
    expect(find.text('850'), findsOneWidget);
    expect(find.text('Low Stock Alerts'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Expiring Soon'), findsOneWidget);
    expect(find.text('Expired Batches'), findsOneWidget);
    expect(find.text("Today's Dispenses"), findsOneWidget);

    // Verify Prescriptions tab loaded
    expect(find.text('Satya Narayan'), findsOneWidget);
    expect(find.text('UHID-2026-0001'), findsOneWidget);
    expect(find.text('Paracetamol 500mg (500 mg) • Qty: 6'), findsOneWidget);
    expect(find.text('Dispense (1 items)'), findsOneWidget);
  });

  testWidgets('Dispense Prescription Dialog displays items, batch selector and actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));

    const testRx = PrescriptionForDispensing(
      id: 'rx-test-1',
      visitId: 'vis-1',
      patientId: 'pat-1',
      patientName: 'Satya Narayan',
      patientUhid: 'UHID-2026-0001',
      doctorName: 'Dr. Sarah Chen, MD',
      status: 'SIGNED',
      items: [
        PrescriptionReadyItem(
          id: 'item-1',
          medicineName: 'Paracetamol 500mg',
          form: 'Tablet',
          dosage: '500 mg',
          route: 'Oral',
          frequency: 'TID',
          quantity: 6,
          availableBatches: [
            InventoryBatchOption(
              inventoryId: 'med-1',
              batchNumber: 'BAT-PCM-01',
              expiryDate: '2027-05-30',
              availableQuantity: 120,
              unitPrice: 3.50,
            ),
          ],
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(800, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pharmacyRepositoryProvider.overrideWithValue(MockPharmacyRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: DispensePrescriptionDialog(prescription: testRx),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Dispense Signed Prescription'), findsOneWidget);
    expect(find.text('Complete Dispensing'), findsOneWidget);
    expect(find.text('Synthetic Medicines Tariff'), findsOneWidget);
    expect(find.text('₹21.00'), findsOneWidget); // 6 x 3.50
  });

  testWidgets('Stock Receipt Dialog renders form fields with synthetic pricing disclaimer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pharmacyRepositoryProvider.overrideWithValue(MockPharmacyRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: StockReceiptDialog(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Stock Receipt (GRN)'), findsOneWidget);
    expect(find.text('Medicine Name *'), findsOneWidget);
    expect(find.text('Batch Number *'), findsOneWidget);
    expect(find.text('Expiry Date *'), findsOneWidget);
    expect(find.text('Confirm Receipt'), findsOneWidget);
  });

  testWidgets('Billing Workspace View renders KPI cards and itemized bills list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billingRepositoryProvider.overrideWithValue(MockBillingRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BillingWorkspaceView(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify KPI Cards
    expect(find.text('Total Invoiced'), findsOneWidget);
    expect(find.text('Total Collected'), findsOneWidget);
    expect(find.text('Outstanding Balance'), findsOneWidget);
    expect(find.text('Invoices Count'), findsOneWidget);

    // Verify Invoice item
    expect(find.text('INV-2026-0001'), findsOneWidget);
    expect(find.text('Satya Narayan (UHID-2026-0001)'), findsOneWidget);
    expect(find.text('Total: ₹412.50'), findsOneWidget);
    expect(find.text('Print Receipt'), findsOneWidget);
  });

  testWidgets('Printable Invoice Screen renders itemized GST tax breakdown and verification seal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billingRepositoryProvider.overrideWithValue(MockBillingRepository()),
        ],
        child: const MaterialApp(
          home: PrintableInvoiceScreen(billId: 'bill-test-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sri Manakula Vinayagar Medical College & Hospital'), findsOneWidget);
    expect(find.text('INV-2026-0001'), findsOneWidget);
    expect(find.text('General OPD Consultation'), findsOneWidget);
    expect(find.text('Minor Wound Dressing'), findsOneWidget);
    expect(find.text('CGST Amount:'), findsOneWidget);
    expect(find.text('SGST Amount:'), findsOneWidget);
    expect(find.text('TOTAL NET AMOUNT:'), findsOneWidget);
    expect(find.text('₹412.50'), findsWidgets);
    expect(find.text('Digitally Verified OPD Connect+ System Record'), findsOneWidget);
  });

  testWidgets('Payment Dialog enforces server-side reconciliation for online payments', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 800));

    const testBill = BillModel(
      id: 'bill-unpaid-1',
      invoiceNumber: 'INV-2026-0002',
      patientId: 'pat-1',
      patientName: 'Satya Narayan',
      patientUhid: 'UHID-2026-0001',
      visitId: 'vis-1',
      subtotal: 500.0,
      taxableAmount: 500.0,
      cgstAmount: 0.0,
      sgstAmount: 0.0,
      totalTaxAmount: 0.0,
      totalAmount: 500.0,
      paidAmount: 0.0,
      outstandingBalance: 500.0,
      paymentStatus: 'UNPAID',
      status: 'ISSUED',
      billedAt: '2026-10-12T11:00:00Z',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billingRepositoryProvider.overrideWithValue(MockBillingRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PaymentDialog(bill: testBill),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Record Payment (INV-2026-0002)'), findsOneWidget);
    expect(find.text('Cash Counter'), findsOneWidget);
    expect(find.text('Debit / Card'), findsOneWidget);
    expect(find.text('Online / UPI'), findsOneWidget);

    // Switch to Online method
    await tester.tap(find.text('Online / UPI'));
    await tester.pumpAndSettle();

    // Verify secure reconciliation notice appears
    expect(find.text('Secure Server-side Reconciliation Policy'), findsOneWidget);
    expect(find.text('Initiate Online Order'), findsOneWidget);
  });
}
