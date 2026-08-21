import 'dart:ui';

import '../models/ad_format.dart';
import '../models/business_category.dart';
import '../models/design_spec.dart';
import 'design_critic.dart';
import 'spec_doctor.dart';
import 'wish_parser.dart';

/// ما يُصمَّم: النصّ والصورة والصيغة.
class DesignBrief {
  const DesignBrief({
    required this.headline,
    required this.format,
    this.subhead,
    this.cta,
    this.badge,
    this.tags,
    this.seasonBadge,
    this.ornament = false,
    this.hasImage = false,
    this.hasLogo = false,
    this.preferLight,
  });

  final String headline;
  final AdFormat format;
  final String? subhead;
  final String? cta;

  /// شارة قصيرة («خصم ٣٠٪») — تُرسم لوحًا صغيرًا يلفت.
  final String? badge;
  final String? tags;

  /// شارة الموسم («🇸🇦 اليوم الوطني») — بلون الموسم لا بلون اللوحة.
  ///
  /// مفصولة عن `badge` عمدًا: التاجر قد يعلن خصمًا **في** موسم، وضمّهما
  /// في حقلٍ واحد يُسقط أحدهما — وكلاهما اختيار صريح اختاره بيده.
  final String? seasonBadge;

  /// زخرفة ركن مستوحاة من نشاط التاجر.
  final bool ornament;

  final bool hasImage;
  final bool hasLogo;

  /// تفضيل خلفية فاتحة. `null` يترك الاختيار للمولّد.
  final bool? preferLight;

  bool get hasSubhead => (subhead ?? '').trim().isNotEmpty;
  bool get hasCta => (cta ?? '').trim().isNotEmpty;
  bool get hasBadge => (badge ?? '').trim().isNotEmpty;
  bool get hasTags => (tags ?? '').trim().isNotEmpty;
  bool get hasSeasonBadge => (seasonBadge ?? '').trim().isNotEmpty;
}

/// تخطيط محلّي بدرجته.
class LocalDesign {
  const LocalDesign({
    required this.spec,
    required this.score,
    required this.archetype,
  });

  final DesignSpec spec;
  final DesignScore score;

  /// اسم النمط الذي وُلد منه — يُفيد في ضمان التنوّع وفي التشخيص.
  final String archetype;
}

/// المصمّم المحلّي — تكوينٌ يُركَّب على الجهاز، بلا شبكة وبلا حصّة.
///
/// كان الذكاء المحلّي عندنا **يملأ** أحد عشر قالبًا مكتوبًا في Dart،
/// والتكوين المفتوح لا يأتي إلا من السحابة: ثماني ثوانٍ انتظارًا، وسقوطٌ
/// تامّ حين تنقطع الشبكة أو تنفد الحصّة، وحصّةٌ تُنفَق على طلبٍ بسيط.
///
/// وهذا المولّد يفعل ما يفعله النموذج — يُركّب تكوينًا — بطريقة أخرى:
///
///   **يقترح**: سبعة أنماط معلَّمة (لا قوالب جامدة) تُضرَب في جهة النصّ
///   وإزاحة حجم العنوان ونصيب المنتج ومقدار الفجوة ونمط الخلفية — نحو
///   ألف ومئتَي محاولة، ينجو منها بعد الطبيب أربعون إلى ستّين تخطيطًا
///   **متمايز الهندسة**.
///
///   والرقم مذكور لأنه قيس: كان التوثيق يقول «مئات التخطيطات» بينما
///   البحث الحقيقي تسعةٌ لا غير — لأن إزاحة الحجم لا تمسّ مستطيلًا،
///   والناقد يقيس النِسَب لا الأحجام، فتتعادل عشرات المرشّحين ويُحسم
///   المعروض بترتيب الفرز لا بقياس. فصار التنويع على ما يغيّر
///   **المستطيلات**: نصيب المنتج والفجوة وجهة النصّ.
///
///   **يقيس**: كل مرشَّح يمرّ على `SpecDoctor` (بوّابة: يُقرأ؟ داخل
///   الهامش؟ بلا تداخل؟) ثم على `DesignCritic` (درجة: تسلسل، اصطفاف،
///   توازن، فراغ، إيقاع، بؤرة).
///
///   **يختار**: الأعلى درجةً، مع فرض تنوّع الأنماط فلا تُعرض ثلاث نسخ
///   من تكوين واحد.
///
/// وهذا ليس تقليدًا لنموذج لغوي بل **بحثٌ موجَّه بدالّة هدف** — وهو ما
/// يجيده الحاسوب أكثر مما يجيده النموذج: النموذج يقترح ولا يرى ما رسم،
/// والمولّد هنا يرى كل مرشَّح ويقيسه قبل أن يعرضه.
///
/// وكل شيء **حتميّ**: البذرة من الموجز نفسه، فالتاجر الذي يعيد الطلب
/// يرى ما رآه. مولّدٌ يعطي نتيجة مختلفة كل مرّة يجعل «أعجبني الأول»
/// خسارةً لا رجعة فيها.
class LocalDesigner {
  const LocalDesigner._();

  /// أعمدة الشبكة. اثنا عشر عمودًا هو مقياس التخطيط المتعارف: يقبل
  /// القسمة على ٢ و٣ و٤ و٦، فتصير أنصافًا وأثلاثًا وأرباعًا كلها
  /// مصطفّة على المحاور نفسها.
  static const cols = 12;

  /// أنماط التكوين المتاحة.
  static const archetypes = <String>[
    'stackTop',
    'stackBottom',
    'sideBySide',
    'heroCentre',
    'bandedHeadline',
    'posterFrame',
    'magazine',
  ];

