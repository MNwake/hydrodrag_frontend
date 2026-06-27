class PaymentPricing {
  final List<PaymentLineItem> lineItems;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final String? promoCode;
  final bool? promoValid;
  final double? spectatorSingleDayPrice;
  final double? spectatorWeekendPrice;
  final String currency;

  PaymentPricing({
    required this.lineItems,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    this.promoCode,
    this.promoValid,
    this.spectatorSingleDayPrice,
    this.spectatorWeekendPrice,
    this.currency = 'USD',
  });

  factory PaymentPricing.fromJson(Map<String, dynamic> json) {
    final items = json['line_items'] as List<dynamic>? ?? [];
    return PaymentPricing(
      lineItems: items
          .map((e) => PaymentLineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: _toDouble(json['subtotal']),
      discountAmount: _toDouble(json['discount_amount']),
      totalAmount: _toDouble(json['total_amount']),
      promoCode: json['promo_code'] as String?,
      promoValid: json['promo_valid'] as bool?,
      spectatorSingleDayPrice: json['spectator_single_day_price'] != null
          ? _toDouble(json['spectator_single_day_price'])
          : null,
      spectatorWeekendPrice: json['spectator_weekend_price'] != null
          ? _toDouble(json['spectator_weekend_price'])
          : null,
      currency: json['currency'] as String? ?? 'USD',
    );
  }
}

class PaymentLineItem {
  final String type;
  final String label;
  final double amount;
  final int? quantity;
  final double? unitPrice;

  PaymentLineItem({
    required this.type,
    required this.label,
    required this.amount,
    this.quantity,
    this.unitPrice,
  });

  factory PaymentLineItem.fromJson(Map<String, dynamic> json) {
    return PaymentLineItem(
      type: json['type'] as String? ?? '',
      label: json['label'] as String? ?? '',
      amount: _toDouble(json['amount']),
      quantity: json['quantity'] as int?,
      unitPrice: json['unit_price'] != null ? _toDouble(json['unit_price']) : null,
    );
  }
}

class PaymentStartResult {
  final String paymentId;
  final String paypalOrderId;
  final String approvalUrl;
  final String clientId;
  final String environment;
  final String status;
  final String? expiresAt;
  final PaymentPricing pricing;
  final bool freeCheckout;
  final bool completed;
  final Map<String, dynamic>? result;

  PaymentStartResult({
    required this.paymentId,
    required this.paypalOrderId,
    required this.approvalUrl,
    required this.clientId,
    required this.environment,
    required this.status,
    this.expiresAt,
    required this.pricing,
    this.freeCheckout = false,
    this.completed = false,
    this.result,
  });

  factory PaymentStartResult.fromJson(Map<String, dynamic> json) {
    return PaymentStartResult(
      paymentId: json['payment_id'] as String? ?? '',
      paypalOrderId: json['paypal_order_id'] as String? ?? '',
      approvalUrl: json['approval_url'] as String? ?? '',
      clientId: json['client_id'] as String? ?? '',
      environment: json['environment'] as String? ?? 'sandbox',
      status: json['status'] as String? ?? 'pending',
      expiresAt: json['expires_at'] as String?,
      pricing: PaymentPricing.fromJson(
        json['pricing'] as Map<String, dynamic>? ?? {},
      ),
      freeCheckout: json['free_checkout'] as bool? ?? false,
      completed: json['completed'] as bool? ?? false,
      result: json['result'] as Map<String, dynamic>?,
    );
  }
}

class PaymentStatusResult {
  final String paymentId;
  final String paypalOrderId;
  final String? paymentType;
  final String status;
  final String? expiresAt;
  final bool isExpired;
  final Map<String, dynamic>? result;

  PaymentStatusResult({
    required this.paymentId,
    required this.paypalOrderId,
    this.paymentType,
    required this.status,
    this.expiresAt,
    this.isExpired = false,
    this.result,
  });

  factory PaymentStatusResult.fromJson(Map<String, dynamic> json) {
    return PaymentStatusResult(
      paymentId: json['payment_id'] as String? ?? '',
      paypalOrderId: json['paypal_order_id'] as String? ?? '',
      paymentType: json['payment_type'] as String?,
      status: json['status'] as String? ?? '',
      expiresAt: json['expires_at'] as String?,
      isExpired: json['is_expired'] as bool? ?? false,
      result: json['result'] as Map<String, dynamic>?,
    );
  }

  bool get isCompleted => status == 'completed' || result != null;
}

class PaymentApproveResult {
  final String status;
  final Map<String, dynamic>? result;
  final String? error;

  PaymentApproveResult({
    required this.status,
    this.result,
    this.error,
  });

  factory PaymentApproveResult.fromJson(Map<String, dynamic> json) {
    return PaymentApproveResult(
      status: json['status'] as String? ?? '',
      result: json['result'] as Map<String, dynamic>?,
      error: json['error'] as String?,
    );
  }

  bool get isSuccess => status == 'completed';
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}
