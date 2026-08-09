import 'package:flutter/material.dart';

/// كتالوج المطبوعات بتسعير فوري حسب المقاس والكمية،
/// على نمط Printify / VistaPrint.
class PrintSize {
  const PrintSize({required this.label, required this.unitPrice});

  final String label;
  final double unitPrice;
}

class PrintProduct {
  const PrintProduct({
    required this.label,
    required this.icon,
    required this.unitName,
    required this.sizes,
    required this.quantities,
  });

  final String label;
  final IconData icon;

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
    sizes: [
      PrintSize(label: '1×2 متر', unitPrice: 90),
      PrintSize(label: '2×3 متر', unitPrice: 220),
      PrintSize(label: '3×4 متر', unitPrice: 380),
    ],
    quantities: [1, 2, 3, 5],
  ),
  PrintProduct(
    label: 'استيكرات',
    icon: Icons.sticky_note_2_outlined,
    unitName: 'حزمة (50 قطعة)',
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