  /// يُركّب ويقيس ويختار. `count` عدد التخطيطات المعادة.
  static List<LocalDesign> compose(
    DesignBrief rawBrief, {
    required Color brandColor,
    Color? seasonColor,
    Map<String, int>? taste,
    int count = 3,
  }) {
    // المصمّم **يُكمل** لا يصمت.
    //
    // الطبيب يحجب كل تصميم بلا دعوة إجراء أو بلا عنوان، فموجزٌ ناقصهما
    // كان يُسقط المرشّحين كلّهم فتعود القائمة فارغة بلا سبب مفهوم —
    // ومسحٌ على ٣٨٤ توليفة أظهر أن نصفها بالضبط (كل ما خلا من زرّ حثّ)
    // يعود صفرًا. ومصمّمٌ بشريّ يُعطى إعلانًا بلا زرّ لا يعتذر: يضع
    // زرًّا. فنفعل مثله، ونترك الطبيب حارسًا على ما لا يُصلَح.
    final brief = _completed(rawBrief);
    if (brief == null) return const [];

    final margin = brief.format.safeMargin;
    final grid = _Grid(margin: margin);
    final candidates = <LocalDesign>[];

    // البذرة من المحتوى لا من الساعة: نفس الموجز ينتج نفس التصاميم.
    final seed = _seedOf(brief);

    // الاقتران الطباعي يُختار بالنيّة لا بالبحث — راجع [_pairingFor].
    final pairing = _pairingFor(brief);

    // بلا صورة منتج تنهار أنماطُ المنتج إلى تخطيط واحد بأسماء ثلاثة:
    // `_sideBySide` يفوّض إلى الكدس، و`stackBottom` يسقط منه المنتج
    // فيصير `stackTop`. فيرى التاجر «ثلاثة خيارات» متطابقة البايتات،
    // وشرحان منها يَعِدان بمنتج لا وجود له.
    final usable = brief.hasImage
        ? archetypes
        : archetypes
              .where(
                (a) => !const {
                  'stackBottom',
                  'sideBySide',
                  'heroCentre',
                  'magazine',
                }.contains(a),
              )
              .toList();

    for (final archetype in usable) {
      for (final textAtStart in [true, false]) {
        for (final headStep in [0, 1, 2]) {
          // وزن المنتج والفجوة يغيّران **المستطيلات** لا الأحجام وحدها.
          // وبلا هذين كان البحث الحقيقي تسعة تخطيطات لا مئتين وعشرة:
          // `headStep` يمسّ حجم الحرف فقط، والناقد يقيس النِسَب لا
          // الأحجام المطلقة — فتتعادل عشرات المرشّحين عند القمّة ويُحسم
          // المعروض بترتيب الفرز لا بقياس.
          for (final productWeight in [2.6, 3.4, 4.4]) {
            for (final gap in [0.024, 0.042]) {
              for (final backdrop in _backdropsFor(brief)) {
                final variant =
                    (seed + usable.indexOf(archetype) * 31 + headStep) % 8;
                final elements = _build(
                  archetype: archetype,
                  grid: grid,
                  brief: brief,
                  textAtStart: textAtStart,
                  headStep: headStep,
                  productWeight: productWeight,
                  gap: gap,
                );
                if (elements.isEmpty) continue;

                final spec = DesignSpec(
                  format: brief.format,
                  backdrop: backdrop,
                  elements: elements,
                  variant: variant.abs(),
                  pairing: pairing,
                  note: _noteFor(archetype),
                );
                final score = DesignCritic.score(
                  spec,
                  brandColor: brandColor,
                  seasonColor: seasonColor,
                );
                if (!score.usable) continue;

                // المعروض هو ما بعد الطبيب لا ما قبله: الدرجة حُسبت على
                // المُصلَح، فعرضُ الخام يعني عرض غير ما قِيس.
                final healed = SpecDoctor.review(
                  spec,
                  brandColor: brandColor,
                  seasonColor: seasonColor,
                ).spec;
                candidates.add(
                  LocalDesign(spec: healed, score: score, archetype: archetype),
                );
              }
            }
          }
        }
      }
    }

    candidates.sort(
      (a, b) => _tasted(b, taste).compareTo(_tasted(a, taste)),
    );

    // تنوّع الأنماط مفروض: ثلاثة تكوينات من نمط واحد تبدو للتاجر خيارًا
    // واحدًا مكرّرًا، ولو كانت أعلى الدرجات.
    // التنوّع بشرطين لا بشرط واحد.
    //
    // الاسم وحده يكذب: ثلاثة أنماط قد تُخرج المستطيلات نفسها بالضبط
    // فيمرّ التكرار مصنَّفًا «تنوّعًا». والهندسة وحدها لا تكفي: ثلاث
    // نسخ من نمطٍ واحد بأوزان منتج مختلفة تتمايز حسابيًّا وتتشابه
    // للعين — والتاجر يريد خيارات لا فروقًا دقيقة.
    //
    // فالمرور الأول يأخذ أعلى تخطيط من **كل نمط**، والثاني يُكمل بما
    // تمايزت هندسته مهما تكرّر نمطه.
    final picked = <LocalDesign>[];
    final seenGeometry = <String>{};
    final seenArchetype = <String>{};

    for (final c in candidates) {
      if (picked.length >= count) break;
      final key = _geometryKey(c.spec);
      if (seenArchetype.contains(c.archetype) || seenGeometry.contains(key)) {
        continue;
      }
      picked.add(c);
      seenArchetype.add(c.archetype);
      seenGeometry.add(key);
    }

    for (final c in candidates) {
      if (picked.length >= count) break;
      final key = _geometryKey(c.spec);
      if (seenGeometry.contains(key)) continue;
      picked.add(c);
      seenGeometry.add(key);
    }
    return picked;
  }

