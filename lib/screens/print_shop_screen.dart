import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_circle.dart';
import 'shell_screen.dart';

/// جذر نكهة المطبعة.
///
/// **وهو اليوم هيكلٌ يقول إنه هيكل.** طوابير الطباعة تحتاج دور مطبعة في
/// القاعدة (`is_shop_member` وسياسات تُري كلّ مطبعةٍ طلباتِها) ولم يُبنَ
/// بعد، ولم يصل أيّ طلب إلى أيّ مطبعة قطّ.
///
/// ولوحةٌ وهمية بأرقام مخترَعة كانت ستبدو أقرب إلى التمام وهي أبعد: من
/// يفتحها يظنّ النظام يعمل. فالصدق هنا أنفع من الزخرفة — والشاشة تقول
/// ما ينقص، وتترك بابًا مفتوحًا إلى واجهة التاجر لمن فتحها بالخطأ.
///
/// وموضعها في الشجرة هو المقصود من هذه المرحلة: الجذر يعرف الدور، فحين
/// يجهز الخادم لا يبقى إلا استبدال متن هذه الشاشة — لا إعادة بناء
/// التطبيق ولا نكهة تُخترع من الصفر.
class PrintShopScreen extends StatelessWidget {
  const PrintShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.shopPanelTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const IconCircle(
                  icon: Icons.print_outlined,
                  background: AppColors.coral,
                  diameter: 88,
                ),
                const SizedBox(height: 24),
                Text(
                  l.shopPanelHeading,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: context.scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l.shopPanelBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => const ShellScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.storefront_outlined),
                  label: Text(l.shopPanelOpenMerchant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
