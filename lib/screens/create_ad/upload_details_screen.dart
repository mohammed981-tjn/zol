import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/ad_brief.dart';
import '../../theme/app_theme.dart';
import '../../widgets/choice_chip_group.dart';
import '../../widgets/section_header.dart';
import 'magic_screen.dart';

class UploadDetailsScreen extends StatefulWidget {
  const UploadDetailsScreen({super.key});

  /// يُستخدم في الاختبارات لتجاوز منتقي الصور الأصلي للجهاز.
  static Future<Uint8List?> Function()? debugPickImageOverride;

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
  Uint8List? _imageBytes;
  bool _picking = false;

  bool get _canContinue =>
      _imageBytes != null && _nameController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _pickFromGallery() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
    return file?.readAsBytes();
  }

  Future<void> _pickImage() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final bytes =
          await (UploadDetailsScreen.debugPickImageOverride ??
              _pickFromGallery)();
      if (!mounted) return;
      if (bytes != null) {
        setState(() => _imageBytes = bytes);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر اختيار الصورة — حاول مجددًا')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
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
                              imageBytes: _imageBytes,
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
    final image = _imageBytes;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _pickImage,
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: image != null ? AppColors.coral : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: image != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(image, fit: BoxFit.cover),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: const Text(
                        'تم اختيار صورة المنتج — اضغط للتغيير',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_picking)
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.coral,
                      ),
                    )
                  else
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 40,
                      color: context.textMuted,
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'اضغط لرفع صورة المنتج',
                    style: TextStyle(color: context.textMuted),
                  ),
                ],
              ),
      ),
    );
  }
}
