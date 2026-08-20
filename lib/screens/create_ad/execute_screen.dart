import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import '../../models/ad_template.dart';
import '../../models/generated_ad.dart';
import '../../models/payment_result.dart';
import '../../models/ad_format.dart';
import '../../models/print_catalog.dart';
import '../../models/print_order.dart';
import '../../l10n/app_localizations.dart';
import '../../services/print_backend.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/payment_config.dart';
import '../../widgets/ad_design_preview.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/print_cost_calculator.dart';
import '../../widgets/print_mockup.dart';
import '../order_map_screen.dart';
import 'design_editor_screen.dart';
import '../payment/payment_flow.dart';
import '../pick_location_screen.dart';

class ExecuteScreen extends StatefulWidget {
  const ExecuteScreen({
    super.key,
    required this.ad,
    required this.isDigital,
    this.initialTemplate,
    this.initialProduct,
    this.initialSizeIndex,
    this.initialQuantity,
    this.backend,
  });

  /// شبكة الطباعة على الخادم. تُحقن في الاختبار بواجهة مزيَّفة بلا شبكة.
  final PrintBackend? backend;

  /// منفذ الاختبارات التي تصل هذه الشاشة بالتنقّل لا بالبناء المباشر —
  /// على نمط `debugGatewayOverride` في شاشة السحر.
  static PrintBackend Function()? debugBackendOverride;

  /// منفذ التقاط التصميم في الاختبار.
  ///
  /// `RenderRepaintBoundary.toImage` يحتاج تنفيذًا حقيقيًّا خارج حلقة
  /// `pump` (‏`runAsync`)، ولا سبيل إلى ذلك من داخل معالج ضغطةٍ يجري
  /// في الاختبار — فيعود الالتقاط فارغًا ويُلغى الطلب، فيبدو الوصل
  /// مكسورًا وهو سليم. والمنفذ يزيّف البايتات وحدها ويترك بقيّة المسار
  /// كما هو.
  static Future<Uint8List?> Function()? debugCaptureOverride;

  /// القالب القادم من معرض القوالب (إن وُجد).
  final AdTemplate? initialTemplate;

  /// اختيار مبدئي قادم من حاسبة تكلفة الطباعة (إن وُجد).
  final PrintProduct? initialProduct;
  final int? initialSizeIndex;
  final int? initialQuantity;

  final GeneratedAd ad;
  final bool isDigital;

  @override
  State<ExecuteScreen> createState() => _ExecuteScreenState();
}

class _ExecuteScreenState extends State<ExecuteScreen> {
  final GlobalKey _designKey = GlobalKey();

  /// يمنع ضغطتين متتاليتين من إنشاء طلبين — والطلب يُقبض ثمنه.
  bool _placing = false;

  PrintBackend? _backendCache;
  PrintBackend get _backend =>
      _backendCache ??= widget.backend ??
          ExecuteScreen.debugBackendOverride?.call() ??
          SupabasePrintBackend(Supabase.instance.client);

  /// الإعلان المعروض — يبدأ بالوارد ويُستبدل بمخرَج المحرر، فيسري
  /// التعديل على التصدير والحفظ والطباعة معًا لا على المعاينة وحدها.
  late GeneratedAd _ad = widget.ad;

  /// المنتج المبدئي: ما جاء من الحاسبة أو من صفحة المطبعة، وإلا **ما
  /// يقابل صيغة التصميم نفسه**.
  ///
  /// من صمّم استاند رول أب كان يجد «بنر» مختارًا فيطبع بمقاس آخر ثم
  /// يكتشف الفرق بعد التسليم. الصيغة تعرف منتجها في الكتالوج بالاسم،
  /// فلا داعي أن يطابقهما التاجر يدويًّا.
  late PrintProduct _product =
      widget.initialProduct ?? _productForFormat() ?? printCatalog.first;

  PrintProduct? _productForFormat() {
    final wanted = adFormatFromLabel(widget.ad.brief.format).printProduct;
    if (wanted == null) return null;
    for (final p in printCatalog) {
      if (p.label == wanted) return p;
    }
    return null;
  }

