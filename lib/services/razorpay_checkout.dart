import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Outcome of one Razorpay Checkout session.
class CheckoutResult {
  final bool success;
  final bool cancelled; // user closed the sheet
  final String? orderId;
  final String? paymentId;
  final String? signature;
  final String? message;

  const CheckoutResult._({
    required this.success,
    this.cancelled = false,
    this.orderId,
    this.paymentId,
    this.signature,
    this.message,
  });

  factory CheckoutResult.ok(String? orderId, String? paymentId, String? signature) =>
      CheckoutResult._(
          success: true, orderId: orderId, paymentId: paymentId, signature: signature);

  factory CheckoutResult.failed(String message, {bool cancelled = false}) =>
      CheckoutResult._(success: false, cancelled: cancelled, message: message);
}

/// Opens Razorpay Checkout and completes a Future when the customer pays, fails or closes it.
class RazorpayCheckout {
  static Future<CheckoutResult> open(Map<String, dynamic> options) {
    final completer = Completer<CheckoutResult>();
    final razorpay = Razorpay();

    void finish(CheckoutResult result) {
      if (completer.isCompleted) return;
      razorpay.clear();
      completer.complete(result);
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      print("🔥 RAZORPAY SUCCESS CALLBACK");
      print("orderId = ${r.orderId}");
      print("paymentId = ${r.paymentId}");
      print("signature = ${r.signature}");

      finish(CheckoutResult.ok(
        r.orderId,
        r.paymentId,
        r.signature,
      ));
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      // code 0 = the user dismissed the checkout
      final cancelled = r.code == 0;
      finish(CheckoutResult.failed(
        cancelled ? 'Payment cancelled' : (r.message ?? 'Payment failed'),
        cancelled: cancelled,
      ));
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      // Wallet apps finish outside the app; treat as not completed so the user can retry.
      finish(CheckoutResult.failed('Payment not completed (${r.walletName ?? 'external wallet'})'));
    });

    try {
      razorpay.open(options);
    } catch (e) {
      finish(CheckoutResult.failed('Could not open payment screen: $e'));
    }

    return completer.future;
  }
}
