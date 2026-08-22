import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/ad_badge.dart';
import '../../models/ad_brief.dart';
import '../../models/ad_format.dart';
import '../../models/seasonal_theme.dart';
import '../../models/ad_template.dart';
import '../../models/design_spec.dart';
import '../../models/generated_ad.dart';
import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';
import '../../models/generation.dart';
import '../../services/ad_generator.dart';
import '../../services/ai_gateway.dart';
import '../../services/design_wish_service.dart';
import '../../services/local_designer.dart';
import '../../services/spec_doctor.dart';
import '../../services/wish_parser.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/art_mood.dart';
import '../../widgets/ad_design_preview.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/print_cost_calculator.dart';
import '../../widgets/section_header.dart';
import 'execute_screen.dart';

class MagicScreen extends StatefulWidget {
  const MagicScreen({
    super.key,
    required this.brief,
    this.initialTemplate,
    this.gateway,
  });

  final AdBrief brief;

  /// يُمرَّر في الاختبارات ببوابة وهمية بلا شبكة.
  final AiGateway? gateway;

  /// الاختبارات تصل إلى هذه الشاشة بالتنقّل من شاشة التفاصيل لا ببنائها
  /// مباشرة، فلا سبيل لتمرير [gateway] عبر المُنشئ هناك. هذا المنفذ
  /// يغطّي تلك الحالة — على نمط debugPickImageOverride في شاشة التفاصيل.
  static AiGateway Function()? debugGatewayOverride;

  /// القالب القادم من معرض القوالب (إن وُجد).
  final AdTemplate? initialTemplate;

  /// منفذ اختباري لخدمة الأمنيات — على نمط [debugGatewayOverride].
  static DesignWishService Function()? debugWishServiceOverride;

  @override
  State<MagicScreen> createState() => _MagicScreenState();
}

class _MagicScreenState extends State<MagicScreen> {
  late final AiGateway _gateway =
      widget.gateway ??
      MagicScreen.debugGatewayOverride?.call() ??
      AiGateway(baseUrl: AppConfig.orchestratorUrl);

  late final DesignWishService _wishes =
      MagicScreen.debugWishServiceOverride?.call() ?? DesignWishService();

  List<GeneratedAd>? _ads;
  GatewayException? _error;
  int _stage = 0;
  int _selectedCard = 0;

  /// البطاقات التي يجري توليد مشهدها السحابي الآن — بهويّتها لا بفهرسها.
  final Set<GeneratedAd> _sceneLoading = {};

  /// نصّ الأمنية وحالتها.
  final TextEditingController _wishText = TextEditingController();
  late AdFormat _wishFormat = adFormatFromLabel(widget.brief.format);
  bool _wishBusy = false;

  /// هل الأمنية القادمة **تعديل** على التصميم المعروض أم تصميم جديد؟
  ///
  /// افتراضها مطفأة: التاجر الذي يكتب أوّل أمنية يريد إعلانًا لا تعديلًا،
  /// وتشغيلُها من تلقائها يجعل أوّل طلبٍ يعدّل بطاقةً لم ينظر إليها.
  bool _refine = false;

  /// كم بطاقةً محلّية في مقدّمة القائمة الآن — تُستبدل حين تصل السحابة.
  int _localCount = 0;

  /// المرشّحون المحسوبون سلفًا — ذخيرة زرّ «تكوين آخر».
  List<LocalDesign> _variants = const [];
  int _variantAt = 0;

  /// ملاحظات الطبيب على آخر تخطيط مولَّد. تُعرض للتاجر لا تُبتلع: تصميمٌ
  /// أُصلح خلسةً يجعل التاجر يظنّ الذكاء معصومًا، فإذا أخطأ يومًا لم يعرف
  /// أن عليه أن ينظر.
  List<String> _wishNotes = const [];

  /// ما فهمه القارئ المحلّي من آخر أمنية — يُعرض للتاجر لا يبقى خفيًّا.
  WishIntent? _reading;

  /// هل الشاشة تنتظر أمنيةً بدل أن تولّد قوالب من تلقائها؟
  ///
  /// كانت [initState] تنادي [_generate] دائمًا، فيُستقبَل **كلّ** داخلٍ
  /// بثلاث بطاقات قوالب لم يطلبها. ومن جاء بلا صورة جاء ليصف تصميمه
  /// بالكلام، فيرى شاشةً امتلأت بافتراضاتنا ويظنّ أن هذا كلّ ما تفعله —
  /// وصندوقُ «اكتب ما تريد» شريطٌ أسفلها تحت شريط البطاقات، يسهل ألّا
  /// يُرى أصلًا. فالانطباع «قوالب فقط» لم يكن سوء فهم: هو ما تقوله
  /// الشاشة بأوّل نظرة.
  bool _awaitingWish = false;

  @override
  void initState() {
    super.initState();
    // بصورةٍ: القوالب مفيدة فورًا — لها ما تضع فيه الصورة.
    // بلا صورة: لا نملأ الشاشة، بل ندعوه إلى الصندوق ونشرح ما يكتب.
    if (widget.brief.hasProductImage) {
      _generate();
    } else {
      _awaitingWish = true;
    }
  }

  @override
  void dispose() {
    if (widget.gateway == null && MagicScreen.debugGatewayOverride == null) {
      _gateway.dispose();
    }
    if (MagicScreen.debugWishServiceOverride == null) _wishes.dispose();
    _wishText.dispose();
    _pages.dispose();
    super.dispose();
  }

  /// المتحكّم يعيش مع الحالة لا مع كل بناء: إنشاؤه داخل `build` كان يُعيد
  /// العرض إلى البطاقة الأولى مع كل `setState`.
  final PageController _pages = PageController(viewportFraction: 0.88);