  /// أقصى ما يرفعه ذوق التاجر من درجة نمطٍ يحبّه.
  ///
  /// اثنا عشر بالمئة تكفي لتقديم المفضَّل حين يتقارب المرشّحون، ولا
  /// تكفي لتقديم رديء على جيّد. والفرق جوهريّ: مفضَّلٌ بلا سقف يجعل
  /// التطبيق يعيد نمطًا واحدًا إلى الأبد، فيصير «تعلُّمًا» اسمًا
  /// لانغلاقٍ على أوّل اختيار.
  static const maxTasteBoost = 0.12;

  /// الدرجة بعد ميل الذوق.
  ///
  /// **ترتيبٌ لا بوّابة**: الضرب يقع على درجةٍ اجتازت الطبيب أصلًا،
  /// فذوق التاجر يقدّم ويؤخّر ولا يُحيي تصميمًا رفضه القياس. ولو دخل
  /// الذوق قبل البوّابة لصار «أحبّ هذا النمط» طريقًا إلى نصٍّ لا يُقرأ.
  static double _tasted(LocalDesign d, Map<String, int>? taste) {
    if (taste == null || taste.isEmpty) return d.score.total;
    var top = 0;
    for (final v in taste.values) {
      if (v > top) top = v;
    }
    if (top <= 0) return d.score.total;
    final mine = taste[d.archetype] ?? 0;
    return d.score.total * (1 + maxTasteBoost * (mine / top));
  }

  /// بصمة هندسية: الأدوار ومواضعها مقرَّبة. تكوينان بالبصمة نفسها
  /// يُرسمان متطابقين مهما اختلف اسماهما.
  static String _geometryKey(DesignSpec s) => s.elements
      .map(
        (e) =>
            '${e.role.name}:${e.rect.x.toStringAsFixed(3)},'
            '${e.rect.y.toStringAsFixed(3)},'
            '${e.rect.w.toStringAsFixed(3)},'
            '${e.rect.h.toStringAsFixed(3)}',
      )
      .join('|');

  /// يُكمل الموجز بما لا يقوم إعلان بدونه، ويرفض ما لا يُكمَّل.
  ///
  /// العنوان لا يُخترع: هو رسالة التاجر، واختراعُه يضع في إعلانه كلامًا
  /// لم يقله. أما دعوة الإجراء فصيغة عامّة يضعها كل مصمّم.
  static DesignBrief? _completed(DesignBrief b) {
    if (b.headline.trim().isEmpty) return null;
    if (b.hasCta) return b;
    return DesignBrief(
      headline: b.headline,
      format: b.format,
      subhead: b.subhead,
      cta: 'اطلب الآن',
      badge: b.badge,
      tags: b.tags,
      seasonBadge: b.seasonBadge,
      ornament: b.ornament,
      hasImage: b.hasImage,
      hasLogo: b.hasLogo,
      preferLight: b.preferLight,
    );
  }

