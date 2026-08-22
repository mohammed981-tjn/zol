import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/ad_template.dart';
import '../../models/brand_font.dart';
import '../../models/design_spec.dart';
import '../../models/generated_ad.dart';
import '../../services/spec_doctor.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ad_design_preview.dart';
import '../../widgets/spec_canvas_editor.dart';

/// محرر التصميم — التاجر يملك تصميمه لا يستلمه جاهزًا فقط.
///
/// أكبر فجوة كانت بيننا وبين أدوات التصميم الكبرى: القالب نهائي لا
/// يُمَسّ. هنا يسحب التاجر منتجه ويكبّره بإصبعيه، ويصحّح كلمة في
/// العنوان بلا إعادة توليد — فلا يدفع حصة توليد ثمنًا لحرف واحد.
///
/// التعديلات كسور لا بكسلات، فتنجو من فرق المقاس بين المعاينة والتصدير،
/// وتُحفظ في الموجز فتعود مع الإعلان من المكتبة كما تركها.
///
/// وللشاشة مساران لأن للتصميم مسارين: قالبٌ من الأحد عشر يُحرَّك فيه
/// المنتج ويُصحَّح نصّه، وتخطيطٌ ركّبه الذكاء تُمسك فيه **عناصره** واحدًا
/// واحدًا. وقبل ذلك كان تحرير النصّ يكتب في `ad.headline` بينما التخطيط
/// المولَّد يرسم من `spec.elements[].text` — فيضغط التاجر «تطبيق» ولا
/// يتغيّر شيء أمامه.
class DesignEditorScreen extends StatefulWidget {
  const DesignEditorScreen({
    super.key,
    required this.ad,
    required this.template,
  });

  final GeneratedAd ad;
  final AdTemplate template;

  @override
  State<DesignEditorScreen> createState() => _DesignEditorScreenState();
}

class _DesignEditorScreenState extends State<DesignEditorScreen> {
  late GeneratedAd _ad = widget.ad;

  /// حدود التكبير: أقل من النصف يضيع المنتج، وأكثر من ثلاثة أضعاف
  /// يخرج عن إطاره فيبدو مقصوصًا عشوائيًا.
  static const _minScale = 0.5;
  static const _maxScale = 3.0;

  double _baseScale = 1;
  Size _canvas = Size.zero;

  final _canvasKey = GlobalKey<SpecCanvasEditorState>();

  /// ملاحظات الطبيب بعد آخر تعديل. تُعرض ولا تُبتلع: من أزاح عنوانه فوق
  /// عنوان يستحق أن يعرف أن التطبيق أنزله، لا أن يفاجئه المطبوع.
  List<String> _notes = const [];

  /// العنصر المحدّد في اللوحة، مرفوعًا إلى هنا لا مقروءًا من المفتاح:
  /// الأب هو من يقرّر أي زرّ يعرض، ولا يُعاد بناؤه حين تتغيّر حالة ابنه.
  DesignElement? _selected;

  bool get _selectedIsText => _selected?.isText ?? false;

  bool get _isSpec => _ad.spec != null;
  bool get _canMoveProduct => _ad.brief.hasProductImage;

  void _onScaleStart(ScaleStartDetails _) {
    _baseScale = _ad.brief.productScale;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (!_canMoveProduct || _canvas.isEmpty) return;
    setState(() {
      _ad = _ad.copyWith(
        brief: _ad.brief.copyWith(
          productScale: (_baseScale * d.scale).clamp(_minScale, _maxScale),
          // الإزاحة نسبة من اللوحة: إصبع يقطع ربع العرض يزيح المنتج
          // ربعًا مهما كان مقاس الشاشة أو دقة التصدير.
          productDx:
              (_ad.brief.productDx + d.focalPointDelta.dx / _canvas.width)
                  .clamp(-0.5, 0.5),
          productDy:
              (_ad.brief.productDy + d.focalPointDelta.dy / _canvas.height)
                  .clamp(-0.5, 0.5),
        ),
      );
    });
  }

