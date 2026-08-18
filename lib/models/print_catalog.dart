import 'package:flutter/material.dart';

/// كتالوج المطبوعات بتسعير فوري حسب المقاس والكمية،
/// على نمط Printify / VistaPrint.
class PrintSize {
  const PrintSize({required this.label, required this.unitPrice});

  final String label;
  final double unitPrice;
}

/// شكل المجسّم المستخدم لعرض التصميم على المطبوع قبل الشراء.
enum PrintMockup { banner, stickers, card, rollup, flyer }

class PrintProduct {
  const PrintProduct({
    required this.label,
    required this.icon,
    required this.unitName,
    required this.sizes,
    required this.quantities,
    required this.mockup,
  });

  final String label;
  final IconData icon;
  final PrintMockup mockup;

  /// اسم وحدة البيع (قطعة، حزمة...) لعرضها بجانب الكمية.
  final String unitName;
  final List<PrintSize> sizes;
  final List<int> quantities;
}

const printCatalog = [
  PrintProduct(
    label: 'بنر',
    icon: Icons.flag_outlined,
    unitName: 'بنر',
    mockup: PrintMockup.banner,
    sizes: [
      PrintSize(label: '1×2 متر', unitPrice: 90),
      PrintSize(label: '2×3 متر', unitPrice: 220),
      PrintSize(label: '3×4 متر', unitPrice: 380),
    ],
    quantities: [1, 2, 3, 5],
  ),
  // الفلاير كان غائبًا عن الكتالوج بينما يذكره التطبيق في أكثر من
  // موضع («طباعة استاندات وفلايرز وملصقات»). وبعد أن صار محرّك التصميم
  // يرسم مقاس ‎A5‎ بنسبته الحقيقية، صار غيابه يعني أن التاجر يصمّم
  // فلايرًا ثم لا يجد كيف يطلبه.
  PrintProduct(
    label: 'فلايرات',
    icon: Icons.description_outlined,
    unitName: 'حزمة (100 ورقة)',
    mockup: PrintMockup.flyer,
    sizes: [
      PrintSize(label: 'A5 — ورق عادي', unitPrice: 120),
      PrintSize(label: 'A5 — ورق لامع', unitPrice: 180),
      PrintSize(label: 'A4 — ورق لامع', unitPrice: 260),
    ],
    quantities: [1, 2, 5, 10],
  ),
  PrintProduct(
    label: 'استيكرات',
    icon: Icons.sticky_note_2_outlined,
    unitName: 'حزمة (50 قطعة)',
    mockup: PrintMockup.stickers,
    sizes: [
      PrintSize(label: '5×5 سم', unitPrice: 45),
      PrintSize(label: '8×8 سم', unitPrice: 70),
      PrintSize(label: '10×10 سم', unitPrice: 95),
    ],
    quantities: [1, 2, 4, 10],
  ),
  PrintProduct(
    label: 'كروت أعمال',
    icon: Icons.badge_outlined,
    unitName: 'حزمة (100 كرت)',
    mockup: PrintMockup.card,
    sizes: [
      PrintSize(label: 'قياسي 9×5 سم', unitPrice: 60),
      PrintSize(label: 'فاخر مع تغليف لامع', unitPrice: 110),
    ],
    quantities: [1, 2, 5, 10],
  ),
  PrintProduct(
    label: 'رول أب',
    icon: Icons.view_agenda_outlined,
    unitName: 'ستاند',
    mockup: PrintMockup.rollup,
    sizes: [
      PrintSize(label: '85×200 سم', unitPrice: 260),
      PrintSize(label: '100×200 سم', unitPrice: 320),
    ],
    quantities: [1, 2, 3],
  ),
];

const deliveryFee = 25.0;
const vatRate = 0.15;
const currency = 'ر.س';

String formatPrice(double value) {
  final text = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return '$text $currency';
}