  /// النص والصورة يأتيان من المنسّق الخلفي وحده — المفاتيح لا تسكن
  /// التطبيق. شريط المراحل يعمل بالتوازي مع الطلب الحقيقي لا قبله،
  /// فلا نضيف تأخيراً مصطنعاً فوق زمن الشبكة.
  Future<void> _generate() async {
    setState(() {
      _ads = null;
      _error = null;
      // توليدٌ حقيقيّ بدأ، فشريط المراحل هو ما يُعرض لا الدعوة — وإلّا
      // رأى من ضغط «أعد التوليد» صفحةَ دعوةٍ ساكنة بينما الطلب يجري.
      _awaitingWish = false;
      _stage = 0;
      _selectedCard = 0;
      _localCount = 0;
      _variants = const [];
      _variantAt = 0;
    });

    final request = _gateway.generatePreview(widget.brief);
    final ticker = _runStages();

    try {
      final result = await request;
      await ticker;
      if (!mounted) return;
      setState(() {
        _ads = _toAds(result);
        _selectedCard = result.bestIndex.clamp(0, result.variants.length - 1);
      });
    } on GatewayException catch (e) {
      await ticker;
      if (!mounted) return;
      setState(() => _error = e);
    } catch (e) {
      // كل ما سوى GatewayException كان يفلت غير ملتقَط، فلا يعمل setState
      // وتبقى الشاشة على حالة التحميل أبدًا بلا رسالة — عطل صامت لا يملك
      // المستخدم منه إلا إغلاق التطبيق. خطأ معروض أهون من انتظار بلا نهاية.
      await ticker;
      if (!mounted) return;
      setState(
        () => _error = GatewayException(L.of(context).magicFailed),
      );
    }
  }

  Future<void> _runStages() async {
    for (var i = 0; i < AdGenerator.generationStages.length; i++) {
      await Future<void>.delayed(AdGenerator.stageDuration);
      if (!mounted) return;
      setState(() => _stage = i + 1);
    }
  }

  /// تحويل صيغ المنسّق إلى نموذج الإعلان الذي تعرفه بقية الشاشات.
  ///
  /// الصورة المولَّدة تُحقن في الموجز لتصير خلفية التصميم، والنص العربي
  /// يُركَّب فوقها طبقةً في التطبيق — لأن نماذج الصور تُشوّه الحروف
  /// العربية، فلا نطلب منها رسم أي حرف.
  List<GeneratedAd> _toAds(PreviewResult result) {
    final brief = result.backgroundImage != null
        ? widget.brief.copyWith(imageBytes: result.backgroundImage)
        : widget.brief;
    final now = DateTime.now();
    return [
      for (final v in result.variants)
        GeneratedAd(
          brief: brief,
          // معاينة التصميم تُبنى على أي صورة متاحة: خلفية المنسّق إن وُجدت،
          // وإلا صورة المنتج التي رفعها التاجر. ربطها بخلفية الذكاء
          // الاصطناعي وحدها كان يُخفي التصميم كلياً مع عقل نصّي.
          kind: brief.hasProductImage ? AdKind.image : AdKind.copy,
          headline: v.headline,
          body: v.body,
          hashtags: v.hashtags,
          cta: v.cta.isEmpty ? 'اطلب الآن' : v.cta,
          angle: v.angle.isEmpty ? null : v.angle,
          imageUrl: v.imageUrl,
          imageVerified: v.imageVerified,
          // الوكيل الناقد في Supabase يمنح درجة من 10؛ الشارة تعرض من 100.
          score: v.score == null ? null : (v.score! * 10).round().clamp(0, 100),
          createdAt: now,
        ),
    ];
  }

