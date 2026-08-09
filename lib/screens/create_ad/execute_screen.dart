import 'package:flutter/material.dart';
import '../../models/generated_ad.dart';
import '../../models/print_catalog.dart';
import '../../models/print_order.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/icon_circle.dart';

class ExecuteScreen extends StatefulWidget {
  const ExecuteScreen({super.key, required this.ad, required this.isDigital});

  final GeneratedAd ad;
  final bool isDigital;

  @override
  State<ExecuteScreen> createState() => _ExecuteScreenState();
}

class _ExecuteScreenState extends State<ExecuteScreen> {
  PrintProduct _product = printCatalog.first;
  int _sizeIndex = 0;
  int _quantity = 1;
  final _addressController = TextEditingController();
  PrintOrder? _confirmedOrder;

  @override
  void initState() {
    super.initState();
    _quantity = _product.quantities.first;
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  double get _subtotal => _product.sizes[_sizeIndex].unitPrice * _quantity;
  double get _vat => (_subtotal + deliveryFee) * vatRate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isDigital ? 'حفظ ونشر' : 'اطبعه وصلّه')),
      body: SafeArea(
        child: widget.isDigital ? _buildDigitalPath() : _buildPrintPath(),
      ),
    );
  }

  Widget _buildDigitalPath() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const IconCircle(
            icon: Icons.cloud_done_outlined,
            background: AppColors.navy,
            diameter: 90,
          ),
          const SizedBox(height: 24),
          Text(
            'المواد الرقمية جاهزة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: context.scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.ad.kind.label} بنبرة ${widget.ad.brief.tone} — '
            'مهيأة لمنصة ${widget.ad.brief.platform}',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textMuted),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              AppStateScope.of(context).saveAd(widget.ad);
              _showConfirmation('تم الحفظ في «إعلاناتي» وتحميل المواد');
            },
            icon: const Icon(Icons.download_outlined),
            label: const Text('حفظ وتحميل الآن'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showConfirmation(
              'تم النشر على ${widget.ad.brief.platform}',
            ),
            icon: const Icon(Icons.ios_share),
            label: const Text('نشر مباشر'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrintPath() {
    final order = _confirmedOrder;
    if (order != null) {
      return _buildOrderConfirmed(order);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionTitle('اختر نوع المطبوع'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: printCatalog.map((product) {
            final isSelected = product == _product;
            return ChoiceChip(
              avatar: Icon(
                product.icon,
                size: 18,
                color: isSelected
                    ? context.scheme.onPrimary
                    : context.scheme.onSurface,
              ),
              label: Text(product.label),
              selected: isSelected,
              onSelected: (_) => setState(() {
                _product = product;
                _sizeIndex = 0;
                _quantity = product.quantities.first;
              }),
              selectedColor: context.scheme.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? context.scheme.onPrimary
                    : context.scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: context.cardBg,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide.none,
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _sectionTitle('المقاس'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(_product.sizes.length, (i) {
            final size = _product.sizes[i];
            final isSelected = i == _sizeIndex;
            return ChoiceChip(
              label: Text('${size.label} — ${formatPrice(size.unitPrice)}'),
              selected: isSelected,
              onSelected: (_) => setState(() => _sizeIndex = i),
              selectedColor: context.scheme.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? context.scheme.onPrimary
                    : context.scheme.onSurface,
              ),
              backgroundColor: context.cardBg,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide.none,
            );
          }),
        ),
        const SizedBox(height: 24),
        _sectionTitle('الكمية (${_product.unitName})'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: _product.quantities.map((q) {
            final isSelected = q == _quantity;
            return ChoiceChip(
              label: Text('$q'),
              selected: isSelected,
              onSelected: (_) => setState(() => _quantity = q),
              selectedColor: context.scheme.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? context.scheme.onPrimary
                    : context.scheme.onSurface,
              ),
              backgroundColor: context.cardBg,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide.none,
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _sectionTitle('عنوان التوصيل'),
        const SizedBox(height: 10),
        TextField(
          controller: _addressController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'المدينة، الحي، أقرب معلم',
            filled: true,
            fillColor: context.cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildPriceSummary(),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed:
              _addressController.text.trim().isEmpty ? null : _confirmOrder,
          child: Text('تأكيد الطلب — ${formatPrice(_subtotal + deliveryFee + _vat)}'),
        ),
      ],
    );
  }

  Widget _buildPriceSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _priceRow('المطبوعات ($_quantity × ${formatPrice(_product.sizes[_sizeIndex].unitPrice)})', _subtotal),
          const SizedBox(height: 8),
          _priceRow('التوصيل', deliveryFee),
          const SizedBox(height: 8),
          _priceRow('الضريبة (15%)', _vat),
          const Divider(height: 24),
          _priceRow('الإجمالي', _subtotal + deliveryFee + _vat, isTotal: true),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double value, {bool isTotal = false}) {
    final style = TextStyle(
      color: isTotal ? context.scheme.onSurface : context.textMuted,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      fontSize: isTotal ? 16 : 13.5,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(formatPrice(value), style: style)],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: context.scheme.onSurface,
      ),
    );
  }

  void _confirmOrder() {
    final state = AppStateScope.of(context);
    final order = PrintOrder(
      id: state.nextOrderId(),
      productLabel: _product.label,
      sizeLabel: _product.sizes[_sizeIndex].label,
      quantity: _quantity,
      subtotal: _subtotal,
      deliveryFee: deliveryFee,
      vat: _vat,
      address: _addressController.text.trim(),
      status: OrderStatus.received,
      createdAt: DateTime.now(),
    );
    state.addOrder(order);
    setState(() => _confirmedOrder = order);
  }

  Widget _buildOrderConfirmed(PrintOrder order) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const IconCircle(
            icon: Icons.local_shipping_outlined,
            background: AppColors.coral,
            diameter: 90,
          ),
          const SizedBox(height: 24),
          Text(
            'تم استلام طلب الطباعة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: context.scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'رقم الطلب ${order.id}\n'
            '${order.productLabel} (${order.sizeLabel}) × ${order.quantity} — '
            '${formatPrice(order.total)}\n'
            'تابع حالته من تبويب «طلباتي»',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textMuted),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('العودة للرئيسية'),
          ),
        ],
      ),
    );
  }

  void _showConfirmation(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
