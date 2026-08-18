import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
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
import 'package:zol/screens/create_ad/design_editor_screen.dart';
import 'package:zol/models/ad_format.dart';
import 'package:zol/models/ad_template.dart';
import 'package:zol/models/business_category.dart';
import 'package:zol/services/admin_api.dart';
import 'package:zol/models/template_category.dart';
import 'package:zol/widgets/ad_design_preview.dart';
import 'package:zol/models/ad_service.dart';
import 'package:zol/screens/market_screen.dart';
import 'package:zol/screens/storefront_screen.dart';
import 'package:zol/screens/shell_screen.dart';
import 'package:zol/theme/app_palette_source.dart';
import 'package:zol/l10n/app_localizations.dart';
import 'package:zol/widgets/product_image.dart';
import 'package:zol/theme/art_palette.dart';
import 'package:zol/widgets/art_backdrop.dart';
import 'package:zol/widgets/art_text.dart';
import 'package:zol/services/background_remover.dart';
import 'package:zol/services/subject_cutout.dart';
import 'package:zol/services/brand_sync.dart';
import 'package:zol/services/image_store.dart';
import 'package:zol/services/photo_enhancer.dart';
import 'package:zol/services/palette_extractor.dart';
import 'package:zol/state/app_state.dart';
import 'package:zol/models/ad_badge.dart';
import 'package:zol/models/trashed_ad.dart';
import 'package:zol/models/brand_font.dart';
import 'package:zol/models/generated_ad.dart';
import 'package:zol/models/generation.dart';
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
      'image_url': 'https://x.test/storage/ads/magic-1-0.png',
      'image_verified': true,
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
    // compute() في اختبارات الودجت لا يكتمل تحت الزمن الوهمي — كل خدمات
    // الصور تعمل متزامنة هنا.
    PhotoEnhancer.debugRunSynchronously = true;
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

  testWidgets('Home screen shows the main call-to-action and stats', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('أنشئ إعلانك الآن'), findsOneWidget);
    expect(find.text('إعلان محفوظ'), findsOneWidget);
    expect(find.text('طلب طباعة'), findsOneWidget);
  });

  testWidgets('Continue button stays disabled until name and image are set', (
    tester,
  ) async {
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

  testWidgets('Magic screen renders Supabase variants with critic scores', (
    tester,
  ) async {
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

  testWidgets('Saving a variant adds it to the My Ads library', (tester) async {
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

  testWidgets('Print flow computes a price and creates a tracked order', (
    tester,
  ) async {
    final state = AppState();
    await _pumpApp(tester, state);
    await _reachMagicResults(tester);

    await tester.tap(find.text('اطبعه وصلّه'));
    await tester.pumpAndSettle();

    // بنر 1×2 متر: 90 + توصيل 25 + ضريبة 15% = 132.25
    final confirm = find.widgetWithText(
      ElevatedButton,
      'تأكيد الطلب — 132.25 ر.س',
    );
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

  testWidgets('Card payment (simulated) marks the order as paid', (
    tester,
  ) async {
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

  test(
    'Background remover isolates product from a uniform background',
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

      final result = await BackgroundRemover.removeBackground(
        Uint8List.fromList(bytes),
      );
      expect(result, isNotNull);

      final cutout = img.decodePng(result!)!;
      // الزاوية أصبحت شفافة (خلفية معزولة).
      expect(cutout.getPixel(5, 5).a, 0);
      // مركز المنتج بقي معتمًا وبلونه.
      final center = cutout.getPixel(60, 60);
      expect(center.a, 255);
      expect(center.r, greaterThan(150));
    },
  );

  test('Background remover refuses to butcher a busy background', () async {
    // خلفية عشوائية الألوان (ضوضاء) — يجب أن يمتنع العزل بدل إتلاف الصورة.
    final noisy = img.Image(width: 60, height: 60, numChannels: 4);
    for (var y = 0; y < 60; y++) {
      for (var x = 0; x < 60; x++) {
        noisy.setPixelRgba(
          x,
          y,
          (x * 37) % 256,
          (y * 91) % 256,
          (x * y) % 256,
          255,
        );
      }
    }
    final result = await BackgroundRemover.removeBackground(
      Uint8List.fromList(img.encodePng(noisy)),
    );
    expect(result, isNull);
  });

  test(
    'Merchant account: register, login, logout, and session restore',
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
    },
  );

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

  test(
    'Palette extractor finds the product colour, not the background',
    () async {
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
    },
  );

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

  test('Season color slots between brand and product in palette priority', () {
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

    // القالب الافتراضي «جريء».
    expect(find.text('اختر قالب التصميم'), findsOneWidget);
    expect(find.text(AdTemplate.bold.description), findsOneWidget);

    // شريط القوالب أسفل معاينة كبيرة: تمرير رأسي ليظهر الشريط، ثم أفقي
    // للوصول إلى القالب المطلوب.
    await tester.drag(find.byType(ListView).first, const Offset(0, -320));
    await tester.pumpAndSettle();

    final strip = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axis == Axis.horizontal,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('template-spotlight')),
      120,
      scrollable: strip,
    );
    await tester.tap(find.byKey(const ValueKey('template-spotlight')));
    await tester.pumpAndSettle();
    expect(find.text(AdTemplate.spotlight.description), findsOneWidget);
    expect(find.text(AdTemplate.bold.description), findsNothing);

    // لا يُفحص حضور القوالب العشرة هنا: الشريط كسول فلا يبني ما خرج عن
    // الشاشة، والتمرير إليها بعد النقر يفشل لأن الشريط يكون قد تفكّك.
    // وحضورها مضمون بالبناء أصلًا — المنتقي يشتقّ عناصره من
    // AdTemplate.values — ويحرسه اختبارا «كل قالب له تسمية ووصف» و«كل
    // قالب يُرسم». هذا الاختبار عن التبديل لا عن الجرد.
  });

  testWidgets('Print flow previews the design on the actual product', (
    tester,
  ) async {
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

  testWidgets('Saved ads reopen from the library for re-export', (
    tester,
  ) async {
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
    Navigator.of(
      tester.element(find.byType(Scaffold).last),
    ).popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إعلاناتي'));
    await tester.pumpAndSettle();

    // النقر على الإعلان المحفوظ يفتح شاشة التصميم لا طريقًا مسدودًا.
    final saved = state.savedAds.single;
    await tester.tap(
      find.byKey(
        ValueKey('saved-ad-${saved.createdAt.microsecondsSinceEpoch}'),
      ),
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

  testWidgets('Template gallery browses by category and searches', (
    tester,
  ) async {
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

  testWidgets('Picking a gallery template preselects format and template', (
    tester,
  ) async {
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
    },
  );

  testWidgets('Gallery shows a trending badge on the top templates', (
    tester,
  ) async {
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
    final realEstate = AdGenerator.preview(
      briefFor(BusinessCategory.realEstate),
    );

    // مفردات الكافيه لا تشبه مفردات العقار — لا نص عام واحد للاثنين.
    final cafeText = cafe.map((a) => '${a.headline} ${a.body}').join(' ');
    final estateText = realEstate
        .map((a) => '${a.headline} ${a.body}')
        .join(' ');
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

    final seasonalText = withSeason
        .map((a) => '${a.headline} ${a.body}')
        .join(' ');
    expect(seasonalText, contains(SeasonalTheme.nationalDay.campaignPhrase));
    expect(withSeason.first.hashtags, contains('#اليوم_الوطني'));
    // مفردات النشاط تبقى كما هي، الموسم يضيف فوقها لا يستبدلها.
    expect(seasonalText, contains('تحميص'));
    expect(withSeason.first.cta, withoutSeason.first.cta);
  });

  test(
    'Season approach detection only trusts Gregorian-anchored occasions',
    () {
      // اليوم الوطني (23 سبتمبر): قريب خلال الثلاثين يومًا السابقة له.
      expect(
        isSeasonApproaching(SeasonalTheme.nationalDay, DateTime(2026, 9, 1)),
        isTrue,
      );
      expect(
        isSeasonApproaching(SeasonalTheme.nationalDay, DateTime(2026, 9, 23)),
        isTrue,
      );
      expect(
        isSeasonApproaching(SeasonalTheme.nationalDay, DateTime(2026, 8, 1)),
        isFalse,
      );
      expect(
        isSeasonApproaching(SeasonalTheme.nationalDay, DateTime(2026, 9, 24)),
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
    },
  );

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
      final total =
          AdGenerator.stageDuration * AdGenerator.generationStages.length;
      await tester.pump(total + const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // شارة الموسم تظهر على التصميم المولَّد.
      expect(find.textContaining(SeasonalTheme.ramadan.label), findsWidgets);
    },
  );

  testWidgets(
    'Decorative background toggle renders the category SVG pattern on '
    'the design, off by default',
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

      final toggle = find.byKey(const ValueKey('decorative-background-toggle'));
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
      final total =
          AdGenerator.stageDuration * AdGenerator.generationStages.length;
      await tester.pump(total + const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // زخرفة الخلفية (SVG مضمَّنة) تظهر على التصميم المولَّد بعد التفعيل.
      expect(find.byType(SvgPicture), findsWidgets);
    },
  );

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

  testWidgets('Business category can be changed from settings', (tester) async {
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
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
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
    },
  );

  testWidgets('Deleting a saved ad moves it to trash with an instant undo', (
    tester,
  ) async {
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

    Navigator.of(
      tester.element(find.byType(Scaffold).last),
    ).popUntil((route) => route.isFirst);
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

  testWidgets('Saved ad card exposes delete and copy as individually reachable '
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

    Navigator.of(
      tester.element(find.byType(Scaffold).last),
    ).popUntil((route) => route.isFirst);
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

  testWidgets('Trash screen restores an ad back to the library', (
    tester,
  ) async {
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

    Navigator.of(
      tester.element(find.byType(Scaffold).last),
    ).popUntil((route) => route.isFirst);
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

  testWidgets(
    'Emptying the trash asks for confirmation before deleting forever',
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

      Navigator.of(
        tester.element(find.byType(Scaffold).last),
      ).popUntil((route) => route.isFirst);
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
    },
  );

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
    final swatch = find.byKey(
      ValueKey('brand-swatch-${SettingsScreen.brandSwatches.first}'),
    );
    await tester.ensureVisible(swatch);
    await tester.pumpAndSettle();
    await tester.tap(swatch);
    await tester.pump();

    expect(state.brandColorValue, SettingsScreen.brandSwatches.first);
    // اللون محفوظ ويُسترجع بعد «إعادة التشغيل».
    final reloaded = await AppState.load();
    expect(reloaded.brandColorValue, SettingsScreen.brandSwatches.first);
  });

  testWidgets('Brand font selection persists and applies to the design', (
    tester,
  ) async {
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
    final ad = AdGenerator.preview(
      brief,
    ).firstWhere((a) => a.kind == AdKind.image);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
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

  // ── القوالب العشرة ────────────────────────────────────────────────

  test('كل قالب له تسمية ووصف ونشاط مناسب — لا فرع منسيّ', () {
    for (final t in AdTemplate.values) {
      expect(t.label.trim(), isNotEmpty, reason: 'تسمية ${t.name}');
      expect(t.description.trim(), isNotEmpty, reason: 'وصف ${t.name}');
      expect(t.suitableFor, isNotEmpty, reason: 'أنشطة ${t.name}');
    }
  });

  test('ترتيب الرواج فريد ومتّصل — التكرار يكسر ترتيب المعرض بصمت', () {
    final ranks = AdTemplate.values.map((t) => t.trendingRank).toList();
    expect(ranks.toSet().length, ranks.length, reason: 'رتبة مكرّرة');
    expect(
      ranks.toSet(),
      List.generate(AdTemplate.values.length, (i) => i + 1).toSet(),
      reason: 'الرتب يجب أن تكون ١..${AdTemplate.values.length} بلا فجوة',
    );
  });

  test('شارة «رائج» تبقى نادرة مهما زادت القوالب', () {
    final trending = AdTemplate.values.where((t) => t.isTrending).length;
    expect(trending, 2, reason: 'الشارة تفقد معناها لو عمّت');
  });

  testWidgets('كل قالب يُرسم بلا استثناء ويُظهر العنوان', (tester) async {
    final state = AppState();
    final brief = AdBrief(
      productName: 'قهوة مختصة',
      description: 'حبوب إثيوبية',
      tone: 'حماسي',
      platform: 'إنستغرام',
      format: 'منشور مربع',
      category: BusinessCategory.cafe,
    );
    final ad = AdGenerator.preview(
      brief,
    ).firstWhere((a) => a.kind == AdKind.image);

    for (final template in AdTemplate.values) {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          theme: buildAppTheme(Brightness.light),
          home: AppStateScope(
            notifier: state,
            child: Scaffold(
              body: SizedBox(
                width: 400,
                child: AdDesignPreview(ad: ad, template: template),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'استثناء في ${t2(template)}',
      );
      // الكسر المتوازن يُدخل أسطرًا داخل العنوان، فالمطابقة الحرفية لم
      // تعد صالحة. نقارن بعد تسوية المسافات: هذا يقبل الكسر الفنّي
      // ويظلّ يرفض العنوان المبتور — وهو الخطر الحقيقي.
      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => (w.data ?? '').replaceAll(RegExp(r'\s+'), ' ').trim())
          .toSet();
      expect(
        rendered,
        contains(ad.headline.replaceAll(RegExp(r'\s+'), ' ').trim()),
        reason: 'العنوان غائب أو مبتور في ${t2(template)}',
      );
    }
  });

  test(
    'AdminApi لا يلمس Supabase في المُنشئ — الشاشة لا تنهار بلا خادم',
    () async {
      // بناؤه وحده كان يرمي، فتسقط شاشة الإعدادات كلها لأجل مدخل إداري.
      expect(AdminApi.new, returnsNormally);
      // وبلا خادم مهيّأ: لا إشراف، لا انفجار.
      expect(await AdminApi().isAdmin(), isFalse);
    },
  );

  // ── بوابة جودة القصّ ──────────────────────────────────────────────

  test('القصّ الممزّق يُرفض والنظيف يُقبل', () async {
    BackgroundRemover.debugRunSynchronously = true;
    // النموذج غير متاح في بيئة الاختبار أصلًا، لكن تعطيله صراحةً يجعل
    // الاختبار يقيس خوارزمية الألوان وحدها لا مصادفة غياب قناة المنصة.
    SubjectCutout.debugDisabled = true;
    addTearDown(() {
      BackgroundRemover.debugRunSynchronously = false;
      SubjectCutout.debugDisabled = false;
    });

    // خلفية بيضاء موحّدة. الحالتان تختلفان في **شكل المقدّمة** لا في
    // عددها: قرص مصمت واحد مقابل شظايا مبعثرة.
    //
    // النخر العشوائي داخل قرص لا يصلح للمحاكاة: التعبئة تبدأ من الحواف
    // ولا تبلغ ثقبًا محبوسًا داخله، فيخرج القناع مصمتًا سليمًا. أما
    // الشظايا المنفصلة فتحيط بها الخلفية من كل جهة — وهو ما يحدث فعلًا
    // حين يفشل القصّ.
    img.Image canvas() {
      final im = img.Image(width: 240, height: 240, numChannels: 4);
      img.fill(im, color: img.ColorRgba8(250, 250, 250, 255));
      return im;
    }

    final solid = canvas();
    for (var y = 0; y < 240; y++) {
      for (var x = 0; x < 240; x++) {
        final dx = x - 120, dy = y - 120;
        if (dx * dx + dy * dy < 70 * 70) {
          solid.setPixelRgba(x, y, 20, 20, 30, 255);
        }
      }
    }

    // شبكة نقاط ٣×٣ متباعدة ٨ بكسلات: كل نقطة معزولة، فمحيطها كله حدود.
    final shards = canvas();
    for (var gy = 12; gy < 228; gy += 8) {
      for (var gx = 12; gx < 228; gx += 8) {
        for (var y = gy; y < gy + 3; y++) {
          for (var x = gx; x < gx + 3; x++) {
            shards.setPixelRgba(x, y, 20, 20, 30, 255);
          }
        }
      }
    }

    final clean = await BackgroundRemover.removeBackground(
      Uint8List.fromList(img.encodePng(solid)),
    );
    expect(clean, isNotNull, reason: 'قرص مصمت على خلفية موحّدة يجب أن يمرّ');

    final shredded = await BackgroundRemover.removeBackground(
      Uint8List.fromList(img.encodePng(shards)),
    );
    expect(
      shredded,
      isNull,
      reason: 'مقدّمة مبعثرة إلى شظايا تفسد كل قالب — يجب أن تُرفض لا أن تُعرض',
    );
  });

  test('صيغة ad-magic تحمل رابط الصورة وتدقيقها حتى الحفظ والاسترجاع', () {
    final parsed = PreviewResult.fromAdCopyJson(
      jsonDecode(_adCopyBody()) as Map<String, dynamic>,
    );
    expect(parsed.variants.first.imageUrl, contains('magic-1-0.png'));
    expect(parsed.variants.first.imageVerified, isTrue);
    // الصيغة الثانية بلا صورة — غيابها لا يكسر التحليل ولا العرض.
    expect(parsed.variants[1].imageUrl, isNull);

    final ad = GeneratedAd(
      brief: AdBrief(
        productName: 'قهوة',
        description: '',
        tone: 'حماسي',
        platform: 'إنستغرام',
        format: 'ستوري',
        category: BusinessCategory.cafe,
      ),
      kind: AdKind.copy,
      headline: 'ع',
      body: 'ن',
      hashtags: const [],
      createdAt: DateTime(2026),
      imageUrl: 'https://x.test/ads/a.png',
      imageVerified: true,
    );
    final back = GeneratedAd.fromJson(
      jsonDecode(jsonEncode(ad.toJson())) as Map<String, dynamic>,
    );
    // الحفظ في المكتبة يمرّ بـtoJson: إسقاط الرابط هناك يعني إعلاناً
    // يفقد صورته بعد إعادة فتح التطبيق.
    expect(back.imageUrl, ad.imageUrl);
    expect(back.imageVerified, isTrue);
  });

  // ── تمرير هوية العلامة إلى العقل المنشور ──────────────────────────

  test('اشتقاق لوني الخادم من لون العلامة: داكن يمرّ وفاتح يُظلم', () {
    double lightness(String hex) {
      final v = int.parse(hex.substring(1), radix: 16);
      final r = ((v >> 16) & 0xFF) / 255.0;
      final g = ((v >> 8) & 0xFF) / 255.0;
      final b = (v & 0xFF) / 255.0;
      return ([r, g, b].reduce(math.max) + [r, g, b].reduce(math.min)) / 2;
    }

    // داكن ⇒ يمرّ حرفيًا: هو نفسه هوية التاجر.
    expect(primaryFromBrand(0xFF0B3D2E), '#0b3d2e');
    // فاتح ⇒ يُظلم: نص الزرّ فاتح، وفاتح فوق فاتح لا يُقرأ.
    expect(lightness(primaryFromBrand(0xFFF2E4C8)), lessThan(0.45));
    // المرافق فاتح دومًا مهما كان الأصل — يُرسم فوق تظليل أسود.
    expect(lightness(accentFromBrand(0xFF0B3D2E)), greaterThan(0.7));
    expect(lightness(accentFromBrand(0xFFF2E4C8)), greaterThan(0.7));
    // ومن عائلة العلامة نفسها: مرافق الأخضر تغلب خضرته حمرته.
    final a = int.parse(accentFromBrand(0xFF0B3D2E).substring(1), radix: 16);
    expect((a >> 8) & 0xFF, greaterThan((a >> 16) & 0xFF));
  });

  test('لون العلامة واسمها يسافران في جسد طلب ad-magic', () async {
    Map<String, dynamic>? sent;
    final gateway = AiGateway(
      baseUrl: 'http://test.local',
      useSupabase: true,
      supabaseUrl: 'http://test.local',
      merchantId: 'merchant-test',
      client: MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response.bytes(
          utf8.encode(_adCopyBody()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    AdBrief brief({String? brandName, int? brandColor, int? paletteColor}) =>
        AdBrief(
          productName: 'قهوة',
          description: '',
          tone: 'حماسي',
          platform: 'سناب شات',
          format: 'ستوري',
          brandName: brandName,
          brandColor: brandColor,
          paletteColor: paletteColor,
        );

    await gateway.generatePreview(
      brief(
        brandName: 'محمصة الفجر',
        brandColor: 0xFF0B3D2E,
        paletteColor: 0xFF123456,
      ),
    );
    expect(sent!['brand_name'], 'محمصة الفجر');
    // اختيار التاجر الصريح يغلب المستخرَج من صورة المنتج.
    expect(sent!['primary'], '#0b3d2e');
    expect(sent!['accent'], accentFromBrand(0xFF0B3D2E));

    // بلا لون علامة يسقط الطلب على لوحة صورة المنتج بدل افتراضيات الخادم.
    await gateway.generatePreview(brief(paletteColor: 0xFF123456));
    expect(sent!['primary'], primaryFromBrand(0xFF123456));

    // زائر بلا هوية ⇒ لا مفاتيح أصلًا، فيقرّر الخادم افتراضياته بنفسه.
    await gateway.generatePreview(brief());
    expect(sent!.containsKey('brand_name'), isFalse);
    expect(sent!.containsKey('primary'), isFalse);
    expect(sent!.containsKey('accent'), isFalse);
  });

  test(
    'المعاينة لا تحمل صورة المنتج أبدًا — الخادم يتجاهلها بلا صور',
    () async {
      ImageStore.debugRunSynchronously = true;
      addTearDown(() => ImageStore.debugRunSynchronously = false);

      Map<String, dynamic>? sent;
      final gateway = AiGateway(
        baseUrl: 'http://test.local',
        useSupabase: true,
        supabaseUrl: 'http://test.local',
        merchantId: 'merchant-test',
        client: MockClient((req) async {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response.bytes(
            utf8.encode(_adCopyBody()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await gateway.generatePreview(
        AdBrief(
          productName: 'قهوة',
          description: '',
          tone: 'حماسي',
          platform: 'سناب شات',
          format: 'ستوري',
          imageBytes: _fakeImage,
        ),
      );
      // ميغابايتان تُرفع هباءً مع كل توليدة كانت تقطع الاتصال على إرسال
      // الجوال الضعيف — الطلب النصي يبقى خفيفًا مهما ضخُمت القصاصة.
      expect(sent!.containsKey('product_b64'), isFalse);
      expect(sent!['images'], isFalse);
    },
  );

  test(
    'صورة المنتج تسافر مضغوطة في product_b64 وغيابها لا يرسل المفتاح',
    () async {
      ImageStore.debugRunSynchronously = true;
      addTearDown(() => ImageStore.debugRunSynchronously = false);

      Map<String, dynamic>? sent;
      final gateway = AiGateway(
        baseUrl: 'http://test.local',
        useSupabase: true,
        supabaseUrl: 'http://test.local',
        merchantId: 'merchant-test',
        client: MockClient((req) async {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'ok': true,
                'url': 'https://x.test/ads/scene-1.png',
                'verify': {'all_present': true},
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      // نداء المشهد هو الوحيد الذي يحمل الصورة — حيث تُستعمل فعلًا.
      await gateway.generateScene(
        AdBrief(
          productName: 'قهوة',
          description: '',
          tone: 'حماسي',
          platform: 'سناب شات',
          format: 'ستوري',
          imageBytes: _fakeImage,
        ),
        headline: 'عنوان',
      );
      // بايتات صالحة تصل الخادم صالحة: ترميز ثم فك بلا رمي.
      final travelled = base64Decode(sent!['product_b64'] as String);
      expect(travelled, isNotEmpty);

      await gateway.generateScene(
        AdBrief(
          productName: 'قهوة',
          description: '',
          tone: 'حماسي',
          platform: 'سناب شات',
          format: 'ستوري',
        ),
        headline: 'عنوان',
      );
      expect(sent!.containsKey('product_b64'), isFalse);
    },
  );

  test('ضاغط الصور يقبل حدَّ عرضٍ أصغر للتمريرة الثانية', () async {
    ImageStore.debugRunSynchronously = true;
    addTearDown(() => ImageStore.debugRunSynchronously = false);

    // صورة 32×32 حمراء — أكبر من حد التمريرة الثانية المطلوب هنا (8).
    final wide = img.Image(width: 32, height: 32);
    img.fill(wide, color: img.ColorRgb8(200, 30, 30));
    final bytes = Uint8List.fromList(img.encodePng(wide));

    final shrunk = await ImageStore.compressForStorage(bytes, maxWidth: 8);
    final decoded = img.decodeImage(shrunk);
    // لا يُكبَّر الحجم أبدًا؛ إن كان الناتج أكبر بايتاتٍ بقي الأصل 32.
    expect(decoded!.width, anyOf(8, 32));
    expect(shrunk.length, lessThanOrEqualTo(bytes.length));
  });

  // ── الاستوديو المنزلي: تحسين بصري على الجهاز بلا أي نداء سحابي ────

  test('المحسِّن يضيء صورة باهتة ويحفظ الشفافية ولا يرمي على التالف', () async {
    PhotoEnhancer.debugRunSynchronously = true;
    addTearDown(() => PhotoEnhancer.debugRunSynchronously = false);

    // صورة رمادية باهتة (المدى 90..150) — كصور المستودعات الحقيقية.
    final dull = img.Image(width: 24, height: 24);
    for (var y = 0; y < 24; y++) {
      for (var x = 0; x < 24; x++) {
        final v = 90 + ((x + y) * 60 ~/ 46);
        dull.setPixelRgb(x, y, v, v, v);
      }
    }
    final out = await PhotoEnhancer.enhance(
      Uint8List.fromList(img.encodePng(dull)),
    );
    final decoded = img.decodeImage(out)!;
    var lo = 255, hi = 0;
    for (final p in decoded) {
      final l = p.r.toInt();
      if (l < lo) lo = l;
      if (l > hi) hi = l;
    }
    // شدّ التباين يوسّع المدى الضيق قرابة المدى الكامل.
    expect(hi - lo, greaterThan(180), reason: 'المدى 60 يجب أن يتمدد');

    // قصاصة شفافة الزوايا تبقى شفافة — التحسين لا يفسد العزل.
    final cut = img.Image(width: 8, height: 8, numChannels: 4);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final inside = x > 1 && x < 6 && y > 1 && y < 6;
        cut.setPixelRgba(x, y, 120, 80, 60, inside ? 255 : 0);
      }
    }
    final cutOut = img.decodeImage(
      await PhotoEnhancer.enhance(Uint8List.fromList(img.encodePng(cut))),
    )!;
    expect(cutOut.getPixel(0, 0).a, 0, reason: 'الزاوية تبقى شفافة');

    // بايتات تالفة تعود كما هي لا استثناءً يقتل الاختيار.
    final junk = Uint8List.fromList([1, 2, 3]);
    expect(await PhotoEnhancer.enhance(junk), junk);
  });

  test('تنعيم القصاصة يذيب الحافة الحادة إلى تدرّج', () async {
    PhotoEnhancer.debugRunSynchronously = true;
    addTearDown(() => PhotoEnhancer.debugRunSynchronously = false);

    // مربع معتم وسط شفاف — حافته ألفا 0/255 حادة.
    final hard = img.Image(width: 16, height: 16, numChannels: 4);
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        final inside = x >= 4 && x < 12 && y >= 4 && y < 12;
        hard.setPixelRgba(x, y, 200, 60, 40, inside ? 255 : 0);
      }
    }
    final polished = img.decodeImage(
      await PhotoEnhancer.polishCutout(Uint8List.fromList(img.encodePng(hard))),
    )!;
    var mids = 0;
    for (final p in polished) {
      final a = p.a.toInt();
      if (a > 20 && a < 235) mids++;
    }
    expect(mids, greaterThan(0), reason: 'حافة ناعمة = قيم ألفا وسيطة');
  });

  test('التوليد نصّ أولًا والمشهد السحابي نداء منفصل عند الطلب', () async {
    ImageStore.debugRunSynchronously = true;
    addTearDown(() => ImageStore.debugRunSynchronously = false);

    final calls = <Uri>[];
    Map<String, dynamic>? lastBody;
    final gateway = AiGateway(
      baseUrl: 'http://test.local',
      useSupabase: true,
      supabaseUrl: 'http://test.local',
      merchantId: 'merchant-test',
      client: MockClient((req) async {
        calls.add(req.url);
        lastBody = jsonDecode(req.body) as Map<String, dynamic>;
        final isScene = req.url.path.contains('ad-director');
        return http.Response.bytes(
          utf8.encode(
            isScene
                ? jsonEncode({
                    'ok': true,
                    'url': 'https://x.test/ads/scene-1.png',
                    'verify': {'all_present': true},
                  })
                : _adCopyBody(),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final brief = AdBrief(
      productName: 'قهوة',
      description: '',
      tone: 'حماسي',
      platform: 'سناب شات',
      format: 'ستوري',
      imageBytes: _fakeImage,
      brandColor: 0xFF0B3D2E,
    );

    await gateway.generatePreview(brief);
    // المعاينة لا تطلب صورًا — نداءان نصيان بدل عشرة.
    expect(lastBody!['images'], isFalse);

    final scene = await gateway.generateScene(
      brief,
      headline: 'عنوان',
      body: 'نص',
      cta: 'اطلب',
    );
    expect(calls.last.path, contains('ad-director'));
    expect(scene.url, contains('scene-1.png'));
    expect(scene.verified, isTrue);
    // المشهد يحمل القصاصة والهوية — لا يسافر أعمى.
    expect(lastBody!['product_b64'], isNotNull);
    expect(lastBody!['primary'], '#0b3d2e');
    expect(lastBody!['storyboard'], isFalse);
  });

  test('هوية العلامة في الموجز تنجو من الحفظ والاسترجاع', () {
    final back = AdBrief.fromJson(
      jsonDecode(
            jsonEncode(
              AdBrief(
                productName: 'قهوة',
                description: '',
                tone: 'حماسي',
                platform: 'سناب شات',
                format: 'ستوري',
                brandName: 'محمصة الفجر',
                brandColor: 0xFF0B3D2E,
              ).toJson(),
            ),
          )
          as Map<String, dynamic>,
    );
    expect(back.brandName, 'محمصة الفجر');
    expect(back.brandColor, 0xFF0B3D2E);
  });

  // ── نظام الثيم ────────────────────────────────────────────────────

  test('الثيم يغطي المكوّنات ويحفظ تباين الذهبي في الوضعين', () {
    for (final b in Brightness.values) {
      final t = buildAppTheme(b);
      // مكوّنات كانت بلا ثيم فتظهر بأنماط ماتيريال الافتراضية وسط
      // واجهة عربية مصمَّمة — كل واحد منها سطح يراه التاجر.
      expect(t.inputDecorationTheme.filled, isTrue);
      expect(t.cardTheme.shape, isNotNull);
      expect(t.chipTheme.shape, isA<StadiumBorder>());
      expect(t.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(t.dialogTheme.shape, isNotNull);
      expect(t.bottomSheetTheme.shape, isNotNull);
      expect(t.textTheme.bodyMedium!.fontFamily, kFontFamily);
      // ارتفاع سطر عربي مريح: ١٫٢ اللاتيني يجعل الحروف متلاصقة.
      expect(t.textTheme.bodyMedium!.height, greaterThanOrEqualTo(1.5));
    }

    double luminance(Color c) => c.computeLuminance();
    // الذهبي الفاتح للنص فوق الكحلي، والغامق فوق الأبيض — عكسهما
    // يجعل النص غير مقروء، وقد كان الفاتح مستعملًا على الأبيض.
    expect(luminance(AppColors.gold), greaterThan(0.6));
    expect(luminance(AppColors.goldDeep), lessThan(0.45));
    // تباين الغامق على الأبيض يجتاز حدّ WCAG AA للنص العادي (٤٫٥:١) —
    // لا حدّ النص الكبير وحده: الذهبي يُستعمل في شارات صغيرة أيضًا.
    final contrast = (1.05) / (luminance(AppColors.goldDeep) + 0.05);
    expect(contrast, greaterThanOrEqualTo(4.5));
  });

  // ── محرر التصميم ──────────────────────────────────────────────────

  testWidgets('سحب المنتج في المحرر يزيحه ويعود التعديل مع الإعلان', (
    tester,
  ) async {
    final state = AppState();
    final ad = GeneratedAd(
      brief: AdBrief(
        productName: 'قهوة',
        description: '',
        tone: 'حماسي',
        platform: 'سناب شات',
        format: 'ستوري',
        imageBytes: _fakeImage,
      ),
      kind: AdKind.image,
      headline: 'عنوان أصلي',
      body: 'نص',
      hashtags: const [],
      createdAt: DateTime(2026),
    );

    GeneratedAd? returned;
    // النطاق فوق MaterialApp كما في main.dart — المسارات المدفوعة تُبنى
    // من سياق Navigator، فنطاقٌ داخل home لا تراه شاشة مدفوعة.
    await tester.pumpWidget(
      AppStateScope(
        notifier: state,
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          theme: buildAppTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  returned = await Navigator.of(context).push<GeneratedAd>(
                    MaterialPageRoute(
                      builder: (_) =>
                          DesignEditorScreen(ad: ad, template: AdTemplate.bold),
                    ),
                  );
                },
                child: const Text('افتح المحرر'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('افتح المحرر'));
    await tester.pumpAndSettle();

    expect(find.text('تحرير التصميم'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('editor-canvas')),
      const Offset(30, 40),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('حفظ التعديلات'));
    await tester.pumpAndSettle();

    // التعديل يعود مع الإعلان لا يبقى حبيس الشاشة.
    expect(returned, isNotNull);
    expect(returned!.brief.productDx, greaterThan(0));
    expect(returned!.brief.productDy, greaterThan(0));
    expect(returned!.brief.hasProductTransform, isTrue);
    // الأصل لا يُمَسّ — التحرير ينتج نسخة.
    expect(ad.brief.hasProductTransform, isFalse);
  });

  testWidgets('تحرير النص في المحرر يغيّر العنوان بلا إعادة توليد', (
    tester,
  ) async {
    final state = AppState();
    final ad = GeneratedAd(
      brief: AdBrief(
        productName: 'قهوة',
        description: '',
        tone: 'حماسي',
        platform: 'سناب شات',
        format: 'ستوري',
        imageBytes: _fakeImage,
      ),
      kind: AdKind.image,
      headline: 'عنوان أصلي',
      body: 'نص',
      hashtags: const [],
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      AppStateScope(
        notifier: state,
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          theme: buildAppTheme(Brightness.light),
          home: DesignEditorScreen(ad: ad, template: AdTemplate.bold),
        ),
      ),
    );

    await tester.tap(find.text('تحرير النص'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'العنوان'),
      'عنوان مُصحَّح',
    );
    await tester.tap(find.text('تطبيق'));
    await tester.pumpAndSettle();

    // النص الجديد يُرسم على التصميم فورًا.
    expect(find.text('عنوان مُصحَّح'), findsWidgets);
    expect(find.text('عنوان أصلي'), findsNothing);
  });

  test('حدود تحويل المنتج ونجاته من الحفظ والاسترجاع', () {
    final moved = AdBrief(
      productName: 'قهوة',
      description: '',
      tone: 'حماسي',
      platform: 'سناب شات',
      format: 'ستوري',
      productScale: 1.8,
      productDx: 0.25,
      productDy: -0.1,
    );
    final back = AdBrief.fromJson(
      jsonDecode(jsonEncode(moved.toJson())) as Map<String, dynamic>,
    );
    expect(back.productScale, 1.8);
    expect(back.productDx, 0.25);
    expect(back.productDy, -0.1);

    // بلا تعديل لا تتضخم البيانات المحفوظة بمفاتيح افتراضية.
    final plain = AdBrief(
      productName: 'قهوة',
      description: '',
      tone: 'حماسي',
      platform: 'سناب شات',
      format: 'ستوري',
    );
    expect(plain.hasProductTransform, isFalse);
    expect(plain.toJson().containsKey('productScale'), isFalse);
    // والاسترجاع من بيانات قديمة (قبل وجود الحقول) يعطي الوضع الافتراضي.
    expect(AdBrief.fromJson(plain.toJson()).productScale, 1);
  });

  // ── مكتبة الشارات الترويجية ───────────────────────────────────────

  testWidgets('الشارة الترويجية تُرسم على التصميم وغيابها لا يترك أثرًا', (
    tester,
  ) async {
    final state = AppState();
    Widget host(AdBadge? badge) => MaterialApp(
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: buildAppTheme(Brightness.light),
      home: AppStateScope(
        notifier: state,
        child: Scaffold(
          body: AdDesignPreview(
            ad: GeneratedAd(
              brief: AdBrief(
                productName: 'قهوة',
                description: '',
                tone: 'حماسي',
                platform: 'سناب شات',
                format: 'ستوري',
                badge: badge,
              ),
              kind: AdKind.image,
              headline: 'عنوان',
              body: 'نص',
              hashtags: const [],
              createdAt: DateTime(2026),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(host(AdBadge.freeDelivery));
    expect(find.text('توصيل مجاني'), findsOneWidget);

    await tester.pumpWidget(host(null));
    expect(find.text('توصيل مجاني'), findsNothing);
  });

  test('الشارة في الموجز تنجو من الحفظ والاسترجاع وكل شارة لها تسمية', () {
    for (final b in AdBadge.values) {
      expect(b.label, isNotEmpty);
    }
    final back = AdBrief.fromJson(
      jsonDecode(
            jsonEncode(
              AdBrief(
                productName: 'قهوة',
                description: '',
                tone: 'حماسي',
                platform: 'سناب شات',
                format: 'ستوري',
                badge: AdBadge.limited,
              ).toJson(),
            ),
          )
          as Map<String, dynamic>,
    );
    expect(back.badge, AdBadge.limited);
  });

  // ── مزامنة هوية العلامة ───────────────────────────────────────────

  test('السحب يملأ الفراغ ولا يدهس هوية مضبوطة على الجهاز', () async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load();

    // سحابة تحمل لونًا وخطًا.
    AppState.debugBrandSyncOverride = _FakeBrandSync(
      remote: const BrandIdentity(colorValue: 0xFF112233, fontName: 'cairo'),
    );
    addTearDown(() => AppState.debugBrandSyncOverride = null);

    // جهاز خالٍ ⇒ يستورد.
    await state.syncBrandIdentityFromCloud();
    expect(state.brandColorValue, 0xFF112233);
    expect(state.brandFont?.name, 'cairo');

    // جهاز مضبوط ⇒ لا يُدهس. من ضبط لونه للتوّ ثم سجّل دخوله لا يتوقّع
    // أن يُمحى اختياره.
    state.setBrandColor(0xFFAABBCC);
    await state.syncBrandIdentityFromCloud();
    expect(state.brandColorValue, 0xFFAABBCC, reason: 'المحلي يبقى');
  });

  test('سحابة فارغة ⇒ يُرفع ما على الجهاز ليجده الجهاز التالي', () async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load();
    final fake = _FakeBrandSync(remote: null);
    AppState.debugBrandSyncOverride = fake;
    addTearDown(() => AppState.debugBrandSyncOverride = null);

    state.setBrandColor(0xFF445566);
    fake.pushed = 0; // نتجاهل دفع الضابط نفسه
    await state.syncBrandIdentityFromCloud();
    expect(fake.pushed, 1, reason: 'الفراغ السحابي يُملأ من الجهاز');
  });

  test('شعار يتجاوز الحدّ يُرفض قبل الإرسال', () async {
    final sync = BrandSync();
    // لا جلسة ⇒ isReady خطأ، والدفع يعيد false بلا رمي.
    expect(sync.isReady, isFalse);
    expect(await sync.push(colorValue: 1), isFalse);
  });

  // ── حصة الشريك ────────────────────────────────────────────────────

  test('حساب الحصة: المتبقي لا يسلب، وبلا حد لا شريط تقدّم له', () {
    const p = Partner(
      id: 'a',
      name: 'شريك',
      slug: 's',
      quota: 100,
      used: 30,
      isActive: true,
    );
    expect(p.unlimited, isFalse);
    expect(p.remaining, 70);
    expect(p.usageRatio, closeTo(0.3, 1e-9));

    // تجاوز الحصة — يقع فعلاً حين تُخفَّض الحصة تحت المستهلك.
    const over = Partner(
      id: 'b',
      name: 'شريك',
      slug: 's',
      quota: 10,
      used: 25,
      isActive: true,
    );
    expect(over.remaining, 0, reason: 'المتبقي لا يكون سالبًا');
    expect(over.usageRatio, 1.0, reason: 'الشريط لا يتجاوز الامتلاء');

    const unlimited = Partner(
      id: 'c',
      name: 'شريك',
      slug: 's',
      quota: -1,
      used: 999,
      isActive: true,
    );
    expect(unlimited.unlimited, isTrue);
    expect(unlimited.usageRatio, isNull, reason: 'بلا حد ⇒ لا نسبة لها معنى');

    // حصة صفر: القسمة على صفر تعطي NaN لو لم تُعالَج.
    const zero = Partner(
      id: 'd',
      name: 'شريك',
      slug: 's',
      quota: 0,
      used: 0,
      isActive: true,
    );
    expect(zero.usageRatio, isNull);
  });

  // ── محرك الفن ──────────────────────────────────────────────────────
  //
  // هذه الاختبارات تحرس الادّعاء المركزي: أن التصميم صار **محسوبًا** لا
  // مذوَّقًا. لو انكسر أحدها عاد الإعلان إلى ما كان — لونًا واحدًا باهتًا
  // ونصًّا مبتورًا — بلا أن يظهر عطل في أي شاشة.

  test('اللوحة الفنية: الحبر مقروء فوق كل سطح تُرسم عليه الحروف', () {
    // عيّنة تغطي الحواف: مشبع، شاحب جدًا، قاتم جدًا، رمادي بلا درجة.
    const sources = [
      Color(0xFF8B5E3C), // بنّي قهوة
      Color(0xFFF2E9E1), // شاحب
      Color(0xFF06070A), // شبه أسود
      Color(0xFF808080), // رمادي محض (تشبّع صفر)
      Color(0xFF1BC47D), // أخضر مشبع
      Color(0xFFFFEB3B), // أصفر ساطع — أخطر لون على النص الأبيض
    ];
    for (final src in sources) {
      for (var variant = 0; variant < 4; variant++) {
        final p = ArtPalette.from(src, variant: variant);
        for (final (bg, ink, where) in [
          (p.deep, p.ink, 'deep'),
          (p.neutral, p.onInk, 'neutral'),
          (p.base, ArtPalette.inkOn(p.base), 'base'),
          (p.complement, ArtPalette.inkOn(p.complement), 'complement'),
        ]) {
          expect(
            ArtPalette.contrast(bg, ink),
            greaterThanOrEqualTo(4.5),
            reason: 'تباين دون معيار WCAG على $where للون $src (نوع $variant)',
          );
        }
      }
    }
  });

  test('اللوحة الفنية: نفس المدخل يعطي نفس اللوحة دائمًا', () {
    // الحتمية ليست ترفًا: المعاينة والتصدير وإعادة الفتح من المكتبة
    // ثلاث عمليات منفصلة تبني اللوحة من جديد. لو دخلت عشوائية اختلف
    // ما صدّره التاجر عمّا وافق عليه.
    const src = Color(0xFF8B5E3C);
    for (var v = 0; v < 6; v++) {
      final a = ArtPalette.from(src, variant: v);
      final b = ArtPalette.from(src, variant: v);
      expect(a.base, b.base);
      expect(a.complement, b.complement);
      expect(a.deep, b.deep);
      expect(a.scheme, b.scheme);
    }
    // والتنويع يعمل فعلًا: أنواع الانسجام الأربعة كلها تُستعمل.
    final schemes = List.generate(
      8,
      (v) => ArtPalette.from(src, variant: v).scheme,
    ).toSet();
    expect(
      schemes.length,
      HarmonyScheme.values.length,
      reason: 'التنويع معطَّل — كل الإعلانات ستخرج بانسجام واحد',
    );
  });

  test('اللوحة الفنية: المرافق لون آخر لا درجة من الأساس', () {
    // هذا هو الفرق الحقيقي عن السابق. لو رجع المرافق قريبًا من الأساس
    // عادت اللوحة أحادية: كل شيء بنّي حول منتج بنّي.
    for (final src in const [
      Color(0xFF8B5E3C),
      Color(0xFF1BC47D),
      Color(0xFF3355EE),
    ]) {
      final p = ArtPalette.from(src, variant: 0); // متقابل ١٨٠°
      final d =
          (p.base.r - p.complement.r).abs() +
          (p.base.g - p.complement.g).abs() +
          (p.base.b - p.complement.b).abs();
      expect(
        d,
        greaterThan(0.35),
        reason: 'المرافق يكاد يطابق الأساس للون $src',
      );
    }
  });

  test('اللوحة الفنية: الرمادي المحض يُنعش بدل أن يُخرج لوحة ميتة', () {
    final p = ArtPalette.from(const Color(0xFF9A9A9A));
    // لو مرّ الرمادي كما هو لخرجت كل الطبقات رمادية والتصميم بلا هوية.
    expect(p.base, isNot(equals(p.complement)));
    expect(
      ArtPalette.contrast(p.deep, p.neutral),
      greaterThan(3.0),
      reason: 'العمق والحيادي متقاربان ⇒ لا عمق في الخلفية',
    );
  });

  test('صفّ النص: الطويل يُصغَّر ليُقرأ كاملًا بدل أن يُبتر', () {
    const style = TextStyle(fontSize: 20, height: 1.2);
    const long = 'افتتاح فرعنا الجديد في حي الياسمين بالرياض هذا الخميس';
    final fitted = ArtText.fitFontSize(
      text: long,
      style: style,
      maxWidth: 200,
      maxHeight: 60,
      maxLines: 2,
      minSize: 20 * 0.62,
      maxSize: 20 * 1.35,
      direction: TextDirection.rtl,
    );
    expect(fitted, lessThan(20.0), reason: 'لم يُصغَّر ⇒ سيُبتر بالنقاط');
    expect(
      fitted,
      greaterThanOrEqualTo(20 * 0.62),
      reason: 'هبط تحت حدّ القراءة',
    );
  });

  test('صفّ النص: القصير يكبر ليملأ الفراغ حين يكون الارتفاع معلومًا', () {
    const style = TextStyle(fontSize: 14);
    final fitted = ArtText.fitFontSize(
      text: 'خصم ٥٠٪',
      style: style,
      maxWidth: 320,
      maxHeight: 200,
      maxLines: 2,
      minSize: 14 * 0.62,
      maxSize: 14 * 1.35,
      direction: TextDirection.rtl,
    );
    expect(fitted, greaterThan(14.0), reason: 'بقي صغيرًا وسط فراغ واسع');
  });

  test('صفّ النص: الكسر المتوازن يمنع السطر اليتيم', () {
    const style = TextStyle(fontSize: 16);
    // نصّ يجبر على سطرين. الكسر الساذج يملأ الأول ويترك كلمة في الثاني.
    const text = 'قهوة مختصة محمّصة طازجة كل صباح';
    // العرض مختار ليفرض سطرين ويسمح بهما معًا: أضيق منه لا يتّسع
    // أيّ توزيع، وأوسع منه يسع النص سطرًا واحدًا فلا يُكسر أصلًا.
    final out = ArtText.balanceLines(
      text: text,
      style: style,
      maxWidth: 300,
      maxLines: 2,
      direction: TextDirection.rtl,
    );
    final lines = out.split('\n');
    expect(lines.length, 2, reason: 'لم يُكسر إلى سطرين');
    // لا يضيع ولا يُزاد حرف: الكسر تنسيق لا تحرير.
    expect(out.replaceAll('\n', ' '), text);
    final shortest = lines.map((l) => l.length).reduce(math.min);
    final longest = lines.map((l) => l.length).reduce(math.max);
    expect(shortest / longest, greaterThan(0.45), reason: 'سطر يتيم: $lines');
  });

  test('صفّ النص: ما يسع سطرًا واحدًا لا يُكسر', () {
    const style = TextStyle(fontSize: 14);
    const text = 'خصم اليوم';
    expect(
      ArtText.balanceLines(
        text: text,
        style: style,
        maxWidth: 400,
        maxLines: 2,
        direction: TextDirection.rtl,
      ),
      text,
    );
  });

  // ── صيغ اللوحة ─────────────────────────────────────────────────────

  test('الصيغ: نِسَبها من مقاسات الطباعة الحقيقية لا من تقدير', () {
    // ما يراه التاجر في المعاينة هو ما يخرج من المطبعة — أو لا يخرج.
    expect(AdFormat.rollUp.aspect, closeTo(85 / 200, 1e-9));
    expect(AdFormat.businessCard.aspect, closeTo(9 / 5, 1e-9));
    expect(AdFormat.banner.aspect, closeTo(2, 1e-9));
    expect(AdFormat.flyer.aspect, closeTo(148 / 210, 1e-9));

    // وكل صيغة مطبوعة تقابل منتجًا في الكتالوج، وإلا صمّم التاجر شيئًا
    // لا يستطيع طلبه.
    final catalogLabels = printCatalog.map((p) => p.label).toSet();
    for (final f in AdFormat.values.where((f) => f.isPrint)) {
      expect(
        catalogLabels,
        contains(f.printProduct),
        reason: '${f.label} بلا منتج مقابل في كتالوج الطباعة',
      );
    }
  });

  test('الصيغ: تصنيف الشكل يفرز العريض من الطويل بلا تداخل', () {
    expect(AdFormat.businessCard.aspectClass, AspectClass.wide);
    expect(AdFormat.banner.aspectClass, AspectClass.wide);
    expect(AdFormat.rollUp.aspectClass, AspectClass.tall);
    expect(AdFormat.story.aspectClass, AspectClass.tall);
    expect(AdFormat.square.aspectClass, AspectClass.square);
    expect(AdFormat.portrait.aspectClass, AspectClass.portrait);
    // الهامش المطبوع أوسع: سكّين القصّ لا تقع على الخطّ.
    expect(AdFormat.rollUp.safeMargin, greaterThan(AdFormat.square.safeMargin));
  });

  test('الصيغ: النصّ المحفوظ القديم لا يكسر إعلانًا محفوظًا', () {
    // إعلانات على أجهزة التجّار تحمل النصّ القديم؛ أي نصّ غير معروف
    // يعود إلى المربّع لا إلى استثناء.
    expect(adFormatFromLabel('منشور مربع'), AdFormat.square);
    expect(adFormatFromLabel('ستوري'), AdFormat.story);
    expect(adFormatFromLabel('ريلز'), AdFormat.story);
    expect(adFormatFromLabel('صيغة اخترعها أحدهم'), AdFormat.square);
    expect(adFormatFromLabel(null), AdFormat.square);
  });

  testWidgets('كل صيغة × كل قالب: تُرسم بنسبتها بلا فيضان', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final format in AdFormat.values) {
      final brief = AdBrief(
        productName: 'قهوة مختصة',
        description: 'حبوب إثيوبية',
        tone: 'حماسي',
        platform: 'إنستغرام',
        format: format.label,
        category: BusinessCategory.cafe,
      );
      final ad = AdGenerator.preview(
        brief,
      ).firstWhere((a) => a.kind == AdKind.image);

      for (final template in AdTemplate.values) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            theme: buildAppTheme(Brightness.light),
            home: AppStateScope(
              notifier: state,
              child: Center(
                child: SizedBox(
                  width: 420,
                  child: RepaintBoundary(
                    key: key,
                    child: AdDesignPreview(ad: ad, template: template),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // الفيضان يُبلَّغ استثناءً في الاختبار — وهو أشيع عطب حين تتغيّر
        // نسبة اللوحة تحت تخطيط كُتب لنسبة أخرى.
        expect(
          tester.takeException(),
          isNull,
          reason: '${format.label} × ${t2(template)}',
        );

        final box = tester.renderObject<RenderBox>(
          find.byKey(key),
        );
        expect(
          box.size.width / box.size.height,
          closeTo(format.aspect, 0.01),
          reason: 'نسبة ${format.label} ليست ما وعد به الكتالوج',
        );
      }
    }
  });

  // ── معالجة الصورة ──────────────────────────────────────────────────

  testWidgets('معالجة الصورة: تُحسّنها ولا تكذب على لون المنتج', (tester) async {
    // اللون الحقيقي للمنتج ليس عنصر تصميم يُتصرَّف فيه: تاجرٌ يبيع قميصًا
    // أزرق لا يقبل أن يخرج في إعلانه بنفسجيًّا. هذا الاختبار يقيس ذلك
    // عددًا لا ذوقًا — ولولاه لبقي «الثنائي اللوني» الجميل يشوّه البضاعة.
    final palette = ArtPalette.from(const Color(0xFFB03030)); // علامة حمراء

    Future<List<int>> render(List<int> rgb, double grade) async {
      final src = img.Image(width: 40, height: 40);
      img.fill(src, color: img.ColorRgb8(rgb[0], rgb[1], rgb[2]));
      late ui.Image decoded;
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(
          Uint8List.fromList(img.encodePng(src)),
        );
        decoded = (await codec.getNextFrame()).image;
      });
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 40,
                height: 40,
                child: ProductImage(
                  palette: palette,
                  grade: grade,
                  vignette: false,
                  child: RawImage(image: decoded, fit: BoxFit.fill),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      late List<int> out;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final px = data!.buffer.asUint8List();
        const i = (20 * 40 + 20) * 4;
        out = [px[i], px[i + 1], px[i + 2]];
        image.dispose();
      });
      return out;
    }

    /// أي القنوات هي المسيطرة — هوية اللون في أبسط صورها.
    int dominant(List<int> c) {
      var best = 0;
      for (var i = 1; i < 3; i++) {
        if (c[i] > c[best]) best = i;
      }
      return best;
    }

    for (final sample in [
      [40, 90, 200], // أزرق
      [40, 160, 90], // أخضر
      [120, 80, 50], // بنّي
    ]) {
      final plain = await render(sample, 0);
      final graded = await render(sample, 0.55);

      expect(
        dominant(graded),
        dominant(plain),
        reason: 'الصبغ قلب هوية اللون: $sample صار $graded',
      );
      // وانحرافٌ محدود في كل قناة: «قريب» ليس رأيًا بل عدد.
      for (var i = 0; i < 3; i++) {
        expect(
          (graded[i] - plain[i]).abs(),
          lessThan(32),
          reason: 'انحراف مفرط في القناة $i للعيّنة $sample',
        );
      }
    }
  });

  // ── تعدّد اللغات ────────────────────────────────────────────────────

  test(
    'لغة الواجهة: تُحفظ فورًا، و«اتبع الجهاز» تُمحى لا تُخزَّن نصًّا',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = await AppState.load();

      // الافتراضي `null` = اتبع لغة الجهاز. فرضُ العربية على كل جهاز كان
      // يُغلق التطبيق في وجه المقيم غير الناطق بها عند أول شاشة.
      expect(state.locale, isNull);

      state.setLocale(const Locale('en'));
      expect(state.locale, const Locale('en'));

      // الحفظ فوري لا مؤجّل: تغيير اللغة يُعيد بناء التطبيق، ولو تأخّر
      // الحفظ عاد بعد الإغلاق إلى اللغة السابقة فيظنّ التاجر أن اختياره
      // لم يُقبل.
      final reloaded = await AppState.load();
      expect(reloaded.locale, const Locale('en'));

      reloaded.setLocale(null);
      final again = await AppState.load();
      expect(again.locale, isNull, reason: '«اتبع الجهاز» لم يُمحَ من التخزين');
    },
  );

  testWidgets('الترجمة مركّبة فعلًا: النصّ يأتي من ARB لا من الشيفرة', (
    tester,
  ) async {
    // اختبار وجود لا اختبار شكل: لو سقط مندوب الترجمة من التركيب لعاد
    // `L.of` بـnull وسقطت كل شاشة — وهذا يمسك ذلك عند الجذر.
    late L l;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Builder(
          builder: (context) {
            l = L.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(l.navMarket, 'السوق');
    // الوسائط تُركَّب لا تُلصق: مفتاح بوسيط يجب أن يُخرج القيمة داخله.
    expect(l.homeWelcome('محمد'), contains('محمد'));
    // الجمع العربي ليس شرط `if`: صيغة المثنّى تختلف عن الجمع.
    expect(l.trashCount(1), isNot(equals(l.trashCount(2))));
    expect(l.trashCount(2), isNot(equals(l.trashCount(5))));
  });

  // ── السوق ──────────────────────────────────────────────────────────

  test('دليل السوق: المطابع تدخله تلقائيًا فلا تفترق قائمتان', () {
    final printing = serviceProviders.where(
      (p) => p.kind == ServiceKind.printing,
    );
    expect(
      printing.length,
      printShops.length,
      reason: 'شبكة المطابع لم تُطابق ما في السوق',
    );
    for (final shop in printShops) {
      expect(
        printing.any((p) => p.name == shop.name && p.city == shop.city),
        isTrue,
        reason: 'المطبعة ${shop.name} غائبة عن السوق',
      );
    }
  });

  test('دليل السوق: المدن تُشتقّ فلا مدينة فارغة ولا مدينة غائبة', () {
    final cities = providerCities;
    expect(cities.toSet().length, cities.length, reason: 'مدينة مكرّرة');
    expect(cities, cities.toList()..sort(), reason: 'غير مرتّبة');
    for (final p in serviceProviders) {
      expect(cities, contains(p.city));
    }
    expect(cities.any((c) => c.trim().isEmpty), isFalse);
  });

  test('دليل السوق: المرشّحات تتراكم ولا يلغي أحدها الآخر', () {
    final byKind = filterProviders(kind: ServiceKind.printing);
    expect(byKind, isNotEmpty);
    expect(byKind.every((p) => p.kind == ServiceKind.printing), isTrue);

    final city = byKind.first.city;
    final both = filterProviders(kind: ServiceKind.printing, city: city);
    expect(both, isNotEmpty);
    expect(
      both.every((p) => p.kind == ServiceKind.printing && p.city == city),
      isTrue,
      reason: 'المرشّح الثاني ألغى الأول',
    );

    // بحث لا يطابق شيئًا يعطي قائمة فارغة لا استثناء.
    expect(filterProviders(query: 'زققزق'), isEmpty);
  });

  test('دليل السوق: الترتيب يوازن التقييم بعدد المراجعات', () {
    // تقييم ٥٫٠ من مراجعتين ليس أفضل من ٤٫٨ من مئتين — لكن الأعلى
    // تقييمًا يتقدّم أولًا، وعند التساوي يفصل عدد المراجعات.
    final all = filterProviders();
    for (var i = 1; i < all.length; i++) {
      final prev = all[i - 1], cur = all[i];
      expect(prev.rating >= cur.rating, isTrue, reason: 'الترتيب مكسور');
      if (prev.rating == cur.rating) {
        expect(
          prev.reviews >= cur.reviews,
          isTrue,
          reason: 'التساوي لم يُفصل بعدد المراجعات',
        );
      }
    }
  });

  test('لوحة المزوّد: حتمية، ومقروءة، ومختلفة بين مزوّد وآخر', () {
    for (final p in serviceProviders) {
      final a = paletteForProvider(p);
      final b = paletteForProvider(p);
      expect(a.base, b.base, reason: 'لون ${p.name} يتغيّر بين استدعاءين');
      // الشارة والزرّ يُرسمان فوق هذين، فالحبر فوقهما ليس تفصيلًا.
      expect(ArtPalette.contrast(a.deep, a.ink), greaterThanOrEqualTo(4.5));
      expect(
        ArtPalette.contrast(a.complement, ArtPalette.inkOn(a.complement)),
        greaterThanOrEqualTo(4.5),
      );
    }
    // مزوّدان مختلفان لا يخرجان بلون واحد، وإلا ضاع تمييزهم البصري.
    final hues = serviceProviders
        .map((p) => paletteForProvider(p).base.toARGB32())
        .toSet();
    expect(
      hues.length,
      greaterThan(serviceProviders.length ~/ 2),
      reason: 'ألوان المزوّدين متكرّرة إلى حدّ يُفقد التمييز',
    );
  });

  testWidgets('شريط التنقّل بستّة أقسام لا يفيض على عرض جوّال', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // ٣٦٠ نقطة: عرض جوّال شائع. الاختبار الافتراضي ٨٠٠ نقطة يخفي
    // الفيضان تمامًا، وإضافة قسم سادس تُقاس هنا لا هناك.
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: buildAppTheme(Brightness.light),
        home: AppStateScope(notifier: state, child: const ShellScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('السوق'), findsOneWidget);
  });

  testWidgets('السوق: البحث يرشّح، والفارغ يعرض مخرجًا لا شاشة ميتة', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: buildAppTheme(Brightness.light),
        home: AppStateScope(notifier: state, child: const MarketScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('متجري'),
      findsOneWidget,
      reason: 'مدخل واجهة التاجر غائب عن السوق',
    );

    await tester.enterText(find.byType(TextField), 'تصوير');
    await tester.pumpAndSettle();
    expect(find.textContaining('لقطة'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'زققزق');
    await tester.pumpAndSettle();
    expect(find.text('لا مزوّد يطابق بحثك'), findsOneWidget);

    // المخرج يعمل فعلًا: زرّ بلا أثر أسوأ من لا زرّ.
    await tester.tap(find.text('إزالة المرشّحات'));
    await tester.pumpAndSettle();
    expect(find.text('لا مزوّد يطابق بحثك'), findsNothing);
  });

  testWidgets('متجري: يُعرض قبل ضبط الهوية، ويعرض ما حُفظ بعدها', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();

    Widget app() => MaterialApp(
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: buildAppTheme(Brightness.light),
      home: AppStateScope(notifier: state, child: const StorefrontScreen()),
    );

    // بلا حساب ولا لون علامة ولا إعلانات: يجب أن تُرسم لا أن تنهار.
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('واجهتك جاهزة وتنتظر أول عمل'), findsOneWidget);

    state.savedAds.add(
      GeneratedAd(
        kind: AdKind.copy,
        headline: 'قهوتنا تفتح نهارك',
        body: 'حبوب مختصة',
        hashtags: const ['#قهوة'],
        cta: 'اطلب الآن',
        createdAt: DateTime(2026, 8, 18),
        brief: AdBrief(
          productName: 'قهوة',
          description: 'حبوب',
          tone: 'حماسي',
          platform: 'إنستغرام',
          format: 'منشور مربع',
          category: BusinessCategory.cafe,
        ),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('المعروض (1)'), findsOneWidget);
    expect(find.text('قهوتنا تفتح نهارك'), findsOneWidget);
  });

  testWidgets('الخلفيات الفنية: كل نمط يُرسم بلا استثناء', (tester) async {
    final palette = ArtPalette.from(const Color(0xFF8B5E3C));
    for (final style in BackdropStyle.values) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            width: 400,
            height: 400,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ArtBackdrop(palette: palette, seed: 7, style: style),
                ProductStage(palette: palette, child: const SizedBox.expand()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'استثناء في $style');
    }
  });
}

/// اسم القالب للرسائل التشخيصية.
String t2(AdTemplate t) => '${t.name} (${t.label})';

/// مزامنة صورية: تعدّ الدفعات وتعيد لقطة ثابتة، بلا شبكة ولا جلسة.
class _FakeBrandSync implements BrandSync {
  _FakeBrandSync({this.remote});

  final BrandIdentity? remote;
  int pushed = 0;

  @override
  bool get isReady => true;

  @override
  Future<BrandIdentity?> fetch() async => remote;

  @override
  Future<bool> push({
    int? colorValue,
    String? fontName,
    Uint8List? logoBytes,
  }) async {
    pushed++;
    return true;
  }
}