  void _reset() {
    setState(() {
      _ad = _ad.copyWith(
        brief: _ad.brief.copyWith(productScale: 1, productDx: 0, productDy: 0),
      );
    });
  }

  /// يُرجع التخطيط إلى ما وُلِّد عليه. مخرجٌ لازم: محرّرٌ بلا تراجع يجعل
  /// التاجر يخاف أن يجرّب، فلا يحرّك شيئًا أصلًا.
  void _resetLayout() {
    final original = widget.ad.spec;
    if (original == null) return;
    setState(() {
      _ad = _ad.copyWith(spec: original);
      _notes = const [];
    });
    _canvasKey.currentState?.select(null);
    setState(() => _selected = null);
  }

  /// كل تعديل على التخطيط يمرّ بالطبيب قبل أن يستقرّ.
  ///
  /// وهذا هو الفرق بين محرّر ومحرّر يبيع طباعة: إصبعٌ يسحب عنوانًا نصف
  /// سنتيمتر خارج الهامش لا يشعر بشيء، وسكّينُ المطبعة تشعر.
  void _applySpec(DesignSpec next) {
    final state = AppStateScope.of(context);
    final report = SpecDoctor.review(
      next,
      brandColor: Color(
        state.brandColorValue ?? _ad.brief.brandColor ?? 0xFF2C6BED,
      ),
      hasLogo: state.brandLogoBytes != null,
    );

    // النصّ المرسوم هو المصدر: ما يراه المشاهد في الإعلان يجب أن يكون
    // هو ما يُنسخ ويُشارك ويُحفظ. تركُهما مفترقين يجعل التاجر ينشر نصًّا
    // غير الذي في صورته.
    final spec = report.spec;
    setState(() {
      _ad = _ad.copyWith(
        spec: spec,
        headline: spec.firstOf(ElementRole.headline)?.text,
        body: spec.firstOf(ElementRole.subhead)?.text,
        cta: spec.firstOf(ElementRole.cta)?.text,
      );
      _notes = [for (final i in report.issues) i.toString()];
    });
  }

  /// متحكّمات النص تعيش مع الشاشة لا مع الورقة: إتلافها فور إغلاق
  /// الورقة يصادم رسمَها وهي ما تزال تنزلق خارج الشاشة، فينهار التطبيق
  /// بـ«controller used after being disposed» في وجه التاجر.
  late final _headlineCtl = TextEditingController();
  late final _bodyCtl = TextEditingController();
  late final _ctaCtl = TextEditingController();
  late final _elementCtl = TextEditingController();

  @override
  void dispose() {
    _headlineCtl.dispose();
    _bodyCtl.dispose();
    _ctaCtl.dispose();
    _elementCtl.dispose();
    super.dispose();
  }

  /// تحرير نصّ العنصر المحدّد وحده — الطريق القصير حين يُزعجه حرف واحد.
  Future<void> _editSelectedElement() async {
    final canvas = _canvasKey.currentState;
    final element = canvas?.selectedElement;
    if (canvas == null || element == null || !element.isText) return;

    _elementCtl.text = element.text ?? '';
    final l = L.of(context);
    final saved = await _sheet(
      title: l.editorEditElement,
      children: [
        TextField(
          controller: _elementCtl,
          decoration: InputDecoration(labelText: l.editorElementText),
          maxLines: 3,
          autofocus: true,
        ),
      ],
    );

    if (saved != true || !mounted) return;
    final text = _elementCtl.text.trim();
    if (text.isEmpty) return;
    canvas.setSelectedText(text);
  }

