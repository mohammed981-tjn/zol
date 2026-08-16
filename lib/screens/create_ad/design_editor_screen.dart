import 'package:flutter/material.dart';

import '../../models/ad_template.dart';
import '../../models/generated_ad.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ad_design_preview.dart';

/// محرر التصميم — التاجر يملك تصميمه لا يستلمه جاهزًا فقط.
///
/// أكبر فجوة كانت بيننا وبين أدوات التصميم الكبرى: القالب نهائي لا
/// يُمَسّ. هنا يسحب التاجر منتجه ويكبّره بإصبعيه، ويصحّح كلمة في
/// العنوان بلا إعادة توليد — فلا يدفع حصة توليد ثمنًا لحرف واحد.
///
/// التعديلات كسور لا بكسلات، فتنجو من فرق المقاس بين المعاينة والتصدير،
/// وتُحفظ في الموجز فتعود مع الإعلان من المكتبة كما تركها.
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
          productDx: (_ad.brief.productDx + d.focalPointDelta.dx / _canvas.width)
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

  /// متحكّمات النص تعيش مع الشاشة لا مع الورقة: إتلافها فور إغلاق
  /// الورقة يصادم رسمَها وهي ما تزال تنزلق خارج الشاشة، فينهار التطبيق
  /// بـ«controller used after being disposed» في وجه التاجر.
  late final _headlineCtl = TextEditingController();
  late final _bodyCtl = TextEditingController();
  late final _ctaCtl = TextEditingController();

  @override
  void dispose() {
    _headlineCtl.dispose();
    _bodyCtl.dispose();
    _ctaCtl.dispose();
    super.dispose();
  }

  Future<void> _editText() async {
    _headlineCtl.text = _ad.headline;
    _bodyCtl.text = _ad.body;
    _ctaCtl.text = _ad.cta;

    final saved = await showModalBottomSheet<bool>(
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
                'تحرير النص',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: sheetContext.scheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _headlineCtl,
                decoration: const InputDecoration(labelText: 'العنوان'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyCtl,
                decoration: const InputDecoration(labelText: 'النص الفرعي'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ctaCtl,
                decoration: const InputDecoration(labelText: 'زر الدعوة'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text('تطبيق'),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved == true && mounted) {
      // نص فارغ يترك التصميم أعرج، فالفارغ يعني «أبقِ ما كان».
      final h = _headlineCtl.text.trim();
      final b = _bodyCtl.text.trim();
      final c = _ctaCtl.text.trim();
      setState(() {
        _ad = _ad.copyWith(
          headline: h.isEmpty ? null : h,
          body: b.isEmpty ? null : b,
          cta: c.isEmpty ? null : c,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final edited =
        _ad.brief.hasProductTransform ||
        _ad.headline != widget.ad.headline ||
        _ad.body != widget.ad.body ||
        _ad.cta != widget.ad.cta;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحرير التصميم'),
        actions: [
          if (_ad.brief.hasProductTransform)
            IconButton(
              tooltip: 'إرجاع المنتج لوضعه',
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // اللوحة تُقاس هنا لا في المستمع: قسمة الإزاحة على
                      // صفر تجعل التحويل NaN فيختفي المنتج كليًا.
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
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _canMoveProduct
                    ? 'اسحب لتحريك المنتج، وباعد إصبعيك لتكبيره'
                    : 'أضف صورة منتج لتتمكن من تحريكها',
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
                      onPressed: _editText,
                      icon: const Icon(Icons.text_fields),
                      label: const Text('تحرير النص'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(_ad),
                      icon: const Icon(Icons.check),
                      label: Text(edited ? 'حفظ التعديلات' : 'تم'),
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
}
