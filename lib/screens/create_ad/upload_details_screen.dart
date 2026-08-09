import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_config.dart';
import '../../models/ad_brief.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_header.dart';
import 'magic_screen.dart';

class UploadDetailsScreen extends StatefulWidget {
  const UploadDetailsScreen({super.key, this.imagePicker});

  /// يُمرَّر في الاختبارات لتفادي منتقي الصور الحقيقي.
  final ImagePicker? imagePicker;

  @override
  State<UploadDetailsScreen> createState() => _UploadDetailsScreenState();
}

class _UploadDetailsScreenState extends State<UploadDetailsScreen> {
  late final ImagePicker _picker = widget.imagePicker ?? ImagePicker();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedTone = AppConfig.tones.first;
  String _selectedPlatform = AppConfig.platforms.first;
  Uint8List? _productImage;
  bool _picking = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canContinue => _nameController.text.trim().length >= 2;

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _productImage = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح الصورة. جرّب صورة أخرى.')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _openSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('اختر من المعرض'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('التقط صورة'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _continue() {
    final brief = AdBrief(
      productName: _nameController.text.trim(),
      productDescription: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      tone: _selectedTone,
      platform: _selectedPlatform,
      productImage: _productImage,
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MagicScreen(brief: brief)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أدخل التفاصيل')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const SectionHeader(
              kicker: 'الخطوة الأولى',
              title: 'عرّفنا بمنتجك',
            ),
            const SizedBox(height: 22),
            _buildImagePicker(),
            const SizedBox(height: 22),
            _buildField(
              controller: _nameController,
              label: 'اسم المنتج',
              hint: 'مثال: قهوة مختصة، عطر عود، خدمة تنظيف',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            _buildField(
              controller: _descriptionController,
              label: 'وصف مختصر (اختياري)',
              hint: 'ما يميّز منتجك في سطر أو سطرين',
              maxLines: 3,
            ),
            const SizedBox(height: 26),
            _buildChoices(
              title: 'نبرة الإعلان',
              options: AppConfig.tones,
              selected: _selectedTone,
              onSelected: (v) => setState(() => _selectedTone = v),
            ),
            const SizedBox(height: 22),
            _buildChoices(
              title: 'المنصة المستهدفة',
              options: AppConfig.platforms,
              selected: _selectedPlatform,
              onSelected: (v) => setState(() => _selectedPlatform = v),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _canContinue ? _continue : null,
              child: const Text('اعرض شاشة السحر'),
            ),
            if (!_canContinue)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'اكتب اسم المنتج للمتابعة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    final image = _productImage;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _picking ? null : _openSourceSheet,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: image != null ? AppColors.coral : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _picking
            ? const Center(child: CircularProgressIndicator())
            : image != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(image, fit: BoxFit.cover),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 18),
                            tooltip: 'أزل الصورة',
                            onPressed: () => setState(() => _productImage = null),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 40,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'أضف صورة المنتج (اختياري)',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'تساعد في وصف المنتج، ويمكنك المتابعة بدونها',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          textInputAction: maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChoices({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((option) {
            final isSelected = option == selected;
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) => onSelected(option),
              selectedColor: AppColors.navy,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: AppColors.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide.none,
            );
          }).toList(),
        ),
      ],
    );
  }
}
