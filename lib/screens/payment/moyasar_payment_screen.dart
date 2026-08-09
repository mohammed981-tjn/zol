// شاشة الدفع بالبطاقة عبر بوابة «ميسر» — منقولة من zadgo2.
//
// لماذا ودجت البوابة الجاهزة (CreditCard) لا حقول من تصميمنا؟ لأن بيانات
// البطاقة لا تمرّ حينها بشيفرتنا إطلاقًا، فيبقى التطبيق خارج نطاق التزامات
// PCI-DSS الثقيلة.
//
// قاعدة أساسية: الطلب لا يُعدّ مدفوعًا إلا بعد أن تؤكّد البوابة نجاح
// الشحن فعليًا وبمعرّف عملية حقيقي منها.
import 'package:flutter/material.dart';
import 'package:moyasar/moyasar.dart';
import '../../models/payment_result.dart' as app;
import '../../utils/payment_config.dart';

class MoyasarPaymentScreen extends StatelessWidget {
  const MoyasarPaymentScreen({
    super.key,
    required this.amountSar,
    required this.orderDescription,
  });

  final double amountSar;
  final String orderDescription;

  @override
  Widget build(BuildContext context) {
    // حماية من الإطلاق بمفتاح غير مضبوط: رسالة صريحة بدل فشل غامض.
    if (!AppPaymentConfig.isConfigured) {
      return Scaffold(
        appBar: AppBar(title: const Text('الدفع بالبطاقة')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'الدفع بالبطاقة غير مفعّل بعد.\n'
              'مرّر مفتاح ميسر المنشور عند البناء:\n'
              'flutter build --dart-define=MOYASAR_PUBLISHABLE_KEY=pk_live_xxx',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final paymentConfig = PaymentConfig(
      publishableApiKey: AppPaymentConfig.moyasarPublishableKey,
      // البوابة تتعامل بالهللات لا الريالات.
      amount: (amountSar * 100).round(),
      description: orderDescription,
      metadata: const {'source': 'adcraft_app'},
      creditCard: CreditCardConfig(saveCard: false, manual: false),
    );

    void onPaymentResult(dynamic result) {
      if (result is PaymentResponse) {
        switch (result.status) {
          case PaymentStatus.paid:
            Navigator.pop(
              context,
              app.PaymentResult(success: true, paymentId: result.id),
            );
          case PaymentStatus.failed:
            Navigator.pop(
              context,
              const app.PaymentResult(
                success: false,
                errorMessage:
                    'فشلت عملية الدفع، تأكّد من بيانات البطاقة أو الرصيد',
              ),
            );
          default:
            Navigator.pop(
              context,
              const app.PaymentResult(
                success: false,
                errorMessage: 'لم تكتمل عملية الدفع',
              ),
            );
        }
      } else {
        Navigator.pop(
          context,
          const app.PaymentResult(
            success: false,
            errorMessage: 'تعذّر الاتصال ببوابة الدفع، حاول مرة أخرى',
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الدفع بالبطاقة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (AppPaymentConfig.isTestKey)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'وضع الاختبار (sandbox) — لن يُسحب أي مبلغ حقيقي',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'المبلغ المطلوب',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${amountSar.toStringAsFixed(2)} ر.س',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // نموذج البطاقة بالعربية من الحزمة نفسها — يبقينا خارج نطاق PCI.
            CreditCard(
              config: paymentConfig,
              onPaymentResult: onPaymentResult,
              locale: const Localization.ar(),
            ),
          ],
        ),
      ),
    );
  }
}