  /// يبني موجزًا من أمنية التاجر — الجسر بين القارئ والمصمّم.
  ///
  /// [category] نشاط التاجر. بدونه يخرج إعلانٌ صحيح وعامّ؛ ومعه يخرج
  /// إعلانٌ يتكلّم لغة النشاط: المقهى يُنادى إليه بـ«زورونا اليوم» لا
  /// بـ«اطلب الآن»، والعقار بـ«احجز معاينتك». والمفردات موجودة في
  /// التطبيق منذ زمن (`business_category.dart`) وكان مسارُ الأمنية
  /// وحده لا يمرّ بها — فيكتب لصاحب الكافيه ما يكتبه لمتجر قطع غيار.
  static DesignBrief briefFromIntent(
    WishIntent intent, {
    required AdFormat fallbackFormat,
    required String product,
    String? brandName,
    BusinessCategory? category,
    bool hasImage = false,
    bool hasLogo = false,
    String? seasonBadge,
    String? merchantBadge,
    bool ornament = false,
    bool? preferLight,
  }) {
    // ما ذكره التاجر في أمنيته أولى بما خزّناه عنه: هو يكتب الآن،
    // والمخزَّن قد يكون من جلسة أخرى وسلعة أخرى.
    final named = intent.subject?.trim() ?? '';
    final stored = product.trim();
    final p = named.isNotEmpty ? named : (stored.isEmpty ? 'منتجنا' : stored);
    final pct = intent.discountPercent;

    // الاختيار من مفردات النشاط **حتميّ** من نصّ الأمنية: التاجر الذي
    // يعيد الطلب نفسه يرى الصياغة نفسها، ومن غيّر كلمةً يرى تنويعًا.
    // ولو كان عشوائيًّا لصار «أعجبني هذا» خسارةً لا رجعة فيها.
    final seed = _fnv(intent.raw);
    String? ofList(List<String> xs, int salt) =>
        xs.isEmpty ? null : xs[(seed ~/ (salt + 1)) % xs.length];

    final catCta = category == null
        ? null
        : ofList([category.cta, ...category.ctaVariants], 1);
    final hook = category == null ? null : ofList(category.hooks, 7);

    // النصّ يُبنى من الفهم لا يُنسخ من الأمنية: التاجر يكتب طلبًا
    // («أبي إعلان خصم») لا عنوانًا، ووضعُ طلبه عنوانًا يُخرج إعلانًا
    // يخاطبنا نحن لا جمهوره.
    final (headline, subhead, cta) = switch (intent.offer) {
      WishOffer.discount => (
        pct != null ? 'خصم $pct٪ على $p' : 'عرض خاص على $p',
        intent.urgent ? 'لفترة محدودة — لا تفوّته' : 'اغتنمها قبل أن تنتهي',
        catCta ?? 'اطلب الآن',
      ),
      WishOffer.opening => (
        'افتتاح ${brandName?.trim().isNotEmpty == true ? brandName!.trim() : p}',
        'ننتظرك في يومنا الأول',
        catCta ?? 'زُرنا اليوم',
      ),
      WishOffer.newItem => ('وصل $p', hook ?? 'جديدنا بين يديك', 'اكتشفه'),
      // والتوظيف وحده لا يأخذ دعوة النشاط: «احجز معاينتك» في إعلان
      // وظيفة يطلب من الباحث عن عمل أن يشتري.
      WishOffer.hiring => (
        'نبحث عن من يشبهنا',
        'فرص عمل في ${brandName?.trim().isNotEmpty == true ? brandName!.trim() : p}',
        'قدّم الآن',
      ),
      WishOffer.delivery => (
        'توصيل مجاني',
        'يصلك $p إلى بابك',
        catCta ?? 'اطلب الآن',
      ),
      WishOffer.season => (
        'موسمنا معك',
        'عروض $p هذا الموسم',
        catCta ?? 'تسوّق الآن',
      ),
      WishOffer.general => (
        p,
        hook ??
            (brandName?.trim().isNotEmpty == true
                ? brandName!.trim()
                : 'جودة تُميّزنا'),
        catCta ?? 'تواصل معنا',
      ),
    };

    return DesignBrief(
      headline: headline,
      subhead: subhead,
      cta: cta,
      // نسبةُ الأمنية أولى من الشارة المخزَّنة، بالقاعدة نفسها التي
      // قدّمت موضوعَ الأمنية على المنتج المحفوظ: التاجر يكتب الآن.
      //
      // وليس لأن معناهما واحد — «حلال ١٠٠٪» و«خصم ٢٥٪» مطلبان مختلفان —
      // بل لأن ثلاث شارات في تكوين واحد (مع شارة الموسم) تزدحم. وشارته
      // المختارة تبقى ظاهرة في مسار القوالب.
      badge: pct != null ? 'خصم $pct٪' : merchantBadge,
      seasonBadge: seasonBadge,
      // هاشتاقات النشاط: `tags` كان حقلًا ميّتًا ثالثًا — لا مسارَ يملؤه،
      // فكلّ إعلان محلّي يخرج بلا هاشتاق، والتاجر الذي ينسخ نصّه إلى
      // إنستغرام ينسخ نصفَ إعلان.
      tags: category?.hashtags.join(' '),
      ornament: ornament,
      format: intent.format ?? fallbackFormat,
      hasImage: hasImage,
      hasLogo: hasLogo,
      // ما نطق به التاجر في أمنيته («تصميم فاتح») أولى بما استنتجناه
      // من قالبٍ اختاره قبل قليل.
      preferLight: intent.wantsLight ?? preferLight,
    );
  }

  // ── الأنماط ────────────────────────────────────────────────────────

  static List<DesignElement> _build({
    required String archetype,
    required _Grid grid,
    required DesignBrief brief,
    required bool textAtStart,
    required int headStep,
    required double productWeight,
    required double gap,
  }) {
    // حجم العنوان من **طول نصّه** لا من عدّاد أعمى.
    //
    // كانت ثلاث درجات تُجرَّب جميعًا بلا نظر إلى الكلام، والتعليق يزعم
    // أنها تراعي الطول. وقياسًا: عنوانٌ بحرف واحد وعنوانٌ بخمس عشرة
    // كلمة كانا يخرجان **بنفس المستطيل ونفس الحجم بالضبط** — ثمانون
    // حرفًا في كرت ‎9×5‎ سم بحجم ٧٪ لا يسعها العارض فيُصغّرها أو يقصّها،
    // والناقد لا يرى شيئًا من ذلك.
    //
    // فالدرجة تُشتقّ من الطول، وتبقى `headStep` إزاحةً حول ما اشتُقّ:
    // تجربةُ الأكبر والأصغر قليلًا حول المقاس المناسب.
    final chars = brief.headline.trim().length;
    final base = chars <= 12
        ? 0.084
        : chars <= 24
        ? 0.068
        : chars <= 40
        ? 0.056
        : 0.046;
    final headSize =
        (base *
                switch (headStep) {
                  0 => 0.85,
                  1 => 1.0,
                  _ => 1.18,
                })
            .clamp(0.030, 0.11);
    final tall = brief.format.aspectClass == AspectClass.tall;

    final body = switch (archetype) {
      'stackTop' => _stack(
        grid,
        brief,
        headSize,
        productBelow: true,
        textAtStart: textAtStart,
        productWeight: productWeight,
        gap: gap,
      ),
      'stackBottom' => _stack(
        grid,
        brief,
        headSize,
        productBelow: false,
        textAtStart: textAtStart,
        productWeight: productWeight,
        gap: gap,
      ),
      'sideBySide' => _sideBySide(grid, brief, headSize, textAtStart, gap),
      'heroCentre' => _heroCentre(grid, brief, headSize, productWeight, gap),
      'bandedHeadline' => _banded(grid, brief, headSize, tall, productWeight),
      'posterFrame' => _poster(grid, brief, headSize, productWeight),
      'magazine' => _magazine(
        grid,
        brief,
        headSize,
        textAtStart,
        productWeight,
      ),
      _ => const <DesignElement>[],
    };
    if (body.isEmpty || !brief.ornament) return body;

    // الزخرفة **أوّل** القائمة لا آخرها: العارض يرسم بترتيبها، فوضعها
    // آخرًا يجعلها طبقةً فوق العنوان والمنتج.
    return [_ornament(brief.format), ...body];
  }