  /// إعادة التوليد تمسح كل شيء — فتُستأذن حين يكون هناك ما يُمسَح.
  ///
  /// `_generate` يُسند `_ads` من جديد، فيمحو التصاميم التي صنعها التاجر
  /// بأمنيته. وأيقونةُ تحديثٍ في شريط العنوان تُضغط بالخطأ كثيرًا، ولا
  /// سبيل بعدها لاسترجاع تكوينٍ كتبه وعدّله.
  Future<void> _regenerate() async {
    final hasOwn = (_ads ?? const []).any((a) => a.spec != null);
    if (!hasOwn) {
      await _generate();
      return;
    }

    final l = L.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.magicRegenerateConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.magicRegenerate),
          ),
        ],
      ),
    );
    if (go == true && mounted) await _generate();
  }

  /// توليد مشهد سحابي للصيغة المختارة وحدها — نداء واحد عند الضرورة،
  /// وفشله لا يمس البطاقة: القالب المحلي يبقى معروضًا كما هو.
  ///
  /// والكتابة عند العودة **بهوية البطاقة** لا بفهرسها: الأمنية تُدرج
  /// بطاقاتها في المقدّمة، فالفهرس الذي بدأ عليه الطلب قد يشير عند
  /// عودته إلى إعلان آخر — فيُلصق مشهدُ منتجٍ على إعلان منتجٍ غيره.
  Future<void> _generateScene(GeneratedAd ad) async {
    if (_sceneLoading.contains(ad)) return;
    setState(() => _sceneLoading.add(ad));
    try {
      final scene = await _gateway.generateScene(
        widget.brief,
        headline: ad.headline,
        body: ad.body,
        cta: ad.cta,
      );
      if (!mounted) return;
      setState(() {
        final at = _ads?.indexOf(ad) ?? -1;
        if (at >= 0) {
          _ads![at] = ad.copyWith(
            imageUrl: scene.url,
            imageVerified: scene.verified,
          );
        }
        _sceneLoading.remove(ad);
      });
    } on GatewayException catch (e) {
      if (!mounted) return;
      setState(() => _sceneLoading.remove(ad));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sceneLoading.remove(ad));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).magicSceneFailed)),
      );
    }
  }

  /// المزاج اللونيّ المختار كفهرس، أو `null` أي «اشتقّ من لون العلامة».
  ///
  /// والترجمة من معرّف إلى فهرس تقع هنا لا في الحالة: الحالة تحفظ
  /// المعرّف لأنه يصمد أمام إعادة ترتيب القائمة، والمواصفة تحمل الفهرس
  /// لأن النموذج يتكلّم بالأرقام. راجع `ArtMood`.
  int? _mood(AppState state) => state.designMoodId == null
      ? null
      : ArtMood.indexOfId(state.designMoodId);

  /// المواصفة المعروضة الآن — أساسُ التعديل حين يطلبه التاجر.
  DesignSpec? get _shownSpec {
    final ads = _ads;
    if (ads == null || _selectedCard < 0 || _selectedCard >= ads.length) {
      return null;
    }
    return ads[_selectedCard].spec;
  }

  /// ينفّذ ما كتبه التاجر: النموذج يُخرج **تخطيطًا** لا نصًّا، والطبيب
  /// يفحصه، والعارض يرسمه. هذه هي النقلة من «املأ الحقول» إلى «قل ما
  /// تريد» — وهي التي كانت تفصلنا عن كانفا.
  Future<void> _runWish() async {
    final text = _wishText.text.trim();
    if (text.isEmpty || _wishBusy) return;
    FocusScope.of(context).unfocus();

    final state = AppStateScope.of(context);
    final brandArgb =
        state.brandColorValue ??
        widget.brief.brandColor ??
        widget.brief.paletteColor ??
        0xFF2C6BED;

    // الأساس يُلتقط قبل النداء: البطاقة المعروضة قد تتغيّر تحت الطلب،
    // وتعديلُ تخطيطٍ غير الذي رآه التاجر أسوأ من رفض الطلب.
    final base = _refine ? _shownSpec : null;

    // القراءة تُعرض للتاجر لا تبقى في رأس البرنامج.
    //
    // كان القارئ يستخرج نوع العرض والنسبة والموضوع ثم يبني عليها بصمت،
    // فإن أخطأ — قرأ «مطعم» موضوعًا وهو اسم الحيّ — خرج إعلانٌ غريب بلا
    // سبب ظاهر، ولا يملك التاجر إلا أن يعيد الطلب بالكلمات نفسها.
    // فإظهار ما فُهم يحوّل عطلًا صامتًا إلى شيء يُصحَّح بإعادة صياغة.
    //
    // وفي وضع التنقيح لا قراءة: النصّ حينها أمرُ تعديل («كبّر العنوان»)
    // لا وصفُ عرض، وعرضُه «فهمتُ: إعلان عام» هراءٌ واثق.
    final intent = base == null ? WishParser.parse(text) : null;

    setState(() {
      _wishBusy = true;
      _wishNotes = const [];
      _reading = intent;
      // والصيغة التي قرأها القارئ تصير الصيغة المختارة: كان يُخرج
      // ستوري لمن كتب «ستوري» بينما تبقى الرقاقة على «مربّع» — فيرى
      // التاجر واجهةً تقول غير ما فعلت.
      if (intent?.format != null) _wishFormat = intent!.format!;
    });

    // ١) الجهاز أوّلًا — قبل الشبكة لا بعد فشلها.
    //
    // القارئ المحلّي يفهم «خصم ٣٠٪ لمقهى مختص» في أجزاء من الثانية،
    // والمصمّح المحلّي يُركّب تكوينًا مقيسًا. فيرى التاجر تصميمه **فورًا**
    // بدل ثماني ثوانٍ من دوّارة انتظار — ولو انقطعت الشبكة أو نفدت
    // الحصّة بقي في يده تصميم لا رسالة عطل.
    //
    // وهذا ليس احتياطًا: هو المخرَج الأساسي، والسحابة تُحسّنه.
    final localMade = intent == null
        ? const <GeneratedAd>[]
        : _composeLocally(intent, brandArgb);
    if (localMade.isNotEmpty && mounted) {
      setState(() {
        _error = null;
        _ads = [...localMade, ...?_ads];
        _selectedCard = 0;
        _localCount = localMade.length;
      });
      if (_pages.hasClients) _pages.jumpToPage(0);
    }

    // كاتب النصّ يجري **بموازاة** المصمّم لا قبله.
    //
    // نصّ الأمنية كان يكتبه نموذج **التخطيط** وهو منشغل بالإحداثيات —
    // كاتبٌ بالعَرَض لا بالقصد. وكاتب النصّ الحقيقيّ (`ad-magic` بسلسلة
    // كاتب ← ناقد) موصولٌ منذ زمن لكن لمسار القوالب وحده، فبطاقاتُ
    // القوالب تحمل نصًّا مكتوبًا ومُقيَّمًا وبطاقاتُ الأمنية لا.
    //
    // والتوازي لا التتابع: نداءٌ قبل نداء يضيف زمنه كاملًا إلى انتظار
    // التاجر، وهذان لا يحتاج أحدهما مخرَج الآخر — المصمّم يضع
    // المستطيلات والكاتب يملؤها. فإن تأخّر الكاتب أو سقط بقي التخطيط
    // كما هو بنصّ النموذج، ولم يخسر التاجر إلّا التحسين.
    // وفي وضع التنقيح لا يُنادى: من كتب «كبّر العنوان» طلب تعديل تكوين
    // لا كلماتٍ جديدة، وإعادةُ كتابتها تحته تُضيّع ما رضي عنه.
    final copy = base != null ? null : _writeCopy(text);

    try {
      final result = await _wishes.design(
        DesignWish(
          text: text,
          // الصيغة تأتي من الأساس حين نعدّله: تغييرُ اللوحة تحت تعديلٍ
          // طُلب على غيرها يُخرج تكوينًا لا يشبه ما رآه.
          format: base?.format ?? _wishFormat,
          product: widget.brief.productName,
          brandName: widget.brief.brandName,
          tone: widget.brief.tone,
          hasImage: widget.brief.hasProductImage,
          base: base,
          // والمزاج من الأساس حين نعدّله، للسبب نفسه الذي جعل الصيغة
          // منه: من طلب «كبّر العنوان» لم يطلب تبديل ألوان لوحته.
          mood: base?.mood ?? _mood(state),
        ),
        brandColor: Color(brandArgb),
        hasLogo: state.brandLogoBytes != null,
      );
      if (!mounted) return;

      final written = await copy;
      if (!mounted) return;

      // لكل تخطيطٍ صيغتُه: الاثنان مرتّبان بالأفضل أوّلًا (التخطيطات
      // بدرجة الناقد، والصيغ بدرجة ناقد النصّ)، فتقابُلهما بالفهرس يعطي
      // بطاقاتٍ تختلف **تكوينًا ونصًّا** معًا. ولو أخذت كلُّها الصيغة
      // الأولى لرأى التاجر ثلاث بطاقات بالكلمات نفسها.
      final made = [
        for (var i = 0; i < result.designs.length; i++)
          _adFromDesign(result.designs[i], copy: _copyAt(written, i)),
      ];
      setState(() {
        _wishBusy = false;
        // تخطيطات السحابة تحلّ محلّ المحلّية لا تُضاف إليها: التاجر طلب
        // تصميمًا واحدًا، وستّ بطاقات لطلب واحد إرباك لا خيار.
        if (_localCount > 0 && _ads != null) {
          _ads = _ads!.sublist(_localCount.clamp(0, _ads!.length));
          _localCount = 0;
        }
        // تتقدّم على بطاقات القوالب: هي ما طلبه التاجر بنصّه، وتلك
        // افتراضاتنا حين لم يطلب.
        _ads = [...made, ...?_ads];
        _selectedCard = 0;
        // النصّ يُفرَّغ بعد التنفيذ: صندوقٌ يبقى ممتلئًا يجعل الضغطة
        // التالية تُعيد الطلب نفسه بلا أن ينتبه.
        _wishText.clear();
        _wishNotes = [
          for (final i in result.designs.first.report.issues) i.toString(),
        ];
      });
      if (_pages.hasClients) _pages.jumpToPage(0);
    } on DesignWishException catch (e) {
      if (!mounted) return;
      setState(() {
        _wishBusy = false;
        _wishText.clear();
      });
      // التصميم المحلّي في يده فعلًا: نُخبره أن السحابة تعذّرت ولا
      // نُوهمه أن شيئًا لم يحدث — ولا نُرعبه برسالة عطل فوق تصميم قائم.
      _say(localMade.isEmpty ? e.message : L.of(context).wishLocalOnly);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _wishBusy = false;
        _wishText.clear();
      });
      _say(
        localMade.isEmpty
            ? L.of(context).wishFailed
            : L.of(context).wishLocalOnly,
      );
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// زينة التاجر كما تدخل المواصفة.
  ///
  /// الموسم والشارة الترويجية والزخرفة كانت تُرسم في مسار القوالب وحده،
  /// فكان التركيب المحلّي محجوبًا عمّن اختار أيًّا منها: إسقاطُ اختيارٍ
  /// صريح بصمت أسوأ من ألّا نعرض التكوين. وصارت الثلاثة **عناصر في
  /// المواصفة** يقيسها الطبيب والناقد كبقيّة العناصر، فلا حجب ولا حقن.
  String? get _seasonBadge {
    final s = widget.brief.season;
    return s == null ? null : '${s.emoji} ${s.label}';
  }

  Color? get _seasonColor {
    final s = widget.brief.season;
    return s == null ? null : Color(s.colorValue);
  }

  /// يُركّب تخطيطات على الجهاز من نصّ إعلانٍ جاهز — **عند الطلب**.
  ///
  /// التركيب يبقى بزرّ لا افتراضًا عند فتح الشاشة: التاجر اختار قالبًا
  /// ونبرةً في شاشة التفاصيل، واستبدالُ تكوينٍ آخر به قبل أن يطلبه
  /// يفاجئه بما لم يختره.
  List<GeneratedAd> _composeFromAd(GeneratedAd? ad) {
    if (ad == null) return const [];
    try {
      final state = AppStateScope.of(context);
      final brandArgb =
          state.brandColorValue ??
          widget.brief.brandColor ??
          widget.brief.paletteColor ??
          0xFF2C6BED;

      final designs = LocalDesigner.compose(
        DesignBrief(
          headline: ad.headline,
          subhead: ad.body,
          cta: ad.cta,
          format: adFormatFromLabel(widget.brief.format),
          badge: widget.brief.badge?.label,
          seasonBadge: _seasonBadge,
          ornament: widget.brief.useDecorativeBackground,
          hasImage: widget.brief.hasProductImage,
          hasLogo: state.brandLogoBytes != null,
        ),
        brandColor: Color(brandArgb),
        seasonColor: _seasonColor,
        taste: state.designTaste,
        count: 8,
        mood: _mood(state),
      );
      if (designs.isEmpty) return const [];
      _variants = designs;
      _variantAt = 0;
      return [
        for (final d in designs.take(2))
          _adFromSpec(d.spec, score: d.score.total),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// يستبدل البطاقة المعروضة بالتكوين التالي في الترتيب.
  ///
  /// بلا شبكة وبلا حصّة: المرشّحون محسوبون سلفًا. وهذا ما كان يكلّف
  /// التاجر إعادةَ توليدٍ كاملة لأنه لم يعجبه موضع عنوان.
  void _nextComposition() {
    final ads = _ads;
    if (ads == null || _selectedCard >= ads.length) return;

    // أوّل ضغطة تُركّب، وما بعدها يتنقّل بين المحسوبين سلفًا.
    if (_variants.isEmpty) {
      final made = _composeFromAd(ads[_selectedCard]);
      if (made.isEmpty || _variants.isEmpty) return;
      setState(() {
        final list = [...ads];
        list[_selectedCard] = made.first;
        _ads = list;
      });
      return;
    }

    final v = _variants;
    if (v.length < 2) return;
    _variantAt = (_variantAt + 1) % v.length;
    // ودرجته معه: بطاقةٌ تحمل رقمًا ثم يختفي عند «تكوين آخر» تبدو
    // تراجعًا — والدرجة موجودة في `LocalDesign` أصلًا، إغفالها سهوٌ لا
    // اختيار.
    final next = _adFromSpec(
      v[_variantAt].spec,
      score: v[_variantAt].score.total,
    );
    setState(() {
      final list = [...ads];
      list[_selectedCard] = next;
      _ads = list;
    });
  }

  /// يُركّب تخطيطات على الجهاز من نصّ الأمنية.
  ///
  /// القارئ يستخرج نوع العرض والنسبة والصيغة والموضوع، والمصمّح يُولّد
  /// مئات المرشّحين ويقيسها ويختار أعلاها درجةً بأنماط متنوّعة.
  List<GeneratedAd> _composeLocally(WishIntent intent, int brandArgb) {
    try {
      final brief = LocalDesigner.briefFromIntent(
        intent,
        fallbackFormat: _wishFormat,
        product: widget.brief.productName,
        brandName: widget.brief.brandName,
        category: widget.brief.category,
        hasImage: widget.brief.hasProductImage,
        hasLogo: AppStateScope.of(context).brandLogoBytes != null,
        seasonBadge: _seasonBadge,
        merchantBadge: widget.brief.badge?.label,
        ornament: widget.brief.useDecorativeBackground,
        // القالب الذي اختاره التاجر يحمل سطحه: تركيبٌ يقلب الفاتح
        // داكنًا يُبطل اختيارًا صريحًا اتّخذه في الشاشة السابقة.
        preferLight: widget.initialTemplate?.isLightSurface,
      );
      final designs = LocalDesigner.compose(
        brief,
        brandColor: Color(brandArgb),
        seasonColor: _seasonColor,
        taste: AppStateScope.of(context).designTaste,
        count: 8,
        mood: _mood(AppStateScope.of(context)),
      );
      if (designs.isEmpty) return const [];
      _variants = designs;
      _variantAt = 0;
      return [
        for (final d in designs.take(3))
          _adFromSpec(d.spec, score: d.score.total),
      ];
    } catch (_) {
      // التوليد المحلّي إثراء لا شرط: عطلٌ فيه لا يمنع مسار السحابة.
      return const [];
    }
  }

  /// ينادي كاتب النصّ على وصف الأمنية. `null` عند أي تعثّر.
  ///
  /// ونصّ الأمنية يُمرَّر في `description` لا في اسم المنتج: الكاتب
  /// يدمج الاسم والوصف في موجزٍ واحد، فيصل إليه ما طلبه التاجر بلفظه
  /// («خصم ٣٠٪ لمقهى مختص») لا اسم المنتج وحده.
  Future<PreviewResult?> _writeCopy(String wish) async {
    try {
      return await _gateway.generatePreview(
        widget.brief.copyWith(description: wish),
      );
    } catch (_) {
      // بلا `_say`: التاجر لا يعنيه أن كاتبًا مساعدًا تعثّر ما دام
      // تصميمه في يده. والعطل يظهر في سجل الخادم لمن يبحث عنه.
      return null;
    }
  }

  /// الصيغة المقابلة للتخطيط رقم [i]، إن كُتبت.
  CopyVariant? _copyAt(PreviewResult? r, int i) =>
      r == null || i >= r.variants.length ? null : r.variants[i];

  /// لون العلامة كما تحسبه بقيّة الشاشة — بترتيب الأسبقية نفسه.
  Color _brandColor() => Color(
    AppStateScope.of(context).brandColorValue ??
        widget.brief.brandColor ??
        widget.brief.paletteColor ??
        0xFF2C6BED,
  );

  GeneratedAd _adFromDesign(WishDesign d, {CopyVariant? copy}) =>
      _adFromSpec(d.spec, score: d.score.total, copy: copy);

  /// يحوّل التخطيط إلى إعلان تعرفه بقية الشاشات.
  ///
  /// [score] درجة الناقد من مئة، إن قِيست. وتُعرض للتخطيطات المولَّدة كما
  /// تُعرض لنسخ القوالب: كان التاجر يرى رقم توافقٍ على ما اقترحناه نحن،
  /// ولا يرى شيئًا على ما طلبه هو — فيبدو المقيس أوثق من المطلوب لأنّ
  /// أحدهما وحده يحمل رقمًا.
  ///
  /// و[copy] صيغةُ كاتب النصّ إن كُتبت. بدونها يبقى نصّ المواصفة كما
  /// كان — وهو ما كان يحدث دائمًا: النموذج يكتبه وهو يرى مكانه، وذلك
  /// أصدق من لا شيء لكنه ليس كتابةً إعلانية. فحين يصل الكاتب **يغلب**:
  /// كلماتُه مرّت على ناقدٍ يقيسها، وكلماتُ المصمّم أثرٌ جانبيّ لعملٍ
  /// آخر.
  ///
  /// ويُكتب في **المواصفة** لا في `GeneratedAd` وحده: العارض يرسم من
  /// المواصفة، فنصٌّ يُبدَّل في الإعلان دون عناصره يجعل البطاقة تقول
  /// شيئًا والصورةَ تقول غيره.
  GeneratedAd _adFromSpec(
    DesignSpec spec, {
    double? score,
    CopyVariant? copy,
  }) {
    if (copy != null) {
      spec = spec
          .withRoleText(ElementRole.headline, copy.headline)
          .withRoleText(ElementRole.subhead, copy.body)
          .withRoleText(ElementRole.cta, copy.cta);
      if (copy.hashtags.isNotEmpty) {
        spec = spec.withRoleText(ElementRole.tags, copy.hashtags.join(' '));
      }

      // والطبيب يُعاد بعد التبديل، لا قبله وحده.
      //
      // خدمة الأمنية فحصت المواصفة بنصّ **النموذج**، ثم بدّلناه هنا
      // بنصّ الكاتب — وهو أطول عادةً لأنه كُتب ليُقنع لا ليملأ مستطيلًا.
      // فحكمُ الطبيب صار على نصٍّ غير الذي سيُرسم، وهو عين العلّة التي
      // منعناها في اللوحة اللونية: مدقّقٌ يقول إنه فحص، ورسمٌ لشيء آخر.
      //
      // ولا يكفي أن `ArtText` يُصغّر ما يفيض: التصغير يُنجّي من الفيضان
      // ولا يُنجّي من التداخل ولا من حرفٍ خرج عن الهامش الآمن.
      spec = SpecDoctor.review(spec, brandColor: _brandColor()).spec;
    }

    String? textOf(ElementRole r) {
      final t = spec.firstOf(r)?.text?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final tags = textOf(ElementRole.tags);
    return GeneratedAd(
      brief: widget.brief.copyWith(format: spec.format.label),
      kind: AdKind.image,
      headline: textOf(ElementRole.headline) ?? widget.brief.productName,
      body: textOf(ElementRole.subhead) ?? widget.brief.description,
      hashtags: tags == null
          ? const []
          : tags
                .split(RegExp(r'\s+'))
                .where((t) => t.isNotEmpty)
                .toList(growable: false),
      // نصّ الإعلان لا يتبع لغة الواجهة: التاجر قد يقرأ الإنجليزية
      // وجمهوره عربيّ. ولغة الإعلان المولَّد تُحسم في دفعتها الخاصّة.
      cta: textOf(ElementRole.cta) ?? 'اطلب الآن',
      angle: spec.note,
      // الدرجة أصلًا من مئة هنا، بخلاف مسار البوّابة الذي يعيدها من
      // عشرة فيضربها في `_toAds`. وضربُها ثانيةً كان سيُخرج ٨٤٠٪.
      score: score?.round().clamp(0, 100),
      createdAt: DateTime.now(),
      spec: spec,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ads = _ads;

    return Scaffold(
      appBar: AppBar(
        title: Text(L.of(context).magicTitle),
        actions: [
          if (ads != null)
            IconButton(
              tooltip: L.of(context).magicRegenerate,
              onPressed: _regenerate,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch ((ads, _error)) {
                (_, final GatewayException e) => _buildError(e),
                (final List<GeneratedAd> list, _) => _buildResults(list),
                _ when _awaitingWish => _buildInvite(),
                _ => _buildGenerating(),
              },
            ),
            // صندوق الأمنية ثابت في كل الحالات — حتى حين يفشل التوليد
            // الأول. من وقف أمام جدار يحتاج بابًا، لا زرَّ إعادةٍ يعيده
            // إلى الجدار نفسه.
            _WishBar(
              controller: _wishText,
              format: _wishFormat,
              busy: _wishBusy,
              notes: _wishNotes,
              reading: _reading,
              canRefine: _shownSpec != null,
              refine: _refine,
              onRefine: (v) => setState(() => _refine = v),
              onFormat: (f) => setState(() => _wishFormat = f),
              onSubmit: _runWish,
            ),
          ],
        ),
      ),
    );
  }

  /// الدعوة إلى الوصف — ما يراه من دخل بلا صورة.
  ///
  /// وفيها أمثلةٌ تُنقر لا شرحٌ يُقرأ: أكثر من يقف أمام صندوق فارغ لا
  /// يعجزه الكتابة بل لا يعرف **بأيّ لغة** يخاطب البرنامج — أيكتب كلمتين
  /// أم فقرة، أيذكر اللون أم يُترك له. ومثالٌ واحد مكتوبٌ بالكامل يجيب
  /// عن هذا كلّه في لمحة، ونقرُه يملأ الصندوق فيصير التعديل عليه أهون
  /// من الإنشاء من الصفر.
  Widget _buildInvite() {
    final l = L.of(context);
    final samples = l.magicInviteSamples.split('|');
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconCircle(
              icon: Icons.edit_note_outlined,
              background: AppColors.coral,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.magicInviteTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: context.scheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l.magicInviteBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textMuted,
                fontSize: 13.5,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            for (final s in samples)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: OutlinedButton(
                  onPressed: _wishBusy
                      ? null
                      : () {
                          _wishText.text = s;
                          _runWish();
                        },
                  child: Text(s, textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(GatewayException e) {
    final l = L.of(context);
    final quotaHit = e.isQuota;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        // بطاقة محتواة لا نصّ عائم وسط الفراغ: الخطأ يبدو حالةً يعالجها
        // التطبيق، لا انهيارًا تركه وحده في منتصف شاشة بيضاء.
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: context.hairline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconCircle(
                icon: quotaHit
                    ? Icons.hourglass_disabled_outlined
                    : Icons.cloud_off_outlined,
                background: quotaHit
                    ? context.goldOnSurface
                    : context.scheme.error,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                quotaHit ? l.magicQuotaTitle : l.magicErrorTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                e.message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.textMuted),
              ),
              if (!quotaHit) ...[
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _generate,
                    icon: const Icon(Icons.refresh, size: 20),
                    label: Text(l.magicRetry),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // مخرج ثانٍ: من فشل توليده مرتين يحتاج بابًا غير زرّ
                // يعيده إلى نفس الجدار.
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(l.magicBackAndEdit),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenerating() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const IconCircle(
            icon: Icons.auto_awesome,
            background: AppColors.coral,
            diameter: 80,
          ),
          const SizedBox(height: 28),
          Text(
            L.of(context).magicWorking,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: context.scheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // شريط تقدّم حقيقي: انتظارٌ بلا مقياس يبدو تعليقًا، وحركةُ
          // الشريط وحدها تقول «ما زال يعمل» في ثوانٍ الصمت الطويلة.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: AdGenerator.generationStages.isEmpty
                  ? null
                  : (_stage / AdGenerator.generationStages.length).clamp(
                      0.04,
                      1.0,
                    ),
              backgroundColor: context.hairline,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (var i = 0; i < AdGenerator.generationStages.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  if (i < _stage)
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.coral,
                      size: 22,
                    )
                  else if (i == _stage)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.coral,
                      ),
                    )
                  else
                    Icon(
                      Icons.circle_outlined,
                      color: context.textMuted,
                      size: 22,
                    ),
                  const SizedBox(width: 12),
                  Text(
                    AdGenerator.generationStages[i],
                    style: TextStyle(
                      color: i <= _stage
                          ? context.scheme.onSurface
                          : context.textMuted,
                      fontWeight: i == _stage
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults(List<GeneratedAd> ads) {
    final l = L.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SectionHeader(
              kicker: L.of(context).magicStepKicker,
              title: L.of(context).magicPickBest,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: PageView.builder(
            itemCount: ads.length,
            controller: _pages,
            onPageChanged: (i) => setState(() {
              _selectedCard = i;
              // بطاقةٌ بلا تخطيط لا تُعدَّل، فلا يبقى المفتاح مضاءً على
              // ما لا ينطبق عليه.
              if (_ads?[i].spec == null) _refine = false;
            }),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: _AdPreviewCard(
                ad: ads[i],
                onSave: () => _saveAd(ads[i]),
                onCopy: () => _copyAd(ads[i]),
                // المشهد السحابي عند الطلب — للصيغة التي أعجبت التاجر
                // وحدها، لا للثلاث جزافًا. و**يبقى** بعد أوّل مشهد.
                //
                // كان الشرط `imageUrl == null && hasProductImage`، وفيه
                // منعان لا مبرّر لهما:
                //
                // أوّلهما أنّ الزرّ يختفي بمجرّد أن تصير للبطاقة صورة،
                // فالمشهد طلقةٌ واحدة: خرج غريبًا أو لم يعجب فلا سبيل إلى
                // غيره إلّا إعادة التوليد من أوّله وفقدُ النصّ والتخطيط
                // معًا. والمشهد مولَّدٌ عشوائيّ بطبعه — أن يُعطى محاولةً
                // واحدة يخالف ما يتوقّعه كلّ من استعمل مولّد صور.
                //
                // وثانيهما اشتراط صورة منتج، و`ad-director` لا يشترطها:
                // `product_b64` اختياريّ فيه، فإن غاب ولّد المشهد من
                // النصّ وحده. فكان من يصف تصميمه بالكلام محرومًا من
                // الصورة لأنه لم يرفع صورة.
                onScene: () => _generateScene(ads[i]),
                sceneLoading: _sceneLoading.contains(ads[i]),
                // التكوين التالي محسوبٌ سلفًا: لا شبكة ولا حصّة، وكان
                // التاجر يدفع إعادة توليدٍ كاملة لأن موضع عنوان لم
                // يعجبه.
                onNextComposition: _nextComposition,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            ads.length,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _selectedCard ? AppColors.coral : context.cardBg,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: PrintCostCalculator(
            onProceed: (product, sizeIndex, quantity) {
              _rememberTaste(ads[_selectedCard]);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExecuteScreen(
                    ad: ads[_selectedCard],
                    isDigital: false,
                    initialTemplate: widget.initialTemplate,
                    initialProduct: product,
                    initialSizeIndex: sizeIndex,
                    initialQuantity: quantity,
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _goExecute(ads, isDigital: true),
                  child: Text(l.magicSaveAndPublish),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _goExecute(ads, isDigital: false),
                  child: Text(l.magicPrintAndDeliver),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _saveAd(GeneratedAd ad) {
    _rememberTaste(ad);
    AppStateScope.of(context).saveAd(ad);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(L.of(context).magicSavedToLibrary)));
  }

  /// يسجّل نمط التكوين الذي أبقاه التاجر — إن كان تكوينًا محلّيًّا.
  ///
  /// المطابقة بهويّة الكائن لا بمقارنة الحقول: مواصفةٌ مرّت على المحرّر
  /// صارت كائنًا آخر بمستطيلات حرّكها التاجر بيده، وعدُّها «اختيارًا
  /// لهذا النمط» يعلّم المصمّم شيئًا لم يقع. فما لم نتعرّف عليه لا
  /// نسجّله — الصمت أصدق من إشارة مخترَعة.
  void _rememberTaste(GeneratedAd ad) {
    final spec = ad.spec;
    if (spec == null) return;
    for (final v in _variants) {
      if (identical(v.spec, spec)) {
        AppStateScope.of(context).rememberComposition(v.archetype);
        return;
      }
    }
  }

  Future<void> _copyAd(GeneratedAd ad) async {
    await Clipboard.setData(ClipboardData(text: ad.shareText));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(L.of(context).magicCopied)));
  }

  void _goExecute(List<GeneratedAd> ads, {required bool isDigital}) {
    _rememberTaste(ads[_selectedCard]);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExecuteScreen(
          ad: ads[_selectedCard],
          isDigital: isDigital,
          initialTemplate: widget.initialTemplate,
        ),
      ),
    );
  }
}

/// صندوق «اكتب ما تريد» — قلب النقلة.
///
/// كل ما قبله في هذه الشاشة كان اختيارًا من قائمة أعددناها: قالبًا من
/// أحد عشر، ونبرةً من خمس. وهذا الصندوق يقلب العلاقة: التاجر يقول، ونحن
/// ننفّذ — وهو ما يفعله كانفا، والفرق أنّ ما يخرج هنا **تخطيط مفحوص**
/// بالتباين والهامش لا صورة نأمل أن تكون صحيحة.
class _WishBar extends StatelessWidget {
  const _WishBar({
    required this.controller,
    required this.format,
    required this.busy,
    required this.notes,
    required this.reading,
    required this.canRefine,
    required this.refine,
    required this.onRefine,
    required this.onFormat,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final AdFormat format;
  final bool busy;
  final List<String> notes;

  /// قراءة القارئ المحلّي لآخر أمنية. `null` يعني لا قراءة تُعرض.
  final WishIntent? reading;

  /// هل البطاقة المعروضة تخطيطٌ يقبل التعديل؟
  final bool canRefine;
  final bool refine;
  final ValueChanged<bool> onRefine;
  final ValueChanged<AdFormat> onFormat;
  final VoidCallback onSubmit;

  /// أمنيات جاهزة. أكثر التجّار لا يعرف ماذا يكتب في صندوق فارغ — وصندوقٌ
  /// فارغ أمام من لا يعرف ما يكتب جدارٌ لا باب. وهي تملأ الصندوق ولا
  /// تُرسل: من لمسها يريدها بداية يعدّلها لا أمرًا يُنفَّذ عنه.
  static List<String> _presets(L l) => [
    l.wishPresetDiscount,
    l.wishPresetOpening,
    l.wishPresetNewItem,
    l.wishPresetDelivery,
    l.wishPresetHiring,
    l.wishPresetRamadan,
  ];

  static String _offerLabel(L l, WishOffer o) => switch (o) {
    WishOffer.discount => l.wishOfferDiscount,
    WishOffer.opening => l.wishOfferOpening,
    WishOffer.newItem => l.wishOfferNewItem,
    WishOffer.hiring => l.wishOfferHiring,
    WishOffer.delivery => l.wishOfferDelivery,
    WishOffer.season => l.wishOfferSeason,
    WishOffer.general => l.wishOfferGeneral,
  };

  /// ما فُهم من الأمنية، رقاقةً رقاقة.
  ///
  /// النسبة تُعرض حين تُقرأ فقط: «خصم ١٥ ريال» ليس «خصم ١٥٪»، وعرضُ
  /// رقاقةٍ بنسبة لم تُذكر يؤكّد للتاجر خطأً يظنّه فهمًا.
  Widget _readingRow(BuildContext context, L l, WishIntent r) {
    final chips = <String>[
      _offerLabel(l, r.offer),
      if (r.discountPercent != null) l.wishReadDiscount(r.discountPercent!),
      if ((r.subject ?? '').trim().isNotEmpty) r.subject!.trim(),
      if (r.format != null) r.format!.label,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.psychology_outlined, size: 15, color: context.textMuted),
          const SizedBox(width: 5),
          Text(
            '${l.wishRead}:',
            style: TextStyle(fontSize: 11.5, color: context.textMuted),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 24,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in chips)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 5),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.hairline,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          child: Text(
                            c,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final r = reading;
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(top: BorderSide(color: context.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r != null) _readingRow(context, l, r),
          if (notes.isNotEmpty) ...[
            // ما وجده الطبيب معروضٌ لا مبتلَع: التاجر يستحق أن يعرف أن
            // العنوان أُزيح أو أن لونًا غُيّر ليُقرأ.
            for (final n in notes.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  n,
                  style: TextStyle(fontSize: 11.5, color: context.textMuted),
                ),
              ),
            const SizedBox(height: 4),
          ],
          // أمنيات جاهزة حين يكون الصندوق فارغًا وحده: بعد أن يكتب،
          // مكانُها أولى بما يكتبه.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.trim().isNotEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final p in _presets(l))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: ActionChip(
                          label: Text(p, style: const TextStyle(fontSize: 12)),
                          onPressed: busy
                              ? null
                              : () => controller.value = TextEditingValue(
                                  text: p,
                                  selection: TextSelection.collapsed(
                                    offset: p.length,
                                  ),
                                ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (canRefine)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: FilterChip(
                      avatar: const Icon(Icons.edit_outlined, size: 15),
                      label: Text(
                        l.wishRefineChip,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: refine,
                      onSelected: busy ? null : onRefine,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                // الصيغة تأتي من التصميم الذي يُعدَّل، فاختيارها هنا
                // يُخفى بدل أن يُعرض ولا يُطاع.
                if (!refine)
                  for (final f in AdFormat.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(
                        label: Text(
                          f.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: f == format,
                        onSelected: busy ? null : (_) => onFormat(f),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !busy,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: refine ? l.wishRefineHint : l.wishHint,
                    prefixIcon: const Icon(Icons.auto_awesome, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                width: 48,
                child: busy
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : IconButton.filled(
                        tooltip: L.of(context).wishRun,
                        onPressed: onSubmit,
                        icon: const Icon(Icons.arrow_upward),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdPreviewCard extends StatelessWidget {
  const _AdPreviewCard({
    required this.ad,
    required this.onSave,
    required this.onCopy,
    this.onScene,
    this.sceneLoading = false,
    this.onNextComposition,
  });

  final GeneratedAd ad;
  final VoidCallback onSave;
  final VoidCallback onCopy;

  /// طلب مشهد سحابي لهذه الصيغة (null = غير متاح: صورة موجودة أو لا منتج).
  final VoidCallback? onScene;
  final bool sceneLoading;

  /// تبديل التكوين إلى المرشّح التالي — محلّيًّا وفورًا.
  final VoidCallback? onNextComposition;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconCircle(
                  icon: ad.kind.icon,
                  background: AppColors.coral,
                  diameter: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ad.angle ?? ad.kind.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: context.scheme.onSurface,
                    ),
                  ),
                ),
                if (ad.score != null) _ScoreBadge(score: ad.score!),
              ],
            ),
            if (ad.imageUrl != null) ...[
              const SizedBox(height: 14),
              // الإعلان المولَّد صورةً كاملة من السحابة: مشهد لكل زاوية
              // وحروف عربية مرسومة ومدقَّقة. وعند تعذّر التحميل نسقط
              // لمحرك القوالب المحلي بدل مربّع مكسور.
              Center(
                child: SizedBox(
                  height: 250,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Image.network(
                        ad.imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (context, _, _) => AdDesignPreview(
                          ad: ad,
                          showWatermark: !AppStateScope.of(context).isPro,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ] else if (ad.kind == AdKind.image) ...[
              const SizedBox(height: 14),
              // معاينة التصميم الحقيقي من محرك القوالب (صورة المنتج مركّبة
              // على القالب) — وليست أيقونة رمزية.
              Center(
                child: SizedBox(
                  height: 250,
                  child: AdDesignPreview(
                    ad: ad,
                    showWatermark: !AppStateScope.of(context).isPro,
                  ),
                ),
              ),
            ],
            // زرّ المشهد **خارج** سلسلة الشرط لا داخل فرعها الثاني.
            //
            // كان يسكن فرع `ad.kind == AdKind.image` وحده، فمتى صارت
            // للبطاقة صورة انتقل العرض إلى الفرع الأوّل وسقط الزرّ من
            // الشجرة أصلًا — وهو الذي كان يجعل المشهد طلقةً واحدة، لا
            // شرطُ `imageUrl == null` في المنادي وحده. ولو أُصلح المنادي
            // دون هذا لبقي العطل كما هو والإصلاح شيفرةً ميّتة.
            //
            // وخروجُه هنا يفتحه كذلك لبطاقات النصّ الخالص: `ad-director`
            // يولّد من النصّ بلا صورة منتج، فلا سبب لحرمانها.
            if (onScene != null || sceneLoading) ...[
              const SizedBox(height: 10),
              // المشهد السحابي اختيار لا فرض: القالب المحلي جاهز فورًا
              // وبلا حصة، ومن أراد مشهدًا واقعيًا ضغط — فيُصرف المفتاح
              // على ما سيُنشر فعلًا.
              Center(
                child: sceneLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: onScene,
                        // التسمية تتبع الحال: «مشهد واقعي» دعوةٌ لمن لا
                        // مشهد لديه، وهي كذبٌ صغير لمن عنده واحد — يقرؤها
                        // فيظنّ الزرّ يفعل شيئًا آخر غير الإعادة.
                        icon: Icon(
                          ad.imageUrl == null
                              ? Icons.auto_awesome
                              : Icons.refresh,
                          size: 18,
                        ),
                        label: Text(
                          ad.imageUrl == null
                              ? L.of(context).magicRealScene
                              : L.of(context).magicAnotherScene,
                        ),
                      ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              ad.headline,
              style: const TextStyle(
                color: AppColors.coral,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ad.body,
              style: TextStyle(color: context.textMuted, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ad.hashtags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.scheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: context.scheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: Text(L.of(context).magicCopyText),
                ),
                TextButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: Text(L.of(context).magicSave),
                ),
                if (onNextComposition != null)
                  TextButton.icon(
                    onPressed: onNextComposition,
                    icon: const Icon(Icons.auto_mode, size: 18),
                    label: Text(L.of(context).magicNextComposition),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 14, color: Color(0xFF8A6D00)),
          const SizedBox(width: 2),
          Text(
            L.of(context).magicMatchScore(score),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8A6D00),
            ),
          ),
        ],
      ),
    );
  }
}
