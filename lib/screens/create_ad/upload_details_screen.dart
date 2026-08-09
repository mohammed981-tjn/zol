import 'package:flutter/material.dart';
import '../../models/ad_brief.dart';
import '../../theme/app_theme.dart';
import '../../widgets/choice_chip_group.dart';
import '../../widgets/section_header.dart';
import 'magic_screen.dart';

class UploadDetailsScreen extends StatefulWidget {
  const UploadDetailsScreen({super.key});

  @override
  State<UploadDetailsScreen> createState() => _UploadDetailsScreenState();
}

class _UploadDetailsScreenState extends State<UploadDetailsScreen> {
  static const _tones = ['حماسي', 'كوميدي', 'رسمي', 'عاطفي'];
  static const _platforms = ['إنستغرام', 'تيك توك', 'فيسبوك', 'سناب شات'];
  static const _formats = ['منشور مربع', 'ستوري', 'ريلز'];

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedTone = _tones.first;
  String _selectedPlatform = _platforms.first;
  String _selectedFormat = _formats.first;
  bool _hasProductImage = false;

  bool get _canContinue =>
      _hasProductImage && _nameController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أدخل التفاصيل')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const SectionHeader(
              kicker: 'الخطوة 1 من 3',
              title: 'عرّفنا على منتجك',
            ),
            const SizedBox(height: 24),
            _buildImagePicker(),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration('اسم المنتج *', 'مثال: قهوة مختصة'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: _inputDecoration(
                'وصف مختصر (اختياري)',
                'ما الذي يميز منتجك؟',
              ),
            ),
            const SizedBox(height: 28),
            ChoiceChipGroup(
              title: 'نبرة الإعلان',
              options: _tones,
              selected: _selectedTone,
              onSelected: (v) => setState(() => _selectedTone = v),
            ),
            const SizedBox(height: 24),
            ChoiceChipGroup(
              title: 'المنصة المستهدفة',
              options: _platforms,
              selected: _selectedPlatform,
              onSelected: (v) => setState(() => _selectedPlatform = v),
            ),
            const SizedBox(height: 24),
            ChoiceChipGroup(
              title: 'صيغة الإعلان',
              options: _formats,
              selected: _selectedFormat,
              onSelected: (v) => setState(() => _selectedFormat = v),
            ),
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: _canContinue
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MagicScreen(
                            brief: AdBrief(
                              productName: _nameController.text,
                              description: _descriptionController.text,
                              tone: _selectedTone,
                              platform: _selectedPlatform,
                              format: _selectedFormat,
                              hasProductImage: _hasProductImage,
                            ),
                          ),
                        ),
                      );
                    }
                  : null,
              child: const Text('اعرض شاشة السحر'),
            ),
            if (!_canContinue) ...[
              const SizedBox(height: 10),
              Text(
                'أضف صورة المنتج واسمه للمتابعة',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: context.cardBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildImagePicker() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _hasProductImage = !_hasProductImage),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hasProductImage ? AppColors.coral : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _hasProductImage
                  ? Icons.check_circle
                  : Icons.add_photo_alternate_outlined,
              size: 40,
              color: _hasProductImage ? AppColors.coral : context.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              _hasProductImage
                  ? 'تم اختيار صورة المنتج'
                  : 'اضغط لرفع صورة المنتج',
              style: TextStyle(color: context.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
