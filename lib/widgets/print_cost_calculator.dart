import 'package:flutter/material.dart';
import '../models/print_catalog.dart';
import '../theme/app_theme.dart';

/// حاسبة تكلفة الطباعة أثناء التصميم — تحوّل «المصمّم» إلى «مشترٍ» بعرض
/// السعر التقديري قبل أن يغادر التاجر شاشة التصميم، بدل أن يكتشف السعر
/// بعد عدة خطوات في مسار الطباعة. كل الحساب محلي وفوري بلا خادم.
class PrintCostCalculator extends StatefulWidget {
  const PrintCostCalculator({super.key, required this.onProceed});

  /// يُستدعى عند تأكيد التاجر المتابعة لطلب الطباعة بالاختيار الحالي.
  final void Function(PrintProduct product, int sizeIndex, int quantity)
  onProceed;

  @override
  State<PrintCostCalculator> createState() => _PrintCostCalculatorState();
}

class _PrintCostCalculatorState extends State<PrintCostCalculator> {
  bool _expanded = false;
  PrintProduct _product = printCatalog.first;
  int _sizeIndex = 0;
  int _quantity = printCatalog.first.quantities.first;

  double get _subtotal => _product.sizes[_sizeIndex].unitPrice * _quantity;
  double get _vat => (_subtotal + deliveryFee) * vatRate;
  double get _total => _subtotal + deliveryFee + _vat;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('print-cost-calculator'),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const ValueKey('print-cost-toggle'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.calculate_outlined, color: AppColors.coral),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'كم يكلفك طباعة هذا التصميم؟',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: context.scheme.onSurface,
                          ),
                        ),
                        Text(
                          '${_product.label} (${_product.sizes[_sizeIndex].label}) '
                          '× $_quantity — تقريبًا ${formatPrice(_total)}',
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: context.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _chipRow(
                    printCatalog.map((p) => p.label).toList(),
                    _product.label,
                    (label) => setState(() {
                      _product = printCatalog.firstWhere(
                        (p) => p.label == label,
                      );
                      _sizeIndex = 0;
                      _quantity = _product.quantities.first;
                    }),
                    icons: printCatalog.map((p) => p.icon).toList(),
                  ),
                  const SizedBox(height: 10),
                  _chipRow(
                    _product.sizes.map((s) => s.label).toList(),
                    _product.sizes[_sizeIndex].label,
                    (label) => setState(
                      () => _sizeIndex = _product.sizes.indexWhere(
                        (s) => s.label == label,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _chipRow(
                    _product.quantities.map((q) => '$q').toList(),
                    '$_quantity',
                    (label) => setState(() => _quantity = int.parse(label)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الإجمالي مع التوصيل والضريبة',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        formatPrice(_total),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: context.scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const ValueKey('print-cost-proceed'),
                      onPressed: () =>
                          widget.onProceed(_product, _sizeIndex, _quantity),
                      child: const Text('تابع لطلب الطباعة'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chipRow(
    List<String> options,
    String selected,
    ValueChanged<String> onSelected, {
    List<IconData>? icons,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(options.length, (i) {
        final option = options[i];
        final isSelected = option == selected;
        return ChoiceChip(
          avatar: icons == null
              ? null
              : Icon(
                  icons[i],
                  size: 16,
                  color: isSelected
                      ? context.scheme.onPrimary
                      : context.scheme.onSurface,
                ),
          label: Text(option, style: const TextStyle(fontSize: 12.5)),
          selected: isSelected,
          onSelected: (_) => onSelected(option),
          selectedColor: context.scheme.primary,
          labelStyle: TextStyle(
            color: isSelected
                ? context.scheme.onPrimary
                : context.scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: context.scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
        );
      }),
    );
  }
}
