import 'package:flutter/material.dart';
import '../models/ad_brief.dart';
import '../models/ad_template.dart';
import '../models/generated_ad.dart';
import '../models/template_category.dart';
import '../services/ad_generator.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_design_preview.dart';
import '../widgets/section_header.dart';
import 'create_ad/upload_details_screen.dart';

/// معرض القوالب — مدخل التطبيق الجديد على نمط Canva: التاجر يتصفّح
/// ويُلهَم أولًا ثم يرفع صورة منتجه، بدل أن تكون القوالب مخبّأة في آخر
/// الرحلة. البطاقات تُعرض بمنتج توضيحي وتنتقل بنقرة إلى إنشاء الإعلان
/// بالقالب والصيغة المختارَين مسبقًا.
class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TemplateCategory> get _visibleCategories => TemplateCategory.values
      .where((c) => c.matchesQuery(_query))
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final categories = _visibleCategories;

    return Scaffold(
      appBar: AppBar(title: const Text('القوالب')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'ابحث في القوالب — ستوري، بنر، كرت…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: context.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: categories.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد قوالب مطابقة لبحثك',
                        style: TextStyle(color: context.textMuted),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                      children: [
                        if (_query.isEmpty)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
                            child: SectionHeader(
                              kicker: 'ابدأ من قالب',
                              title: 'اختر الشكل الذي تريده',
                            ),
                          ),
                        for (final category in categories)
                          _CategoryRow(category: category),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category});

  final TemplateCategory category;

  /// إعلان توضيحي بلا صورة منتج — يُظهر شكل القالب قبل أن يرفع التاجر شيئًا.
  GeneratedAd _sampleAd() {
    final brief = AdBrief(
      productName: 'اسم منتجك',
      description: '',
      tone: 'حماسي',
      platform: category.suggestedPlatform,
      format: category.adFormat,
    );
    return AdGenerator.preview(brief).firstWhere(
      (ad) => ad.kind == AdKind.image,
      orElse: () => AdGenerator.preview(brief).first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sample = _sampleAd();
    final templates = category.templates;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(category.icon, size: 18, color: AppColors.coral),
                const SizedBox(width: 8),
                Text(
                  category.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: context.scheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (category.isPrint)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'قابل للطباعة',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8A6D00),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: templates.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _TemplateCard(
                key: ValueKey('gallery-${category.name}-${templates[i].name}'),
                category: category,
                template: templates[i],
                sample: sample,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    super.key,
    required this.category,
    required this.template,
    required this.sample,
  });

  final TemplateCategory category;
  final AdTemplate template;
  final GeneratedAd sample;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // ينتقل إلى إنشاء الإعلان بالقالب والصيغة والمنصة مُعبّأة مسبقًا.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UploadDetailsScreen(
              initialFormat: category.adFormat,
              initialPlatform: category.suggestedPlatform,
              initialTemplate: template,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AdDesignPreview(
                ad: sample,
                template: template,
                showWatermark: false,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            template.label,
            style: TextStyle(fontSize: 12, color: context.textMuted),
          ),
        ],
      ),
    );
  }
}
