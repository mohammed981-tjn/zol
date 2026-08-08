import 'package:flutter/material.dart';
import '../../models/ad_brief.dart';
import '../../theme/app_theme.dart';
import '../../widgets/icon_circle.dart';

class ExecuteScreen extends StatefulWidget {
  const ExecuteScreen({super.key, required this.brief, required this.isDigital});

  final AdBrief brief;
  final bool isDigital;

  @override
  State<ExecuteScreen> createState() => _ExecuteScreenState();
}

class _ExecuteScreenState extends State<ExecuteScreen> {
  static const _printProducts = ['بنر', 'استيكرات', 'كروت'];

  String _selectedProduct = _printProducts.first;
  final _addressController = TextEditingController();
  bool _orderConfirmed = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isDigital ? 'حفظ ونشر' : 'اطبعه وصلّه')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: widget.isDigital ? _buildDigitalPath() : _buildPrintPath(),
        ),
      ),
    );
  }

  Widget _buildDigitalPath() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const IconCircle(icon: Icons.cloud_done_outlined, background: AppColors.navy, diameter: 90),
        const SizedBox(height: 24),
        const Text(
          'المواد الرقمية جاهزة',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textDark),
        ),
        const SizedBox(height: 8),
        Text(
          'بنبرة ${widget.brief.tone} — مهيأة لمنصة ${widget.brief.platform}',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showConfirmation(context, 'تم تحميل المواد الرقمية'),
            icon: const Icon(Icons.download_outlined),
            label: const Text('تحميل الآن'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showConfirmation(context, 'تم النشر على ${widget.brief.platform}'),
            icon: const Icon(Icons.ios_share),
            label: const Text('نشر مباشر'),
          ),
        ),
      ],
    );
  }

  Widget _buildPrintPath() {
    if (_orderConfirmed) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const IconCircle(icon: Icons.local_shipping_outlined, background: AppColors.coral, diameter: 90),
          const SizedBox(height: 24),
          const Text(
            'تم استلام طلب الطباعة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            '$_selectedProduct — سيتم التوصيل إلى العنوان المُدخل',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ],
      );
    }

    return ListView(
      children: [
        const Text(
          'اختر نوع المطبوع',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: _printProducts.map((product) {
            final isSelected = product == _selectedProduct;
            return ChoiceChip(
              label: Text(product),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedProduct = product),
              selectedColor: AppColors.navy,
              labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textDark),
              backgroundColor: AppColors.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide.none,
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          'عنوان التوصيل',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _addressController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'المدينة، الحي، أقرب معلم',
            filled: true,
            fillColor: AppColors.cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _addressController.text.trim().isEmpty
              ? null
              : () => setState(() => _orderConfirmed = true),
          child: const Text('تأكيد الطلب'),
        ),
      ],
    );
  }

  void _showConfirmation(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