  /// زخرفة الركن — ركنٌ ينزف خارج اللوحة كما في المطبوعات.
  ///
  /// عرضها كسرٌ من **العرض**، وارتفاعها يُشتقّ من نسبة اللوحة حتى يبقى
  /// الرسم مربّعًا على الشاشة: كسرٌ ثابت للارتفاع يُخرج في الرول أب
  /// ‎85×200‎ صندوقًا ممطوطًا يضيع الرسم في وسطه.
  static DesignElement _ornament(AdFormat format) {
    const w = 0.52;
    const bleed = 0.22; // ما ينزف خارج الحافّة من الزخرفة نفسها.
    final h = (w * format.aspect).clamp(0.18, 0.60);
    return DesignElement(
      role: ElementRole.ornament,
      rect: SpecRect(1 - w * (1 - bleed), 1 - h * (1 - bleed), w, h),
    );
  }

  /// **موزّع العمود** — المفتاح الذي جعل كل نمط يعمل على كل لوحة.
  ///
  /// كانت الأحجام كسورًا ثابتة من اللوحة (٠٫٤٠ للمنتج، ٠٫٣٠ للنصّ…)،
  /// وهي تصلح لمربّع وتفيض على رول أب ‎85×200‎: يتجاوز مجموعها الواحد
  /// فيُقصّ زرّ الحثّ أو يتداخل، فيحجبه الطبيب. وكانت النتيجة أن خمسة
  /// من سبعة أنماط لا تُنتج تخطيطًا صالحًا لأطول لوحة عندنا وأهمّها.
  ///
  /// هنا تُوزَّع المساحة **نسبةً إلى المتاح**: لكل كتلة وزن، والفجوات
  /// تُحسم أوّلًا، وما بقي يُقسَّم بالأوزان. فيصحّ التكوين على المربّع
  /// والكرت والرول أب بلا رقم مكتوب لكل صيغة.
  static List<DesignElement> _column(
    _Grid g,
    List<_Block> blocks, {
    double gap = 0.03,
  }) {
    final live = blocks.where((b) => b.weight > 0).toList();
    if (live.isEmpty) return const [];

    final gaps = gap * (live.length - 1);
    final space = (g.height - gaps).clamp(0.05, 1.0);
    final totalWeight = live.fold<double>(0, (a, b) => a + b.weight);

    final out = <DesignElement>[];
    var y = g.top;
    for (final b in live) {
      final h = space * (b.weight / totalWeight);
      out.add(b.build(g, y, h));
      y += h + gap;
    }
    return out;
  }

  /// كدسٌ رأسي: نصّ ثم منتج (أو العكس).
  static List<DesignElement> _stack(
    _Grid g,
    DesignBrief b,
    double headSize, {
    required bool productBelow,
    bool textAtStart = true,
    double productWeight = 3.4,
    double gap = 0.03,
  }) {
    // جهة النصّ كانت مُهمَلة في خمسة أنماط من سبعة، فيتكرّر التخطيط
    // نفسه مرّتين تحت اسمين — «تنوّعٌ» في العدّ لا في الرؤية.
    final align = textAtStart ? SpecAlign.start : SpecAlign.end;
    final col = textAtStart ? 0 : 2;

    final badges = _badgeBlocks(g, b, col: col);
    final head = _headBlock(b, headSize, 2.0, align, span: 10, col: col);
    final sub = _subBlock(b, headSize, 1.1, align, span: 9, col: col);
    final product = _productBlock(b, productWeight, col: 1, span: 10);
    final cta = _ctaBlock(b, headSize, 1.0, col: col, span: 5);

    return _column(g, [
      _logoBlock(b, col: 0, span: 2),
      if (!productBelow) product,
      ...badges,
      head,
      sub,
      if (productBelow) product,
      cta,
      _tagsBlock(b, headSize, align, span: 9, col: col),
    ], gap: gap);
  }

  /// نصفان: نصّ في جهة ومنتج في الأخرى — تكوين اللوحات العريضة.
  static List<DesignElement> _sideBySide(
    _Grid g,
    DesignBrief b,
    double headSize,
    bool textAtStart,
    double gap,
  ) {
    if (!b.hasImage) {
      return _stack(
        g,
        b,
        headSize,
        productBelow: true,
        textAtStart: textAtStart,
      );
    }

    final textCol = textAtStart ? 0 : 7;
    final prodCol = textAtStart ? 7 : 0;
    final align = textAtStart ? SpecAlign.start : SpecAlign.end;

    // عمود النصّ يُوزَّع في نصف اللوحة، والمنتج يملأ ارتفاعها كاملًا.
    final textGrid = _Grid(margin: g.margin);
    final text = _column(textGrid, [
      _logoBlock(b, col: textCol, span: 2),
      ..._badgeBlocks(g, b, col: textCol, span: 3),
      _headBlock(b, headSize * 0.86, 2.2, align, span: 5, col: textCol),
      _subBlock(b, headSize, 1.1, align, span: 5, col: textCol),
      _ctaBlock(b, headSize, 1.0, col: textCol, span: 4),
      _tagsBlock(b, headSize, align, span: 5, col: textCol),
    ], gap: gap);

    return [
      DesignElement(
        role: ElementRole.product,
        rect: g.rect(col: prodCol, span: 5, y: g.top, h: g.height),
      ),
      ...text,
    ];
  }

