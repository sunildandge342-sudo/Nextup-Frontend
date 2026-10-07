/// Result of POST /api/user/payment/create-order
class PaymentOrder {
  final bool paymentRequired;
  final int? paymentId;
  final String? orderId;
  final int amountPaise; // what Razorpay Checkout needs
  final double amount;   // rupees, for display
  final String currency;
  final String? keyId;
  final String serviceName;

  PaymentOrder({
    required this.paymentRequired,
    this.paymentId,
    this.orderId,
    required this.amountPaise,
    required this.amount,
    required this.currency,
    this.keyId,
    required this.serviceName,
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    return PaymentOrder(
      paymentRequired: json['paymentRequired'] == true,
      paymentId: (json['paymentId'] as num?)?.toInt(),
      orderId: json['orderId'] as String?,
      amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      keyId: json['keyId'] as String?,
      serviceName: json['serviceName'] as String? ?? 'Service',
    );
  }
}

/// One row of payment history (customer) or payment records (provider).
class PaymentRecord {
  final int id;
  final String serviceName;
  final double amount;
  final String currency;
  final String status; // SUCCESS | FAILED | PENDING
  final String? razorpayPaymentId;
  final DateTime? createdAt;
  final DateTime? paidAt;

  PaymentRecord({
    required this.id,
    required this.serviceName,
    required this.amount,
    required this.currency,
    required this.status,
    this.razorpayPaymentId,
    this.createdAt,
    this.paidAt,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      serviceName: json['serviceName'] as String? ?? 'Service',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      status: json['status'] as String? ?? 'PENDING',
      razorpayPaymentId: json['razorpayPaymentId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      paidAt: DateTime.tryParse(json['paidAt']?.toString() ?? ''),
    );
  }
}
