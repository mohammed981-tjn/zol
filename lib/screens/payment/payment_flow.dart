import 'package:flutter/material.dart';
import '../../models/payment_result.dart';
import '../../theme/app_theme.dart';
import '../../utils/payment_config.dart';
import 'moyasar_payment_screen.dart';

/// نقطة الدخول الموحدة للدفع بالبطاقة:
/// - مفتاح ميسر مضبوط → شاشة البوابة الحقيقية (نمط zadgo2).
/// - غير مضبوط (بيئة تطوير/عرض) → ورقة محاكاة موسومة «تجريبي» بوضوح،
///   حتى تبقى رحلة الدفع قابلة للتجربة قبل ربط المفتاح.
Future<PaymentResult?> startCardPayment(
  BuildContext context, {
  required double amountSar,
  required String description,
}) {
  if (AppPaymentConfig.isConfigured) {
    return Navigator.of(context).push<PaymentResult>(
      MaterialPageRoute(
        builder: (_) => MoyasarPaymentScreen(
          amountSar: amountSar,
          orderDescription: description,
        ),
      ),
    );
  }
  return showModalBottomSheet<PaymentResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) =>
        _MockPaymentSheet(amountSar: amountSar, description: description),
  );
}

class _MockPaymentSheet extends StatelessWidget {
  const _MockPaymentSheet({required this.amountSar, required this.description});

  final double amountSar;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'محاكاة بوابة الدفع (تجريبي) — لا يُسحب أي مبلغ.\n'
              'تُستبدل ببوابة «ميسر» الحقيقية عند ضبط المفتاح.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(description, style: TextStyle(color: context.textMuted)),
              Text(
                '${amountSar.toStringAsFixed(2)} ر.س',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(
              context,
              PaymentResult(
                success: true,
                paymentId: 'SIM-${DateTime.now().millisecondsSinceEpoch}',
              ),
            ),
            icon: const Icon(Icons.credit_score_outlined),
            label: const Text('محاكاة نجاح الدفع'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.pop(
              context,
              const PaymentResult(
                success: false,
                errorMessage: 'ألغيت عملية الدفع',
              ),
            ),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }
}