  /// المنتج بطلًا في الوسط، والنصّ فوقه وتحته.
  static List<DesignElement> _heroCentre(
    _Grid g,
    DesignBrief b,
    double headSize,
    double productWeight,
    double gap,
  ) {
    if (!b.hasImage) return const [];
    return _column(g, [
      _logoBlock(b, col: 5, span: 2),
      ..._badgeBlocks(g, b, col: 4, span: 4),
      _headBlock(b, headSize, 1.6, SpecAlign.center, span: 10, col: 1),
      _productBlock(b, productWeight + 0.8, col: 1, span: 10),
      _subBlock(b, headSize, 1.0, SpecAlign.center, span: 10, col: 1),
      _ctaBlock(b, headSize, 1.0, col: 4, span: 4),
      _tagsBlock(b, headSize, SpecAlign.center, span: 10, col: 1),
    ], gap: gap);
  }

  /// شريطٌ ملوّن خلف العنوان — أوضح تسلسل ممكن، ويعمل فوق أي خلفية.
  static List<DesignElement> _banded(
    _Grid g,
    DesignBrief b,
    double headSize,
    bool tall,
    double productWeight,
  ) {
    final body = _column(g, [
      _headBlock(b, headSize, tall ? 1.8 : 2.2, SpecAlign.center, span: 12),
      ..._badgeBlocks(g, b, col: 4, span: 4),
      _logoBlock(b, col: 5, span: 2),
      _productBlock(b, productWeight, col: 1, span: 10),
      _subBlock(b, headSize, 1.0, SpecAlign.center, span: 10, col: 1),
      _ctaBlock(b, headSize, 1.0, col: 4, span: 4),
      _tagsBlock(b, headSize, SpecAlign.center, span: 10, col: 1),
    ]);
    if (body.isEmpty) return body;

    // اللوح يُرسم **تحت** العنوان تمامًا: العارض يرسم بترتيب القائمة،
    // فوضعه أوّلًا يجعله خلفية له لا صندوقًا فوقه.
    final head = body.first;
    return [
      DesignElement(
        role: ElementRole.shape,
        rect: SpecRect(
          g.margin,
          head.rect.y - 0.015 < g.top ? g.top : head.rect.y - 0.015,
          g.usable,
          head.rect.h + 0.03,
        ),
        fill: ColorRole.deep,
      ),
      ...body,
    ];
  }

  /// إطارٌ رفيع وتكوين مركزي — تكوين المطبوعات الهادئة.
  static List<DesignElement> _poster(
    _Grid g,
    DesignBrief b,
    double headSize,
    double productWeight,
  ) => _column(g, [
    _logoBlock(b, col: 5, span: 2),
    _headBlock(b, headSize, 2.0, SpecAlign.center, span: 10, col: 1),
    ..._badgeBlocks(g, b, col: 4, span: 4),
    _subBlock(b, headSize, 1.0, SpecAlign.center, span: 8, col: 2),
    _productBlock(b, productWeight - 0.4, col: 2, span: 8),
    _ctaBlock(b, headSize, 1.0, col: 4, span: 4),
    _tagsBlock(b, headSize, SpecAlign.center, span: 8, col: 2),
  ], gap: 0.04);

  /// عنوانٌ كبير ومنتجٌ مزاح — تكوين غير مركزي.
  ///
  /// لا يُفوَّض إلى `_sideBySide` على اللوحات العريضة كما كان: تفويضٌ
  /// يعطي تخطيطين باسمين مختلفين، فيرى التاجر «تنوّعًا» هو تكرار.
  static List<DesignElement> _magazine(
    _Grid g,
    DesignBrief b,
    double headSize,
    bool textAtStart,
    double productWeight,
  ) {
    if (!b.hasImage) return const [];
    final col = textAtStart ? 0 : 4;
    final align = textAtStart ? SpecAlign.start : SpecAlign.end;
    return _column(g, [
      _logoBlock(b, col: col, span: 2),
      ..._badgeBlocks(g, b, col: col, span: 3),
      _headBlock(b, headSize, 2.0, align, span: 8, col: col),
      // المنتج غير مركزي عمدًا: قِستُ في بنر كانفا حقيقي منتجًا عند ٤٢٪
      // من العرض لا في المنتصف، وهو ما يعطي التكوين حركةً.
      _productBlock(b, productWeight, col: textAtStart ? 3 : 1, span: 8),
      _subBlock(b, headSize, 1.0, align, span: 7, col: col),
      _ctaBlock(b, headSize, 1.0, col: col, span: 5),
      _tagsBlock(b, headSize, align, span: 7, col: col),
    ]);
  }

  // ── الكتل ──────────────────────────────────────────────────────────

  static _Block _headBlock(
    DesignBrief b,
    double size,
    double weight,
    SpecAlign align, {
    required int span,
    int col = 0,
  }) => _Block(
    weight: weight,
    build: (g, y, h) => DesignElement(
      role: ElementRole.headline,
      rect: g.rect(col: col, span: span, y: y, h: h),
      text: b.headline,
      align: align,
      maxLines: 3,
      sizeFactor: size,
      weight: 800,
    ),
  );