  Future<void> _editText() async {
    _headlineCtl.text = _ad.headline;
    _bodyCtl.text = _ad.body;
    _ctaCtl.text = _ad.cta;
    final l = L.of(context);

    final saved = await _sheet(
      title: l.editorEditText,
      children: [
        TextField(
          controller: _headlineCtl,
          decoration: InputDecoration(labelText: l.editorFieldHeadline),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bodyCtl,
          decoration: InputDecoration(labelText: l.editorFieldBody),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ctaCtl,
          decoration: InputDecoration(labelText: l.editorFieldCta),
        ),
      ],
    );

    if (saved != true || !mounted) return;

    // نص فارغ يترك التصميم أعرج، فالفارغ يعني «أبقِ ما كان».
    final h = _headlineCtl.text.trim();
    final b = _bodyCtl.text.trim();
    final c = _ctaCtl.text.trim();

    final spec = _ad.spec;
    if (spec != null) {
      // على مسار التخطيط المولَّد يُكتب النصّ في **عناصر المواصفة**: هي
      // ما يُرسم. الكتابة في حقول الإعلان وحدها كانت تجعل «تطبيق» لا
      // تفعل شيئًا مرئيًّا.
      var next = spec;
      if (h.isNotEmpty) next = next.withRoleText(ElementRole.headline, h);
      if (b.isNotEmpty) next = next.withRoleText(ElementRole.subhead, b);
      if (c.isNotEmpty) next = next.withRoleText(ElementRole.cta, c);
      _applySpec(next);
      return;
    }

    setState(() {
      _ad = _ad.copyWith(
        headline: h.isEmpty ? null : h,
        body: b.isEmpty ? null : b,
        cta: c.isEmpty ? null : c,
      );
    });
  }

  Future<bool?> _sheet({
    required String title,
    required List<Widget> children,
  }) {
    final l = L.of(context);
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        // تمرير لا عمود صلب: لوح المفاتيح المرفوع على شاشة صغيرة كان
        // يفيض بالمحتوى خارج الورقة فتختفي أزرارها تحت الحافة.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: sheetContext.scheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ...children,
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: Text(l.editorApply),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final edited =
        _ad.brief.hasProductTransform ||
        _ad.headline != widget.ad.headline ||
        _ad.body != widget.ad.body ||
        _ad.cta != widget.ad.cta ||
        !identical(_ad.spec, widget.ad.spec);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.editorTitle),
        actions: [
          if (_isSpec)
            IconButton(
              tooltip: l.editorResetLayout,
              onPressed: _resetLayout,
              icon: const Icon(Icons.restart_alt),
            )
          else if (_ad.brief.hasProductTransform)
            IconButton(
              tooltip: l.editorResetProduct,
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _isSpec ? _specCanvas() : _templateCanvas(),
                ),
              ),
            ),
            if (_notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final n in _notes.take(2))
                      Text(
                        n,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _isSpec
                    ? l.editorSpecHint
                    : _canMoveProduct
                    ? l.editorProductHint
                    : l.editorNoProductHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textMuted, fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSpec && _selectedIsText
                          ? _editSelectedElement
                          : _editText,
                      icon: const Icon(Icons.text_fields),
                      label: Text(
                        _isSpec && _selectedIsText
                            ? l.editorEditElement
                            : l.editorEditText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(_ad),
                      icon: const Icon(Icons.check),
                      label: Text(edited ? l.editorSaveChanges : l.editorDone),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _specCanvas() {
    final state = AppStateScope.of(context);
    return SpecCanvasEditor(
      key: _canvasKey,
      spec: _ad.spec!,
      brandColor: Color(
        state.brandColorValue ?? _ad.brief.brandColor ?? 0xFF2C6BED,
      ),
      product: _ad.brief.imageBytes,
      logo: state.brandLogoBytes,
      fontFamily: state.brandFont?.family,
      productScale: _ad.brief.productScale,
      productDx: _ad.brief.productDx,
      productDy: _ad.brief.productDy,
      onChanged: _applySpec,
      onSelected: (_, element) => setState(() => _selected = element),
    );
  }

  Widget _templateCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // اللوحة تُقاس هنا لا في المستمع: قسمة الإزاحة على صفر تجعل
        // التحويل NaN فيختفي المنتج كليًا.
        _canvas = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: AdDesignPreview(
            key: const ValueKey('editor-canvas'),
            ad: _ad,
            template: widget.template,
            showWatermark: !AppStateScope.of(context).isPro,
          ),
        );
      },
    );
  }
}