  late int _sizeIndex = widget.initialSizeIndex ?? 0;
  late int _quantity = widget.initialQuantity ?? _product.quantities.first;
  final _addressController = TextEditingController();
  LatLng? _deliveryPoint;
  PayMethod _payMethod = PayMethod.cash;
  PrintOrder? _confirmedOrder;
  bool _exporting = false;

  /// هل هذا تخطيط ركّبه الذكاء؟ يحسم أي أدوات تُعرض: القوالب لا تنطبق
  /// عليه، وتحريره تحريكُ عناصر لا تبديلُ قالب.
  bool get _isGenerated => _ad.spec != null;
  late AdTemplate _template = widget.initialTemplate ?? AdTemplate.bold;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  double get _subtotal => _product.sizes[_sizeIndex].unitPrice * _quantity;
  /// الضريبة **المشمولة** في الإجمالي، لا المضافة فوقه.
  ///
  /// نفس صيغة الخادم: `(الإجمالي) × ٠٫١٥ ÷ ١٫١٥`. وكانت `× ٠٫١٥` فتُخرج
  /// رقمًا يُجمع على الإجمالي — فيُقبض من التاجر أكثر ممّا يُسجَّل في
  /// طلبه بخمسة عشر بالمئة.
  double get _vat =>
      (_subtotal + deliveryFee) * vatRate / (1 + vatRate);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isDigital ? 'حفظ ونشر' : 'اطبعه وصلّه'),
      ),
      body: SafeArea(
        child: widget.isDigital ? _buildDigitalPath() : _buildPrintPath(),
      ),
    );
  }

  // ── المسار الرقمي: معاينة التصميم النهائي وتصديره كصورة PNG ──

  Widget _buildDigitalPath() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: SizedBox(
            height: 420,
            child: RepaintBoundary(
              key: _designKey,
              child: AdDesignPreview(
                ad: _ad,
                template: _template,
                showWatermark: !AppStateScope.of(context).isPro,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openEditor,
          icon: const Icon(Icons.tune),
          label: Text(
            _isGenerated
                ? L.of(context).executeEditSpec
                : L.of(context).executeEditTemplate,
          ),
        ),
        const SizedBox(height: 16),
        // اختيار القالب لا معنى له فوق تخطيط مولَّد: `AdDesignPreview`
        // يتجاهل القالب حين توجد مواصفة. وزرٌّ لا يفعل شيئًا أسوأ من
        // غيابه — التاجر يضغطه مرارًا ويظنّ التطبيق معطّلًا.
        if (_isGenerated)
          Text(
            L.of(context).executeGeneratedNote,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textMuted, fontSize: 12.5),
          )
        else
          _buildTemplatePicker(),
        const SizedBox(height: 8),
        Text(
          '${_ad.kind.label} بأسلوب ${_ad.brief.tone} — '
          'مهيأة لمنصة ${_ad.brief.platform}',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _exporting ? null : _exportDesign,
          icon: _exporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download_outlined),
          label: Text(
            _exporting ? 'جارٍ التصدير…' : 'تحميل/مشاركة التصميم (PNG)',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            AppStateScope.of(context).saveAd(_ad);
            _showConfirmation('تم الحفظ في «إعلاناتي»');
          },
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('حفظ في إعلاناتي'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () =>
              _showConfirmation('النشر المباشر سيتوفر مع ربط واجهات المنصات'),
          icon: const Icon(Icons.ios_share),
          label: Text('نشر مباشر على ${_ad.brief.platform}'),
        ),
        const SizedBox(height: 16),
        // إغلاق الحلقة: حاسبة تكلفة تُظهر السعر فورًا وتنتقل لطلب الطباعة
        // بالاختيار نفسه — بدل اكتشاف السعر بعد عدة خطوات.
        PrintCostCalculator(
          onProceed: (product, sizeIndex, quantity) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExecuteScreen(
                  ad: _ad,
                  isDigital: false,
                  initialTemplate: _template,
                  initialProduct: product,
                  initialSizeIndex: sizeIndex,
                  initialQuantity: quantity,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// شريط اختيار القالب — معاينة مصغّرة حيّة لكل قالب على المنتج نفسه.
  Future<void> _openEditor() async {
    final edited = await Navigator.of(context).push<GeneratedAd>(
      MaterialPageRoute(
        builder: (_) => DesignEditorScreen(ad: _ad, template: _template),
      ),
    );
    if (edited != null && mounted) setState(() => _ad = edited);
  }

  Widget _buildTemplatePicker() {
    final isPro = AppStateScope.of(context).isPro;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اختر قالب التصميم',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.scheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: AdTemplate.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final template = AdTemplate.values[i];
              final isSelected = template == _template;
              return GestureDetector(
                key: ValueKey('template-${template.name}'),
                onTap: () => setState(() => _template = template),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.coral
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: SizedBox(
                        height: 96,
                        // معاينة حيّة بالقالب الفعلي على منتج التاجر.
                        child: AdDesignPreview(
                          ad: _ad,
                          template: template,
                          showWatermark: !isPro,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? AppColors.coral : context.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _template.description,
          style: TextStyle(color: context.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  /// يلتقط التصميم المُركّب من محرك القوالب كصورة PNG عالية الدقة
  /// ويعرض ورقة المشاركة/الحفظ الخاصة بالنظام.
  /// يلتقط التصميم بايتاتٍ — يستعمله التصدير ورفعُ ملفّ الطباعة معًا.
  ///
  /// مصدرٌ واحد للصورة: ما يشاركه التاجر هو نفسه ما تطبعه المطبعة. ولو
  /// التُقطت مرّتين بإعدادين لاختلف المطبوع عمّا رآه.
  Future<Uint8List?> _captureDesign() async {
    final override = ExecuteScreen.debugCaptureOverride;
    if (override != null) return override();
    try {
      final boundary =
          _designKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _exportDesign() async {
    setState(() => _exporting = true);
    try {
      final png = await _captureDesign();
      if (png == null) throw StateError('capture_failed');
      await Share.shareXFiles([
        XFile.fromData(
          png,
          mimeType: 'image/png',
          name: 'zol_${_ad.brief.productName}.png',
        ),
      ], text: _ad.shareText);
    } catch (_) {
      if (mounted) {
        _showConfirmation('تعذّر تصدير التصميم على هذا الجهاز');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── مسار الطباعة: كتالوج + موقع توصيل على الخريطة + تسعير فوري ──

  Widget _buildPrintPath() {
    final order = _confirmedOrder;
    if (order != null) {
      return _buildOrderConfirmed(order);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // معاينة التصميم على المطبوع قبل الشراء.
        PrintMockupPreview(
          ad: _ad,
          template: _template,
          mockup: _product.mockup,
          sizeLabel: _product.sizes[_sizeIndex].label,
        ),
        const SizedBox(height: 16),
        _buildTemplatePicker(),
        const SizedBox(height: 24),
        _sectionTitle('اختر نوع المطبوع'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: printCatalog.map((product) {
            final isSelected = product == _product;
            return ChoiceChip(
              avatar: Icon(
                product.icon,
                size: 18,
                color: isSelected
                    ? context.scheme.onPrimary
                    : context.scheme.onSurface,
              ),
              label: Text(product.label),
              selected: isSelected,
              onSelected: (_) => setState(() {
                _product = product;
                _sizeIndex = 0;
                _quantity = product.quantities.first;
              }),
              selectedColor: context.scheme.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? context.scheme.onPrimary
                    : context.scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: context.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              side: BorderSide.none,
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _sectionTitle('المقاس'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(_product.sizes.length, (i) {
            final size = _product.sizes[i];
            final isSelected = i == _sizeIndex;
            return ChoiceChip(
              label: Text('${size.label} — ${formatPrice(size.unitPrice)}'),
              selected: isSelected,
              onSelected: (_) => setState(() => _sizeIndex = i),
              selectedColor: context.scheme.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? context.scheme.onPrimary
                    : context.scheme.onSurface,
              ),
              backgroundColor: context.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              side: BorderSide.none,
            );
          }),
        ),
        const SizedBox(height: 24),
        _sectionTitle('الكمية (${_product.unitName})'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: _product.quantities.map((q) {
            final isSelected = q == _quantity;
            return ChoiceChip(
              label: Text('$q'),
              selected: isSelected,
              onSelected: (_) => setState(() => _quantity = q),
              selectedColor: context.scheme.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? context.scheme.onPrimary
                    : context.scheme.onSurface,
              ),
              backgroundColor: context.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              side: BorderSide.none,
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _sectionTitle('عنوان التوصيل'),
        const SizedBox(height: 10),
        TextField(
          controller: _addressController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'المدينة، الحي، أقرب معلم',
            filled: true,
            fillColor: context.cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickDeliveryLocation,
          icon: Icon(
            _deliveryPoint == null
                ? Icons.map_outlined
                : Icons.where_to_vote_outlined,
            color: _deliveryPoint == null ? null : AppColors.coral,
          ),
          label: Text(
            _deliveryPoint == null
                ? 'تحديد الموقع على الخريطة (اختياري)'
                : 'تم تحديد الموقع على الخريطة ✓ — اضغط للتعديل',
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle('طريقة الدفع'),
        const SizedBox(height: 10),
        _buildPayMethodPicker(),
        const SizedBox(height: 24),
        _buildPriceSummary(),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _addressController.text.trim().isEmpty
              ? null
              : _confirmOrder,
          child: Text(
            _payMethod == PayMethod.card
                ? 'ادفع وأكّد الطلب — ${formatPrice(_subtotal + deliveryFee)}'
                : 'تأكيد الطلب — ${formatPrice(_subtotal + deliveryFee)}',
          ),
        ),
      ],
    );
  }

  Widget _buildPayMethodPicker() {
    return RadioGroup<PayMethod>(
      groupValue: _payMethod,
      onChanged: (v) => setState(() => _payMethod = v!),
      child: Column(
        children: PayMethod.values.map((method) {
          final isSelected = method == _payMethod;
          final isSimulated =
              method == PayMethod.card && !AppPaymentConfig.isConfigured;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.coral : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: RadioListTile<PayMethod>(
                value: method,
                activeColor: AppColors.coral,
                title: Text(
                  method.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.scheme.onSurface,
                  ),
                ),
                subtitle: isSimulated
                    ? Text(
                        'محاكاة تجريبية — تصبح بوابة «ميسر» الحقيقية بعد ضبط المفتاح',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.textMuted,
                        ),
                      )
                    : null,
                dense: true,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickDeliveryLocation() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => PickLocationScreen(initialLocation: _deliveryPoint),
      ),
    );
    if (result != null) {
      setState(() => _deliveryPoint = result);
    }
  }

  Widget _buildPriceSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _priceRow(
            'المطبوعات ($_quantity × ${formatPrice(_product.sizes[_sizeIndex].unitPrice)})',
            _subtotal,
          ),
          const SizedBox(height: 8),
          _priceRow('التوصيل', deliveryFee),
          const Divider(height: 24),
          // الضريبة **مشمولة** في الإجمالي لا مضافة فوقه — وهي الفوترة
          // السعودية، وهي ما يحسبه الخادم. وكان العرض يجمعها فوق
          // الإجمالي فيُقبض من التاجر خمسة عشر بالمئة زيادةً عمّا
          // يُسجَّل في طلبه.
          _priceRow('الإجمالي', _subtotal + deliveryFee, isTotal: true),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              L.of(context).priceVatIncluded(formatPrice(_vat)),
              style: TextStyle(color: context.textMuted, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double value, {bool isTotal = false}) {
    final style = TextStyle(
      color: isTotal ? context.scheme.onSurface : context.textMuted,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      fontSize: isTotal ? 16 : 13.5,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(formatPrice(value), style: style),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: context.scheme.onSurface,
      ),
    );
  }

  /// يُنشئ الطلب على الخادم ثم يقبض ثمنه.
  ///
  /// **الترتيب هنا هو كل شيء.** كان التطبيق يقبض البطاقة ثم يكتب الطلب في
  /// `SharedPreferences` وحدها: تُقبض الأموال ولا يعلم بالطلب خادمٌ ولا
  /// مطبعة، ومن أعاد تثبيت التطبيق فقد طلبًا دفع ثمنه.
  ///
  /// وحتى بعد الوصل يبقى السؤال: أيّهما أوّلًا؟ فاخترنا **الطلب قبل
  /// الدفع**، لأن الخطأين ليسا سواء: طلبٌ أُنشئ ولم يُدفع يظهر في اللوحة
  /// غيرَ مدفوع فيُلغى أو يُتابَع، أمّا دفعٌ بلا طلب فمالٌ أُخذ بلا أثر
  /// يُنسب إليه — ولا يعرف صاحبه كيف يطالب به.
  ///
  /// والسعر من `print_order_quote` لا من حساب الشاشة: الخادم يعدّ الضريبة
  /// مشمولة والتطبيق كان يجمعها فوق الإجمالي، فبنران بتسعين يُقبضان
  /// بـ‎٢٣٥٫٧٥‎ ويُسجَّلان بـ‎٢٠٥٫٠٠‎. من يحسب المال هو من يسجّله.
  Future<void> _confirmOrder() async {
    if (_placing) return;
    final state = AppStateScope.of(context);
    final l = L.of(context);
    final backend = _backend;
    setState(() => _placing = true);
    try {
      // ١) مَن يطبع؟ ولا مطبعة معتمدة تعني **لا طلب**، لا طلبًا معلّقًا
      //    في الهواء: توجيهُ طلبٍ مدفوع إلى جهة لم توافق أسوأ من ردّه.
      final shops = await backend.shops();
      if (!mounted) return;
      if (shops.isEmpty) {
        _showConfirmation(l.orderNoShopYet);
        return;
      }
      final point = _deliveryPoint;
      final shop = (point == null
              ? null
              : nearestShopRow(shops, point.latitude, point.longitude)) ??
          shops.first;

      // ٢) وهل تبيع هذه المطبعة ما اختاره التاجر؟ المطابقة على الصنف
      //    ثم المقاس، فإن لم يوجد المقاس بعينه فأقرب سعر في الصنف نفسه.
      final products = await backend.products(shop.id);
      if (!mounted) return;
      final size = _product.sizes[_sizeIndex].label;
      final sameKind =
          products.where((p) => p.kind == _product.kind).toList();
      final match = _firstOrNull(sameKind.where((p) => p.size == size)) ??
          _firstOrNull(sameKind);
      if (match == null) {
        _showConfirmation(
          l.orderShopLacksProduct(shop.name, _product.label),
        );
        return;
      }

      // ٣) السعر من الخادم، ويُعرض على التاجر قبل أن يُقبض منه شيء إن
      //    خالف ما رآه. مفاجأةٌ في المبلغ تكسر الثقة مرّة ولا تعود.
      final quote = await backend.quote(
        shopId: shop.id,
        productId: match.id,
        quantity: _quantity,
      );
      if (!mounted) return;
      if (quote == null) {
        _showConfirmation(l.orderQuoteFailed);
        return;
      }
      final shown = _subtotal + deliveryFee;
      if ((quote.grandTotal - shown).abs() > 0.01) {
        final ok = await _confirmNewPrice(shown, quote.grandTotal);
        if (!mounted || ok != true) return;
      }

      // ٤) الملفّ قبل الطلب: مطبعةٌ تستلم طلبًا بلا ما تطبعه لا تستطيع
      //    تنفيذه، فلا معنى لإنشائه.
      final png = await _captureDesign();
      if (!mounted) return;
      if (png == null) {
        _showConfirmation(l.orderArtworkCaptureFailed);
        return;
      }
      final artworkUrl = await backend.uploadArtwork(png);
      if (!mounted) return;
      if (artworkUrl == null) {
        _showConfirmation(l.orderArtworkUploadFailed);
        return;
      }

      // ٥) الطلب — غيرَ مدفوع بعد.
      final created = await backend.createOrder(
        shopId: shop.id,
        productId: match.id,
        quantity: _quantity,
        address: _addressController.text.trim(),
        lat: _deliveryPoint?.latitude,
        lng: _deliveryPoint?.longitude,
        artworkUrl: artworkUrl,
        specs: {'size': size, 'product': _product.label},
        paymentMethod: _payMethod == PayMethod.card ? 'card' : 'cash',
      );
      if (!mounted) return;
      if (!created.ok) {
        _showConfirmation(_orderError(l, created));
        return;
      }

      // ٦) ثم الدفع. وفشلُه لا يمحو الطلب: يبقى غير مدفوع في اللوحة،
      //    والتاجر يعرف أن طلبه قائم لا ضائع.
      String? paymentId;
      if (_payMethod == PayMethod.card) {
        final result = await startCardPayment(
          context,
          amountSar: quote.grandTotal,
          description: 'طلب طباعة ${_product.label} × $_quantity',
        );
        if (!mounted) return;
        if (result == null || !result.success) {
          _showConfirmation(result?.errorMessage ?? l.orderPaymentIncomplete);
        } else {
          paymentId = result.paymentId;
          // مرجعٌ للمطابقة لا إعلانُ دفع: `is_paid` يضبطه الخادم وحده،
          // فمن يستطيع أن يقول «دفعتُ» يستطيع أن يكذب.
          await backend.attachPayment(created.orderId!, paymentId!);
        }
      }
      if (!mounted) return;

      final order = PrintOrder(
        id: state.nextOrderId(),
        productLabel: _product.label,
        sizeLabel: size,
        quantity: _quantity,
        subtotal: quote.itemsTotal,
        deliveryFee: quote.deliveryFee,
        vat: quote.vatIncluded,
        address: _addressController.text.trim(),
        status: OrderStatus.received,
        createdAt: DateTime.now(),
        deliveryLat: _deliveryPoint?.latitude,
        deliveryLng: _deliveryPoint?.longitude,
        payMethod: _payMethod,
        // النسخة المحلية لا تدّعي الدفع أيضًا: الخادم مصدره.
        isPaid: false,
        paymentId: paymentId,
        shopName: shop.name,
        shopLat: shop.lat,
        shopLng: shop.lng,
        serverId: created.orderId,
        artworkUrl: artworkUrl,
        grandTotal: quote.grandTotal,
      );
      state.addOrder(order);
      setState(() => _confirmedOrder = order);
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  /// أوّل عنصر أو `null` — بلا اعتمادية `collection` لأجل سطر واحد.
  static ProductRow? _firstOrNull(Iterable<ProductRow> xs) =>
      xs.isEmpty ? null : xs.first;

  /// يترجم رمز رفض الخادم إلى جملة يفهمها التاجر.
  String _orderError(L l, OrderResult r) => switch (r.outcome) {
    OrderOutcome.needsAccount => l.orderNeedsAccount,
    OrderOutcome.offline => l.orderOffline,
    _ => switch (r.reason) {
      'shop_not_available' => l.orderShopUnavailable,
      'product_not_available' => l.orderProductUnavailable,
      'below_min_qty' => l.orderBelowMinQty,
      _ => l.orderCreateFailed,
    },
  };

  Future<bool?> _confirmNewPrice(double shown, double actual) {
    final l = L.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.orderPriceChangedTitle),
        content: Text(
          l.orderPriceChangedBody(formatPrice(actual), formatPrice(shown)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.commonContinue),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderConfirmed(PrintOrder order) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 40),
        const Center(
          child: IconCircle(
            icon: Icons.local_shipping_outlined,
            background: AppColors.coral,
            diameter: 90,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'تم استلام طلب الطباعة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: context.scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'رقم الطلب ${order.id}\n'
          '${order.productLabel} (${order.sizeLabel}) × ${order.quantity} — '
          '${formatPrice(order.total)}\n'
          '${order.isPaid ? 'مدفوع بالبطاقة ✓' : 'الدفع عند الاستلام'}\n'
          '${order.shopName != null ? 'أُسند تلقائيًا إلى ${order.shopName} (الأقرب لموقعك)\n' : ''}'
          'تابع حالته من تبويب «طلباتي»',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textMuted),
        ),
        const SizedBox(height: 32),
        if (order.hasDeliveryPoint) ...[
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => OrderMapScreen(order: order)),
              );
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('متابعة الطلب على الخريطة'),
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton(
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text('العودة للرئيسية'),
        ),
      ],
    );
  }

  void _showConfirmation(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
