import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:zol/main.dart';
import 'package:zol/models/ad_brief.dart';
import 'package:zol/models/print_order.dart';
import 'package:zol/models/print_catalog.dart';
import 'package:zol/models/print_shop.dart';
import 'package:zol/widgets/print_mockup.dart';
import 'package:zol/screens/settings_screen.dart';
import 'package:zol/screens/create_ad/upload_details_screen.dart';
import 'package:zol/services/ad_generator.dart';
import 'package:zol/services/ai_gateway.dart';
import 'package:zol/screens/create_ad/magic_screen.dart';
import 'package:zol/models/ad_template.dart';
import 'package:zol/models/business_category.dart';
import 'package:zol/models/template_category.dart';
import 'package:zol/widgets/ad_design_preview.dart';
import 'package:zol/services/background_remover.dart';
import 'package:zol/services/image_store.dart';
import 'package:zol/services/palette_extractor.dart';
import 'package:zol/state/app_state.dart';
import 'package:zol/models/trashed_ad.dart';
import 'package:zol/models/brand_font.dart';
import 'package:zol/models/generated_ad.dart';
import 'package:zol/models/seasonal_theme.dart';
import 'package:zol/theme/app_theme.dart';
import 'package:zol/widgets/print_cost_calculator.dart';

/// صورة PNG صالحة 1×1 بكسل تُستخدم بدل منتقي الصور الأصلي في الاختبارات.
final _fakeImage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
  'AAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Future<void> _pumpApp(WidgetTester tester, [AppState? state]) async {
  final appState = state ?? AppState();
  // شاشة الترحيب تُعرض لأول تشغيل فقط؛ تخطّيها في اختبارات بقية الشاشات.
  appState.completeOnboarding();
  await tester.pumpWidget(ZolApp(state: appState));
}

