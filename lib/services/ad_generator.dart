import '../models/ad_brief.dart';
import '../models/business_category.dart';
import '../models/generated_ad.dart';
import '../models/seasonal_theme.dart';

/// مولّد المحتوى الإعلاني — يعمل بالكامل على الجهاز (الطبقة 1).
///
/// الجودة تأتي من تقاطع ثلاثة مصادر بدل قوالب عامة:
/// **نشاط التاجر** (يحدد المفردات والمنافع ودعوة الإجراء)،
/// **النبرة** (تحدد الصياغة والانفعال)، و**المنصة** (تحدد الهاشتاقات).
/// الناتج حتمي لنفس المدخلات ليبقى قابلًا للتكرار في الاختبارات،
/// ويتغيّر مع كل «إعادة توليد» عبر البذرة [seed].
class AdGenerator {
  AdGenerator._();

  static const generationStages = [
    'تحليل صورة المنتج',
    'كتابة النص الإعلاني',
    'إخراج التصميم النهائي',
  ];

  static const stageDuration = Duration(milliseconds: 800);

  /// صياغة العنوان حسب النبرة: تُطبَّق على عبارة الجذب الخاصة بالنشاط.
  static const _headlineByTone = {
    'حماسي': ['{hook} — لا تفوّت!', '{hook} 🔥', 'أخيرًا: {hook}!'],
    'كوميدي': ['{hook}… لا تلومنا 😄', 'تحذير: {hook}', '{hook} وبس!'],
    'رسمي': ['{hook}', 'نقدّم لكم: {hook}', '{hook} — بمعايير تليق بكم'],
    'عاطفي': ['{hook} ❤️', '{hook}… لمن تحب', 'لأنك تستاهل: {hook}'],
  };

  static const _hashtagsByPlatform = {
    'إنستغرام': ['#اكسبلور', '#عروض'],
    'تيك توك': ['#فوريو', '#ترند'],
    'فيسبوك': ['#تسوق_اونلاين', '#جديدنا'],
    'سناب شات': ['#سناب', '#وصل_حديثا'],
  };

  static Future<List<GeneratedAd>> generate(
    AdBrief brief, {
    int seed = 0,
  }) async {
    await Future<void>.delayed(stageDuration * generationStages.length);
    return preview(brief, seed: seed);
  }

  static List<GeneratedAd> preview(AdBrief brief, {int seed = 0}) {
    final category = brief.category;
    final product = brief.productName.trim().isEmpty
        ? 'منتجك'
        : brief.productName.trim();
    final about = brief.description.trim();

    final hook = _pick(category.hooks, seed);
    final headline = _pick(
      _headlineByTone[brief.tone] ?? _headlineByTone.values.first,
      seed,
    ).replaceAll('{hook}', hook);

    // منفعتان مختلفتان حتى لا تتكرر الجملة نفسها في النسخ الثلاث.
    final benefit = _pick(category.benefits, seed);
    final benefitAlt = _pick(category.benefits, seed + 1);

    final tags = [
      ..._hashtagsByPlatform[brief.platform] ??
          _hashtagsByPlatform.values.first,
      ...category.hashtags,
      if (brief.season != null) brief.season!.hashtag,
    ];
    final productTag = '#${product.replaceAll(' ', '_')}';
    // [category.cta] يبقى أول خيار دائمًا فيتطابق سلوك seed=0 مع السابق،
    // والمتغيّرات تُضاف لتنويع الصياغة عند إعادة التوليد.
    final cta = _pick([category.cta, ...category.ctaVariants], seed);
    final now = DateTime.now();

    // الوصف الاختياري يُدمج جملةً كاملة بدل إقحامه كما هو.
    final aboutClause = about.isEmpty ? '' : ' $about.';
    // الموسم يضيف طابعًا احتفاليًا فوق مفردات النشاط، لا يستبدلها.
    final seasonClause =
        brief.season == null ? '' : ' ${brief.season!.campaignPhrase}.';

    return [
      GeneratedAd(
        brief: brief,
        kind: AdKind.video,
        headline: headline,
        body:
            'سيناريو ${brief.format} من 15 ثانية: لقطة افتتاحية لـ$product، '
            'ثم تعليق صوتي بأسلوب ${brief.tone} يذكر أن $benefit،'
            '$aboutClause$seasonClause وختام بدعوة واضحة «$cta».',
        hashtags: _dedupe([...tags, productTag]),
        score: _score(brief, AdKind.video, seed),
        cta: cta,
        createdAt: now,
      ),
      GeneratedAd(
        brief: brief,
        kind: AdKind.image,
        headline: headline,
        body:
            'تصميم ${brief.format} يُبرز $product بإضاءة تُظهر تفاصيله، '
            'ونصّ جانبي يؤكد أن $benefitAlt.$aboutClause$seasonClause',
        hashtags: _dedupe(tags),
        score: _score(brief, AdKind.image, seed),
        cta: cta,
        createdAt: now,
      ),
      GeneratedAd(
        brief: brief,
        kind: AdKind.copy,
        headline: headline,
        body:
            '$product الآن بين يديك — $benefit.$aboutClause$seasonClause '
            '$cta عبر ${brief.platform}.',
        hashtags: _dedupe([...tags, '#عرض_خاص']),
        score: _score(brief, AdKind.copy, seed),
        cta: cta,
        createdAt: now,
      ),
    ];
  }

  /// يمنع تكرار الهاشتاق حين يطابق اسمُ المنتج أحدَ هاشتاقات الفئة.
  static List<String> _dedupe(List<String> tags) =>
      tags.toSet().toList(growable: false);

  static String _pick(List<String> options, int seed) =>
      options[seed.abs() % options.length];

  /// درجة توافق (78-97) على نمط Creative Score، حتمية لنفس المدخلات.
  static int _score(AdBrief brief, AdKind kind, int seed) {
    final hash = brief.tone.length * 7 +
        brief.platform.length * 5 +
        brief.format.length * 3 +
        brief.category.index * 17 +
        kind.index * 13 +
        seed * 11;
    return 78 + (hash % 20);
  }
}
