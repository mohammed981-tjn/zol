import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_config.dart';
import '../../models/ad_badge.dart';
import '../../models/ad_brief.dart';
import '../../models/ad_template.dart';
import '../../models/seasonal_theme.dart';
import '../../services/background_remover.dart';
import '../../services/palette_extractor.dart';
import '../../models/ad_format.dart';
import '../../services/photo_enhancer.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/choice_chip_group.dart';
import '../../widgets/section_header.dart';
import 'magic_screen.dart';

class UploadDetailsScreen extends StatefulWidget {
  const UploadDetailsScreen({
    super.key,
    this.initialFormat,
    this.initialPlatform,
    this.initialTemplate,
  });

  /// قيم مُعبّأة مسبقًا حين يصل التاجر من معرض القوالب.
  final String? initialFormat;
  final String? initialPlatform;
  final AdTemplate? initialTemplate;

  /// يُستخدم في الاختبارات لتجاوز منتقي الصور الأصلي للجهاز.
  static Future<Uint8List?> Function()? debugPickImageOverride;

  @override
  State<UploadDetailsScreen> createState() => _UploadDetailsScreenState();
}

class _UploadDetailsScreenState extends State<UploadDetailsScreen> {
  // النبرات والمنصات تُقرأ من AppConfig لا تُكتب هنا: الخادم يرفض أي
  // قيمة خارج قوائمه المحصورة، ونسخة ثانية منها في الواجهة تعني انحرافاً
  // صامتاً ينتهي بخطأ تحقّق عند التاجر.
  static const _tones = AppConfig.tones;
  static const _platforms = AppConfig.platforms;

  /// كل الصيغ التي يستطيع محرّك التصميم رسمها فعلًا — رقميّة ومطبوعة.
  ///
  /// كانت ثلاثًا رقميّة فقط، والتطبيق يبيع طباعة: التاجر يطلب رول أب
  /// ولا يجد صيغته فيصمّم مربّعًا ثم يُقصّ عند المطبعة. القائمة تُشتقّ
  /// من `AdFormat` فلا تفترق عمّا يرسمه المحرّك.
  static final _formats = AdFormat.values.map((f) => f.label).toList();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedTone = _tones.first;
  late String _selectedPlatform = _platforms.contains(widget.initialPlatform)
      ? widget.initialPlatform!
      : _platforms.first;
  late String _selectedFormat = _formats.contains(widget.initialFormat)
      ? widget.initialFormat!
      : _formats.first;
  Uint8List? _imageBytes;
  Uint8List? _cutoutBytes;
  int? _paletteColor;
  bool _useCutout = false;
  bool _isolating = false;
  bool _picking = false;
  SeasonalTheme? _season;
  AdBadge? _badge;
  bool _useDecorativeBackground = false;

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
        // استوديو منزلي على الجهاز: إضاءة وتباين وتشبع تلقائي قبل كل
        // شيء — فيستفيد قاطع الخلفية والقوالب والخادم من الصورة الأنظف.
        final enhanced = await PhotoEnhancer.enhance(bytes);
        if (!mounted) return;
        setState(() {
          _imageBytes = enhanced;
          _cutoutBytes = null;
          _paletteColor = null;
          _useCutout = false;
        });
        _isolateBackground(enhanced);
        _extractPalette(enhanced);
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

  /// عزل خلفية الصورة على الجهاز (الطبقة 1 من استراتيجية الذكاء).
  Future<void> _isolateBackground(Uint8List bytes) async {
    setState(() => _isolating = true);
    var cutout = await BackgroundRemover.removeBackground(bytes);
    if (cutout != null) {
      // القص الآلي يترك هالة بيضاء وحوافّ مسنّنة تفضح اللصق — تنعيمها
      // على الجهاز يرفع كل قالب يعرض القصاصة.
      cutout = await PhotoEnhancer.polishCutout(cutout);
    }
    if (!mounted || !identical(bytes, _imageBytes)) return;
    setState(() {
      _isolating = false;
      _cutoutBytes = cutout;
      // عند نجاح العزل نعتمده افتراضيًا — التصميم يبدو أنظف.
      _useCutout = cutout != null;
    });
  }