/// يمرّ عبر: الرئيسية → التفاصيل → توليد شاشة السحر حتى ظهور النتائج.
Future<void> _reachMagicResults(WidgetTester tester) async {
  await tester.tap(find.text('أنشئ إعلانك الآن'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).first, 'قهوة مختصة');
  await tester.tap(find.text('اضغط لرفع صورة المنتج'));
  await tester.pump();

  await tester.scrollUntilVisible(
    find.text('اعرض شاشة السحر'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('اعرض شاشة السحر'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('اعرض شاشة السحر'));
  await tester.pump();

  // شريط المراحل يعمل بالتوازي مع طلب المنسّق، فبعد انقضاء زمنه ننتظر
  // استقرار الشجرة حتى يُحلّ مستقبل البوابة الوهمية وتُبنى النتائج.
  final total = AdGenerator.stageDuration * AdGenerator.generationStages.length;
  await tester.pump(total + const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

/// رد ناجح مطابق لشكل ما تعيده دالة ad-copy في Supabase فعلاً — بما فيه
/// درجة الوكيل الناقد وملاحظته، والصيغ مرتّبة تنازلياً بالدرجة.
String _adCopyBody() => jsonEncode({
  'ok': true,
  'generation_id': 'gen-1',
  'model': 'gemini-3.5-flash',
  'provider': 'google',
  'tokens': {'in': 700, 'out': 300},
  'cost_usd': 0.0009,
  'cost_sar': 0.0034,
  'latency_ms': 24600,
  'variants': [
    {
      'angle': 'عرض',
      'headline': 'ربع السعر طايح بأول طلب',
      'body': 'خصم ٢٥٪ على أول طلب من قهوة رذاذ الإثيوبية.',
      'cta': 'اطلب الحين',
      'hashtags': ['#قهوة_مختصة', '#خصم_رذاذ'],
      'score_total': 9,
      'fix_note': null,
      'rank': 1,
    },
    {
      'angle': 'منفعة',
      'headline': 'طعم يروقك من أول رشفة',
      'body': 'تحميص فاتح يبرز نكهات الفاكهة الطبيعية.',
      'cta': 'اطلبها الحين',
      'hashtags': ['#قهوة_رذاذ'],
      'score_total': 6.4,
      'fix_note': 'أضف عرض الخصم المذكور في الموجز.',
      'rank': 2,
    },
  ],
});

AiGateway _fakeGateway() => AiGateway(
  baseUrl: 'http://test.local',
  useSupabase: true,
  supabaseUrl: 'http://test.local',
  merchantId: 'merchant-test',
  // Response(String,…) يرمّز بـ Latin-1 وهو عاجز عن تمثيل العربية فيرمي
  // عند البناء؛ نمرّر البايتات مرمّزة UTF-8 كما تفعل الدالة الحقيقية.
  client: MockClient(
    (req) async => http.Response.bytes(
      utf8.encode(_adCopyBody()),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  ),
);

void main() {
  setUpAll(() {
    MagicScreen.debugGatewayOverride = _fakeGateway;
    UploadDetailsScreen.debugPickImageOverride = () async => _fakeImage;
    BackgroundRemover.debugRunSynchronously = true;
    PaletteExtractor.debugRunSynchronously = true;
    ImageStore.debugRunSynchronously = true;
  });

  testWidgets('Onboarding shows on first run and only once', (tester) async {
    final state = AppState();
    await tester.pumpWidget(ZolApp(state: state));
    await tester.pumpAndSettle();

    // أول تشغيل → شاشة الترحيب لا الرئيسية.
    expect(find.text('إعلانك يولد في ثوانٍ'), findsOneWidget);
    expect(find.text('أنشئ إعلانك الآن'), findsNothing);

    // التنقل بين صفحات التعريف الثلاث ثم التخطّي بلا اختيار نشاط.
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('اطبعه عند أقرب مطبعة'), findsOneWidget);
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('ويصلك حتى الباب'), findsOneWidget);
    await tester.tap(find.text('تخطٍّ'));
    await tester.pumpAndSettle();

    expect(state.hasOnboarded, isTrue);
    expect(find.text('أنشئ إعلانك الآن'), findsOneWidget);
  });

  testWidgets('Home screen shows the main call-to-action and stats',
      (tester) async {
    await _pumpApp(tester);

    expect(find.text('أنشئ إعلانك الآن'), findsOneWidget);
    expect(find.text('إعلان محفوظ'), findsOneWidget);
    expect(find.text('طلب طباعة'), findsOneWidget);
  });

  testWidgets('Continue button stays disabled until name and image are set',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('أنشئ إعلانك الآن'));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(ElevatedButton, 'اعرض شاشة السحر');
    await tester.scrollUntilVisible(
      find.text('اعرض شاشة السحر'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<ElevatedButton>(button).enabled, isFalse);

    // نصعد أولًا لأعلى القائمة قبل الكتابة — بعد إضافة قسم الموسم صار
    // المحتوى أطول، فالبقاء في أسفل القائمة (بعد التمرير للزر) يُخرج
    // حقل الاسم من نطاق التخزين المؤقت لـ ListView فيُفكَّك من الشجرة.
    await tester.scrollUntilVisible(
      find.text('اضغط لرفع صورة المنتج'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField).first, 'قهوة مختصة');
    await tester.tap(find.text('اضغط لرفع صورة المنتج'));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('اعرض شاشة السحر'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<ElevatedButton>(button).enabled, isTrue);
  });

  testWidgets('Magic screen renders Supabase variants with critic scores',
      (tester) async {
    await _pumpApp(tester);
    await _reachMagicResults(tester);

    expect(find.text('اختر النسخة الأنسب'), findsOneWidget);

    // عقل Supabase يعيد زاوية لكل صيغة ودرجة من وكيله الناقد، والصيغ
    // تصل مرتّبة تنازلياً فالأعلى درجة أولاً.
    expect(find.text('عرض'), findsOneWidget);
    expect(find.textContaining('توافق'), findsWidgets);

    expect(find.text('حفظ ونشر'), findsOneWidget);
    expect(find.text('اطبعه وصلّه'), findsOneWidget);
  });

  testWidgets('Saving a variant adds it to the My Ads library',
      (tester) async {
    final state = AppState();
    await _pumpApp(tester, state);
    await _reachMagicResults(tester);

    await tester.ensureVisible(find.text('حفظ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ').first);
    await tester.pump();
    expect(state.savedAds, hasLength(1));
    expect(state.savedAds.first.brief.productName, 'قهوة مختصة');
  });

  testWidgets('Print flow computes a price and creates a tracked order',
      (tester) async {
    final state = AppState();
    await _pumpApp(tester, state);
    await _reachMagicResults(tester);

    await tester.tap(find.text('اطبعه وصلّه'));
    await tester.pumpAndSettle();

    // بنر 1×2 متر: 90 + توصيل 25 + ضريبة 15% = 132.25
    final confirm = find.widgetWithText(ElevatedButton, 'تأكيد الطلب — 132.25 ر.س');
    // التمرير لأسفل القائمة (السحب المباشر يتفادى التباس تعدد الـ Scrollables).
    await tester.drag(find.byType(ListView).last, const Offset(0, -1600));
    await tester.pumpAndSettle();
    // ملخص السعر ظاهر وزر التأكيد معطل قبل إدخال العنوان.
    expect(find.text('الإجمالي'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(confirm).enabled, isFalse);

    await tester.enterText(find.byType(TextField), 'الرياض، حي النرجس');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pump();

    expect(find.text('تم استلام طلب الطباعة'), findsOneWidget);
    expect(state.orders, hasLength(1));
    expect(state.orders.first.id, 'AD-1001');
    expect(state.orders.first.total, closeTo(132.25, 0.01));

    // العودة ثم فتح تبويب «طلباتي» والتحقق من ظهور الطلب.
    await tester.tap(find.text('العودة للرئيسية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طلباتي'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AD-1001'), findsOneWidget);
  });

  test('State persists across app restarts', () async {
    SharedPreferences.setMockInitialValues({});

    final first = await AppState.load();
    final brief = AdBrief(
      productName: 'قهوة مختصة',
      description: '',
      tone: 'حماسي',
      platform: 'إنستغرام',
      format: 'منشور مربع',
    );
    first.saveAd(AdGenerator.preview(brief).first);
    first.addOrder(
      PrintOrder(
        id: first.nextOrderId(),
        productLabel: 'بنر',
        sizeLabel: '1×2 متر',
        quantity: 1,
        subtotal: 90,
        deliveryFee: 25,
        vat: 17.25,
        address: 'الرياض',
        status: OrderStatus.received,
        createdAt: DateTime.now(),
        deliveryLat: 24.7,
        deliveryLng: 46.6,
      ),
    );

    // «إعادة تشغيل»: تحميل حالة جديدة من نفس التخزين.
    final second = await AppState.load();
    expect(second.savedAds, hasLength(1));
    expect(second.savedAds.first.brief.productName, 'قهوة مختصة');
    expect(second.orders, hasLength(1));
    expect(second.orders.first.hasDeliveryPoint, isTrue);
    // تسلسل أرقام الطلبات يستمر بعد إعادة التشغيل.
    expect(second.nextOrderId(), 'AD-1002');
  });

  testWidgets('Card payment (simulated) marks the order as paid',
      (tester) async {
    final state = AppState();
    await _pumpApp(tester, state);
    await _reachMagicResults(tester);

    await tester.tap(find.text('اطبعه وصلّه'));
    await tester.pumpAndSettle();

    // اختيار الدفع بالبطاقة بعد التمرير لأسفل القائمة.
    await tester.drag(find.byType(ListView).last, const Offset(0, -1600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بطاقة (mada / Visa / Mastercard)'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'الرياض، حي النرجس');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('ادفع وأكّد الطلب'));
    await tester.pumpAndSettle();

    // ورقة المحاكاة تظهر بوضوح أنها تجريبية.
    expect(find.textContaining('محاكاة بوابة الدفع'), findsOneWidget);
    await tester.tap(find.text('محاكاة نجاح الدفع'));
    await tester.pumpAndSettle();

    expect(find.text('تم استلام طلب الطباعة'), findsOneWidget);
    expect(find.textContaining('مدفوع بالبطاقة ✓'), findsOneWidget);
    expect(state.orders.single.isPaid, isTrue);
    expect(state.orders.single.paymentId, startsWith('SIM-'));
  });

  testWidgets('Cancelling card payment creates no order', (tester) async {
    final state = AppState();
    await _pumpApp(tester, state);
    await _reachMagicResults(tester);

    await tester.tap(find.text('اطبعه وصلّه'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بطاقة (mada / Visa / Mastercard)'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'الرياض');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('ادفع وأكّد الطلب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    // لا طلب بلا دفع ناجح (قاعدة zadgo2).
    expect(state.orders, isEmpty);
    expect(find.text('تم استلام طلب الطباعة'), findsNothing);
  });

  testWidgets('Pro upgrade removes the watermark plan card', (tester) async {
    final state = AppState();
    await _pumpApp(tester, state);

    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('الترقية للاحترافية'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('الترقية للاحترافية'));
    await tester.pump();
    await tester.tap(find.text('الترقية للاحترافية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('محاكاة نجاح الدفع'));
    await tester.pumpAndSettle();

    expect(state.isPro, isTrue);
    expect(find.text('الخطة الاحترافية مفعّلة ✓'), findsOneWidget);
    expect(find.text('الترقية للاحترافية'), findsNothing);
  });

  test('Background remover isolates product from a uniform background',
      () async {
    // صورة اصطناعية: خلفية بيضاء وموضوع أحمر في المنتصف.
    final source = img.Image(width: 120, height: 120, numChannels: 4);
    img.fill(source, color: img.ColorRgba8(250, 250, 250, 255));
    img.fillRect(
      source,
      x1: 40,
      y1: 40,
      x2: 80,
      y2: 80,
      color: img.ColorRgba8(200, 30, 30, 255),
    );
    final bytes = img.encodePng(source);

    final result =
        await BackgroundRemover.removeBackground(Uint8List.fromList(bytes));
    expect(result, isNotNull);

    final cutout = img.decodePng(result!)!;
    // الزاوية أصبحت شفافة (خلفية معزولة).
    expect(cutout.getPixel(5, 5).a, 0);
    // مركز المنتج بقي معتمًا وبلونه.
    final center = cutout.getPixel(60, 60);
    expect(center.a, 255);
    expect(center.r, greaterThan(150));
  });

  test('Background remover refuses to butcher a busy background', () async {
    // خلفية عشوائية الألوان (ضوضاء) — يجب أن يمتنع العزل بدل إتلاف الصورة.
    final noisy = img.Image(width: 60, height: 60, numChannels: 4);
    for (var y = 0; y < 60; y++) {
      for (var x = 0; x < 60; x++) {
        noisy.setPixelRgba(x, y, (x * 37) % 256, (y * 91) % 256, (x * y) % 256, 255);
      }
    }
    final result = await BackgroundRemover.removeBackground(
      Uint8List.fromList(img.encodePng(noisy)),
    );
    expect(result, isNull);
  });

  test('Merchant account: register, login, logout, and session restore',
      () async {
    SharedPreferences.setMockInitialValues({});

    final first = await AppState.load();
    expect(
      await first.register(
        name: 'محمد',
        storeName: 'محمصة الفجر',
        email: 'M@Example.com',
        password: 'secret123',
      ),
      isNull,
    );
    expect(first.isLoggedIn, isTrue);

    // بريد مكرر يرفض.
    expect(
      await first.register(
        name: 'آخر',
        storeName: 'متجر',
        email: 'm@example.com',
        password: 'other123',
      ),
      isNotNull,
    );

    // الجلسة تُسترجع بعد «إعادة تشغيل».
    final second = await AppState.load();
    expect(second.account?.name, 'محمد');
    expect(second.account?.email, 'm@example.com');

    second.logout();
    expect(second.isLoggedIn, isFalse);
    expect(
      await second.login(email: 'm@example.com', password: 'wrong'),
      isNotNull,
    );
    expect(
      await second.login(email: 'm@example.com', password: 'secret123'),
      isNull,
    );
    expect(second.account?.storeName, 'محمصة الفجر');
  });

  testWidgets('Merchant can register from the settings tab', (tester) async {
    final state = AppState();
    await _pumpApp(tester, state);

    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل الدخول / إنشاء حساب'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ليس لديك حساب؟ أنشئ حسابًا جديدًا'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'محمد');
    await tester.enterText(fields.at(1), 'محمصة الفجر');
    await tester.enterText(fields.at(2), 'm@example.com');
    await tester.enterText(fields.at(3), 'secret123');
    await tester.tap(find.text('إنشاء الحساب'));
    await tester.pumpAndSettle();

    expect(state.isLoggedIn, isTrue);
    expect(find.text('محمد'), findsOneWidget);
    expect(find.textContaining('محمصة الفجر'), findsOneWidget);
  });

  test('Palette extractor finds the product colour, not the background', () async {
    // خلفية بيضاء واسعة + منتج أخضر — يجب أن يفوز الأخضر لا الأبيض.
    final source = img.Image(width: 120, height: 120, numChannels: 4);
    img.fill(source, color: img.ColorRgba8(252, 252, 252, 255));
    img.fillRect(
      source,
      x1: 35,
      y1: 35,
      x2: 85,
      y2: 85,
      color: img.ColorRgba8(20, 160, 70, 255),
    );

    final value = await PaletteExtractor.dominantColor(
      Uint8List.fromList(img.encodePng(source)),
    );
    expect(value, isNotNull);
    final color = Color(value!);
    expect(color.g, greaterThan(color.r));
    expect(color.g, greaterThan(color.b));
  });

  test('Palette extractor returns null for a colourless image', () async {
    final grey = img.Image(width: 60, height: 60, numChannels: 4);
    img.fill(grey, color: img.ColorRgba8(128, 128, 128, 255));
    final value = await PaletteExtractor.dominantColor(
      Uint8List.fromList(img.encodePng(grey)),
    );
    expect(value, isNull);
  });

  test('Palette resolution follows brand → product → tone priority', () {
    // لون العلامة يتقدّم على لون المنتج.
    final branded = AdPalette.resolve(
      brandColor: 0xFF00695C,
      productColor: 0xFFB91D3A,
      tone: 'حماسي',
    );
    expect(branded.primary, const Color(0xFF00695C));

    // بلا لون علامة → لون المنتج.
    final fromProduct = AdPalette.resolve(
      productColor: 0xFFB91D3A,
      tone: 'حماسي',
    );
    expect(fromProduct.primary, const Color(0xFFB91D3A));

    // بلا هذا ولا ذاك → تدرّج النبرة.
    final formal = AdPalette.resolve(tone: 'رسمي');
    expect(formal.primary, const Color(0xFF1F2A5E));
  });

  test('Season color slots between brand and product in palette priority',
      () {
    // العلامة تتقدّم حتى على الموسم — الهوية الدائمة تسبق الاختيار الموسمي.
    final branded = AdPalette.resolve(
      brandColor: 0xFF00695C,
      seasonColor: SeasonalTheme.eid.colorValue,
      productColor: 0xFFB91D3A,
      tone: 'حماسي',
    );
    expect(branded.primary, const Color(0xFF00695C));

    // بلا لون علامة، الموسم يتقدّم على لون المنتج المستخرَج تلقائيًا.
    final seasonal = AdPalette.resolve(
      seasonColor: SeasonalTheme.eid.colorValue,
      productColor: 0xFFB91D3A,
      tone: 'حماسي',
    );
    expect(seasonal.primary, SeasonalTheme.eid.color);
  });

  testWidgets('Template picker switches the exported design', (tester) async {
    await _pumpApp(tester);
    await _reachMagicResults(tester);

    await tester.tap(find.text('حفظ ونشر'));
    await tester.pumpAndSettle();

    // القوالب الستة كلها معروضة، والقالب الافتراضي «جريء».
    expect(find.text('اختر قالب التصميم'), findsOneWidget);
    for (final template in AdTemplate.values) {
      expect(find.byKey(ValueKey('template-${template.name}')), findsOneWidget);
    }
    expect(find.text(AdTemplate.bold.description), findsOneWidget);

    // شريط القوالب أسفل معاينة كبيرة، و«بقعة ضوء» رابع القوالب:
    // تمرير رأسي ليظهر الشريط، ثم أفقي للوصول إلى القالب.
    await tester.drag(find.byType(ListView).first, const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('template-spotlight')),
      120,
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axis == Axis.horizontal,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('template-spotlight')));
    await tester.pumpAndSettle();
    expect(find.text(AdTemplate.spotlight.description), findsOneWidget);
    expect(find.text(AdTemplate.bold.description), findsNothing);
  });

  testWidgets('Print flow previews the design on the actual product',
      (tester) async {
    await _pumpApp(tester);
    await _reachMagicResults(tester);

    await tester.tap(find.text('اطبعه وصلّه'));
    await tester.pumpAndSettle();

    // المعاينة ظاهرة بمقاس المطبوع المختار قبل الشراء.
    expect(find.byType(PrintMockupPreview), findsOneWidget);
    expect(find.textContaining('معاينة تقريبية'), findsOneWidget);
    expect(find.textContaining('1×2 متر'), findsWidgets);

    // تغيير المطبوع يغيّر شكل المجسّم ومقاسه في المعاينة.
    await tester.drag(find.byType(ListView).last, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('كروت أعمال'));
    await tester.pumpAndSettle();

    final preview = tester.widget<PrintMockupPreview>(
      find.byType(PrintMockupPreview),
    );
    expect(preview.mockup, PrintMockup.card);
    expect(preview.sizeLabel, contains('9×5'));
  });

  testWidgets('Saved ads reopen from the library for re-export',
      (tester) async {
    final state = AppState();
    await _pumpApp(tester, state);
    await _reachMagicResults(tester);

    await tester.ensureVisible(find.text('حفظ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ').first);
    await tester.pumpAndSettle();
    expect(state.savedAds, hasLength(1));
    // شريط تنبيه «تم الحفظ» يغطي أسفل الشاشة — ننتظر اختفاءه.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // العودة للجذر ثم فتح تبويب المكتبة.
    Navigator.of(tester.element(find.byType(Scaffold).last))
        .popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إعلاناتي'));
    await tester.pumpAndSettle();

    // النقر على الإعلان المحفوظ يفتح شاشة التصميم لا طريقًا مسدودًا.
    final saved = state.savedAds.single;
    await tester.tap(
      find.byKey(ValueKey('saved-ad-${saved.createdAt.microsecondsSinceEpoch}')),
    );
    await tester.pumpAndSettle();

    expect(find.text('اختر قالب التصميم'), findsOneWidget);
    // القائمة الرأسية لشاشة التصميم (لا شريط القوالب الأفقي).
    await tester.drag(
      find
          .byWidgetPredicate(
            (w) => w is ListView && w.scrollDirection == Axis.vertical,
          )
          .last,
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    // إعادة التصدير متاحة من الإعلان المحفوظ.
    expect(find.textContaining('تحميل/مشاركة التصميم'), findsOneWidget);

    // والحلقة مكتملة: من المكتبة إلى طلب طباعة عبر حاسبة التكلفة.
    final calcToggle = find.byKey(const ValueKey('print-cost-toggle'));
    await tester.ensureVisible(calcToggle);
    await tester.pumpAndSettle();
    await tester.tap(calcToggle);
    await tester.pumpAndSettle();
    final proceed = find.byKey(const ValueKey('print-cost-proceed'));
    await tester.ensureVisible(proceed);
    await tester.pumpAndSettle();
    await tester.tap(proceed);
    await tester.pumpAndSettle();
    expect(find.byType(PrintMockupPreview), findsOneWidget);
    expect(find.text('اختر نوع المطبوع'), findsOneWidget);
  });

  test('Saved ad keeps its product image across a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await AppState.load();

    final brief = AdBrief(
      productName: 'قهوة مختصة',
      description: '',
      tone: 'حماسي',
      platform: 'إنستغرام',
      format: 'منشور مربع',
      imageBytes: _fakeImage,
    );
    await first.saveAd(AdGenerator.preview(brief).first);

    final second = await AppState.load();
    expect(second.savedAds, hasLength(1));
    // الصورة تُسترجع فيبقى التصميم قابلًا لإعادة التصدير.
    expect(second.savedAds.single.brief.imageBytes, isNotNull);
    expect(second.savedAds.single.brief.imageBytes, isNotEmpty);
  });

  testWidgets('Template gallery browses by category and searches',
      (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('القوالب'));
    await tester.pumpAndSettle();

    // الفئات معروضة مع معاينات حيّة للقوالب.
    expect(find.text('اختر الشكل الذي تريده'), findsOneWidget);
    expect(find.text(TemplateCategory.post.label), findsOneWidget);
    expect(find.text(TemplateCategory.story.label), findsOneWidget);
    expect(find.byType(AdDesignPreview), findsWidgets);

    // البحث يصفّي الفئات.
    await tester.enterText(find.byType(TextField).first, 'كرت');
    await tester.pumpAndSettle();
    expect(find.text(TemplateCategory.card.label), findsOneWidget);
    expect(find.text(TemplateCategory.post.label), findsNothing);

    // بحث بلا نتائج يعطي رسالة واضحة لا شاشة فارغة.
    await tester.enterText(find.byType(TextField).first, 'زززز');
    await tester.pumpAndSettle();
    expect(find.text('لا توجد قوالب مطابقة لبحثك'), findsOneWidget);
  });

  testWidgets('Picking a gallery template preselects format and template',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('القوالب'));
    await tester.pumpAndSettle();

    // اختيار قالب «بقعة ضوء» من فئة الستوري (صف ثانٍ يحتاج تمريرًا).
    const card = ValueKey('gallery-story-spotlight');
    await tester.ensureVisible(find.byKey(card));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(card));
    await tester.pumpAndSettle();

    // شاشة التفاصيل فُتحت بالصيغة والمنصة معبّأتين مسبقًا.
    final details = tester.widget<UploadDetailsScreen>(
      find.byType(UploadDetailsScreen),
    );
    expect(details.initialFormat, TemplateCategory.story.adFormat);
    expect(details.initialPlatform, TemplateCategory.story.suggestedPlatform);
    expect(details.initialTemplate, AdTemplate.spotlight);
  });

  test(
      'Template ordering puts the merchant business match first, trending as tiebreaker',
      () {
    // فئة الجمال تفضّل «منقسم» و«أنيق» — يجب أن يتقدّما على «جريء» رغم أن
    // «جريء» الأكثر رواجًا عمومًا، وعلى «عرض خاص» غير المناسب لها إطلاقًا.
    final order = orderTemplatesForBusiness(
      TemplateCategory.post.templates,
      BusinessCategory.beauty,
    );
    expect(order, [
      AdTemplate.split,
      AdTemplate.minimal,
      AdTemplate.bold,
      AdTemplate.offer,
    ]);

    // بلا نشاط مطابق (لا قالب من هذه الفئة موجّه للكافيهات)، يتصدّر
    // الأكثر رواجًا فقط.
    final noMatch = orderTemplatesForBusiness(
      TemplateCategory.post.templates,
      BusinessCategory.cafe,
    );
    expect(noMatch.first, AdTemplate.bold);

    // القالبان الأكثر رواجًا فقط يحملان شارة «رائج».
    expect(AdTemplate.bold.isTrending, isTrue);
    expect(AdTemplate.offer.isTrending, isTrue);
    expect(AdTemplate.minimal.isTrending, isFalse);
  });

  testWidgets('Gallery shows a trending badge on the top templates',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('القوالب'));
    await tester.pumpAndSettle();

    expect(find.text('🔥 رائج'), findsWidgets);
  });

  test('Generated copy uses the merchant business vocabulary', () {
    AdBrief briefFor(BusinessCategory category) => AdBrief(
      productName: 'منتجي',
      description: '',
      tone: 'حماسي',
      platform: 'إنستغرام',
      format: 'منشور مربع',
      category: category,
    );

    final cafe = AdGenerator.preview(briefFor(BusinessCategory.cafe));
    final realEstate =
        AdGenerator.preview(briefFor(BusinessCategory.realEstate));

    // مفردات الكافيه لا تشبه مفردات العقار — لا نص عام واحد للاثنين.
    final cafeText = cafe.map((a) => '${a.headline} ${a.body}').join(' ');
    final estateText =
        realEstate.map((a) => '${a.headline} ${a.body}').join(' ');
    expect(cafeText, contains('تحميص'));
    expect(estateText, contains('تشطيب'));
    expect(cafeText, isNot(contains('تشطيب')));
    expect(estateText, isNot(contains('تحميص')));

    // دعوة الإجراء والهاشتاقات تتبع النشاط أيضًا.
    expect(cafe.first.cta, BusinessCategory.cafe.cta);
    expect(realEstate.first.cta, BusinessCategory.realEstate.cta);
    expect(cafe.first.hashtags, contains('#قهوة_مختصة'));
    expect(realEstate.first.hashtags, contains('#عقار'));

    // النبرة تُغيّر الصياغة مع بقاء مفردات النشاط.
    final formalCafe = AdGenerator.preview(
      AdBrief(
        productName: 'منتجي',
        description: '',
        tone: 'رسمي',
        platform: 'إنستغرام',
        format: 'منشور مربع',
        category: BusinessCategory.cafe,
      ),
    );
    expect(formalCafe.first.headline, isNot(cafe.first.headline));
  });

  test('Regenerating with a new seed varies the CTA and hook without losing '
      'the business vocabulary', () {
    final brief = AdBrief(
      productName: 'قهوة مختصة',
      description: '',
      tone: 'حماسي',
      platform: 'إنستغرام',
      format: 'منشور مربع',
      category: BusinessCategory.cafe,
    );

    // seed=0 يبقى مطابقًا للسلوك السابق — أول عنصر في كل قائمة.
    expect(
      AdGenerator.preview(brief, seed: 0).first.cta,
      BusinessCategory.cafe.cta,
    );

    // بذور مختلفة تُنتج دعوات إجراء مختلفة (تنويعات وليست دعوة واحدة ثابتة).
    final ctas = {
      for (var seed = 0; seed < 8; seed++)
        AdGenerator.preview(brief, seed: seed).first.cta,
    };
    expect(ctas.length, greaterThan(1));
    // كل دعوة إجراء منتَجة يجب أن تكون من مجموعة خيارات الكافيه المعروفة.
    final knownCtas = {
      BusinessCategory.cafe.cta,
      ...BusinessCategory.cafe.ctaVariants,
    };
    expect(ctas.every(knownCtas.contains), isTrue);

    // كل عنوان مولَّد يحمل إحدى عبارات جذب الكافيه المعروفة — التنويع في
    // الاختيار، لا في استبدال مفردات النشاط بشيء عام.
    for (var seed = 0; seed < 8; seed++) {
      final ad = AdGenerator.preview(brief, seed: seed).first;
      expect(
        BusinessCategory.cafe.hooks.any((hook) => ad.headline.contains(hook)),
        isTrue,
      );
    }
  });

  test('Seasonal theme adds a campaign phrase and hashtag without replacing '
      'the business vocabulary', () {
    final withSeason = AdGenerator.preview(
      AdBrief(
        productName: 'قهوة مختصة',
        description: '',
        tone: 'حماسي',
        platform: 'إنستغرام',
        format: 'منشور مربع',
        category: BusinessCategory.cafe,
        season: SeasonalTheme.nationalDay,
      ),
    );
    final withoutSeason = AdGenerator.preview(
      AdBrief(
        productName: 'قهوة مختصة',
        description: '',
        tone: 'حماسي',
        platform: 'إنستغرام',
        format: 'منشور مربع',
        category: BusinessCategory.cafe,
      ),
    );

    final seasonalText =
        withSeason.map((a) => '${a.headline} ${a.body}').join(' ');
    expect(seasonalText, contains(SeasonalTheme.nationalDay.campaignPhrase));
    expect(withSeason.first.hashtags, contains('#اليوم_الوطني'));
    // مفردات النشاط تبقى كما هي، الموسم يضيف فوقها لا يستبدلها.
    expect(seasonalText, contains('تحميص'));
    expect(withSeason.first.cta, withoutSeason.first.cta);
  });

  test('Season approach detection only trusts Gregorian-anchored occasions',
      () {
    // اليوم الوطني (23 سبتمبر): قريب خلال الثلاثين يومًا السابقة له.
    expect(
      isSeasonApproaching(
        SeasonalTheme.nationalDay,
        DateTime(2026, 9, 1),
      ),
      isTrue,
    );
    expect(
      isSeasonApproaching(
        SeasonalTheme.nationalDay,
        DateTime(2026, 9, 23),
      ),
      isTrue,
    );
    expect(
      isSeasonApproaching(
        SeasonalTheme.nationalDay,
        DateTime(2026, 8, 1),
      ),
      isFalse,
    );
    expect(
      isSeasonApproaching(
        SeasonalTheme.nationalDay,
        DateTime(2026, 9, 24),
      ),
      isFalse,
    );

    // الجمعة البيضاء: النصف الثاني من نوفمبر تقريبًا.
    expect(
      isSeasonApproaching(SeasonalTheme.whiteFriday, DateTime(2026, 11, 20)),
      isTrue,
    );
    expect(
      isSeasonApproaching(SeasonalTheme.whiteFriday, DateTime(2026, 11, 5)),
      isFalse,
    );

    // موسم الرياض: أكتوبر–مارس، يمتد عبر بداية السنة.
    expect(
      isSeasonApproaching(SeasonalTheme.riyadhSeason, DateTime(2026, 12, 1)),
      isTrue,
    );
    expect(
      isSeasonApproaching(SeasonalTheme.riyadhSeason, DateTime(2026, 2, 1)),
      isTrue,
    );
    expect(
      isSeasonApproaching(SeasonalTheme.riyadhSeason, DateTime(2026, 6, 1)),
      isFalse,
    );

    // رمضان والعيد بالتقويم الهجري المتغيّر — لا اقتراح تلقائي بلا تقويم
    // هجري مضمَّن، تجنّبًا لادّعاء دقة غير موثوقة.
    expect(
      isSeasonApproaching(SeasonalTheme.ramadan, DateTime(2026, 3, 1)),
      isFalse,
    );
    expect(
      isSeasonApproaching(SeasonalTheme.eid, DateTime(2026, 3, 20)),
      isFalse,
    );
  });

  testWidgets(
      'Season picker threads through to the design badge and gallery flow',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('أنشئ إعلانك الآن'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('اضغط لرفع صورة المنتج'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField).first, 'قهوة مختصة');
    await tester.tap(find.text('اضغط لرفع صورة المنتج'));
    await tester.pump();

    final ramadanChip = find.byKey(const ValueKey('season-ramadan'));
    await tester.scrollUntilVisible(
      ramadanChip,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(ramadanChip);
    await tester.pumpAndSettle();
    await tester.tap(ramadanChip);
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('اعرض شاشة السحر'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('اعرض شاشة السحر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اعرض شاشة السحر'));
    await tester.pump();
    final total = AdGenerator.stageDuration * AdGenerator.generationStages.length;
    await tester.pump(total + const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // شارة الموسم تظهر على التصميم المولَّد.
    expect(find.textContaining(SeasonalTheme.ramadan.label), findsWidgets);
  });

  testWidgets(
      'Decorative background toggle renders the category SVG pattern on '
      'the design, off by default', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('أنشئ إعلانك الآن'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('اضغط لرفع صورة المنتج'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField).first, 'قهوة مختصة');
    await tester.tap(find.text('اضغط لرفع صورة المنتج'));
    await tester.pump();

    final toggle =
        find.byKey(const ValueKey('decorative-background-toggle'));
    await tester.scrollUntilVisible(
      toggle,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    // افتراضيًا معطّلة — بلا خلفية مصمَّمة قبل التفعيل.
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

    await tester.scrollUntilVisible(
      find.text('اعرض شاشة السحر'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('اعرض شاشة السحر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اعرض شاشة السحر'));
    await tester.pump();
    final total = AdGenerator.stageDuration * AdGenerator.generationStages.length;
    await tester.pump(total + const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // زخرفة الخلفية (SVG مضمَّنة) تظهر على التصميم المولَّد بعد التفعيل.
    expect(find.byType(SvgPicture), findsWidgets);
  });

  testWidgets('Onboarding asks for the business and stores it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load();
    await tester.pumpWidget(ZolApp(state: state));
    await tester.pumpAndSettle();

    // تجاوز صفحات التعريف الثلاث حتى سؤال النشاط.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
    }
    expect(find.text('ما نشاطك؟'), findsOneWidget);

    // لا متابعة قبل الاختيار.
    final cta = find.widgetWithText(ElevatedButton, 'اختر نشاطك للمتابعة');
    expect(tester.widget<ElevatedButton>(cta).enabled, isFalse);

    await tester.tap(find.byKey(const ValueKey('category-cafe')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ الآن'));
    await tester.pumpAndSettle();

    expect(state.businessCategory, BusinessCategory.cafe);
    expect(find.text('أنشئ إعلانك الآن'), findsOneWidget);

    // الاختيار محفوظ بعد إعادة التشغيل.
    final reloaded = await AppState.load();
    expect(reloaded.businessCategory, BusinessCategory.cafe);
  });

  testWidgets('Business category can be changed from settings',
      (tester) async {
    final state = AppState();
    await _pumpApp(tester, state);

    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-category-beauty')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('settings-category-beauty')));
    await tester.pumpAndSettle();

    expect(state.businessCategory, BusinessCategory.beauty);
  });

  testWidgets(
      'Print cost calculator computes total and proceeds with the chosen selection',
      (tester) async {
    PrintProduct? proceedProduct;
    int? proceedSizeIndex;
    int? proceedQuantity;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: PrintCostCalculator(
            onProceed: (product, sizeIndex, quantity) {
              proceedProduct = product;
              proceedSizeIndex = sizeIndex;
              proceedQuantity = quantity;
            },
          ),
        ),
      ),
    );

    // مطويّة افتراضيًا وتُظهر تقدير «بنر» (المنتج الأول في الكتالوج).
    expect(find.textContaining('بنر'), findsOneWidget);
    expect(find.byKey(const ValueKey('print-cost-proceed')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('print-cost-toggle')));
    await tester.pumpAndSettle();

    // تغيير المنتج إلى كروت أعمال يحدّث التقدير والملخص فورًا.
    await tester.tap(find.text('كروت أعمال'));
    await tester.pumpAndSettle();
    // 60 (سعر القياسي) + 25 توصيل، ‎×1.15 ضريبة = 97.75
    expect(find.textContaining('97.75'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('print-cost-proceed')));
    await tester.pumpAndSettle();

    expect(proceedProduct?.label, 'كروت أعمال');
    expect(proceedSizeIndex, 0);
    expect(proceedQuantity, 1);
  });

  testWidgets('Deleting a saved ad moves it to trash with an instant undo',
      (tester) async {
    final state = AppState();
    await _pumpApp(tester, state);
    await _reachMagicResults(tester);

    await tester.ensureVisible(find.text('حفظ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ').first);
    await tester.pumpAndSettle();
    expect(state.savedAds, hasLength(1));
    // شريط تنبيه «تم الحفظ» يغطي أسفل الشاشة — ننتظر اختفاءه قبل حذف
    // الإعلان، وإلا يبقى شريط الحذف التالي في قائمة الانتظار خلفه.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(Scaffold).last))
        .popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إعلاناتي'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('حذف'));
    await tester.pump();
    // السماح للـ Snackbar بإنهاء حركة الظهور.
    await tester.pump(const Duration(milliseconds: 300));

    expect(state.savedAds, isEmpty);
    expect(state.trashedAds, hasLength(1));
    expect(find.text('نُقل الإعلان إلى سلة المهملات'), findsOneWidget);

    // التراجع من الـ Snackbar يعيده للمكتبة فورًا بلا حاجة لفتح السلة.
    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();
    expect(state.savedAds, hasLength(1));
    expect(state.trashedAds, isEmpty);
  });

  testWidgets(
      'Saved ad card exposes delete and copy as individually reachable '
      'accessibility actions, not merged into the whole card', (tester) async {
    final handle = tester.ensureSemantics();
    final state = AppState();
    await _pumpApp(tester, state);
    await _reachMagicResults(tester);

    await tester.ensureVisible(find.text('حفظ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ').first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(Scaffold).last))
        .popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إعلاناتي'));
    await tester.pumpAndSettle();

    // كون الزرّين خارج شجرة InkWell فتح التصميم (لا عنصر تفاعلي داخل
    // عنصر تفاعلي آخر) يضمن أن لكل منهما عقدة إتاحة مستقلة بصفة button،
    // وSemantics.label الصريح يضمن اسمًا يقرأه قارئ الشاشة (تلميح
    // IconButton وحده لا يُترجم إلى aria-label في محرك الويب الحالي).
    final deleteData = tester.getSemantics(find.byTooltip('حذف'));
    expect(deleteData.flagsCollection.isButton, isTrue);
    expect(deleteData.label, 'حذف');

    final copyData = tester.getSemantics(find.byTooltip('نسخ النص'));
    expect(copyData.flagsCollection.isButton, isTrue);
    expect(copyData.label, 'نسخ النص');

    handle.dispose();
  });

  testWidgets('Trash screen restores an ad back to the library',
      (tester) async {
    final state = AppState();
    await _pumpApp(tester, state);
    await _reachMagicResults(tester);
    await tester.ensureVisible(find.text('حفظ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ').first);
    await tester.pumpAndSettle();
    // شريط تنبيه «تم الحفظ» يغطي أسفل الشاشة — ننتظر اختفاءه أولًا.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(Scaffold).last))
        .popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إعلاناتي'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('حذف'));
    // شريط تنبيه الحذف يغطي أسفل الشاشة — ننتظر اختفاءه.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('سلة المهملات'));
    await tester.pumpAndSettle();
    expect(find.textContaining('يُحذف نهائيًا خلال'), findsOneWidget);

    await tester.tap(find.text('استعادة'));
    await tester.pumpAndSettle();

    expect(state.savedAds, hasLength(1));
    expect(state.trashedAds, isEmpty);
    expect(find.text('سلة المهملات فارغة'), findsOneWidget);
  });

  testWidgets('Emptying the trash asks for confirmation before deleting forever',
      (tester) async {
    final state = AppState();
    await _pumpApp(tester, state);
    await _reachMagicResults(tester);
    await tester.ensureVisible(find.text('حفظ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ').first);
    await tester.pumpAndSettle();
    // شريط تنبيه «تم الحفظ» يغطي أسفل الشاشة — ننتظر اختفاءه أولًا.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(Scaffold).last))
        .popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إعلاناتي'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('حذف'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('سلة المهملات'));
    await tester.pumpAndSettle();

    // الإلغاء لا يحذف شيئًا.
    await tester.tap(find.text('إفراغ السلة'));
    await tester.pumpAndSettle();
    expect(find.text('إفراغ السلة نهائيًا؟'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(state.trashedAds, hasLength(1));

    // التأكيد يفرغ السلة نهائيًا.
    await tester.tap(find.text('إفراغ السلة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إفراغ نهائيًا'));
    await tester.pumpAndSettle();
    expect(state.trashedAds, isEmpty);
    expect(find.text('سلة المهملات فارغة'), findsOneWidget);
  });

  test('Expired trash items are purged automatically on load', () async {
    final oldAd = AdGenerator.preview(
      AdBrief(
        productName: 'قديم',
        description: '',
        tone: 'حماسي',
        platform: 'إنستغرام',
        format: 'منشور مربع',
      ),
    ).first;
    final fresh = TrashedAd(ad: oldAd, deletedAt: DateTime.now());
    final expired = TrashedAd(
      ad: oldAd,
      deletedAt: DateTime.now().subtract(const Duration(days: 40)),
    );

    SharedPreferences.setMockInitialValues({
      'trashed_ads': jsonEncode([fresh.toJson(), expired.toJson()]),
    });

    final state = await AppState.load();
    expect(state.trashedAds, hasLength(1));
    expect(
      state.trashedAds.single.deletedAt
          .difference(fresh.deletedAt)
          .inSeconds
          .abs(),
      lessThan(2),
    );
  });

  test('Orders route to the nearest partner print shop', () {
    // موقع في شمال الرياض → مطبعة العليا لا الشفا.
    expect(nearestShop(24.80, 46.65).name, 'مطبعة العليا');
    // موقع في جدة → مطبعة الروضة.
    expect(nearestShop(21.50, 39.20).name, 'مطبعة الروضة');
    // موقع في الدمام → مطبعة الشاطئ.
    expect(nearestShop(26.40, 50.10).name, 'مطبعة الشاطئ');
  });

  testWidgets('Brand Kit color selection persists into state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load();
    await _pumpApp(tester, state);

    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('هوية العلامة (Brand Kit)'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    final swatch =
        find.byKey(ValueKey('brand-swatch-${SettingsScreen.brandSwatches.first}'));
    await tester.ensureVisible(swatch);
    await tester.pumpAndSettle();
    await tester.tap(swatch);
    await tester.pump();

    expect(state.brandColorValue, SettingsScreen.brandSwatches.first);
    // اللون محفوظ ويُسترجع بعد «إعادة التشغيل».
    final reloaded = await AppState.load();
    expect(reloaded.brandColorValue, SettingsScreen.brandSwatches.first);
  });

  testWidgets('Brand font selection persists and applies to the design',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load();
    await _pumpApp(tester, state);

    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('خط العلامة'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    final cairoChip = find.byKey(const ValueKey('brand-font-cairo'));
    await tester.ensureVisible(cairoChip);
    await tester.pumpAndSettle();
    await tester.tap(cairoChip);
    await tester.pump();

    expect(state.brandFont, BrandFont.cairo);
    // الخط محفوظ ويُسترجع بعد «إعادة التشغيل».
    final reloaded = await AppState.load();
    expect(reloaded.brandFont, BrandFont.cairo);

    // يُطبَّق فعليًا على نصوص التصميم المولَّد، لا واجهة التطبيق فقط.
    final brief = AdBrief(
      productName: 'قهوة مختصة',
      description: '',
      tone: 'حماسي',
      platform: 'إنستغرام',
      format: 'منشور مربع',
      category: BusinessCategory.cafe,
    );
    final ad = AdGenerator.preview(brief).firstWhere((a) => a.kind == AdKind.image);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: AppStateScope(
          notifier: state,
          child: Scaffold(body: AdDesignPreview(ad: ad)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text(ad.headline),
    );
    expect(paragraph.text.style?.fontFamily, 'Cairo');
  });

  testWidgets('Settings screen toggles dark mode', (tester) async {
    final state = AppState();
    await _pumpApp(tester, state);

    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('داكن'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('داكن'));
    await tester.pumpAndSettle();

    expect(state.themeMode, ThemeMode.dark);
    final context = tester.element(find.text('المظهر'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