  static _Block _subBlock(
    DesignBrief b,
    double headSize,
    double weight,
    SpecAlign align, {
    required int span,
    int col = 0,
  }) => _Block(
    weight: b.hasSubhead ? weight : 0,
    build: (g, y, h) => DesignElement(
      role: ElementRole.subhead,
      rect: g.rect(col: col, span: span, y: y, h: h),
      text: b.subhead,
      align: align,
      maxLines: 2,
      // الثانوي بين ثلث العنوان ونصفه: أقلّ منه يختفي، وأكثر ينقض
      // التسلسل الذي يقيسه الناقد.
      sizeFactor: headSize * 0.40,
      weight: 500,
    ),
  );

  static _Block _productBlock(
    DesignBrief b,
    double weight, {
    required int col,
    required int span,
  }) => _Block(
    weight: b.hasImage ? weight : 0,
    build: (g, y, h) => DesignElement(
      role: ElementRole.product,
      rect: g.rect(col: col, span: span, y: y, h: h),
    ),
  );

  /// صفّا الشارتين: الموسم ثمّ العرض.
  ///
  /// دالّة واحدة يستدعيها كل نمط بدل تكرار السطرين سبع مرّات — والسبب
  /// ليس الاختصار: `logo` و`tags` و`badge` كانت حقولًا تُحسب ولا يضعها
  /// بعض الأنماط، فتسقط شارة الخصم من تصميم فائز بلا أن يُنبَّه أحد.
  /// موضعُ إضافةٍ واحد يجعل نسيان نمطٍ مستحيلًا.
  static List<_Block> _badgeBlocks(
    _Grid g,
    DesignBrief b, {
    int col = 0,
    int span = 4,
  }) => [
    _seasonBlock(b, col: col, span: span),
    _badgeBlock(g, b, col: col, span: span),
  ];

  /// شارة الموسم — بلوحٍ بلون الموسم لا بلون اللوحة.
  ///
  /// وهي شارة كبقيّة الشارات في نظر الطبيب والناقد: يُقاس تباين حروفها،
  /// ويُحسب موضعها في الاصطفاف. وهذا الفرق كلّه بينها وبين ما كانت
  /// عليه — ملصقًا يُحقن في ركنٍ بعد أن يفرغ التكوين من الحساب، فيقع
  /// حيث اتّفق ولا يعلم به مقياس.
  static _Block _seasonBlock(DesignBrief b, {int col = 0, int span = 4}) =>
      _Block(
        weight: b.hasSeasonBadge ? 0.7 : 0,
        build: (g, y, h) => DesignElement(
          role: ElementRole.badge,
          rect: g.rect(col: col, span: span, y: y, h: h),
          text: b.seasonBadge,
          fill: ColorRole.season,
          align: SpecAlign.center,
          maxLines: 1,
          sizeFactor: 0.030,
          weight: 800,
        ),
      );

  static _Block _badgeBlock(
    _Grid g,
    DesignBrief b, {
    int col = 0,
    int span = 4,
  }) => _Block(
    weight: b.hasBadge ? 0.8 : 0,
    build: (grid, y, h) => DesignElement(
      role: ElementRole.badge,
      rect: grid.rect(col: col, span: span, y: y, h: h),
      text: b.badge,
      fill: ColorRole.complement,
      align: SpecAlign.center,
      maxLines: 1,
      sizeFactor: 0.034,
      weight: 900,
    ),
  );

  /// شعار العلامة كتلةً في العمود لا ملصقًا في ركن.
  ///
  /// `hasLogo` كان حقلًا ميّتًا: لا نمط يبني `ElementRole.logo` إطلاقًا،
  /// فشعار التاجر لا يظهر في أي تخطيط محلّي. ووضعُه في ركنٍ فوق النصّ
  /// يجعله حاجبًا يُزيح العنوان، فمكانه صفٌّ خاصّ به.
  static _Block _logoBlock(DesignBrief b, {int col = 0, int span = 2}) =>
      _Block(
        weight: b.hasLogo ? 0.7 : 0,
        build: (g, y, h) => DesignElement(
          role: ElementRole.logo,
          rect: g.rect(col: col, span: span, y: y, h: h),
        ),
      );

  /// الهاشتاقات — حقلٌ ميّت آخر: `_adFromSpec` يقرأها من المواصفة
  /// فتعود `null` دائمًا، فكل إعلان محلّي بلا هاشتاقات.
  static _Block _tagsBlock(
    DesignBrief b,
    double headSize,
    SpecAlign align, {
    required int span,
    int col = 0,
  }) => _Block(
    weight: b.hasTags ? 0.7 : 0,
    build: (g, y, h) => DesignElement(
      role: ElementRole.tags,
      rect: g.rect(col: col, span: span, y: y, h: h),
      text: b.tags,
      align: align,
      maxLines: 2,
      sizeFactor: headSize * 0.30,
      weight: 500,
    ),
  );

  static _Block _ctaBlock(
    DesignBrief b,
    double headSize,
    double weight, {
    required int col,
    required int span,
  }) => _Block(
    weight: b.hasCta ? weight : 0,
    build: (g, y, h) => DesignElement(
      role: ElementRole.cta,
      rect: g.rect(col: col, span: span, y: y, h: h),
      text: b.cta,
      fill: ColorRole.deep,
      align: SpecAlign.center,
      maxLines: 1,
      sizeFactor: headSize * 0.36,
      weight: 700,
    ),
  );

