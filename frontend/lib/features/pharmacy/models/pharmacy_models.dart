class MedicineInventoryItem {
  final String id;
  final String medicineCode;
  final String name;
  final String genericName;
  final String strength;
  final String dosageForm;
  final String batchNumber;
  final String expiryDate;
  final int availableQuantity;
  final int minimumStockLevel;
  final double unitPrice;
  final String taxClassification;
  final String supplierName;
  final bool isActive;
  final bool isLowStock;
  final bool isExpiringSoon;
  final bool isExpired;
  final bool isSyntheticPrice;

  const MedicineInventoryItem({
    required this.id,
    required this.medicineCode,
    required this.name,
    this.genericName = '',
    this.strength = '',
    this.dosageForm = 'Tablet',
    required this.batchNumber,
    required this.expiryDate,
    required this.availableQuantity,
    this.minimumStockLevel = 20,
    required this.unitPrice,
    this.taxClassification = 'GST_12',
    this.supplierName = '',
    this.isActive = true,
    this.isLowStock = false,
    this.isExpiringSoon = false,
    this.isExpired = false,
    this.isSyntheticPrice = true,
  });

  factory MedicineInventoryItem.fromJson(Map<String, dynamic> json) {
    return MedicineInventoryItem(
      id: json['id'] as String? ?? '',
      medicineCode: json['medicine_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      genericName: json['generic_name'] as String? ?? '',
      strength: json['strength'] as String? ?? '',
      dosageForm: json['dosage_form'] as String? ?? 'Tablet',
      batchNumber: json['batch_number'] as String? ?? '',
      expiryDate: json['expiry_date'] as String? ?? '',
      availableQuantity: (json['available_quantity'] as num?)?.toInt() ?? 0,
      minimumStockLevel: (json['minimum_stock_level'] as num?)?.toInt() ?? 20,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      taxClassification: json['tax_classification'] as String? ?? 'GST_12',
      supplierName: json['supplier_name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      isLowStock: json['is_low_stock'] as bool? ?? false,
      isExpiringSoon: json['is_expiring_soon'] as bool? ?? false,
      isExpired: json['is_expired'] as bool? ?? false,
      isSyntheticPrice: json['is_synthetic_price'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicine_code': medicineCode,
        'name': name,
        'generic_name': genericName,
        'strength': strength,
        'dosage_form': dosageForm,
        'batch_number': batchNumber,
        'expiry_date': expiryDate,
        'available_quantity': availableQuantity,
        'minimum_stock_level': minimumStockLevel,
        'unit_price': unitPrice,
        'tax_classification': taxClassification,
        'supplier_name': supplierName,
        'is_active': isActive,
      };
}

class InventoryStats {
  final int totalMedicines;
  final int totalStockUnits;
  final int lowStockCount;
  final int expiringSoonCount;
  final int expiredCount;
  final int totalDispensesToday;

  const InventoryStats({
    this.totalMedicines = 0,
    this.totalStockUnits = 0,
    this.lowStockCount = 0,
    this.expiringSoonCount = 0,
    this.expiredCount = 0,
    this.totalDispensesToday = 0,
  });

  factory InventoryStats.fromJson(Map<String, dynamic> json) {
    return InventoryStats(
      totalMedicines: (json['total_medicines'] as num?)?.toInt() ?? 0,
      totalStockUnits: (json['total_stock_units'] as num?)?.toInt() ?? 0,
      lowStockCount: (json['low_stock_count'] as num?)?.toInt() ?? 0,
      expiringSoonCount: (json['expiring_soon_count'] as num?)?.toInt() ?? 0,
      expiredCount: (json['expired_count'] as num?)?.toInt() ?? 0,
      totalDispensesToday: (json['total_dispenses_today'] as num?)?.toInt() ?? 0,
    );
  }
}

class StockMovementItem {
  final String id;
  final String inventoryId;
  final String medicineName;
  final String batchNumber;
  final String movementType;
  final int quantity;
  final int balanceAfter;
  final String referenceNumber;
  final String reason;
  final String notes;
  final String performedByName;
  final String createdAt;

  const StockMovementItem({
    required this.id,
    required this.inventoryId,
    this.medicineName = '',
    this.batchNumber = '',
    required this.movementType,
    required this.quantity,
    required this.balanceAfter,
    this.referenceNumber = '',
    this.reason = '',
    this.notes = '',
    this.performedByName = '',
    this.createdAt = '',
  });

  factory StockMovementItem.fromJson(Map<String, dynamic> json) {
    return StockMovementItem(
      id: json['id'] as String? ?? '',
      inventoryId: json['inventory_id'] as String? ?? '',
      medicineName: json['medicine_name'] as String? ?? '',
      batchNumber: json['batch_number'] as String? ?? '',
      movementType: json['movement_type'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
      referenceNumber: json['reference_number'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      performedByName: json['performed_by_name'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class InventoryBatchOption {
  final String inventoryId;
  final String batchNumber;
  final String expiryDate;
  final int availableQuantity;
  final double unitPrice;
  final bool isExpired;

  const InventoryBatchOption({
    required this.inventoryId,
    required this.batchNumber,
    required this.expiryDate,
    required this.availableQuantity,
    required this.unitPrice,
    this.isExpired = false,
  });

  factory InventoryBatchOption.fromJson(Map<String, dynamic> json) {
    return InventoryBatchOption(
      inventoryId: json['inventory_id'] as String? ?? '',
      batchNumber: json['batch_number'] as String? ?? '',
      expiryDate: json['expiry_date'] as String? ?? '',
      availableQuantity: (json['available_quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      isExpired: json['is_expired'] as bool? ?? false,
    );
  }
}

class PrescriptionReadyItem {
  final String id;
  final String medicineName;
  final String form;
  final String dosage;
  final String route;
  final String frequency;
  final int durationDays;
  final int quantity;
  final String timing;
  final String instructions;
  final bool isDispensed;
  final List<InventoryBatchOption> availableBatches;

  const PrescriptionReadyItem({
    required this.id,
    required this.medicineName,
    this.form = 'Tablet',
    this.dosage = '',
    this.route = 'Oral',
    this.frequency = '',
    this.durationDays = 5,
    this.quantity = 0,
    this.timing = 'After Food',
    this.instructions = '',
    this.isDispensed = false,
    this.availableBatches = const [],
  });

  factory PrescriptionReadyItem.fromJson(Map<String, dynamic> json) {
    var rawBatches = json['available_batches'] as List<dynamic>? ?? [];
    return PrescriptionReadyItem(
      id: json['id'] as String? ?? '',
      medicineName: json['medicine_name'] as String? ?? '',
      form: json['form'] as String? ?? 'Tablet',
      dosage: json['dosage'] as String? ?? '',
      route: json['route'] as String? ?? 'Oral',
      frequency: json['frequency'] as String? ?? '',
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 5,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      timing: json['timing'] as String? ?? 'After Food',
      instructions: json['instructions'] as String? ?? '',
      isDispensed: json['is_dispensed'] as bool? ?? false,
      availableBatches: rawBatches
          .map((b) => InventoryBatchOption.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PrescriptionForDispensing {
  final String id;
  final String visitId;
  final String patientId;
  final String patientName;
  final String patientUhid;
  final String doctorName;
  final String status;
  final String? signedAt;
  final String? notes;
  final List<PrescriptionReadyItem> items;

  const PrescriptionForDispensing({
    required this.id,
    required this.visitId,
    required this.patientId,
    required this.patientName,
    required this.patientUhid,
    required this.doctorName,
    required this.status,
    this.signedAt,
    this.notes,
    this.items = const [],
  });

  factory PrescriptionForDispensing.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List<dynamic>? ?? [];
    return PrescriptionForDispensing(
      id: json['id'] as String? ?? '',
      visitId: json['visit_id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? 'Unknown',
      patientUhid: json['patient_uhid'] as String? ?? '',
      doctorName: json['doctor_name'] as String? ?? 'Clinician',
      status: json['status'] as String? ?? 'SIGNED',
      signedAt: json['signed_at'] as String?,
      notes: json['notes'] as String?,
      items: rawItems
          .map((i) => PrescriptionReadyItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PharmacyDispenseItemRecord {
  final String id;
  final String medicineName;
  final String batchNumber;
  final int quantityDispensed;
  final double unitPrice;
  final double totalPrice;
  final String instructions;

  const PharmacyDispenseItemRecord({
    required this.id,
    required this.medicineName,
    required this.batchNumber,
    required this.quantityDispensed,
    required this.unitPrice,
    required this.totalPrice,
    this.instructions = '',
  });

  factory PharmacyDispenseItemRecord.fromJson(Map<String, dynamic> json) {
    return PharmacyDispenseItemRecord(
      id: json['id'] as String? ?? '',
      medicineName: json['medicine_name'] as String? ?? '',
      batchNumber: json['batch_number'] as String? ?? '',
      quantityDispensed: (json['quantity_dispensed'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      instructions: json['instructions'] as String? ?? '',
    );
  }
}

class PharmacyDispenseRecord {
  final String id;
  final String dispenseNumber;
  final String prescriptionId;
  final String patientId;
  final String patientName;
  final String patientUhid;
  final String visitId;
  final String dispensedByName;
  final String dispensedAt;
  final String status;
  final int totalItemsDispensed;
  final double totalAmount;
  final String notes;
  final List<PharmacyDispenseItemRecord> items;

  const PharmacyDispenseRecord({
    required this.id,
    required this.dispenseNumber,
    required this.prescriptionId,
    required this.patientId,
    required this.patientName,
    this.patientUhid = '',
    required this.visitId,
    required this.dispensedByName,
    required this.dispensedAt,
    required this.status,
    this.totalItemsDispensed = 0,
    this.totalAmount = 0.0,
    this.notes = '',
    this.items = const [],
  });

  factory PharmacyDispenseRecord.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List<dynamic>? ?? [];
    return PharmacyDispenseRecord(
      id: json['id'] as String? ?? '',
      dispenseNumber: json['dispense_number'] as String? ?? '',
      prescriptionId: json['prescription_id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? '',
      patientUhid: json['patient_uhid'] as String? ?? '',
      visitId: json['visit_id'] as String? ?? '',
      dispensedByName: json['dispensed_by_name'] as String? ?? '',
      dispensedAt: json['dispensed_at'] as String? ?? '',
      status: json['status'] as String? ?? 'COMPLETED',
      totalItemsDispensed: (json['total_items_dispensed'] as num?)?.toInt() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String? ?? '',
      items: rawItems
          .map((i) => PharmacyDispenseItemRecord.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}
