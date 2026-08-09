import '../models/ad_brief.dart';
import '../models/generated_ad.dart';

/// مولّد محتوى وهمي (mock) يحاكي مخرجات مزوّد ذكاء اصطناعي حقيقي.
/// المحتوى والدرجات محسوبة بشكل حتمي من المدخلات حتى تكون
/// التجربة والاختبارات قابلة للتكرار، ويتغيّر الناتج مع كل «إعادة توليد»
/// عبر البذرة [seed].
class AdGenerator {
  AdGenerator._();

  static const generationStages = [
    'تحليل صورة المنتج',
    'كتابة النص الإعلاني',
    'إخراج التصميم النهائي',
  ];

  static const stageDuration = Duration(milliseconds: 800);

  static const _hooksByTone = {
    'حماسي': ['عرض لا يفوّت!', 'الفرصة اللي تنتظرها وصلت 🔥', 'خلّك أول من يجرب!'],
    'كوميدي': ['جرّبته؟ لا تلومنا إذا أدمنت 😄', 'تحذير: قد يسبب الإعجاب الشديد', 'أخيرًا شي يستاهل التصوير'],
    'رسمي': ['جودة تليق بأعمالكم', 'اختيار الشركات الرائدة', 'التميز يبدأ من التفاصيل'],
    'عاطفي': ['لأن أهلك يستاهلون الأفضل ❤️', 'لحظات لا تُنسى تبدأ من هنا', 'صنعناه بحب، لتشاركه مع من تحب'],
  };

  static const _hashtagsByPlatform = {
    'إنستغرام': ['#اكسبلور', '#تسويق', '#عروض'],
    'تيك توك': ['#فوريو', '#ترند', '#اكتشف'],
    'فيسبوك': ['#تسوق_اونلاين', '#عروض_اليوم', '#جديدنا'],
    'سناب شات': ['#سناب', '#وصل_حديثا', '#مميز'],
  };

  static Future<List<GeneratedAd>> generate(
    AdBrief brief, {
    int seed = 0,
  }) async {
    await Future<void>.delayed(
      stageDuration * generationStages.length,
    );
    return preview(brief, seed: seed);
  }

  static List<GeneratedAd> preview(AdBrief brief, {int seed = 0}) {
    final hooks = _hooksByTone[brief.tone] ?? _hooksByTone.values.first;
    final hook = hooks[seed % hooks.length];
    final tags = _hashtagsByPlatform[brief.platform] ??
        _hashtagsByPlatform.values.first;
    final product = brief.productName.trim().isEmpty
        ? 'منتجك'
        : brief.productName.trim();
    final about = brief.description.trim().isEmpty
        ? ''
        : ' ${brief.description.trim()}.';
    final now = DateTime.now();

    return [
      GeneratedAd(
        brief: brief,
        kind: AdKind.video,
        headline: hook,
        body:
            'سيناريو ${brief.format} من 15 ثانية: لقطة افتتاحية للمنتج، '
            'ثم عرض $product مع تعليق صوتي بنبرة ${brief.tone}،'
            '$about وختام بدعوة واضحة «اطلب الآن».',
        hashtags: [...tags, '#$product'.replaceAll(' ', '_')],
        score: _score(brief, AdKind.video, seed),
        createdAt: now,
      ),
      GeneratedAd(
        brief: brief,
        kind: AdKind.image,
        headline: hook,
        body:
            'تصميم ${brief.format} بخلفية احترافية تُبرز $product '
            'مع إضاءة استوديو وألوان متوافقة مع هوية ${brief.platform}.$about',
        hashtags: tags,
        score: _score(brief, AdKind.image, seed),
        createdAt: now,
      ),
      GeneratedAd(
        brief: brief,
        kind: AdKind.copy,
        headline: hook,
        body:
            '$product الآن بين يديك.$about اطلبه اليوم عبر ${brief.platform} '
            'واستمتع بتجربة تستحق المشاركة.',
        hashtags: [...tags, '#عرض_خاص'],
        score: _score(brief, AdKind.copy, seed),
        createdAt: now,
      ),
    ];
  }

  /// درجة توافق (78-97) على نمط Creative Score، حتمية لنفس المدخلات.
  static int _score(AdBrief brief, AdKind kind, int seed) {
    final hash = brief.tone.length * 7 +
        brief.platform.length * 5 +
        brief.format.length * 3 +
        kind.index * 13 +
        seed * 11;
    return 78 + (hash % 20);
  }
}
