import 'package:flutter/material.dart';
import '../../models/ad_brief.dart';
import '../../theme/app_theme.dart';
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

  String _selectedTone = _tones.first;
  String _selectedPlatform = _platforms.first;
  bool _hasProductImage = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أدخل التفاصيل')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const SectionHeader(
              kicker: 'تجربة المستخدم',
              title: 'صورة المنتج، النبرة، والمنصة',
            ),
            const SizedBox(height: 24),
            _buildImagePicker(),
            const SizedBox(height: 28),
            _buildChipSection(
              title: 'نبرة الإعلان',
              options: _tones,
              selected: _selectedTone,
              onSelected: (v) => setState(() => _selectedTone = v),
            ),
            const SizedBox(height: 24),
            _buildChipSection(
              title: 'المنصة المستهدفة',
              options: _platforms,
              selected: _selectedPlatform,
              onSelected: (v) => setState(() => _selectedPlatform = v),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _hasProductImage
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MagicScreen(
                              brief: AdBrief(
                                tone: _selectedTone,
                                platform: _selectedPlatform,
                                hasProductImage: _hasProductImage,
                              ),
                            ),
                          ),
                        );
                      }
                    : null,
                child: const Text('اعرض شاشة السحر'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _hasProductImage = !_hasProductImage),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
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
              _hasProductImage ? Icons.check_circle : Icons.add_photo_alternate_outlined,
              size: 40,
              color: _hasProductImage ? AppColors.coral : AppColors.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              _hasProductImage ? 'تم اختيار صورة المنتج' : 'اضغط لرفع صورة المنتج',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipSection({
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