  /// استخراج اللون المسيطر ليبني عليه محرك القوالب لوحته.
  Future<void> _extractPalette(Uint8List bytes) async {
    final color = await PaletteExtractor.dominantColor(bytes);
    if (!mounted || !identical(bytes, _imageBytes)) return;
    setState(() => _paletteColor = color);
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
            if (_imageBytes != null) ...[
              const SizedBox(height: 12),
              _buildCutoutToggle(),
            ],
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
            const SizedBox(height: 8),
            _FormatHint(format: adFormatFromLabel(_selectedFormat)),
            const SizedBox(height: 24),
            _buildSeasonPicker(),
            const SizedBox(height: 24),
            _buildBadgePicker(),
            const SizedBox(height: 24),
            _buildDecorativeBackgroundToggle(),
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: _canContinue
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MagicScreen(
                            initialTemplate: widget.initialTemplate,
                            brief: AdBrief(
                              productName: _nameController.text,
                              description: _descriptionController.text,
                              tone: _selectedTone,
                              platform: _selectedPlatform,
                              format: _selectedFormat,
                              category: AppStateScope.of(
                                context,
                              ).businessCategory,
                              imageBytes: _useCutout && _cutoutBytes != null
                                  ? _cutoutBytes
                                  : _imageBytes,
                              paletteColor: _paletteColor,
                              season: _season,
                              badge: _badge,
                              useDecorativeBackground: _useDecorativeBackground,
                              // هوية العلامة تركب الموجز هنا لأن هذه آخر
                              // نقطة تملك AppState قبل أن يسافر الطلب.
                              brandName: AppStateScope.of(
                                context,
                              ).account?.storeName,
                              brandColor: AppStateScope.of(
                                context,
                              ).brandColorValue,
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

  /// موسم محلي اختياري (اليوم الوطني، رمضان، ...) — يضيف شارة وهاشتاقًا
  /// وجملة حملة احتفالية للتصميم دون تغيير مفردات النشاط. كله محلي بلا
  /// خادم، ومناسب لمواسم ذروة الطلب التي لا تغطيها قوالب Canva العربية
  /// (مجرد ترجمة لتصاميم غربية).
  /// مكتبة الشارات الترويجية — عنصر جاهز يرتفع به أي قالب بضغطة.
  Widget _buildBadgePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'شارة ترويجية (اختياري)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.scheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _badgeChip(null, 'بلا'),
            for (final badge in AdBadge.values) _badgeChip(badge, badge.label),
          ],
        ),
      ],
    );
  }

  Widget _badgeChip(AdBadge? badge, String label) {
    final isSelected = _badge == badge;
    return ChoiceChip(
      key: ValueKey('badge-${badge?.name ?? 'none'}'),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _badge = badge),
      selectedColor: context.scheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : context.scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSeasonPicker() {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'موسم محلي (اختياري)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.scheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _seasonChip(null, 'بلا'),
            for (final season in SeasonalTheme.values)
              _seasonChip(
                season,
                '${season.emoji} ${season.label}',
                isUpcoming: isSeasonApproaching(season, now),
              ),
          ],
        ),
      ],
    );
  }

  Widget _seasonChip(
    SeasonalTheme? season,
    String label, {
    bool isUpcoming = false,
  }) {
    final isSelected = _season == season;
    return ChoiceChip(
      key: ValueKey('season-${season?.name ?? 'none'}'),
      label: Text(isUpcoming ? '$label · قريبًا' : label),
      selected: isSelected,
      onSelected: (_) => setState(() => _season = season),
      selectedColor: season?.color ?? context.scheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : context.scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: context.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: isUpcoming && !isSelected
          ? BorderSide(color: season!.color, width: 1.2)
          : BorderSide.none,
    );
  }

  /// خلفية مصمَّمة اختيارية: زخرفة زاوية مستوحاة من نشاط التاجر (رسوم
  /// متجهة حقيقية مضمَّنة، لا تدرّج لوني محسوب فقط) — بديل بصري نمط
  /// قوالب Canva الجاهزة، لا يغيّر لوحة الألوان (العلامة/الموسم/المنتج).
  Widget _buildDecorativeBackgroundToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          key: const ValueKey('decorative-background-toggle'),
          contentPadding: EdgeInsets.zero,
          value: _useDecorativeBackground,
          onChanged: (v) => setState(() => _useDecorativeBackground = v),
          activeThumbColor: AppColors.coral,
          title: Text(
            'خلفية مصمَّمة بدل التدرّج',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.scheme.onSurface,
            ),
          ),
          subtitle: Text(
            'زخرفة زاوية مستوحاة من نشاطك تُضاف فوق ألوان تصميمك',
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildCutoutToggle() {
    if (_isolating) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.coral,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'جارٍ عزل خلفية الصورة على جهازك…',
            style: TextStyle(color: context.textMuted, fontSize: 12.5),
          ),
        ],
      );
    }
    if (_cutoutBytes == null) {
      return Text(
        'تعذّر عزل الخلفية تلقائيًا (خلفية غير موحدة) — ستُستخدم الصورة الأصلية',
        style: TextStyle(color: context.textMuted, fontSize: 12),
      );
    }
    return Wrap(
      spacing: 10,
      children: [
        ChoiceChip(
          label: const Text('معزولة الخلفية ✨'),
          selected: _useCutout,
          onSelected: (_) => setState(() => _useCutout = true),
          selectedColor: context.scheme.primary,
          labelStyle: TextStyle(
            color: _useCutout
                ? context.scheme.onPrimary
                : context.scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: context.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side: BorderSide.none,
        ),
        ChoiceChip(
          label: const Text('الصورة الأصلية'),
          selected: !_useCutout,
          onSelected: (_) => setState(() => _useCutout = false),
          selectedColor: context.scheme.primary,
          labelStyle: TextStyle(
            color: !_useCutout
                ? context.scheme.onPrimary
                : context.scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: context.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side: BorderSide.none,
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    final image = _useCutout && _cutoutBytes != null
        ? _cutoutBytes
        : _imageBytes;
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
                  // الصورة المعزولة تُعرض كاملة على أبيض لإظهار الشفافية.
                  if (_useCutout && _cutoutBytes != null)
                    Container(
                      color: Colors.white,
                      child: Image.memory(image, fit: BoxFit.contain),
                    )
                  else
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

/// سطر يشرح الصيغة المختارة: مقاسها الحقيقي ومتى تُستعمل.
///
/// أكثر التجّار لا يعرف الفرق بين «بنر» و«رول أب» قبل أن يقف أمام
/// المطبعة، واختيارٌ خاطئ هنا يعني ألف نسخة بمقاس لا يصلح.
class _FormatHint extends StatelessWidget {
  const _FormatHint({required this.format});
  final AdFormat format;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          format.isPrint ? Icons.print_outlined : Icons.smartphone_outlined,
          size: 15,
          color: context.textMuted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${format.sizeHint} · ${format.useWhen}',
            style: TextStyle(fontSize: 12, color: context.textMuted),
          ),
        ),
      ],
    );
  }
}
