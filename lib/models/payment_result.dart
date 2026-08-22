/// نتيجة محاولة دفع تُعاد من شاشة البوابة (أو المحاكاة) إلى شاشة الطلب.
class PaymentResult {
  const PaymentResult({
    required this.success,
    this.paymentId,
    this.errorMessage,
  });

  final bool success;
  final String? paymentId;
  final String? errorMessage;
}

enum PayMethod { cash, card }

extension PayMethodInfo on PayMethod {
  String get label => switch (this) {
    PayMethod.cash => 'الدفع عند الاستلام',
    PayMethod.card => 'بطاقة (mada / Visa / Mastercard)',
  };
}