  static List<SpecBackdrop> _backdropsFor(DesignBrief b) {
    if (b.preferLight == true) return const [SpecBackdrop.paper];
    if (b.preferLight == false) {
      return const [
        SpecBackdrop.mesh,
        SpecBackdrop.spotlight,
        SpecBackdrop.arcs,
      ];
    }
    return const [
      SpecBackdrop.mesh,
      SpecBackdrop.spotlight,
      SpecBackdrop.arcs,
      SpecBackdrop.strata,
      SpecBackdrop.paper,
    ];
  }

  static String _noteFor(String archetype) => switch (archetype) {
    'stackTop' => 'نصّ أعلى ومنتج تحته — أوضح تسلسل للقراءة',
    'stackBottom' => 'منتج أعلى ونصّ تحته — الصورة تلفت أولًا',
    'sideBySide' => 'النصّ في جهة والمنتج في الأخرى — تكوين اللوحات العريضة',
    'heroCentre' => 'المنتج بطلًا في الوسط',
    'bandedHeadline' => 'شريط ملوّن خلف العنوان — يُقرأ من بعيد',
    'posterFrame' => 'تكوين مركزي هادئ يناسب المطبوع',
    'magazine' => 'عنوان كبير ومنتج مزاح — تكوين غير مركزي',
    _ => 'تكوين محلّي',
  };

  /// بذرة ثابتة من المحتوى — بحساب صريح لا بـ`hashCode`.
  ///
  /// `String.hashCode` في Dart لا يضمن قيمةً واحدة عبر المنصّات ولا عبر
  /// إصدارات التنفيذ (الجهاز غير الويب)، والتوثيق أعلاه يَعِد بالحتمية:
  /// «نفس الموجز يعطي نفس التصاميم». فوعدٌ مبنيّ على تفصيلة تنفيذٍ ليس
  /// وعدًا. وFNV-1a حسابٌ معرَّف بالكامل يعطي الرقم نفسه في كل مكان.
  /// يختار الاقتران الطباعي من **نيّة** الإعلان لا من البحث.
  ///
  /// وسائر محاور التنويع هنا تُبحَث: نجرّب مئات التوليفات ونقيسها
  /// بالناقد ونأخذ أعلاها. والطباعة لا تصلح لذلك، لأن الناقد **لا
  /// يقيسها** — يقيس النِسَب والمواضع والتباين، فتخرج التوليفات الأربع
  /// بدرجات متطابقة إلى الرقم، ويُحسم المعروض بترتيب الفرز لا بحكم.
  /// أي أن ضربَ البحث في أربعة يضاعف العمل على جهاز التاجر ولا يضيف
  /// حكمًا واحدًا.
  ///
  /// فالاختيار هنا بقاعدة تُقرأ: الخصمُ يُصرَخ به، والموسمُ يُزيَّن،
  /// والباقي يُقال بهدوء. وهي قاعدة قابلة للنقض بالنظر — بخلاف رقمٍ
  /// خرج من بذرة.
  static int _pairingFor(DesignBrief b) {
    // شارة خصم ⇒ ملصق عالي الصوت. من يكتب «خصم ٥٠٪» يريد أن يُقرأ من
    // الشارع لا أن يُتأمَّل.
    if (b.hasBadge) return 2;
    // موسمٌ ⇒ نسخيّ. المواسم عندنا (رمضان، العيد، اليوم الوطني) لها
    // ذاكرة بصرية نسخيّة، والسانس الهندسيّ فيها يبدو غريبًا عنها.
    if (b.hasSeasonBadge) return 1;
    // وما عداه ⇒ كوفيّ وحديث: أوسع الأزواج صلاحيةً.
    return 0;
  }

  static int _seedOf(DesignBrief b) {
    var h = 0x811C9DC5;
    void mix(String s) {
      h = _fnv(s, h);
      h ^= 0x5F;
    }

    mix(b.headline);
    mix(b.subhead ?? '');
    mix(b.format.name);
    return h;
  }

  /// FNV-1a على وحدات الترميز — حسابٌ معرَّف بالكامل يعطي الرقم نفسه
  /// على كل منصّة، بخلاف `String.hashCode`.
  static int _fnv(String s, [int seed = 0x811C9DC5]) {
    var h = seed;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0x7FFFFFFF;
    }
    return h;
  }
}

/// شبكة تخطيط كسريّة — الأداة التي تجعل الحواف تصطفّ من تلقائها.
///
/// كل عنصر يبدأ عند عمود وينتهي عند عمود، فلا يقع بينهما شيء بالصدفة.
/// وهذا وحده أكثر ما يُميّز تصميمًا مصمَّمًا من عناصر وُضعت بالتقدير.
class _Grid {
  const _Grid({required this.margin});

  final double margin;

  double get top => margin;
  double get bottom => 1 - margin;
  double get height => 1 - margin * 2;
  double get usable => 1 - margin * 2;

  double x(int col) => margin + col * (usable / LocalDesigner.cols);
  double w(int span) => span * (usable / LocalDesigner.cols);

  SpecRect rect({
    required int col,
    required int span,
    required double y,
    required double h,
  }) {
    final top = y.clamp(margin, 1 - margin - 0.02);
    final height = h.clamp(0.02, 1 - margin - top);
    return SpecRect(x(col), top, w(span), height);
  }
}

/// كتلة في عمود: وزنها ودالّة بنائها.
///
/// الوزن نسبيّ لا مطلق — وهذا هو الفرق كلّه: كتلةٌ وزنها ٣٫٤ تأخذ من
/// اللوحة الطويلة أكثر مما تأخذ من الكرت، وكلتاهما تصحّ.
class _Block {
  const _Block({required this.weight, required this.build});

  final double weight;
  final DesignElement Function(_Grid g, double y, double h) build;
}
