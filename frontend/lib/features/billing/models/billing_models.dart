class ServiceCatalogueItem {
  final String code;
  final String name;
  final String category;
  final double basePrice;
  final double taxRatePercent;
  final bool isSynthetic;
  final bool isActive;
  final String description;

  const ServiceCatalogueItem({
    required this.code,
    required this.name,
    required this.category,
    required this.basePrice,
    this.taxRatePercent = 0.0,
    this.isSynthetic = true,
    this.isActive = true,
    this.description = '',
  });

  factory ServiceCatalogueItem.fromJson(Map<String, dynamic> json) {
    return ServiceCatalogueItem(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'GENERAL',
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0.0,
      taxRatePercent: (json['tax_rate_percent'] as num?)?.toDouble() ?? 0.0,
      isSynthetic: json['is_synthetic'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      description: json['description'] as String? ?? '',
    );
  }
}

class BillItemModel {
  final String id;
  final String itemType;
  final String itemCode;
  final String description;
  final int quantity;
  final double unitPrice;
  final double taxRatePercent;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;

  const BillItemModel({
    required this.id,
    required this.itemType,
    required this.itemCode,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.taxRatePercent,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
  });

  factory BillItemModel.fromJson(Map<String, dynamic> json) {
    return BillItemModel(
      id: json['id'] as String? ?? '',
      itemType: json['item_type'] as String? ?? 'SERVICE',
      itemCode: json['item_code'] as String? ?? '',
      description: json['description'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      taxRatePercent: (json['tax_rate_percent'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_type': itemType,
        'item_code': itemCode,
        'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
        'tax_rate_percent': taxRatePercent,
        'subtotal': subtotal,
        'tax_amount': taxAmount,
        'total_amount': totalAmount,
      };
}

class PaymentTransactionModel {
  final String id;
  final String receiptNumber;
  final String paymentMethod;
  final double amount;
  final String paymentStatus;
  final String gatewayOrderId;
  final String gatewayPaymentId;
  final String idempotencyKey;
  final bool isOnline;
  final String? verifiedAt;
  final double refundAmount;
  final String refundReason;
  final String createdAt;

  const PaymentTransactionModel({
    required this.id,
    required this.receiptNumber,
    required this.paymentMethod,
    required this.amount,
    required this.paymentStatus,
    this.gatewayOrderId = '',
    this.gatewayPaymentId = '',
    this.idempotencyKey = '',
    this.isOnline = false,
    this.verifiedAt,
    this.refundAmount = 0.0,
    this.refundReason = '',
    this.createdAt = '',
  });

  factory PaymentTransactionModel.fromJson(Map<String, dynamic> json) {
    return PaymentTransactionModel(
      id: json['id'] as String? ?? '',
      receiptNumber: json['receipt_number'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? 'CASH',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['payment_status'] as String? ?? 'COMPLETED',
      gatewayOrderId: json['gateway_order_id'] as String? ?? '',
      gatewayPaymentId: json['gateway_payment_id'] as String? ?? '',
      idempotencyKey: json['idempotency_key'] as String? ?? '',
      isOnline: json['is_online'] as bool? ?? false,
      verifiedAt: json['verified_at'] as String?,
      refundAmount: (json['refund_amount'] as num?)?.toDouble() ?? 0.0,
      refundReason: json['refund_reason'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'receipt_number': receiptNumber,
        'payment_method': paymentMethod,
        'amount': amount,
        'payment_status': paymentStatus,
        'gateway_order_id': gatewayOrderId,
        'gateway_payment_id': gatewayPaymentId,
        'idempotency_key': idempotencyKey,
        'is_online': isOnline,
        'verified_at': verifiedAt,
        'refund_amount': refundAmount,
        'refund_reason': refundReason,
        'created_at': createdAt,
      };
}

class BillModel {
  final String id;
  final String invoiceNumber;
  final String patientId;
  final String patientName;
  final String patientUhid;
  final String visitId;
  final String visitNumber;
  final String departmentName;
  final double subtotal;
  final String discountType;
  final double discountRate;
  final double discountAmount;
  final String discountReason;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalTaxAmount;
  final double totalAmount;
  final double paidAmount;
  final double outstandingBalance;
  final String paymentStatus; // UNPAID, PARTIAL, PAID, REFUNDED
  final String status; // ISSUED, PAID, PARTIALLY_PAID, CANCELLED, REFUNDED
  final bool isSyntheticPricing;
  final String billedAt;
  final String cancellationReason;
  final List<BillItemModel> items;
  final List<PaymentTransactionModel> payments;

  const BillModel({
    required this.id,
    required this.invoiceNumber,
    required this.patientId,
    required this.patientName,
    this.patientUhid = '',
    required this.visitId,
    this.visitNumber = '',
    this.departmentName = '',
    required this.subtotal,
    this.discountType = 'NONE',
    this.discountRate = 0.0,
    this.discountAmount = 0.0,
    this.discountReason = '',
    required this.taxableAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    this.igstAmount = 0.0,
    required this.totalTaxAmount,
    required this.totalAmount,
    this.paidAmount = 0.0,
    required this.outstandingBalance,
    required this.paymentStatus,
    required this.status,
    this.isSyntheticPricing = true,
    required this.billedAt,
    this.cancellationReason = '',
    this.items = const [],
    this.payments = const [],
  });

  factory BillModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List<dynamic>? ?? [];
    var rawPayments = json['payments'] as List<dynamic>? ?? [];
    return BillModel(
      id: json['id'] as String? ?? '',
      invoiceNumber: json['invoice_number'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? '',
      patientUhid: json['patient_uhid'] as String? ?? '',
      visitId: json['visit_id'] as String? ?? '',
      visitNumber: json['visit_number'] as String? ?? '',
      departmentName: json['department_name'] as String? ?? '',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountType: json['discount_type'] as String? ?? 'NONE',
      discountRate: (json['discount_rate'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      discountReason: json['discount_reason'] as String? ?? '',
      taxableAmount: (json['taxable_amount'] as num?)?.toDouble() ?? 0.0,
      cgstAmount: (json['cgst_amount'] as num?)?.toDouble() ?? 0.0,
      sgstAmount: (json['sgst_amount'] as num?)?.toDouble() ?? 0.0,
      igstAmount: (json['igst_amount'] as num?)?.toDouble() ?? 0.0,
      totalTaxAmount: (json['total_tax_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      outstandingBalance: (json['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['payment_status'] as String? ?? 'UNPAID',
      status: json['status'] as String? ?? 'ISSUED',
      isSyntheticPricing: json['is_synthetic_pricing'] as bool? ?? true,
      billedAt: json['billed_at'] as String? ?? '',
      cancellationReason: json['cancellation_reason'] as String? ?? '',
      items: rawItems.map((i) => BillItemModel.fromJson(i as Map<String, dynamic>)).toList(),
      payments: rawPayments.map((p) => PaymentTransactionModel.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoice_number': invoiceNumber,
        'patient_id': patientId,
        'patient_name': patientName,
        'patient_uhid': patientUhid,
        'visit_id': visitId,
        'visit_number': visitNumber,
        'department_name': departmentName,
        'subtotal': subtotal,
        'discount_type': discountType,
        'discount_rate': discountRate,
        'discount_amount': discountAmount,
        'discount_reason': discountReason,
        'taxable_amount': taxableAmount,
        'cgst_amount': cgstAmount,
        'sgst_amount': sgstAmount,
        'igst_amount': igstAmount,
        'total_tax_amount': totalTaxAmount,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'outstanding_balance': outstandingBalance,
        'payment_status': paymentStatus,
        'status': status,
        'is_synthetic_pricing': isSyntheticPricing,
        'billed_at': billedAt,
        'cancellation_reason': cancellationReason,
        'items': items.map((i) => i.toJson()).toList(),
        'payments': payments.map((p) => p.toJson()).toList(),
      };
}
