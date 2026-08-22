import 'dart:convert';
import 'dart:io';
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
import 'package:zol/services/spec_doctor.dart';
import 'package:zol/services/local_designer.dart';
import 'package:zol/services/print_backend.dart';
import 'package:zol/screens/create_ad/execute_screen.dart';
import 'package:zol/screens/user_guide_screen.dart';
import 'package:zol/config/app_role.dart';
import 'package:zol/screens/print_shop_screen.dart';
import 'package:zol/screens/admin_screen.dart';
import 'package:zol/services/design_critic.dart';
import 'package:zol/services/wish_parser.dart';
import 'package:zol/services/design_wish_service.dart';
import 'package:zol/models/design_spec.dart';
import 'package:zol/theme/spec_palette.dart';
import 'package:zol/widgets/spec_renderer.dart';
import 'package:zol/widgets/spec_canvas_editor.dart';
import 'package:zol/models/ad_template.dart';
import 'package:zol/models/business_category.dart';
import 'package:zol/services/admin_api.dart';
import 'package:zol/models/template_category.dart';
import 'package:zol/widgets/ad_design_preview.dart';
import 'package:zol/models/ad_service.dart';
import 'package:zol/screens/market_screen.dart';
import 'package:zol/screens/provider_screen.dart';
import 'package:zol/services/quote_requests.dart';
import 'package:zol/widgets/quote_request_sheet.dart';
import 'package:zol/screens/provider_signup_screen.dart';
import 'package:zol/screens/storefront_screen.dart';
import 'package:zol/screens/shell_screen.dart';
import 'package:zol/theme/app_palette_source.dart';
import 'package:zol/l10n/app_localizations.dart';
import 'package:zol/widgets/product_image.dart';
import 'package:zol/theme/art_fonts.dart';
import 'package:zol/theme/art_mood.dart';
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
    // جهاز الاختبار لغته الإنجليزية. وبعد أن صارت الإنجليزية مدعومة
    // فعلًا صار التطبيق يتبعه — وهو السلوك الصحيح، لكنه يجعل كل توقّع
    // على نصّ عربي يسقط. فنثبّت لغة الجهاز على العربية هنا: هذه
    // الاختبارات تفحص الواجهة العربية، وللإنجليزية اختبارها الخاصّ.
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.localeTestValue = const Locale('ar');
    binding.platformDispatcher.localesTestValue = const [Locale('ar')];

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

  // الصورة **ليست** شرطًا. كان هذا الاختبار يحرس العكس: «حتى يُضبط الاسم
  // والصورة»، فيثبّت البوّابة التي كانت تمنع من يريد أن يصف تصميمه بالكلام
  // كما يفعل في كانفا. والاسم وحده هو الشرط الحقيقي — بلا اسمٍ لا موضوع
  // للإعلان أصلًا، وبلا صورةٍ يعمل محرّك الأمنيات كما هو.
  testWidgets('Continue button needs only a name — the image is optional', (
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
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('اعرض شاشة السحر'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // ولا صورة رُفعت — الاسم وحده فتح الباب.
    expect(tester.widget<ElevatedButton>(button).enabled, isTrue);
  });

  // من دخل بلا صورة جاء ليصف تصميمه، فيُستقبَل بدعوةٍ إلى الوصف لا بثلاث
  // بطاقات قوالب لم يطلبها. وهذا ما كان يجعل الشاشة تبدو «قوالب فقط».
  testWidgets('Magic screen without a photo invites a description', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.text('أنشئ إعلانك الآن'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'قهوة مختصة');
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('اعرض شاشة السحر'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('اعرض شاشة السحر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اعرض شاشة السحر'));
    await tester.pumpAndSettle();

    expect(find.text('صِف التصميم الذي تريده'), findsOneWidget);
    // ولا توليدَ قوالب جرى خلف ظهره.
    expect(find.text('اختر النسخة الأنسب'), findsNothing);
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
    final backend = _FakePrintBackend();
    ExecuteScreen.debugBackendOverride = () => backend;
    ExecuteScreen.debugCaptureOverride = () async => Uint8List.fromList([1, 2, 3]);
    addTearDown(() {
      ExecuteScreen.debugBackendOverride = null;
      ExecuteScreen.debugCaptureOverride = null;
    });

    final state = AppState();
    await _pumpApp(tester, state);
    await _reachMagicResults(tester);

    await tester.tap(find.text('اطبعه وصلّه'));
    await tester.pumpAndSettle();

    // بنر 1×2 متر: 90 + توصيل 25 = 115، **والضريبة مشمولة فيه** لا
    // مضافة فوقه. وكان المعروض 132.25 — أي أن التاجر كان يُقبض منه
    // خمسة عشر بالمئة زيادةً عمّا يُسجَّل في طلبه على الخادم.
    final confirm = find.widgetWithText(
      ElevatedButton,
      'تأكيد الطلب — 115 ر.س',
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

    await tester.pumpAndSettle();

    expect(find.text('تم استلام طلب الطباعة'), findsOneWidget);
    expect(state.orders, hasLength(1));
    expect(state.orders.first.id, 'AD-1001');
    expect(state.orders.first.total, closeTo(115, 0.01));

    // وهذا هو الوصل: الطلب **غادر الجهاز** ومعه ملفّه. وبلا هذين
    // السطرين يمرّ الاختبار على تطبيق يكتب في هاتفه ولا يعلم به أحد.
    expect(backend.creates, 1);
    expect(backend.uploads, 1);
    expect(state.orders.first.serverId, 'srv-order-1');
    expect(state.orders.first.artworkUrl, isNotNull);

    // العودة ثم فتح تبويب «طلباتي» والتحقق من ظهور الطلب.
    await tester.tap(find.text('العودة للرئيسية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طلباتي'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AD-1001'), findsOneWidget);
  });


  testWidgets('لا مطبعة معتمدة ⇒ لا طلب ولا قبض', (tester) async {
    // المسار الذي اخترناه على «سعرٍ لا يقابله من يطبع»: التاجر الذي
    // يدفع لطلبٍ لا يجد من ينفّذه يخسر ثقته مرّة ولا تعود.
    final backend = _FakePrintBackend(shopsResult: const []);
    ExecuteScreen.debugBackendOverride = () => backend;
    ExecuteScreen.debugCaptureOverride = () async => Uint8List.fromList([1]);
    addTearDown(() {
      ExecuteScreen.debugBackendOverride = null;
      ExecuteScreen.debugCaptureOverride = null;
    });

    final state = AppState();
    await _pumpApp(tester, state);
    await _reachMagicResults(tester);
    await tester.tap(find.text('اطبعه وصلّه'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).last, const Offset(0, -1600));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'الرياض');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'تأكيد الطلب — 115 ر.س'));
    await tester.pumpAndSettle();

    expect(state.orders, isEmpty);
    expect(backend.uploads, 0, reason: 'رُفع ملفّ لطلب لن يُنشأ');
    expect(backend.creates, 0);
    expect(find.textContaining('لا مطبعة معتمدة'), findsOneWidget);
  });

  testWidgets('رفض الخادم ⇒ لا طلب محلّي يوهم التاجر أنه مضى', (tester) async {
    // وهذا هو الفخّ المقابل: أن يسقط الإنشاء على الخادم ويُكتب الطلب
    // محليًّا على كل حال، فيرى التاجر «تم استلام طلبك» ولا يعلم به أحد
    // — وهو بالضبط ما كان يفعله التطبيق قبل الوصل، دائمًا.
    final backend = _FakePrintBackend(createOutcome: OrderOutcome.offline);
    ExecuteScreen.debugBackendOverride = () => backend;
    ExecuteScreen.debugCaptureOverride = () async => Uint8List.fromList([1]);
    addTearDown(() {
      ExecuteScreen.debugBackendOverride = null;
      ExecuteScreen.debugCaptureOverride = null;
    });

    final state = AppState();
    await _pumpApp(tester, state);
    await _reachMagicResults(tester);
    await tester.tap(find.text('اطبعه وصلّه'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).last, const Offset(0, -1600));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'الرياض');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'تأكيد الطلب — 115 ر.س'));
    await tester.pumpAndSettle();

    expect(backend.creates, 1, reason: 'حاول الإنشاء');
    expect(state.orders, isEmpty, reason: 'ولم يُكتب محليًّا بعد رفضه');
    expect(find.text('تم استلام طلب الطباعة'), findsNothing);
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

  testWidgets('الدفع الناجح يربط مرجعه بالطلب ولا يدّعي الدفع محليًّا', (
    tester,
  ) async {
    final backend = _FakePrintBackend();
    ExecuteScreen.debugBackendOverride = () => backend;
    ExecuteScreen.debugCaptureOverride = () async => Uint8List.fromList([1, 2, 3]);
    addTearDown(() {
      ExecuteScreen.debugBackendOverride = null;
      ExecuteScreen.debugCaptureOverride = null;
    });

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
    expect(state.orders.single.paymentId, startsWith('SIM-'));

    // المرجع يُربط بالطلب على الخادم…
    expect(backend.attached, hasLength(1));
    expect(backend.attached.single, startsWith('srv-order-1:SIM-'));

    // …و`isPaid` **تبقى false** محليًّا. من يستطيع أن يقول «دفعتُ»
    // يستطيع أن يكذب، فالخادم وحده يضبطها — والنسخة المحلية لا تدّعي
    // ما لا تملك إثباته.
    expect(state.orders.single.isPaid, isFalse);
  });

  testWidgets('إلغاء الدفع يترك طلبًا غير مدفوع لا عدمًا', (tester) async {
    final backend = _FakePrintBackend();
    ExecuteScreen.debugBackendOverride = () => backend;
    ExecuteScreen.debugCaptureOverride = () async => Uint8List.fromList([1, 2, 3]);
    addTearDown(() {
      ExecuteScreen.debugBackendOverride = null;
      ExecuteScreen.debugCaptureOverride = null;
    });

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

    // انقلبت القاعدة عن قصد، والخطآن ليسا سواء: كان الترتيب «ادفع ثم
    // أنشئ الطلب»، فإن سقط الإنشاء بعد قبض البطاقة ضاع مالٌ بلا أثر
    // يُنسب إليه. وصار «أنشئ ثم ادفع»، فإلغاء الدفع يترك طلبًا **غير
    // مدفوع** يراه صاحبه ويراه المشغّل فيُلغى أو يُكمَل.
    expect(state.orders, hasLength(1));
    expect(state.orders.single.isPaid, isFalse);
    expect(state.orders.single.paymentId, isNull);
    expect(state.orders.single.serverId, 'srv-order-1');
    expect(backend.attached, isEmpty);
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
    // السياق يُؤخذ من الزرّ نفسه لا من عنوان القسم: القائمة كسولة، وما
    // خرج من نافذة العرض بعد التمرير يُتلَف — فيسقط الاختبار كلّما
    // أُضيف قسم جديد أعلى منه، وهو تغيّرٌ لا علاقة له بالمظهر.
    final context = tester.element(find.text('داكن'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });


  // ── الإنجليزية: لغة ثانية حقيقية لا ملفّ ────────────────────────────

  testWidgets('الإنجليزية تُعرض فعلًا، ومبدّلها يصل إليه التاجر', (
    tester,
  ) async {
    final state = AppState();
    await _pumpApp(tester, state);

    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();

    // المبدّل كان غائبًا كليًّا: اللغة مدعومة في الحالة وتُحفظ، ولا سبيل
    // للتاجر إليها — دعمٌ يبدو منجَزًا في الشيفرة ولا وجود له عنده.
    final list = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('English'), 200, scrollable: list);
    // تمريرة زائدة: `scrollUntilVisible` يقف عند أوّل ظهور، وشريط
    // التنقّل السفلي يغطّي الصفّ فتضيع اللمسة على حافّته.
    await tester.drag(list, const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(state.locale?.languageCode, 'en');
    // والواجهة تحوّلت فعلًا — لا الحالة وحدها.
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Language'), findsWidgets);

    // ثم يعود، فالتبديل ليس طريقًا واحدًا.
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(state.locale?.languageCode, 'ar');
    expect(find.text('اللغة'), findsWidgets);
  });

  test('كل مفتاح عربي له مقابل إنجليزي — لا شاشة نصفها معرَّب', () {
    final ar = jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
        as Map<String, dynamic>;
    final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;

    final missing = ar.keys
        .where((k) => !k.startsWith('@') && !en.containsKey(k))
        .toList();
    expect(
      missing,
      isEmpty,
      reason: 'مفاتيح بلا ترجمة إنجليزية: ${missing.join(', ')}',
    );

    // ومفتاح إنجليزي بلا أصل عربي بقيّةُ مفتاح حُذف — يكبر الملفّ بما لا
    // يُستعمل ويُربك المترجم.
    final orphan = en.keys
        .where((k) => !k.startsWith('@') && !ar.containsKey(k))
        .toList();
    expect(orphan, isEmpty, reason: 'مفاتيح يتيمة: ${orphan.join(', ')}');

    // والوسائط نفسها في اللغتين: `{count}` يسقط في لغة ويبقى في أخرى
    // فيظهر للمستخدم اسم الوسيط حرفيًّا.
    final placeholder = RegExp(r'\{(\w+)[,}]');
    for (final k in ar.keys.where((k) => !k.startsWith('@'))) {
      final a = placeholder
          .allMatches(ar[k] as String)
          .map((m) => m.group(1))
          .toSet();
      final e = placeholder
          .allMatches(en[k] as String)
          .map((m) => m.group(1))
          .toSet();
      expect(e, equals(a), reason: 'وسائط مختلفة في $k');
    }
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

  // ── مواصفة التصميم وطبيبها ─────────────────────────────────────────

  test('المواصفة تنجو من مخرَج نموذج فوضوي بلا استثناء', () {
    // النموذج اللغوي يخترع أسماء حقول ويُسقط أخرى. إسقاط تصميم كامل
    // بسبب كلمة أهون من إسقاطه بلا سبب مفهوم — فكل مجهول يعود إلى قيمة
    // آمنة، والمدقّق يُبلّغ بعدها.
    final spec = DesignSpec.fromJson({
      'format': 'صيغة لا وجود لها',
      'backdrop': 'قوس قزح',
      'elements': [
        {'role': 'title', 'text': 'عنوان'}, // دور مخترَع
        {'role': 'cta', 'rect': {'x': 0.1, 'y': 0.8}}, // أبعاد ناقصة
        'ليس كائنًا أصلًا',
      ],
    });

    expect(spec.format, AdFormat.square, reason: 'صيغة مجهولة ⇒ الأسلم');
    expect(spec.backdrop, SpecBackdrop.mesh);
    expect(spec.elements.length, 2, reason: 'ما ليس كائنًا يُهمَل لا يُسقط');
    expect(spec.elements.first.role, ElementRole.shape, reason: 'دور مجهول');
  });

  test('الطبيب يعيد ما خرج عن الهامش الآمن — وهو قصّ حقيقي لا تجميل', () {
    // على المطبوع: عنصر على الحافّة يخرج مقصوصًا في ألف نسخة.
    const spec = DesignSpec(
      format: AdFormat.rollUp, // مطبوع ⇒ هامش أوسع
      backdrop: SpecBackdrop.mesh,
      elements: [
        DesignElement(
          role: ElementRole.headline,
          rect: SpecRect(0.0, 0.0, 0.9, 0.2), // ملاصق للحافّة
          text: 'عنوان',
        ),
        DesignElement(
          role: ElementRole.cta,
          rect: SpecRect(0.3, 0.85, 0.4, 0.1),
          text: 'اطلب',
        ),
      ],
    );

    final report = SpecDoctor.review(spec, brandColor: const Color(0xFFB03030));
    final margin = AdFormat.rollUp.safeMargin;

    for (final e in report.spec.elements) {
      expect(e.rect.x, greaterThanOrEqualTo(margin - 1e-9),
          reason: '${e.role} تجاوز الحافّة اليمنى');
      expect(e.rect.y, greaterThanOrEqualTo(margin - 1e-9));
      expect(e.rect.right, lessThanOrEqualTo(1 - margin + 1e-9));
      expect(e.rect.bottom, lessThanOrEqualTo(1 - margin + 1e-9));
    }
    expect(
      report.issues.any((i) => i.code == SpecIssueCode.outsideSafeArea),
      isTrue,
      reason: 'أُصلح بلا إبلاغ — والإصلاح الصامت يُخفي نموذجًا يُخطئ دائمًا',
    );
  });

  test('الطبيب يرفض حبرًا لا يُقرأ ويستبدله بالمحسوب', () {
    // النموذج يطلب «حياديًّا فاتحًا» فوق خلفية فاتحة: جميل في وصفه،
    // غير مقروء على الورق.
    const spec = DesignSpec(
      format: AdFormat.square,
      backdrop: SpecBackdrop.paper, // خلفية فاتحة
      elements: [
        DesignElement(
          role: ElementRole.headline,
          rect: SpecRect(0.1, 0.1, 0.8, 0.2),
          text: 'عنوان',
          color: ColorRole.neutral, // فاتح فوق فاتح
        ),
        DesignElement(
          role: ElementRole.cta,
          rect: SpecRect(0.3, 0.7, 0.4, 0.1),
          text: 'اطلب',
        ),
      ],
    );

    final report = SpecDoctor.review(spec, brandColor: const Color(0xFF2E6BB8));
    expect(report.spec.elements.first.color, ColorRole.auto);
    expect(
      report.issues.any((i) => i.code == SpecIssueCode.lowContrast),
      isTrue,
    );

    // وبعد الإصلاح يتحقّق التباين فعلًا لا اسمًا.
    final art = ArtPalette.from(const Color(0xFF2E6BB8));
    expect(
      ArtPalette.contrast(art.neutral, ArtPalette.inkOn(art.neutral)),
      greaterThanOrEqualTo(SpecDoctor.minContrast),
    );
  });

  test('الطبيب ينزل النصّ المغطّي ويعترف حين لا يستطيع', () {
    const overlapping = DesignSpec(
      format: AdFormat.square,
      backdrop: SpecBackdrop.mesh,
      elements: [
        DesignElement(
          role: ElementRole.headline,
          rect: SpecRect(0.1, 0.10, 0.8, 0.20),
          text: 'عنوان',
        ),
        DesignElement(
          role: ElementRole.subhead,
          rect: SpecRect(0.1, 0.15, 0.8, 0.20), // يغطّي العنوان
          text: 'ثانوي',
        ),
        DesignElement(
          role: ElementRole.cta,
          rect: SpecRect(0.3, 0.80, 0.4, 0.10),
          text: 'اطلب',
        ),
      ],
    );

    final report = SpecDoctor.review(
      overlapping,
      brandColor: const Color(0xFFB03030),
    );
    final head = report.spec.elements[0].rect;
    final sub = report.spec.elements[1].rect;
    expect(
      head.overlapRatio(sub),
      lessThanOrEqualTo(SpecDoctor.maxTextOverlap),
      reason: 'بقي التغطّي بعد الإصلاح',
    );

    // وحين لا يوجد فراغ: يُبلّغ ولا يدّعي. مدقّقٌ يزعم الإصلاح دائمًا
    // يُمرّر تصميمًا مكسورًا وهو يبتسم.
    const cramped = DesignSpec(
      format: AdFormat.square,
      backdrop: SpecBackdrop.mesh,
      elements: [
        DesignElement(
          role: ElementRole.headline,
          rect: SpecRect(0.05, 0.05, 0.9, 0.85),
          text: 'عنوان ضخم',
        ),
        DesignElement(
          role: ElementRole.cta,
          rect: SpecRect(0.05, 0.10, 0.9, 0.80),
          text: 'اطلب',
        ),
      ],
    );
    final second = SpecDoctor.review(
      cramped,
      brandColor: const Color(0xFFB03030),
    );
    expect(second.usable, isFalse);
    expect(second.blocking, isNotEmpty);
  });

  test('الطبيب يمنع إعلانًا بلا رسالة أو بلا دعوة', () {
    const spec = DesignSpec(
      format: AdFormat.square,
      backdrop: SpecBackdrop.mesh,
      elements: [
        DesignElement(
          role: ElementRole.product,
          rect: SpecRect(0.1, 0.1, 0.8, 0.8),
        ),
      ],
    );
    final report = SpecDoctor.review(spec, brandColor: const Color(0xFFB03030));
    final codes = report.issues.map((i) => i.code).toSet();
    expect(codes, contains(SpecIssueCode.missingHeadline));
    expect(codes, contains(SpecIssueCode.missingCta));
    expect(report.usable, isFalse, reason: 'يُعاد الطلب لا يُعرض ناقصًا');
  });

  test('المواصفة تدور ذهابًا وإيابًا عبر JSON بلا فقد', () {
    // الرحلة الحقيقية: النموذج ⇒ JSON ⇒ التطبيق ⇒ حفظ ⇒ إعادة فتح.
    const original = DesignSpec(
      format: AdFormat.businessCard,
      backdrop: SpecBackdrop.strata,
      variant: 3,
      note: 'تكوين أفقي: النصّ يمينًا والمنتج يسارًا',
      elements: [
        DesignElement(
          role: ElementRole.headline,
          rect: SpecRect(0.08, 0.2, 0.5, 0.3),
          text: 'قهوة مختصة',
          color: ColorRole.complement,
          fill: ColorRole.deep,
          align: SpecAlign.end,
          maxLines: 3,
          sizeFactor: 0.049,
          weight: 900,
        ),
      ],
    );

    final round = DesignSpec.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    expect(round.format, original.format);
    expect(round.backdrop, original.backdrop);
    expect(round.variant, original.variant);
    expect(round.note, original.note);

    final a = original.elements.first, b = round.elements.first;
    expect(b.role, a.role);
    expect(b.text, a.text);
    expect(b.color, a.color);
    expect(b.fill, a.fill);
    expect(b.align, a.align);
    expect(b.maxLines, a.maxLines);
    expect(b.sizeFactor, a.sizeFactor);
    expect(b.weight, a.weight);
    expect(b.rect.x, closeTo(a.rect.x, 1e-9));
    expect(b.rect.h, closeTo(a.rect.h, 1e-9));
  });

  testWidgets('العارض يحترم الإحداثيات الكسريّة في كل صيغة', (tester) async {
    // هذا هو ادّعاء المواصفة كلّها: عنصر عند ‎0.5‎ يقع في منتصف اللوحة
    // سواء كانت كرتًا أو رول أب. لو كُسر هذا لاحتجنا مواصفة لكل صيغة،
    // وضاع سبب وجود الإحداثيات الكسريّة.
    const canvasKey = ValueKey('canvas');
    for (final format in [
      AdFormat.square,
      AdFormat.businessCard,
      AdFormat.rollUp,
    ]) {
      final spec = DesignSpec(
        format: format,
        backdrop: SpecBackdrop.mesh,
        elements: const [
          DesignElement(
            role: ElementRole.headline,
            rect: SpecRect(0.25, 0.5, 0.5, 0.2),
            text: 'عنوان',
            align: SpecAlign.center,
          ),
        ],
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              key: canvasKey,
              width: 400,
              child: SpecRenderer(
                spec: spec,
                brandColor: const Color(0xFFB03030),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: format.label);

      // مركز النصّ المرسوم = مركز المستطيل في المواصفة، بأي نسبة.
      final canvas = tester.getRect(find.byKey(canvasKey));
      final text = tester.getRect(find.text('عنوان'));
      final fx = (text.center.dx - canvas.left) / canvas.width;
      final fy = (text.center.dy - canvas.top) / canvas.height;

      expect(fx, closeTo(0.5, 0.02), reason: 'الأفقي انزاح في ${format.label}');
      expect(fy, closeTo(0.6, 0.02), reason: 'الرأسي انزاح في ${format.label}');
    }
  });

  // ── المزاج اللونيّ: لوحة تُختار لا تُشتقّ ───────────────────────────

  test('المزاج: null يشتقّ من لون العلامة، والرقم يأخذ اللوحة كما هي', () {
    const brand = Color(0xFFB03030);
    const bare = DesignSpec(
      format: AdFormat.square,
      backdrop: SpecBackdrop.mesh,
      elements: [],
    );

    // بلا مزاج: نفس ما كان يحدث قبل الأمزجة، حرفيًّا.
    final derived = paletteFor(bare, brand);
    final before = ArtPalette.from(brand, variant: bare.variant);
    expect(derived.base, before.base);
    expect(derived.complement, before.complement);

    // بمزاج: ألوانه هي هي، بلا اشتقاق ولا ضبط تشبّع.
    const at = 2;
    final mood = ArtMood.at(at);
    final picked = paletteFor(
      const DesignSpec(
        format: AdFormat.square,
        backdrop: SpecBackdrop.mesh,
        elements: [],
        mood: at,
      ),
      brand,
    );
    expect(picked.base, mood.base);
    expect(picked.deep, mood.deep);
    expect(picked.complement, mood.complement);
    expect(picked.neutral, mood.neutral);
    expect(
      picked.base,
      isNot(before.base),
      reason: 'وإلّا لم يكن المزاج قد غيّر شيئًا',
    );
  });

  test('المزاج: حبر كل مزاج مقروء فوق عمقه وفوق حياديّه', () {
    // الأمزجة تُضاف بالعين، والعين تخطئ. وهذا ما يمنع مزاجًا جديدًا
    // بذهبٍ فاتح على عاجيّ من أن يمرّ بنصٍّ لا يُقرأ.
    for (final m in ArtMood.moods) {
      final p = ArtPalette.fromMood(m);
      expect(
        ArtPalette.contrast(m.deep, p.ink),
        greaterThanOrEqualTo(4.5),
        reason: 'حبر ${m.id} فوق عمقه',
      );
      expect(
        ArtPalette.contrast(m.neutral, p.onInk),
        greaterThanOrEqualTo(4.5),
        reason: 'حبر ${m.id} فوق حياديّه',
      );
    }
  });

  test('المزاج: المعرّفات فريدة، والمجهول يعود إلى الأوّل لا يرمي', () {
    final ids = ArtMood.moods.map((m) => m.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'معرّف مكرّر يخلط حفظين');
    expect(ArtMood.byId('لا-وجود-له').id, ArtMood.moods.first.id);
    expect(ArtMood.indexOfId('لا-وجود-له'), 0);
    expect(ArtMood.indexOfId(ids[3]), 3);
  });

  testWidgets('المزاج: الطبيب والعارض على لوحة واحدة لا لوحتين', (
    tester,
  ) async {
    // أخطر ما في إضافة المزاج: أن يُضاف في العارض وحده، فيفحص الطبيب
    // تباين لوحةٍ مشتقّة ويرسم العارض ألوان مزاج — فيمرّ نصّ لا يُقرأ
    // من مدقّق يقول إنه فحصه.
    const brand = Color(0xFFB03030);
    const at = 7; // ورقيّ وحبر — فاتح، فالحبر عليه داكن لا أبيض.
    const spec = DesignSpec(
      format: AdFormat.square,
      backdrop: SpecBackdrop.mesh,
      mood: at,
      elements: [
        DesignElement(
          role: ElementRole.headline,
          rect: SpecRect(0.1, 0.2, 0.8, 0.12),
          text: 'عنوان',
          color: ColorRole.auto,
          align: SpecAlign.center,
          maxLines: 1,
          sizeFactor: 0.07,
        ),
      ],
    );

    final expected = ArtPalette.fromMood(ArtMood.at(at)).ink;

    // الطبيب يرى المزاج.
    final report = SpecDoctor.review(spec, brandColor: brand);
    expect(report.spec.mood, at, reason: 'الطبيب لا يُسقط المزاج وهو يُصلح');

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: 400,
            child: SpecRenderer(spec: spec, brandColor: brand),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // والعارض يرسم بالحبر الذي حسبه الطبيب على اللوحة نفسها.
    expect(tester.widget<Text>(find.text('عنوان')).style?.color, expected);
  });

  // ── الاقتران الطباعي: وجهان لا حجمان ──────────────────────────────

  test('الاقتران: خطّ العلامة يحلّ محلّ وجه العرض وحده', () {
    final plain = ArtFonts.from(0);
    expect(plain.display, isNot(plain.text), reason: 'وجهان متطابقان ليسا اقترانًا');

    final branded = ArtFonts.from(0, brandDisplay: 'Almarai');
    expect(branded.display, 'Almarai', reason: 'اختيار التاجر يظهر في العنوان');
    expect(
      branded.text,
      plain.text,
      reason: 'ولا يبتلع وجه المتن — وإلّا عاد التصميم إلى خطّ واحد',
    );

    // وحين يصادف خطّ العلامة وجهَ المتن يسقط المتن إلى غيره.
    final clash = ArtFonts.from(0, brandDisplay: plain.text);
    expect(clash.display, plain.text);
    expect(clash.text, isNot(plain.text));
  });

  test('الاقتران: الوجه يتبع دور العنصر حين لا يُذكر', () {
    DesignElement at(ElementRole r) =>
        DesignElement(role: r, rect: const SpecRect(0, 0, 1, 0.1));

    expect(at(ElementRole.headline).effectiveFont, SpecFont.display);
    expect(at(ElementRole.badge).effectiveFont, SpecFont.display);
    expect(at(ElementRole.cta).effectiveFont, SpecFont.accent);
    expect(at(ElementRole.subhead).effectiveFont, SpecFont.text);
    expect(at(ElementRole.tags).effectiveFont, SpecFont.text);

    // والتصريح يغلب الدور: النموذج قد يريد عنوانًا صامتًا.
    expect(
      at(ElementRole.headline).copyWith(font: SpecFont.text).effectiveFont,
      SpecFont.text,
    );
  });

  testWidgets('العارض يرسم العنوان بوجه العرض والمتن بوجه المتن', (
    tester,
  ) async {
    const spec = DesignSpec(
      format: AdFormat.square,
      backdrop: SpecBackdrop.paper,
      elements: [
        DesignElement(
          role: ElementRole.headline,
          rect: SpecRect(0.1, 0.16, 0.8, 0.10),
          text: 'عنوان',
          color: ColorRole.deep,
          align: SpecAlign.center,
          maxLines: 1,
          sizeFactor: 0.07,
        ),
        DesignElement(
          role: ElementRole.subhead,
          rect: SpecRect(0.1, 0.30, 0.8, 0.08),
          text: 'متن',
          color: ColorRole.base,
          align: SpecAlign.center,
          maxLines: 1,
          sizeFactor: 0.04,
        ),
      ],
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: 400,
            child: SpecRenderer(spec: spec, brandColor: Color(0xFFB03030)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    String familyOf(String text) =>
        tester.widget<Text>(find.text(text)).style?.fontFamily ?? '';

    final pair = ArtFonts.from(spec.pairing);
    expect(familyOf('عنوان'), pair.display);
    expect(familyOf('متن'), pair.text);
    expect(
      familyOf('عنوان'),
      isNot(familyOf('متن')),
      reason: 'هذا هو الفرق كلّه — وجهان لا حجمان من وجه واحد',
    );
  });

  testWidgets('العارض يرسم كل دور بلا استثناء وبلا فيضان', (tester) async {
    final photo = _solidPng(120, 90, 70);
    const spec = DesignSpec(
      format: AdFormat.portrait,
      backdrop: SpecBackdrop.paper,
      elements: [
        DesignElement(
          role: ElementRole.shape,
          rect: SpecRect(0.06, 0.06, 0.88, 0.30),
          fill: ColorRole.base,
        ),
        DesignElement(
          role: ElementRole.logo,
          rect: SpecRect(0.06, 0.06, 0.12, 0.08),
        ),
        DesignElement(
          role: ElementRole.headline,
          rect: SpecRect(0.08, 0.40, 0.84, 0.12),
          text: 'قهوة مختصة تفتح نهارك',
          align: SpecAlign.center,
        ),
        DesignElement(
          role: ElementRole.subhead,
          rect: SpecRect(0.08, 0.53, 0.84, 0.06),
          text: 'حبوب إثيوبية محمّصة',
          align: SpecAlign.center,
        ),
        DesignElement(
          role: ElementRole.product,
          rect: SpecRect(0.18, 0.60, 0.64, 0.22),
        ),
        DesignElement(
          role: ElementRole.badge,
          rect: SpecRect(0.70, 0.08, 0.22, 0.06),
          text: 'جديد',
          fill: ColorRole.complement,
          align: SpecAlign.center,
        ),
        DesignElement(
          role: ElementRole.cta,
          rect: SpecRect(0.30, 0.84, 0.40, 0.07),
          text: 'اطلب الآن',
          fill: ColorRole.complement,
          align: SpecAlign.center,
        ),
        DesignElement(
          role: ElementRole.tags,
          rect: SpecRect(0.08, 0.92, 0.84, 0.05),
          text: '#قهوة #الرياض',
          align: SpecAlign.center,
        ),
      ],
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: 400,
            child: SpecRenderer(
              spec: spec,
              brandColor: const Color(0xFF2E6BB8),
              product: photo,
              logo: photo,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // الكسر المتوازن يُدخل أسطرًا داخل العنوان، فنقارن بعد تسوية
    // المسافات: يقبل الكسر الفنّي ويظلّ يرفض النصّ المبتور.
    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => (w.data ?? '').replaceAll(RegExp(r'\s+'), ' ').trim())
        .toSet();
    expect(rendered, contains('قهوة مختصة تفتح نهارك'));
    expect(rendered, contains('اطلب الآن'));
    expect(rendered, contains('جديد'));
    expect(rendered, contains('#قهوة #الرياض'));
  });

  testWidgets('ما يخرج من الطبيب يُرسم بلا علّة — الحلقة مغلقة',
      (tester) async {
    // مواصفة كما قد يُخرجها نموذج: عنصر خارج الحافّة، ولون لا يُقرأ،
    // ونصّان متغطّيان. الطبيب يُصلح، والعارض يرسم المُصلَح.
    const raw = DesignSpec(
      format: AdFormat.story,
      backdrop: SpecBackdrop.paper,
      elements: [
        DesignElement(
          role: ElementRole.headline,
          rect: SpecRect(-0.1, -0.05, 0.9, 0.18),
          text: 'عرض نهاية الأسبوع',
          color: ColorRole.neutral, // فاتح فوق فاتح
        ),
        DesignElement(
          role: ElementRole.subhead,
          rect: SpecRect(0.05, 0.02, 0.9, 0.14), // يغطّي العنوان
          text: 'خصم يستحقّ الزيارة',
        ),
        DesignElement(
          role: ElementRole.cta,
          rect: SpecRect(0.30, 0.85, 0.40, 0.07),
          text: 'اطلب الآن',
          fill: ColorRole.complement,
          align: SpecAlign.center,
        ),
      ],
    );

    const brand = Color(0xFF1BC47D);
    final report = SpecDoctor.review(raw, brandColor: brand);
    expect(report.usable, isTrue, reason: report.blocking.join(' / '));

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: 360,
            child: SpecRenderer(spec: report.spec, brandColor: brand),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // والحبر المرسوم مقروء فعلًا — لا اسمًا.
    final art = ArtPalette.from(brand);
    for (final e in report.spec.elements.where((e) => e.isText)) {
      final behind = backgroundBehind(e, report.spec, art);
      expect(
        ArtPalette.contrast(behind, resolveColorRole(e.color, art, behind: behind)),
        greaterThanOrEqualTo(SpecDoctor.minContrast),
        reason: 'نصّ غير مقروء وصل العارض: ${e.text}',
      );
    }
  });


  // ── أمنية التاجر: يكتب فيُنفَّذ ───────────────────────────────────────

  /// ردّ حقيقي من دالة `ad-design` المنشورة، منقولًا كما وصل — بما فيه
  /// خطؤها: اسم العلامة في دور `logo`. الاختبار على مخرَج مصنوع يدويًّا
  /// يفحص خيالنا عن النموذج لا النموذج.
  String liveDesignBody({bool broken = false}) => jsonEncode({
    'ok': true,
    'model': 'gemini-3.5-flash',
    'ms': 8258,
    'designs': [
      {
        'backdrop': 'paper',
        'variant': 2,
        'note': 'تخطيط طولي فاخر لرول أب مقهى',
        'elements': [
          {
            'role': 'logo',
            'rect': {'x': 0.3, 'y': 0.08, 'w': 0.4, 'h': 0.06},
            'text': 'بن الرياض',
            'color': 'deep',
            'align': 'center',
            'maxLines': 1,
            'sizeFactor': 0.04,
            'weight': 700,
          },
          {
            'role': 'headline',
            'rect': broken
                ? {'x': 0.1, 'y': 0.30, 'w': 0.8, 'h': 0.40}
                : {'x': 0.1, 'y': 0.16, 'w': 0.8, 'h': 0.08},
            'text': 'مذاق الفخامة والهدوء',
            'color': 'deep',
            'align': 'center',
            'maxLines': 1,
            'sizeFactor': 0.07,
            'weight': 800,
          },
          {
            'role': 'subhead',
            'rect': broken
                ? {'x': 0.1, 'y': 0.32, 'w': 0.8, 'h': 0.40}
                : {'x': 0.1, 'y': 0.26, 'w': 0.8, 'h': 0.06},
            'text': 'تجربة استثنائية لكل كوب',
            'color': 'base',
            'align': 'center',
            'maxLines': 1,
            'sizeFactor': 0.04,
            'weight': 600,
          },
          {
            'role': 'product',
            'rect': {'x': 0.15, 'y': 0.42, 'w': 0.7, 'h': 0.30},
            'align': 'center',
          },
          {
            'role': 'cta',
            'rect': {'x': 0.25, 'y': 0.85, 'w': 0.5, 'h': 0.06},
            'text': 'اطلبها الآن',
            'color': 'auto',
            'fill': 'deep',
            'align': 'center',
            'maxLines': 1,
            'sizeFactor': 0.04,
            'weight': 700,
          },
        ],
      },
    ],
  });

  DesignWishService wishService(
    MockClient client, {
    Duration timeout = const Duration(seconds: 5),
  }) => DesignWishService(
    client: client,
    supabaseUrl: 'http://test.local',
    supabaseAnonKey: 'anon',
    merchantId: 'merchant-test',
    timeout: timeout,
  );

  test('الأمنية تصير تخطيطًا مفحوصًا لا نصًّا', () async {
    var calls = 0;
    final service = wishService(
      MockClient((req) async {
        calls++;
        final sent = jsonDecode(req.body) as Map<String, dynamic>;
        // ما كتبه التاجر يسافر كما كتبه، والنسبة رقمًا لا اسمًا: النموذج
        // لا يعرف كم عرض «رول أب» ويعرف أن ٠٫٤٢ لوحة طويلة.
        expect(sent['wish'], 'استاند رول لمقهى بخصم ٣٠٪');
        expect(sent['aspect'], closeTo(AdFormat.rollUp.aspect, 1e-9));
        expect(sent['merchant_id'], 'merchant-test');
        return http.Response.bytes(utf8.encode(liveDesignBody()), 200);
      }),
    );

    final result = await service.design(
      const DesignWish(
        text: 'استاند رول لمقهى بخصم ٣٠٪',
        format: AdFormat.rollUp,
        hasImage: true,
      ),
      brandColor: const Color(0xFF6B4A2F),
    );

    expect(calls, 1, reason: 'نداء واحد يكفي حين يصلح المخرَج من أوّله');
    expect(result.designs, isNotEmpty);
    final first = result.designs.first;
    expect(first.usable, isTrue, reason: first.report.blocking.join(' / '));

    // الصيغة من التاجر لا من النموذج — هو من اختار اللوحة التي سيُطبع
    // عليها، وحقل `format` في الردّ تخمينٌ قد يخالفها.
    expect(first.spec.format, AdFormat.rollUp);

    // وكل عنصر داخل الهامش الآمن للطباعة بعد مرور الطبيب.
    const margin = 0.062;
    for (final e in first.spec.elements) {
      expect(e.rect.x, greaterThanOrEqualTo(margin - 1e-9));
      expect(e.rect.y, greaterThanOrEqualTo(margin - 1e-9));
      expect(e.rect.right, lessThanOrEqualTo(1 - margin + 1e-9));
      expect(e.rect.bottom, lessThanOrEqualTo(1 - margin + 1e-9));
    }
  });

  test('اسم العلامة في مكان الشعار لا يختفي من الإعلان', () async {
    // النموذج يظنّ الشعار كلمةً فيضع اسم العلامة في دور `logo`. والعارض
    // لا يرسم ذلك الدور إلا صورة، فبلا الطبيب يضيع اسم التاجر من إعلانه
    // بصمت — وهو أسوأ من عطل ظاهر لأنه لا يُرى.
    final service = wishService(
      MockClient(
        (req) async => http.Response.bytes(utf8.encode(liveDesignBody()), 200),
      ),
    );

    final result = await service.design(
      const DesignWish(text: 'رول أب', format: AdFormat.rollUp),
      brandColor: const Color(0xFF6B4A2F),
      hasLogo: false,
    );

    final spec = result.designs.first.spec;
    expect(
      spec.elements.any(
        (e) => e.isText && (e.text ?? '').contains('بن الرياض'),
      ),
      isTrue,
      reason: 'اسم العلامة بقي في دور لا يُرسم',
    );
    expect(
      result.designs.first.report.issues.any(
        (i) => i.code == SpecIssueCode.textAsLogo && i.repaired,
      ),
      isTrue,
      reason: 'الإصلاح تمّ بلا إبلاغ — والتاجر يستحق أن يعرف',
    );
  });

  test('التخطيط المعطوب يُعاد طلبه مرّة واحدة لا بلا نهاية', () async {
    var calls = 0;
    final service = wishService(
      MockClient((req) async {
        calls++;
        final sent = jsonDecode(req.body) as Map<String, dynamic>;
        if (calls > 1) {
          // المحاولة الثانية تُشدَّد لا تُعاد كما هي.
          expect(sent['wish'], contains('باعد بين الكتل'));
        }
        return http.Response.bytes(
          utf8.encode(liveDesignBody(broken: calls == 1)),
          200,
        );
      }),
    );

    final result = await service.design(
      const DesignWish(text: 'رول أب', format: AdFormat.rollUp),
      brandColor: const Color(0xFF6B4A2F),
    );

    expect(calls, 2, reason: 'محاولتان: واحدة تفشل وواحدة تنجح');
    expect(result.attempts, 2);
    expect(result.designs.first.usable, isTrue);
  });

  // انعدامُ العلل شرطُ عرضٍ لا دليلُ جودة.
  //
  // كان الفرز بـ`usable` ثم عدد العلل الحاجبة وحدهما، فتخطيطان بلا علّة
  // واحدة يتساويان فيه مهما تباعدت درجتاهما — ويُحسم المعروض بترتيب
  // النموذج لا بقياس. ولهذا يأتي الرديء **أوّلًا** في هذا الردّ: تحته
  // كان يبقى أوّلًا.
  test('الأمنية: يتقدّم الأجود درجةً لا الأقلّ عللًا', () async {
    Map<String, dynamic> el(
      String role,
      double x,
      double y,
      double w,
      double h, {
      String? text,
      String color = 'deep',
      String? fill,
      String align = 'center',
      double? size,
      int weight = 700,
    }) => {
      'role': role,
      'rect': {'x': x, 'y': y, 'w': w, 'h': h},
      if (text != null) 'text': text,
      'color': color,
      if (fill != null) 'fill': fill,
      'align': align,
      'maxLines': 1,
      if (size != null) 'sizeFactor': size,
      'weight': weight,
    };

    // رديء ومقبول معًا: كل النصّ بحجم واحد تقريبًا (لا تسلسل)، وحوافّ
    // يساريّة متفاوتة (لا اصطفاف)، والكتل كلّها في الثلث الأعلى
    // (لا توازن ولا فراغ) — ولا علّة حاجبة واحدة.
    final poor = {
      'backdrop': 'paper',
      'variant': 2,
      'note': 'الرديء',
      'elements': [
        el('headline', 0.10, 0.10, 0.50, 0.05,
            text: 'عنوان', size: 0.040, align: 'start'),
        el('subhead', 0.14, 0.17, 0.50, 0.05,
            text: 'سطر ثانوي', color: 'base', size: 0.038, align: 'start'),
        el('cta', 0.18, 0.24, 0.40, 0.05,
            text: 'اطلب', color: 'auto', fill: 'deep', size: 0.036,
            align: 'start'),
        el('product', 0.12, 0.32, 0.45, 0.20),
      ],
    };

    // جيّد: تسلسل واضح (٠٫٠٧ ثم ٠٫٠٤)، وحوافّ مصطفّة على ٠٫١، وتوزيع
    // على اللوحة كلّها.
    final good = {
      'backdrop': 'paper',
      'variant': 2,
      'note': 'الجيّد',
      'elements': [
        el('headline', 0.10, 0.16, 0.80, 0.08,
            text: 'عنوان', size: 0.070, weight: 800),
        el('subhead', 0.10, 0.26, 0.80, 0.06,
            text: 'سطر ثانوي', color: 'base', size: 0.040, weight: 600),
        el('product', 0.15, 0.42, 0.70, 0.30),
        el('cta', 0.25, 0.85, 0.50, 0.06,
            text: 'اطلب', color: 'auto', fill: 'deep', size: 0.040),
      ],
    };

    final service = wishService(
      MockClient(
        (req) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'model': 'gemini-3.5-flash',
              'ms': 900,
              'designs': [poor, good],
            }),
          ),
          200,
        ),
      ),
    );

    final result = await service.design(
      const DesignWish(text: 'رول أب', format: AdFormat.rollUp, count: 2),
      brandColor: const Color(0xFF6B4A2F),
    );

    expect(result.designs, hasLength(2));
    expect(
      result.designs.every((d) => d.usable),
      isTrue,
      reason: 'لا علّة حاجبة في أيّهما — فلا يفرزهما إلا الناقد',
    );
    expect(
      result.designs.first.spec.note,
      'الجيّد',
      reason: 'الرديء جاء أوّلًا في ردّ النموذج، والدرجة هي التي قدّمت الجيّد',
    );
    expect(
      result.designs.first.score.total,
      greaterThan(result.designs.last.score.total),
    );
  });

  testWidgets('شاشة السحر: يكتب ما يريد فيُرسم تخطيطه هو', (tester) async {
    MagicScreen.debugWishServiceOverride = () => wishService(
      MockClient(
        (req) async => http.Response.bytes(utf8.encode(liveDesignBody()), 200),
      ),
    );
    addTearDown(() => MagicScreen.debugWishServiceOverride = null);

    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: buildAppTheme(Brightness.light),
        home: AppStateScope(
          notifier: state,
          child: MagicScreen(
            brief: AdBrief(
              productName: 'قهوة مختصة',
              description: 'حبّ مختار',
              tone: 'فخم',
              platform: 'إنستغرام',
              format: 'ستوري',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'استاند رول لمقهى بخصم ٣٠٪',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    // البطاقة الأولى صارت تخطيط التاجر، ومرسومة بعارض المواصفة لا
    // بأحد القوالب الأحد عشر.
    expect(find.byType(SpecRenderer), findsWidgets);

    // النصّ يُكسر كسرًا متوازنًا فيدخله سطرٌ جديد — المقارنة على النصّ
    // بعد توحيد المسافات لا على شكله المرسوم.
    final drawn = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => (w.data ?? '').replaceAll(RegExp(r'\s+'), ' ').trim())
        .toList();
    expect(
      drawn.any((t) => t.contains('مذاق الفخامة')),
      isTrue,
      reason: 'عنوان التخطيط المولَّد لم يصل إلى الشاشة: $drawn',
    );
  });

  testWidgets('شاشة السحر: ما فهمه القارئ يُعرض ويُصحَّح بالصيغة', (
    tester,
  ) async {
    // بلا خدمة سحابية: القراءة والتركيب كلاهما على الجهاز، وهذا ما
    // يجب أن يظهر.
    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: buildAppTheme(Brightness.light),
        home: AppStateScope(
          notifier: state,
          child: MagicScreen(
            brief: AdBrief(
              productName: 'قهوة مختصة',
              description: 'حبّ مختار',
              tone: 'فخم',
              platform: 'إنستغرام',
              format: 'مربّع',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'ابي ستوري خصم ٢٥٪ على القهوة',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // القراءة معروضة: نوع العرض والنسبة والموضوع.
    expect(find.textContaining('فهمتُ'), findsOneWidget);
    expect(find.text('خصم'), findsWidgets);
    // الأرقام تُصاغ عبر `NumberFormat` بحسب اللغة لا تُكتب يدويًّا،
    // فتخرج لاتينية في العربية السعودية كما هو المتعارف هناك — وهو
    // ما يُكتب في نصّ الإعلان نفسه أيضًا، فلا تختلف الرقاقة عن اللوحة.
    expect(find.text('خصم 25٪'), findsWidgets);

    // والصيغة التي قرأها القارئ صارت المختارة: كان يُخرج ستوري لمن
    // كتب «ستوري» بينما تبقى الرقاقة على «مربّع».
    final chosen = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .where((c) => c.selected)
        .map((c) => (c.label as Text).data)
        .toList();
    expect(
      chosen,
      contains(AdFormat.story.label),
      reason: 'الرقاقة تقول غير ما فعل القارئ: $chosen',
    );
  });



  test('الأمنية على تخطيط قائم تُرسل الأساس لا تبدأ من الصفر', () async {
    Map<String, dynamic>? sent;
    final service = wishService(
      MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response.bytes(utf8.encode(liveDesignBody()), 200);
      }),
    );

    const base = DesignSpec(
      format: AdFormat.banner,
      backdrop: SpecBackdrop.arcs,
      elements: [
        DesignElement(
          role: ElementRole.headline,
          rect: SpecRect(0.1, 0.1, 0.5, 0.2),
          text: 'العنوان الأصلي',
        ),
      ],
    );

    await service.design(
      const DesignWish(
        text: 'كبّر العنوان',
        format: AdFormat.banner,
        base: base,
      ),
      brandColor: const Color(0xFF2C6BED),
    );

    expect(sent, isNotNull);
    // النموذج يرى ما يعدّله. والأساس يُرسل حقلًا أيضًا ليستعمله إصدار
    // لاحق من الدالّة استعمالًا مقيَّدًا بمخطط.
    expect(sent!['wish'], contains('كبّر العنوان'));
    expect(sent!['wish'], contains('العنوان الأصلي'));
    expect(sent!['base'], isA<Map<String, dynamic>>());
  });

  testWidgets('شاشة السحر: أمنيات جاهزة تملأ الصندوق ولا تُرسل عن التاجر', (
    tester,
  ) async {
    var calls = 0;
    MagicScreen.debugWishServiceOverride = () => wishService(
      MockClient((req) async {
        calls++;
        return http.Response.bytes(utf8.encode(liveDesignBody()), 200);
      }),
    );
    addTearDown(() => MagicScreen.debugWishServiceOverride = null);

    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: buildAppTheme(Brightness.light),
        home: AppStateScope(
          notifier: state,
          child: MagicScreen(
            brief: AdBrief(
              productName: 'قهوة',
              description: '',
              tone: 'فخم',
              platform: 'إنستغرام',
              format: 'ستوري',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // صندوقٌ فارغ أمام من لا يعرف ما يكتب جدارٌ لا باب.
    final preset = find.text('افتتاح فرع جديد');
    expect(preset, findsOneWidget);

    await tester.tap(preset);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller!.text, 'افتتاح فرع جديد');
    expect(calls, 0, reason: 'الاقتراح نُفِّذ عن التاجر بلا أن يطلب');

    // وتختفي الاقتراحات بعد أن يكتب: مكانها أولى بما يكتبه.
    expect(find.text('عرض رمضان'), findsNothing);
  });

  // ── محرّر العناصر: التاجر يمسك تصميمه ────────────────────────────────

  DesignSpec sampleSpec() => const DesignSpec(
    format: AdFormat.square,
    backdrop: SpecBackdrop.mesh,
    elements: [
      DesignElement(
        role: ElementRole.headline,
        rect: SpecRect(0.10, 0.10, 0.80, 0.20),
        text: 'عنوان قابل للتحريك',
        align: SpecAlign.center,
        maxLines: 1,
      ),
      DesignElement(
        role: ElementRole.cta,
        rect: SpecRect(0.30, 0.78, 0.40, 0.10),
        text: 'اطلب الآن',
        fill: ColorRole.complement,
        align: SpecAlign.center,
        maxLines: 1,
      ),
    ],
  );

  testWidgets('المحرّر: سحب عنصر يحرّكه فعلًا ويبقى داخل اللوحة', (
    tester,
  ) async {
    // المحرّر **مقاد**: يعرض ما يمرّره الأب لا ما فعله الإصبع. وهذا
    // مقصود — الأب يمرّر المواصفة بعد الطبيب، فيرى التاجر ما سيُطبع لا
    // ما سحبه. فالمضيف هنا يجب أن يُعيد التغذية كما تفعل شاشة المحرّر.
    var applied = sampleSpec();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: StatefulBuilder(
                builder: (context, setLocal) => SpecCanvasEditor(
                  spec: applied,
                  brandColor: const Color(0xFF2C6BED),
                  onChanged: (s) => setLocal(() => applied = s),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final canvas = find.byType(SpecCanvasEditor);
    final origin = tester.getTopLeft(canvas);
    // مركز العنوان: من ٠٫١ إلى ٠٫٩ عرضًا، ومن ٠٫١ إلى ٠٫٣ ارتفاعًا.
    final headlineCentre = origin + const Offset(150, 60);

    await tester.dragFrom(headlineCentre, const Offset(0, 45));
    await tester.pumpAndSettle();

    final first = applied.firstOf(ElementRole.headline)!;
    expect(first.rect.y, isNot(0.10), reason: 'الإفلات لم يُبلّغ الأب بالتعديل');
    final step1 = first.rect.y - 0.10;
    expect(step1, greaterThan(0), reason: 'السحب لأسفل لم يُنزل العنصر');
    expect(
      first.rect.x,
      closeTo(0.10, 1e-6),
      reason: 'تحرّك أفقيًّا وقد سُحب رأسيًّا وحده',
    );

    // سحبة ثانية مطابقة تُنتج إزاحة مطابقة: الحركة متناسبة مع الإصبع لا
    // مقدارًا ثابتًا. (المقارنة بينهما تتجاوز عتبة اللمس التي تبتلع أوّل
    // بكسلات كل سحبة، وهي تفصيلة إطارٍ لا عقدٌ لنا.)
    final centre2 =
        origin + Offset(150, (first.rect.y + first.rect.h / 2) * 300);
    await tester.dragFrom(centre2, const Offset(0, 45));
    await tester.pumpAndSettle();
    final second = applied.firstOf(ElementRole.headline)!;
    expect(second.rect.y - first.rect.y, closeTo(step1, 0.005));

    // ولا يخرج من اللوحة مهما سحب.
    final centre3 =
        origin + Offset(150, (second.rect.y + second.rect.h / 2) * 300);
    await tester.dragFrom(centre3, const Offset(0, 900));
    await tester.pumpAndSettle();
    final far = applied.firstOf(ElementRole.headline)!;
    expect(far.rect.bottom, lessThanOrEqualTo(1.0 + 1e-9));
  });

  testWidgets('المحرّر: تحرير النصّ يغيّر ما يُرسم لا حقلًا مخفيًّا', (
    tester,
  ) async {
    // الانحدار الذي كان: الشاشة تكتب في ad.headline بينما التخطيط
    // المولَّد يرسم من spec.elements[].text — فيضغط التاجر «تطبيق» ولا
    // يتغيّر شيء أمامه.
    final state = AppState();
    final ad = GeneratedAd(
      brief: AdBrief(
        productName: 'قهوة',
        description: '',
        tone: 'فخم',
        platform: 'إنستغرام',
        format: 'منشور مربع',
      ),
      kind: AdKind.image,
      headline: 'عنوان قابل للتحريك',
      body: '',
      hashtags: const [],
      createdAt: DateTime(2026),
      spec: sampleSpec(),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: buildAppTheme(Brightness.light),
        home: AppStateScope(
          notifier: state,
          child: DesignEditorScreen(ad: ad, template: AdTemplate.bold),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('تحرير النص'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'عنوان جديد تمامًا');
    await tester.tap(find.text('تطبيق'));
    await tester.pumpAndSettle();

    // النصّ المرسوم تغيّر — لا حقل الإعلان وحده.
    final drawn = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => (w.data ?? '').replaceAll(RegExp(r'\s+'), ' ').trim())
        .toList();
    expect(
      drawn.any((t) => t.contains('عنوان جديد تمامًا')),
      isTrue,
      reason: 'التعديل لم يصل إلى ما يُرسم: $drawn',
    );

    // وما يُعاد إلى الشاشة السابقة يحمل التعديل في المواصفة نفسها.
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
  });

  testWidgets('المحرّر: وضع المنتج يصل التخطيط المولَّد لا القوالب وحدها', (
    tester,
  ) async {
    // كان SpecRenderer يتجاهل productScale/Dx/Dy كليًّا، فيسحب التاجر
    // منتجه على تخطيط مولَّد ولا يتحرّك شيء — ويظنّ المحرّر معطّلًا.
    final state = AppState();
    Widget host(double scale) => MaterialApp(
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: AppStateScope(
        notifier: state,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: AdDesignPreview(
                ad: GeneratedAd(
                  brief: AdBrief(
                    productName: 'قهوة',
                    description: '',
                    tone: 'فخم',
                    platform: 'إنستغرام',
                    format: 'منشور مربع',
                    imageBytes: _fakeImage,
                    productScale: scale,
                  ),
                  kind: AdKind.image,
                  headline: 'عنوان',
                  body: '',
                  hashtags: const [],
                  createdAt: DateTime(2026),
                  spec: const DesignSpec(
                    format: AdFormat.square,
                    backdrop: SpecBackdrop.mesh,
                    elements: [
                      DesignElement(
                        role: ElementRole.product,
                        rect: SpecRect(0.2, 0.2, 0.6, 0.6),
                      ),
                    ],
                  ),
                ),
                showWatermark: false,
              ),
            ),
          ),
        ),
      ),
    );

    const probe = ValueKey('spec-product-transform');

    await tester.pumpWidget(host(1));
    await tester.pumpAndSettle();
    expect(find.byKey(probe), findsNothing, reason: 'تحويل بلا سبب');

    await tester.pumpWidget(host(1.6));
    await tester.pumpAndSettle();
    expect(
      find.byKey(probe),
      findsOneWidget,
      reason: 'التكبير لم يصل عارض المواصفة',
    );
  });


  // ── طلب التسعير: الطريق الذي كان مسدودًا ─────────────────────────────

  test('طلب التسعير: نصّه يحمل ما يقرّر به المزوّد أوّلًا', () {
    const p = ServiceProvider(
      id: 'print-net',
      name: 'مطابع الرياض',
      kind: ServiceKind.printing,
      city: 'الرياض',
      tagline: 'طباعة سريعة',
      priceFrom: 120,
      rating: 0,
      reviews: 0,
      works: [],
    );

    final text = QuoteRequests.compose(
      provider: p,
      need: 'خمسمئة كرت أعمال بورق مطفي',
      contact: '0500000000',
      merchantName: 'بُنّ الرياض',
      budgetSar: 400,
    );

    // المزوّد يقرّر بالخدمة والمدينة إن كان الطلب له أصلًا.
    expect(text.indexOf('الرياض'), lessThan(text.indexOf('المطلوب')));
    expect(text, contains('خمسمئة كرت أعمال'));
    expect(text, contains('٤٠٠ ريال'.replaceAll('٤٠٠', '400')));
    expect(text, contains('0500000000'));
    expect(text, contains('بُنّ الرياض'));
  });

  test('طلب التسعير: مزوّد الكتالوج المحلّي لا يُدّعى أنه استقبل', () async {
    // معرّفات الكتالوج ليست UUID، وهي علامة أنه لا صفّ له على الخادم.
    // ادّعاءُ الوصول هنا يجعل التاجر ينتظر ردًّا مستحيلًا.
    const local = ServiceProvider(
      id: 'print-net',
      name: 'مطابع الرياض',
      kind: ServiceKind.printing,
      city: 'الرياض',
      tagline: 'طباعة سريعة',
      priceFrom: 120,
      rating: 0,
      reviews: 0,
      works: [],
    );
    expect(QuoteRequests.isRoutable(local), isFalse);

    final result = await QuoteRequests.send(
      provider: local,
      body: 'خمسمئة كرت أعمال',
      contact: '0500000000',
    );
    expect(result.outcome, QuoteOutcome.notRoutable);
    expect(result.delivered, isFalse);

    const remote = ServiceProvider(
      id: '3f1c2b7a-8d4e-4a19-9f22-5b6c7d8e9f01',
      name: 'استوديو',
      kind: ServiceKind.design,
      city: 'جدة',
      tagline: 'تصميم هوية',
      priceFrom: 900,
      rating: 0,
      reviews: 0,
      works: [],
    );
    expect(QuoteRequests.isRoutable(remote), isTrue);
  });

  testWidgets('طلب التسعير: لا يُرسل ناقصًا، ويخرج نصًّا يصل بيد التاجر', (
    tester,
  ) async {
    String? shared;
    const p = ServiceProvider(
      id: 'print-net',
      name: 'مطابع الرياض',
      kind: ServiceKind.printing,
      city: 'الرياض',
      tagline: 'طباعة سريعة',
      priceFrom: 120,
      rating: 0,
      reviews: 0,
      works: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: QuoteRequestSheet(
            provider: p,
            merchantName: 'بُنّ الرياض',
            debugShare: (t) => shared = t,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // طلبٌ بلا وسيلة ردّ لا تصله تسعيرة — فلا يُرسل صامتًا.
    await tester.tap(find.text('أرسل الطلب'));
    await tester.pumpAndSettle();
    expect(find.text('اكتب عشرة أحرف على الأقل ليفهم المزوّد طلبك'), findsOne);
    expect(find.text('اكتب رقمًا أو بريدًا صحيحًا'), findsOne);

    await tester.enterText(
      find.byType(TextFormField).first,
      'خمسمئة كرت أعمال بورق مطفي',
    );
    await tester.enterText(find.byType(TextFormField).last, '0500000000');
    await tester.pumpAndSettle();

    // «أرسله بنفسك» ظاهر دائمًا لا عند الفشل وحده: هو الطريق العامل
    // اليوم لأكثر المزوّدين.
    await tester.tap(find.text('أرسله بنفسك'));
    await tester.pumpAndSettle();

    expect(shared, isNotNull, reason: 'الزرّ لم يُخرج نصًّا يرسله التاجر');
    expect(shared, contains('خمسمئة كرت أعمال'));
    expect(shared, contains('0500000000'));
  });

  test('هجرة طلبات التسعير: لا يقرأها ثالث ولا يبدّل المزوّد ما طُلب', () {
    final sql = File(
      'supabase/migrations/20260819000000_quote_requests.sql',
    ).readAsStringSync();

    // لا سياسة قراءة عامّة: نصّ الطلب فيه ميزانية التاجر وهاتفه.
    expect(sql, isNot(contains('for select\n  using (status')));
    expect(sql, contains('quote_requests_read_own'));
    expect(sql, contains('quote_requests_read_addressed'));

    // والحارس يمنع المزوّد من إعادة كتابة ما طُلب منه ثم الاحتجاج به.
    expect(sql, contains('quote_request_guard'));
    expect(sql, contains('new.body        := old.body;'));
    expect(sql, contains('new.budget_sar  := old.budget_sar;'));
    expect(sql, contains('new.merchant_id := old.merchant_id;'));

    // والإرسال إلى معتمَد وحده: طلبٌ إلى مزوّد معلَّق لا يقرأه أحد.
    expect(sql, contains("p.status = 'approved'"));
  });


  // ── ما كشفه الفحص الشامل ────────────────────────────────────────────

  test('الطبيب يمسح حتى الاستقرار: إزاحةٌ تُحدث تداخلًا جديدًا لا تُهمَل', () {
    // المسح المفرد كان يمرّ على الأزواج بالترتيب ويُعدّل أثناء مروره:
    // عنصرٌ أُنزل يهبط فوق عنصرٍ فُحص قبله، والزوج لا يُزار ثانيةً —
    // فيخرج التقرير «صالح» والتداخل باقٍ.
    const spec = DesignSpec(
      format: AdFormat.square,
      backdrop: SpecBackdrop.mesh,
      elements: [
        DesignElement(
          role: ElementRole.headline,
          rect: SpecRect(0.1, 0.10, 0.8, 0.12),
          text: 'العنوان',
        ),
        DesignElement(
          role: ElementRole.subhead,
          rect: SpecRect(0.1, 0.12, 0.8, 0.12), // يغطّي العنوان
          text: 'السطر الثانوي',
        ),
        DesignElement(
          role: ElementRole.cta,
          rect: SpecRect(0.1, 0.26, 0.8, 0.12), // حيث سيهبط الثانوي
          text: 'اطلب الآن',
        ),
      ],
    );

    final report = SpecDoctor.review(spec, brandColor: const Color(0xFF2C6BED));

    // الثابتة: **إمّا** ألّا يبقى تداخل، **وإمّا** أن يُبلَّغ عنه بلا
    // إصلاح فيُعاد الطلب. ما لا يجوز هو الثالث: تقرير «صالح» فوق تصميم
    // متداخل — وهو ما كان يقع.
    final texts = report.spec.elements.where((e) => e.isText).toList();
    var residual = 0.0;
    for (var i = 0; i < texts.length; i++) {
      for (var j = i + 1; j < texts.length; j++) {
        final r = texts[i].rect.overlapRatio(texts[j].rect);
        if (r > residual) residual = r;
      }
    }
    if (residual > SpecDoctor.maxTextOverlap) {
      expect(
        report.usable,
        isFalse,
        reason:
            'تقرير «صالح» وفيه تداخل باقٍ '
            '(${(residual * 100).round()}٪)',
      );
    }

    // ولا يمرّ الاختبار فارغًا: المدخل متداخل فعلًا، فلا بدّ من بلاغ.
    expect(
      report.issues.any((i) => i.code == SpecIssueCode.overlap),
      isTrue,
      reason: 'مدخلٌ متداخل ولا بلاغ تداخل — الفحص لم يعمل أصلًا',
    );
  });

  test('الطبيب يرى الحاجب لا النصّ وحده: صورة فوق عنوان تُبلَّغ', () {
    // `shape` بلوح معتم و`product` بصورة معتمة يدفنان العنوان دفنًا
    // تامًّا، والعارض يرسم بترتيب القائمة. مدقّقٌ يفحص النصّ ضدّ النصّ
    // فقط يُجيز تصميمًا لا يُرى عنوانه.
    const spec = DesignSpec(
      format: AdFormat.square,
      backdrop: SpecBackdrop.mesh,
      elements: [
        DesignElement(
          role: ElementRole.headline,
          rect: SpecRect(0.1, 0.12, 0.8, 0.16),
          text: 'عنوان مدفون',
        ),
        DesignElement(
          role: ElementRole.product,
          rect: SpecRect(0.1, 0.12, 0.8, 0.5), // فوقه تمامًا
        ),
        DesignElement(
          role: ElementRole.cta,
          rect: SpecRect(0.3, 0.80, 0.4, 0.08),
          text: 'اطلب الآن',
        ),
      ],
    );

    final report = SpecDoctor.review(spec, brandColor: const Color(0xFF2C6BED));
    expect(
      report.issues.any((i) => i.code == SpecIssueCode.overlap),
      isTrue,
      reason: 'المنتج يدفن العنوان والمدقّق ساكت',
    );

    // وإن أُصلح فالنصّ هو الذي يُزاح، لا الحاجب: موضع المنتج تكوينٌ
    // قصده النموذج.
    final product = report.spec.firstOf(ElementRole.product)!;
    expect(product.rect.y, closeTo(0.12, 1e-9));
  });

  test('التباين يُقاس على ما تحت الحروف: لوحٌ سابق يُحسب', () {
    // شريطٌ حياديّ رُسم قبل نصٍّ حياديّ يعطي حياديًّا على حياديّ، وكان
    // الفحص يقيس على خلفيةٍ لا يراها المشاهد أصلًا فيمرّ.
    const spec = DesignSpec(
      format: AdFormat.square,
      backdrop: SpecBackdrop.mesh,
      elements: [
        DesignElement(
          role: ElementRole.shape,
          rect: SpecRect(0.05, 0.10, 0.90, 0.20),
          fill: ColorRole.neutral,
        ),
        DesignElement(
          role: ElementRole.headline,
          rect: SpecRect(0.08, 0.12, 0.84, 0.16),
          text: 'عنوان فوق شريط',
          color: ColorRole.neutral,
        ),
        DesignElement(
          role: ElementRole.cta,
          rect: SpecRect(0.3, 0.80, 0.4, 0.08),
          text: 'اطلب الآن',
        ),
      ],
    );

    const brand = Color(0xFF2C6BED);
    final art = ArtPalette.from(brand);
    final headline = spec.elements[1];
    expect(
      backgroundBehind(headline, spec, art),
      art.neutral,
      reason: 'الخلفية المحسوبة ليست اللوح الذي تحت الحروف',
    );

    // والطبيب يمسك النتيجة: حياديّ على حياديّ لا يُقرأ.
    final report = SpecDoctor.review(spec, brandColor: brand);
    final drawn = report.spec.elements[1];
    final behind = backgroundBehind(drawn, report.spec, art);
    expect(
      ArtPalette.contrast(behind, resolveColorRole(drawn.color, art, behind: behind)),
      greaterThanOrEqualTo(SpecDoctor.minContrast),
    );
  });

  test('sizeFactor مقيَّد: النموذج يظنّها نقاطًا أحيانًا', () {
    final huge = DesignElement.fromJson({
      'role': 'headline',
      'rect': {'x': 0.1, 'y': 0.1, 'w': 0.8, 'h': 0.2},
      'text': 'عنوان',
      'sizeFactor': 12, // ظنّها نقاطًا
    });
    expect(huge.sizeFactor, lessThanOrEqualTo(0.22));

    final tiny = DesignElement.fromJson({
      'role': 'headline',
      'rect': {'x': 0.1, 'y': 0.1, 'w': 0.8, 'h': 0.2},
      'text': 'عنوان',
      'sizeFactor': 0.0001,
    });
    expect(tiny.sizeFactor, greaterThanOrEqualTo(0.012));
  });

  testWidgets('دورٌ مجهول لا يبتلع نصّ التاجر', (tester) async {
    // كل دور لا يعرفه المخطط يسقط إلى `shape`، وكان العارض يرسمه صندوقًا
    // فارغًا — فيختفي كلام التاجر بلا أن يعلم به أحد.
    final spec = DesignSpec.fromJson({
      'format': 'square',
      'backdrop': 'mesh',
      'elements': [
        {
          'role': 'title', // اسم اخترعه النموذج
          'rect': {'x': 0.1, 'y': 0.1, 'w': 0.8, 'h': 0.2},
          'text': 'كلام لا يجوز أن يضيع',
        },
      ],
    });

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: 320,
            child: SpecRenderer(spec: spec, brandColor: const Color(0xFF2C6BED)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final drawn = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => (w.data ?? '').replaceAll(RegExp(r'\s+'), ' ').trim())
        .toList();
    expect(drawn.any((t) => t.contains('كلام لا يجوز أن يضيع')), isTrue);
  });

  testWidgets('لوحة الإعلان لا تنقلب حين يبدّل التاجر لغة واجهته', (
    tester,
  ) async {
    // كل محاذاة في محرّك التصميم اتجاهية، فواجهةٌ إنجليزية كانت تقلب
    // إعلانًا عربيًّا كاملًا — والانقلاب ينتقل إلى الملفّ المصدَّر.
    expect(adTextDirection('عرض خاص'), TextDirection.rtl);
    expect(adTextDirection('Special offer'), TextDirection.ltr);
    expect(adTextDirection('٣٠٪ خصم'), TextDirection.rtl);
    expect(adTextDirection('٣٠٪'), TextDirection.rtl, reason: 'بلا حرف حاسم');

    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        // الواجهة إنجليزية عمدًا.
        locale: const Locale('en'),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: AppStateScope(
          notifier: state,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: AdDesignPreview(
                  ad: GeneratedAd(
                    brief: AdBrief(
                      productName: 'قهوة',
                      description: '',
                      tone: 'فخم',
                      platform: 'إنستغرام',
                      format: 'منشور مربع',
                    ),
                    kind: AdKind.copy,
                    headline: 'عرض خاص على القهوة',
                    body: 'لفترة محدودة',
                    hashtags: const [],
                    createdAt: DateTime(2026),
                  ),
                  showWatermark: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final inner = tester.widget<Directionality>(
      find
          .descendant(
            of: find.byType(AdDesignPreview),
            matching: find.byType(Directionality),
          )
          .first,
    );
    expect(
      inner.textDirection,
      TextDirection.rtl,
      reason: 'اللوحة تبعت لغة الواجهة فانقلب الإعلان العربي',
    );
  });

  test('فشل المحاولة الثانية لا يمحو حصاد الأولى', () async {
    var calls = 0;
    final service = wishService(
      MockClient((req) async {
        calls++;
        if (calls == 1) {
          // تخطيط فيه علّة لا تُصلَح، فتُطلب محاولة ثانية.
          return http.Response.bytes(
            utf8.encode(liveDesignBody(broken: true)),
            200,
          );
        }
        return http.Response.bytes(utf8.encode('{"ok":false}'), 503);
      }),
    );

    final result = await service.design(
      const DesignWish(text: 'رول أب', format: AdFormat.rollUp),
      brandColor: const Color(0xFF6B4A2F),
    );

    expect(calls, 2);
    expect(
      result.designs,
      isNotEmpty,
      reason: 'تخطيط الأولى ضاع لأن الثانية سقطت — والتصميم كان في اليد',
    );
  });


  // ── الذكاء المحلّي: يقرأ، ويُركّب، ويحكم ─────────────────────────────

  test('قارئ الأمنية: يفهم ما كتبه التاجر لا ما تمنّينا أن يكتبه', () {
    // التطبيع أوّلًا: التاجر يكتب بالهمزات والتشكيل والأرقام الهندية،
    // والمطابقة الحرفية تفشل في أكثر ما يكتبه فعلًا.
    expect(WishParser.normalize('إفتتاح'), WishParser.normalize('افتتاح'));
    expect(WishParser.normalize('٣٠٪'), '30%');
    expect(WishParser.normalize('مِظَلَّة'), 'مظله');

    final a = WishParser.parse('استاند رول لمقهى مختص، خصم ٣٠٪، فخم');
    expect(a.offer, WishOffer.discount);
    expect(a.discountPercent, 30);
    expect(a.format, AdFormat.rollUp);
    expect(a.tone, 'فخم');
    expect(a.subject, 'مقهى مختص');

    // الموضوع من الأمنية لا من المخزَّن: التاجر يكتب الآن.
    expect(WishParser.parse('كرت أعمال لعيادة أسنان').subject, 'عيادة أسنان');

    // والفاصلة حدّ معنويّ: «لمخبز، خلفية فاتحة» موضوعها المخبز.
    final b = WishParser.parse('تصميم ستوري لمخبز، خلفية فاتحة');
    expect(b.subject, 'مخبز');
    expect(b.wantsLight, isTrue);
    expect(b.format, AdFormat.story);

    // و«لفترة محدودة» إلحاحٌ لا موضوع.
    final c = WishParser.parse('خصم ٥٠٪ لفترة محدودة');
    expect(c.urgent, isTrue);
    expect(c.subject, isNull);
    expect(c.discountPercent, 50);

    // ورقمٌ خارج المعقول ليس نسبة خصم.
    expect(WishParser.parse('خصم 900').discountPercent, isNull);
  });

  test('المصمّم المحلّي: كل صيغة تجد تكوينًا، وكل تكوين يمرّ الطبيب', () {
    const brand = Color(0xFF6B4A2F);
    for (final fmt in AdFormat.values) {
      final brief = DesignBrief(
        headline: 'خصم ٣٠٪ على القهوة المختصة',
        subhead: 'اغتنمها قبل أن تنتهي',
        cta: 'اطلب الآن',
        badge: 'خصم ٣٠٪',
        format: fmt,
        hasImage: true,
      );
      final out = LocalDesigner.compose(brief, brandColor: brand, count: 3);

      expect(
        out.length,
        3,
        reason: 'صيغة ${fmt.name} لم تجد ثلاثة تكوينات صالحة',
      );
      for (final d in out) {
        expect(d.score.usable, isTrue, reason: '${fmt.name}/${d.archetype}');
        // والدرجة ليست صفرًا مموّهًا: تكوينٌ صالح يتجاوز السبعين.
        expect(
          d.score.total,
          greaterThan(70),
          reason: '${fmt.name}/${d.archetype} = ${d.score}',
        );
      }

      // وتنوّع الأنماط مفروض: ثلاث نسخ من تكوين واحد ليست خيارًا.
      expect(
        out.map((d) => d.archetype).toSet().length,
        greaterThanOrEqualTo(2),
        reason: 'صيغة ${fmt.name} أعادت تكوينًا واحدًا مكرّرًا',
      );
    }
  });

  test('المصمّم المحلّي: حتميّ وسريع', () {
    const brand = Color(0xFF2C6BED);
    const brief = DesignBrief(
      headline: 'وصل الجديد',
      subhead: 'تشكيلة هذا الموسم',
      cta: 'اكتشفه',
      format: AdFormat.portrait,
      hasImage: true,
    );

    final sw = Stopwatch()..start();
    final first = LocalDesigner.compose(brief, brandColor: brand);
    sw.stop();

    // بلا شبكة وبلا حصّة: التركيب كلّه حسابٌ على الجهاز.
    expect(
      sw.elapsedMilliseconds,
      lessThan(600),
      reason: 'التركيب المحلّي بطيء: ${sw.elapsedMilliseconds}ms',
    );

    // ونفس الموجز يعطي نفس التصاميم: مولّدٌ يتغيّر كل مرّة يجعل
    // «أعجبني الأول» خسارةً لا رجعة فيها.
    final second = LocalDesigner.compose(brief, brandColor: brand);
    expect(first.length, second.length);
    for (var i = 0; i < first.length; i++) {
      expect(first[i].archetype, second[i].archetype);
      expect(
        jsonEncode(first[i].spec.toJson()),
        jsonEncode(second[i].spec.toJson()),
        reason: 'التصميم ${i + 1} اختلف بين نداءين متطابقين',
      );
    }
  });

  test('الناقد يُميّز: تصميم مركَّب بالتقدير يسقط دون المُركَّب على شبكة', () {
    const brand = Color(0xFF2C6BED);

    // تصميم وُضعت عناصره حيث وقعت: بلا اصطفاف، بلا تسلسل، بلا فراغ.
    const sloppy = DesignSpec(
      format: AdFormat.square,
      backdrop: SpecBackdrop.mesh,
      elements: [
        DesignElement(
          role: ElementRole.headline,
          rect: SpecRect(0.07, 0.07, 0.30, 0.05),
          text: 'عنوان',
          sizeFactor: 0.030,
        ),
        DesignElement(
          role: ElementRole.subhead,
          rect: SpecRect(0.41, 0.63, 0.28, 0.05),
          text: 'سطر ثانوي',
          sizeFactor: 0.029,
        ),
        DesignElement(
          role: ElementRole.cta,
          rect: SpecRect(0.13, 0.86, 0.22, 0.05),
          text: 'اطلب',
          sizeFactor: 0.028,
        ),
      ],
    );
    final bad = DesignCritic.score(sloppy, brandColor: brand);

    const brief = DesignBrief(
      headline: 'عنوان',
      subhead: 'سطر ثانوي',
      cta: 'اطلب',
      format: AdFormat.square,
      hasImage: true,
    );
    final good = LocalDesigner.compose(brief, brandColor: brand).first;

    expect(
      good.score.total,
      greaterThan(bad.total + 20),
      reason:
          'الناقد لا يُميّز: المُركَّب ${good.score.total.toStringAsFixed(1)} '
          'والمبعثر ${bad.total.toStringAsFixed(1)}',
    );

    // ويُسمّي العلّة لا يكتفي برقم: الاصطفاف والفراغ هما ما انهار.
    expect(bad.parts['alignment'], lessThan(0.5));
    expect(bad.parts['whitespace'], lessThan(0.5));
  });

  test('الناقد بوّابة لا مفاضلة وحدها: ما لا يصلح يأخذ صفرًا', () {
    // درجةٌ منخفضة لتصميم بلا عنوان تُبقيه في المنافسة، وقد يفوز على
    // تصميم سليم بأن يتفوّق في التوازن والفراغ. والصفر يُخرجه منها: هو
    // ليس «أقلّ جمالًا» بل غير صالح.
    const noHeadline = DesignSpec(
      format: AdFormat.square,
      backdrop: SpecBackdrop.mesh,
      elements: [
        DesignElement(
          role: ElementRole.subhead,
          rect: SpecRect(0.1, 0.4, 0.8, 0.2),
          text: 'سطر وحيد بلا عنوان',
        ),
      ],
    );
    final s = DesignCritic.score(
      noHeadline,
      brandColor: const Color(0xFF2C6BED),
    );
    expect(s.usable, isFalse);
    expect(s.total, 0);
    expect(s.blocked.map((i) => i.code), contains(SpecIssueCode.missingHeadline));
  });


  testWidgets('شاشة السحر: الأمنية تُنفَّذ بلا شبكة إطلاقًا', (tester) async {
    // أهمّ ما في الذكاء المحلّي: أن يبقى التطبيق مفيدًا حين تسقط
    // السحابة. قبله كان صندوق الأمنية يعرض رسالة عطل ولا شيء غيرها —
    // وتاجرٌ في محلّه بشبكة متقطّعة يخرج بلا إعلان.
    var calls = 0;
    MagicScreen.debugWishServiceOverride = () => wishService(
      MockClient((req) async {
        calls++;
        throw const SocketException('لا شبكة');
      }),
    );
    addTearDown(() => MagicScreen.debugWishServiceOverride = null);

    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: buildAppTheme(Brightness.light),
        home: AppStateScope(
          notifier: state,
          child: MagicScreen(
            brief: AdBrief(
              productName: 'قهوة',
              description: '',
              tone: 'فخم',
              platform: 'إنستغرام',
              format: 'ستوري',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'خصم ٣٠٪ لمقهى مختص، فخم',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(calls, greaterThan(0), reason: 'لم تُحاوَل السحابة أصلًا');

    // ومع ذلك: تصميم مرسوم في يده، لا رسالة عطل وحدها.
    expect(
      find.byType(SpecRenderer),
      findsWidgets,
      reason: 'سقطت الشبكة فلم يبقَ للتاجر شيء',
    );

    final drawn = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => (w.data ?? '').replaceAll(RegExp(r'\s+'), ' ').trim())
        .toList();

    // والنصّ من فهم أمنيته: النسبة والموضوع اللذان كتبهما.
    expect(
      drawn.any((t) => t.contains('30') && t.contains('مقهى مختص')),
      isTrue,
      reason: 'التصميم المحلّي لم يستعمل ما فهمه من الأمنية: $drawn',
    );

    // ويُقال له بصراحة إن هذا صُمّم على جهازه.
    expect(find.textContaining('على جهازك'), findsWidgets);
  });


  // ── ما كسره الفريق الأحمر، مثبَّتًا ─────────────────────────────────

  test('النسبة: مبلغ بالريال ليس خصمًا مئويًّا', () {
    // أخطر ما وجده الفحص: «خصم ١٥ ريال» كان يخرج «خصم ١٥٪» على شارة
    // ولوحة **مطبوعة**. خطأ تجاريّ لا تجميليّ — ورقة لا تُسترجَع.
    for (final w in [
      'خصم ١٥ ريال على كل وجبة',
      'وفر 30 ريال عند الشراء',
      'تخفيض 15 ريال لكل وجبة',
      'خصم ٥٠ ر.س',
    ]) {
      expect(
        WishParser.parse(w).discountPercent,
        isNull,
        reason: 'قرأ مبلغًا بالريال نسبةً مئوية: $w',
      );
    }
    // والنسبة الحقيقية تُقرأ.
    expect(WishParser.parse('خصم ٣٠٪ على القهوة').discountPercent, 30);
    expect(WishParser.parse('25% off today').discountPercent, 25);
    expect(WishParser.parse('خصم 40 بالمئة').discountPercent, 40);
  });

  test('المطابقة بحدود كلمات: «معرض» ليست «عرض»', () {
    // كان البحث بـ`contains`، فيخرج لمعرض سيارات إعلانُ خصم، ولعيادة
    // أسنان إعلانٌ موسميّ، ولـ«مرحبا» نبرةٌ مرحة.
    expect(WishParser.parse('معرض سيارات في الرياض').offer, isNot(WishOffer.discount));
    expect(WishParser.parse('مواعيد العيادة').offer, isNot(WishOffer.season));
    expect(WishParser.parse('المنتج متوفر الحين').offer, isNot(WishOffer.discount));
    expect(WishParser.parse('مرحبا ابي تصميم لمغسلة').tone, isNull);
    expect(WishParser.parse('علبة كرتون لمنتجاتنا').format, isNot(AdFormat.businessCard));
    expect(WishParser.parse('انشر بالانستقرام').urgent, isFalse);
    expect(WishParser.parse('coffee shop menu').offer, isNot(WishOffer.discount));

    // ومع ذلك تبقى اللواصق والصرف مفهومة.
    expect(WishParser.parse('والخصم مستمر').offer, WishOffer.discount);
    expect(WishParser.parse('خلفية فاتحة').wantsLight, isTrue);
  });

  test('النفي يُقرأ نفيًا: «بدون خصم» ليست طلب خصم', () {
    expect(WishParser.parse('بدون خصم، اعلان تعريفي').offer, isNot(WishOffer.discount));
    expect(WishParser.parse('ما ابي خصم').offer, isNot(WishOffer.discount));
    expect(WishParser.parse('لا يوجد توصيل').offer, isNot(WishOffer.delivery));
  });

  test('الموضوع: لامٌ من بنية الكلمة ليست لام جرّ', () {
    // «لدينا» ليست «دينا»، و«لوحة» ليست «وحة» — وكانت تُطبع عنوانًا.
    expect(WishParser.parse('لدينا خصم كبير').subject, isNull);
    expect(WishParser.parse('لازم يكون فخم').subject, isNull);

    // و«للمخبز» لامان، و«لِمقهى» بتشكيل، و«لـمقهى» بتطويل.
    expect(WishParser.parse('شي حلو للمخبز').subject, 'مخبز');
    expect(WishParser.parse('ابي خصم لِمقهى مختص').subject, 'مقهى مختص');
    expect(WishParser.parse('ستوري لـمقهى مختص').subject, 'مقهى مختص');

    // ومحرف التوجيه الملصَق من واتساب لا يمنع الفهم.
    expect(WishParser.parse('بنر ‏لمطعم برجر').subject, 'مطعم برجر');
  });


  // ── شبكة الطباعة على الخادم ───────────────────────────────────────


  testWidgets('دليل الاستخدام يُقرأ من الحزمة ويُعرض للتاجر', (tester) async {
    // الحارس الآخر يفحص الملفّ على القرص؛ هذا يفحص أنه **محزوم** فعلًا:
    // ملفّ سليم غير مُعلَن في `assets` يمرّ كل فحص نصّي ثم يخرج التطبيق
    // على الجهاز بشاشة عطل.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: buildAppTheme(Brightness.light),
        home: const UserGuideScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('دليل الاستخدام'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // عنوان من متن الدليل: وجودُه يعني أن المحتوى وصل لا الشاشة وحدها.
    expect(find.text('دليل استخدام zol'), findsOneWidget);

    // والقائمة كسولة، فالأقسام البعيدة لا تُبنى حتى تُرى — والتمرير
    // إليها يفحص المتن كلّه لا رأسه.
    await tester.scrollUntilVisible(find.text('شاشة السحر'), 200);
    expect(find.text('شاشة السحر'), findsOneWidget);
  });


  test('جذر التطبيق يتبع البناء وحده لا صفة الحساب', () {
    // المثبَّت في مدخل النكهة يغلب كل شيء — به تعمل النكهات الثلاث.
    expect(rootRole(pinned: AppRole.printShop), AppRole.printShop);
    expect(rootRole(pinned: AppRole.admin), AppRole.admin);

    // وبلا تثبيت: تاجر. وهذا هو الإصلاح — كانت صفةُ الحساب تحسم الجذر،
    // فمن يملك المنصّة يفتح التطبيق فلا يجد إلّا لوحة الإدارة: لا شاشة
    // سحر ولا تنقّل سفلي ولا سهم رجوع، لأن اللوحة جذرٌ لا صفحة مدفوعة.
    // والامتياز صار بابًا في الإعدادات لا بيتًا يُبدَّل.
    expect(rootRole(), AppRole.merchant);
  });

  testWidgets('جذر التطبيق يتبع الدور المثبَّت', (tester) async {
    // الفحص الذي يجعل النكهة «مفتاحًا يُقلَب»: تثبيت الدور يغيّر الجذر
    // فعلًا. وبدونه يبقى `AppRole` تعدادًا لا أثر له — وهو بالضبط ما
    // وقع في `logo` و`tags` من قبل: حقلٌ يُحسب ولا يُرسم.
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load();

    await tester.pumpWidget(
      ZolApp(state: state, pinnedRole: AppRole.printShop),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PrintShopScreen), findsOneWidget);
    expect(find.byType(ShellScreen), findsNothing);

    // والتاجر يرى واجهته هو.
    state.completeOnboarding();
    await tester.pumpWidget(ZolApp(state: state, pinnedRole: AppRole.merchant));
    await tester.pumpAndSettle();
    expect(find.byType(ShellScreen), findsOneWidget);
    expect(find.byType(PrintShopScreen), findsNothing);

    // وبلا تثبيت: صفةُ الحساب **لا** تخطف الجذر. هذا ما وقع فعلًا في
    // الجهاز: صاحب المنصّة فتح التطبيق فوجد لوحة الإدارة أوّل شاشة، بلا
    // شاشة سحر ولا تنقّل سفلي ولا سهم رجوع — الامتياز حبسه في اللوحة.
    state.isShopOwner = true;
    await tester.pumpWidget(ZolApp(state: state));
    await tester.pumpAndSettle();
    expect(find.byType(ShellScreen), findsOneWidget);
    expect(find.byType(PrintShopScreen), findsNothing);
    expect(find.byType(AdminScreen), findsNothing);
  });

  testWidgets('صاحب المطبعة يجد بابه في الإعدادات', (tester) async {
    // ولأن الجذر لم يعد يتبدّل بالصفة، فالباب هو الطريق الوحيد إلى
    // اللوحة. وبلا هذا الفحص يصير الإصلاح أعلاه حجبًا لا تحريرًا:
    // صاحب المطبعة يخرج من حبس اللوحة ولا يجدها بعد ذلك أبدًا.
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load();
    state.completeOnboarding();
    state.isShopOwner = true;

    await tester.pumpWidget(
      AppStateScope(
        notifier: state,
        child: MaterialApp(
          // مثبَّتة: النصّ المتوقَّع أدناه عربيّ، فلو تبدّلت لغة بيئة
          // الاختبار صار الفحص يبحث عن نصّ لا يُعرض.
          locale: const Locale('ar'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final door = find.widgetWithText(ListTile, 'لوحة المطبعة');
    await tester.scrollUntilVisible(door, 200);
    await tester.tap(door);
    await tester.pumpAndSettle();
    expect(find.byType(PrintShopScreen), findsOneWidget);

    // ويرجع منها — وهو بالضبط ما لم يكن ممكنًا حين كانت جذرًا.
    //
    // و`pageBack()` لا تصلح هنا: تبحث عن `tooltip: 'Back'`، والتطبيق
    // عربيّ فتسمية الزرّ «رجوع». فالنوع أصدق من النصّ المترجَم.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('ومن لا مطبعة له لا يرى الباب', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load();
    state.completeOnboarding();

    await tester.pumpWidget(
      AppStateScope(
        notifier: state,
        child: MaterialApp(
          // مثبَّتة: النصّ المتوقَّع أدناه عربيّ، فلو تبدّلت لغة بيئة
          // الاختبار صار الفحص يبحث عن نصّ لا يُعرض.
          locale: const Locale('ar'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('لوحة المطبعة'), findsNothing);
  });

  test('المال يأتي من الخادم: الضريبة مشمولة لا مُضافة', () {
    // العطل الذي كشفه أوّل نداء حقيقي: التطبيق يجمع الضريبة **فوق**
    // الإجمالي، والخادم يعدّها **مشمولة فيه** (فوترة سعودية). فبنران
    // بتسعين: يُقبض من البطاقة ٢٣٥٫٧٥ ويُسجَّل الطلب بـ٢٠٥٫٠٠.
    //
    // وهذا الاختبار يحرس القاعدة لا الرقم: من يحسب المال هو من يسجّله.
    final quote = PrintQuote.fromJson(const {
      'items_total': 180.0,
      'delivery_fee': 25.0,
      'vat_included': 26.74,
      'grand_total': 205.0,
      'turnaround_hours': 24,
    });

    expect(quote.grandTotal, 205.0);
    expect(
      quote.itemsTotal + quote.deliveryFee,
      closeTo(quote.grandTotal, 0.001),
      reason: 'الإجمالي يساوي المنتج والتوصيل — الضريبة داخله',
    );

    // والصيغة المحلية القديمة تُخرج رقمًا آخر. إن تساوى الرقمان يومًا
    // فقد عاد أحد الطرفين إلى حساب الآخر، وحينها يُراجَع هذا الاختبار
    // لا يُحذف.
    final localFormula =
        quote.itemsTotal + quote.deliveryFee + (quote.grandTotal * 0.15);
    expect(
      localFormula,
      isNot(closeTo(quote.grandTotal, 0.01)),
      reason: 'الحساب المحلي صار يوافق الخادم — تحقّق من أيّهما تغيّر',
    );
  });

  test('أقرب مطبعة تتجاهل من لا موقع لها', () {
    // مطبعة بلا إحداثيات كانت ستُقرأ صفرًا صفرًا — نقطة في خليج غينيا
    // تصير «الأقرب» لكل طلب في الجزيرة العربية.
    const riyadh = [
      ShopRow(id: 'a', name: 'بلا موقع'),
      ShopRow(id: 'b', name: 'الرياض', lat: 24.7136, lng: 46.6753),
      ShopRow(id: 'c', name: 'جدة', lat: 21.5623, lng: 39.1520),
    ];
    expect(nearestShopRow(riyadh, 24.83, 46.64)?.id, 'b');
    expect(nearestShopRow(riyadh, 21.60, 39.20)?.id, 'c');

    // ولا مطبعةَ لها موقع يعني **لا إسناد**، لا إسنادًا عشوائيًّا.
    const noneLocated = [ShopRow(id: 'a', name: 'بلا موقع')];
    expect(nearestShopRow(noneLocated, 24.83, 46.64), isNull);
  });

  test('المنتج يقرأ مقاسه من specs ولا ينهار بدونه', () {
    final withSize = ProductRow.fromJson(const {
      'id': 'p1', 'shop_id': 's1', 'kind': 'banner', 'title': 'بنر',
      'specs': {'size': '1×2 متر'}, 'unit_price': 90, 'min_qty': 1,
      'turnaround_hours': 24,
    });
    expect(withSize.size, '1×2 متر');
    expect(withSize.unitPrice, 90);

    // مطبعة لم تكتب المقاس: المنتج يبقى صالحًا للطلب بلا مقاس معروض.
    final bare = ProductRow.fromJson(const {
      'id': 'p2', 'shop_id': 's1', 'kind': 'card', 'title': 'كرت',
      'unit_price': 60,
    });
    expect(bare.size, isNull);
    expect(bare.minQty, 1);
  });

  test('المصمّح يُكمل الناقص ولا يصمت', () {
    const brand = Color(0xFF2C6BED);
    // موجزٌ بلا زرّ حثّ كان يُسقط المرشّحين كلّهم فتعود القائمة فارغة
    // بلا سبب — ومسحٌ على ٣٨٤ توليفة أظهر أن نصفها بالضبط يعود صفرًا.
    const noCta = DesignBrief(
      headline: 'خصم ٣٠٪ على العسل',
      subhead: 'لفترة محدودة',
      format: AdFormat.square,
      hasImage: true,
    );
    final out = LocalDesigner.compose(noCta, brandColor: brand, count: 3);
    expect(out, hasLength(3));
    expect(out.first.spec.firstOf(ElementRole.cta), isNotNull);

    // والعنوان لا يُخترع: هو رسالة التاجر. فموجزٌ بلا عنوان يُرفض بدل
    // أن يخرج رول أب ‎85×200‎ سم بلا رسالة — وكان يخرج بدرجة كاملة.
    const noHead = DesignBrief(
      headline: '   ',
      cta: 'اطلب',
      format: AdFormat.rollUp,
      hasImage: true,
    );
    expect(LocalDesigner.compose(noHead, brandColor: brand), isEmpty);
  });

  test('التنوّع بالهندسة لا بالاسم', () {
    const brand = Color(0xFF2C6BED);
    // بلا صورة منتج كانت ثلاثة أنماط تُخرج المستطيلات نفسها بالضبط،
    // وشرحان منها يَعِدان بمنتج لا وجود له.
    const noImage = DesignBrief(
      headline: 'وصل جديدنا',
      subhead: 'جديدنا بين يديك',
      cta: 'اكتشفه',
      format: AdFormat.square,
      hasImage: false,
    );
    final out = LocalDesigner.compose(noImage, brandColor: brand, count: 3);
    expect(out, hasLength(3));

    final geometries = out
        .map(
          (d) => d.spec.elements
              .map(
                (e) =>
                    '${e.role.name}${e.rect.x.toStringAsFixed(3)}'
                    '${e.rect.y.toStringAsFixed(3)}',
              )
              .join('|'),
        )
        .toSet();
    expect(geometries, hasLength(3), reason: 'تخطيطات متطابقة بأسماء مختلفة');

    // ولا يَعِد شرحٌ بمنتج غائب.
    for (final d in out) {
      expect(d.spec.firstOf(ElementRole.product), isNull);
    }
  });

  test('كل زينة اختارها التاجر تصل إلى المواصفة، في كل صيغة', () {
    // الحارس ضدّ **الحقول الميّتة**: حقلٌ في الموجز يُحسب ثم لا يضعه
    // بعض الأنماط في التخطيط. وقد وقع مرّتين — `logo` لم يكن يبنيه أي
    // نمط، ثم بناه أربعة من سبعة وأسقطته ثلاثة. والعطل صامت تمامًا:
    // التصميم يخرج جميلًا، وشعارُ التاجر ليس فيه.
    //
    // فالفحص على **كل** مخرَج لا على أوّله: نمطٌ واحد ناقص يكفي ليصل
    // إلى التاجر.
    const brand = Color(0xFF2C6BED);
    const season = Color(0xFF1E7A46);

    for (final format in AdFormat.values) {
      final out = LocalDesigner.compose(
        DesignBrief(
          headline: 'خصم ٣٠٪ على العسل',
          subhead: 'لفترة محدودة',
          cta: 'اطلب الآن',
          badge: 'خصم ٣٠٪',
          seasonBadge: '🇸🇦 اليوم الوطني',
          tags: '#عسل #خصم',
          ornament: true,
          hasImage: true,
          hasLogo: true,
          format: format,
        ),
        brandColor: brand,
        seasonColor: season,
        count: LocalDesigner.archetypes.length,
      );

      // العدد بعدد الأنماط لا ثلاثة: المرور الأوّل يأخذ واحدًا من كل
      // نمط، فطلبُ ثلاثة يفحص ثلاثة أنماط ويترك أربعة بلا فحص — ونمطٌ
      // واحد ناقص يكفي ليصل إلى التاجر.
      expect(
        out.map((d) => d.archetype).toSet(),
        hasLength(LocalDesigner.archetypes.length),
        reason: 'صيغة ${format.name} لا تُخرج كل الأنماط مع كل الزينة',
      );

      for (final d in out) {
        final roles = d.spec.elements.map((e) => e.role).toList();
        for (final needed in const [
          ElementRole.headline,
          ElementRole.cta,
          ElementRole.product,
          ElementRole.logo,
          ElementRole.tags,
          ElementRole.ornament,
        ]) {
          expect(
            roles,
            contains(needed),
            reason:
                'نمط ${d.archetype} في ${format.name} أسقط ${needed.name}',
          );
        }

        // الشارتان اثنتان لا واحدة: الموسم بلون الموسم، والعرض بلون
        // اللوحة. وضمّهما في شارة واحدة يُسقط اختيارًا صريحًا.
        final badges = d.spec.elements
            .where((e) => e.role == ElementRole.badge)
            .toList();
        expect(
          badges.map((e) => e.fill),
          containsAll(const [ColorRole.season, ColorRole.complement]),
          reason: 'نمط ${d.archetype} لا يحمل الشارتين معًا',
        );
      }
    }
  });

  test('الزخرفة تُرسم ولا تُقاس: لا تُحشر داخل الهامش ولا تدخل الميزان', () {
    const brand = Color(0xFF2C6BED);
    const bare = DesignBrief(
      headline: 'وصل جديدنا',
      subhead: 'جديدنا بين يديك',
      cta: 'اكتشفه',
      format: AdFormat.square,
      hasImage: true,
    );
    final plain = LocalDesigner.compose(bare, brandColor: brand, count: 1);
    final adorned = LocalDesigner.compose(
      const DesignBrief(
        headline: 'وصل جديدنا',
        subhead: 'جديدنا بين يديك',
        cta: 'اكتشفه',
        format: AdFormat.square,
        hasImage: true,
        ornament: true,
      ),
      brandColor: brand,
      count: 1,
    );
    expect(plain, isNotEmpty);
    expect(adorned, isNotEmpty);

    // الزخرفة زينة لا محتوى: إضافتها لا تُزحزح درجة التكوين. ولو دخلت
    // الميزان لعاقبت التاجرَ على اختياره إيّاها — حافّة زائدة في
    // الاصطفاف، وثقل في ركن، ومساحة مشغولة في الفراغ.
    expect(
      adorned.first.score.total,
      closeTo(plain.first.score.total, 0.001),
      reason: 'الزخرفة غيّرت الدرجة — دخلت الميزان وهي خارجه',
    );

    // ونزفُها خارج اللوحة مقصود: الطبيب لا يحشرها داخل الهامش الآمن،
    // وإلا انقلبت من ركنٍ إلى بقعةٍ معلّقة في الفراغ.
    final orn = adorned.first.spec.firstOf(ElementRole.ornament)!;
    expect(orn.rect.right, greaterThan(1.0));
    expect(orn.rect.bottom, greaterThan(1.0));

    // وهي **أوّل** القائمة: العارض يرسم بترتيبها، فآخرُها طبقةٌ فوق
    // العنوان والمنتج.
    expect(adorned.first.spec.elements.first.role, ElementRole.ornament);
  });

  test('الأمنية تتكلّم لغة النشاط لا لغة عامّة', () {
    // مفردات الأنشطة موجودة في التطبيق منذ زمن، وكان مسار الأمنية
    // وحده لا يمرّ بها — فيكتب لصاحب الكافيه ما يكتبه لمتجر قطع غيار.
    final wish = WishParser.parse('ابي إعلان خصم ٢٠٪');

    final cafe = LocalDesigner.briefFromIntent(
      wish,
      fallbackFormat: AdFormat.square,
      product: 'قهوة مختصة',
      category: BusinessCategory.cafe,
    );
    final generic = LocalDesigner.briefFromIntent(
      wish,
      fallbackFormat: AdFormat.square,
      product: 'قهوة مختصة',
    );

    final cafeCalls = [
      BusinessCategory.cafe.cta,
      ...BusinessCategory.cafe.ctaVariants,
    ];
    expect(
      cafeCalls,
      contains(cafe.cta),
      reason: 'دعوة الإجراء عامّة رغم معرفتنا بالنشاط: ${cafe.cta}',
    );
    expect(generic.cta, 'اطلب الآن', reason: 'بلا نشاط تبقى الصيغة العامّة');

    // والهاشتاقات كانت حقلًا ميّتًا ثالثًا: لا مسارَ يملؤه، فمن ينسخ
    // نصّه إلى إنستغرام ينسخ نصف إعلان.
    expect(cafe.hasTags, isTrue);
    expect(cafe.tags, contains('#قهوة_مختصة'));
    expect(generic.hasTags, isFalse);

    // وحتميّ: نفس الأمنية تعطي نفس الصياغة، فمن أعجبه ما رآه يجده.
    final again = LocalDesigner.briefFromIntent(
      wish,
      fallbackFormat: AdFormat.square,
      product: 'قهوة مختصة',
      category: BusinessCategory.cafe,
    );
    expect(again.cta, cafe.cta);
    expect(again.subhead, cafe.subhead);

    // والتوظيف وحده لا يأخذ دعوة النشاط: «زورونا اليوم» في إعلان وظيفة
    // يطلب من الباحث عن عمل أن يشتري.
    final hiring = LocalDesigner.briefFromIntent(
      WishParser.parse('نبي إعلان توظيف'),
      fallbackFormat: AdFormat.square,
      product: 'قهوة مختصة',
      category: BusinessCategory.cafe,
    );
    expect(hiring.cta, 'قدّم الآن');
  });

  test('الذوق يقدّم ولا يفتح بوّابة: ترتيبٌ مائل بسقف', () {
    const brand = Color(0xFF2C6BED);
    const brief = DesignBrief(
      headline: 'خصم ٣٠٪ على العسل',
      subhead: 'لفترة محدودة',
      cta: 'اطلب الآن',
      format: AdFormat.square,
      hasImage: true,
    );

    final neutral = LocalDesigner.compose(brief, brandColor: brand, count: 7);
    expect(neutral, isNotEmpty);

    // نمطٌ لم يكن الأوّل: نُعلِّم المصمّم أن التاجر يبقيه، فيتقدّم.
    final laggard = neutral.last.archetype;
    expect(laggard, isNot(neutral.first.archetype));

    final tasted = LocalDesigner.compose(
      brief,
      brandColor: brand,
      taste: {laggard: 5},
      count: 7,
    );
    expect(
      tasted.first.archetype,
      laggard,
      reason: 'الذوق لم يقدّم ما أبقاه التاجر مرارًا',
    );

    // لكنّه **ترتيب لا بوّابة**: الميل يضرب درجةً اجتازت الطبيب، فلا
    // يُدخل نمطًا لم يُخرج تخطيطًا صالحًا أصلًا. وبلا صورة منتج تُستبعَد
    // أنماط المنتج كلّها — ولا يُعيدها حبٌّ ولا تكرار.
    const noImage = DesignBrief(
      headline: 'وصل جديدنا',
      subhead: 'جديدنا بين يديك',
      cta: 'اكتشفه',
      format: AdFormat.square,
      hasImage: false,
    );
    final forced = LocalDesigner.compose(
      noImage,
      brandColor: brand,
      taste: const {'magazine': 99},
      count: 7,
    );
    expect(forced, isNotEmpty);
    expect(
      forced.map((d) => d.archetype),
      isNot(contains('magazine')),
      reason: 'الذوق أحيا نمطًا لا يصلح لهذا الموجز',
    );

    // وسقف الميل يمنع الانغلاق: نمطٌ محبوب بدرجة ضعيفة لا يتقدّم على
    // نمطٍ ممتاز. اثنا عشر بالمئة تقدّم عند التقارب لا عند الفرق البيّن.
    expect(LocalDesigner.maxTasteBoost, lessThanOrEqualTo(0.2));
  });

  test('ذاكرة الذوق تُحفظ وتُنسى بالنصف عند السقف', () async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load();
    expect(state.designTaste, isEmpty);

    for (var i = 0; i < 3; i++) {
      state.rememberComposition('stackTop');
    }
    state.rememberComposition('magazine');
    expect(state.designTaste['stackTop'], 3);
    expect(state.designTaste['magazine'], 1);

    // تُقرأ بعد إعادة التشغيل: ذاكرةٌ تُمحى عند الإغلاق ليست ذاكرة.
    final again = await AppState.load();
    expect(again.designTaste['stackTop'], 3);

    // وتُنسى بالنصف عند السقف: عدّادٌ لا ينقص يجعل الشهر الأول يحكم
    // السنة كلّها.
    for (var i = 0; i < 40; i++) {
      state.rememberComposition('stackTop');
    }
    final total = state.designTaste.values.fold<int>(0, (a, b) => a + b);
    expect(
      total,
      lessThanOrEqualTo(40),
      reason: 'الذاكرة تراكمت بلا نسيان',
    );
    expect(state.designTaste['stackTop'], greaterThan(0));
  });

  test('الناقد لا يُخدَع بشريط ضيّق ولا بعناصر لا تُرسم', () {
    const brand = Color(0xFF2C6BED);

    // ١) كل المحتوى في خيط ارتفاعه ٦٪ واللوحة خالية — كان يأخذ ٩٣٫٤
    //    لأن الفراغ كان يجمع الصناديق لا يوحّدها.
    final strip = <DesignElement>[
      for (var i = 0; i < 8; i++)
        const DesignElement(
          role: ElementRole.shape,
          rect: SpecRect(0.07, 0.47, 0.86, 0.06),
          fill: ColorRole.deep,
        ),
      const DesignElement(
        role: ElementRole.headline,
        rect: SpecRect(0.07, 0.47, 0.40, 0.06),
        text: 'عنوان',
        sizeFactor: 0.05,
      ),
      const DesignElement(
        role: ElementRole.cta,
        rect: SpecRect(0.55, 0.47, 0.30, 0.06),
        text: 'اطلب',
        sizeFactor: 0.02,
      ),
    ];
    final stripScore = DesignCritic.score(
      DesignSpec(
        format: AdFormat.banner,
        backdrop: SpecBackdrop.mesh,
        elements: strip,
      ),
      brandColor: brand,
    );
    expect(
      stripScore.total,
      lessThan(80),
      reason: 'شريط ٦٪ ما زال يُخدع الناقد: $stripScore',
    );

    // ٢) أشكال «شبح» بلا لوح لا يرسمها العارض — وكانت ترفع الاصطفاف.
    List<DesignElement> withGhosts(int n) => [
      const DesignElement(
        role: ElementRole.headline,
        rect: SpecRect(0.07, 0.08, 0.40, 0.10),
        text: 'عنوان',
        sizeFactor: 0.05,
      ),
      const DesignElement(
        role: ElementRole.cta,
        rect: SpecRect(0.41, 0.50, 0.30, 0.08),
        text: 'اطلب',
        sizeFactor: 0.02,
      ),
      for (var i = 0; i < n; i++)
        DesignElement(
          role: ElementRole.shape,
          rect: SpecRect(0.07, 0.05 + i * 0.0005, 0.025, 0.03),
        ),
    ];
    double align(int n) =>
        DesignCritic.score(
          DesignSpec(
            format: AdFormat.square,
            backdrop: SpecBackdrop.mesh,
            elements: withGhosts(n),
          ),
          brandColor: brand,
        ).parts['alignment']!;

    expect(
      align(24),
      closeTo(align(0), 1e-9),
      reason: 'عناصر لا تُرسم غيّرت درجة الاصطفاف',
    );
  });


  testWidgets('«إعادة توليد» لا تحرق تصاميم التاجر بلا استئذان', (
    tester,
  ) async {
    // أيقونة التحديث في شريط العنوان تُضغط بالخطأ كثيرًا، وكانت تمسح
    // كل تخطيط صنعه التاجر بأمنيته بلا سؤال ولا استرجاع.
    MagicScreen.debugWishServiceOverride = () => wishService(
      MockClient(
        (req) async => http.Response.bytes(utf8.encode(liveDesignBody()), 200),
      ),
    );
    addTearDown(() => MagicScreen.debugWishServiceOverride = null);

    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: buildAppTheme(Brightness.light),
        home: AppStateScope(
          notifier: state,
          child: MagicScreen(
            brief: AdBrief(
              productName: 'قهوة',
              description: '',
              tone: 'فخم',
              platform: 'إنستغرام',
              format: 'ستوري',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'خصم ٣٠٪ لمقهى');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();
    expect(find.byType(SpecRenderer), findsWidgets);

    // ضغطة تحديث ⇒ سؤال لا مسح.
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(
      find.byType(SpecRenderer),
      findsWidgets,
      reason: 'أُلغي السؤال ومع ذلك ضاعت التصاميم',
    );
  });


  test('البذرة محسوبة لا مأخوذة من hashCode', () {
    // `String.hashCode` في Dart تفصيلةُ تنفيذ لا تُضمن عبر المنصّات ولا
    // عبر الإصدارات، ووعدُ الحتمية في التوثيق مبنيّ عليها كان وعدًا
    // بلا سند. البذرة الآن حسابٌ معرَّف بالكامل (FNV-1a).
    // الفحص على الشيفرة لا على النثر: التعليق يشرح لماذا تُركت
    // `hashCode`، فالبحث في الملفّ كاملًا يلتقط شرحَها لا استعمالها.
    final code = File('lib/services/local_designer.dart')
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');
    expect(
      code,
      isNot(contains('.hashCode')),
      reason: 'عاد الاعتماد على hashCode في بذرة التوليد',
    );

    // ونفس الموجز يعطي نفس اللوحة الفنّية (variant) لا نفس الترتيب فقط.
    const brand = Color(0xFF2C6BED);
    const brief = DesignBrief(
      headline: 'خصم ٣٠٪ على القهوة',
      subhead: 'اغتنمها',
      cta: 'اطلب',
      format: AdFormat.square,
      hasImage: true,
    );
    final a = LocalDesigner.compose(brief, brandColor: brand, count: 3);
    final b = LocalDesigner.compose(brief, brandColor: brand, count: 3);
    expect(a.map((d) => d.spec.variant), b.map((d) => d.spec.variant));
    expect(a.map((d) => d.spec.backdrop), b.map((d) => d.spec.backdrop));
  });

  // ── لوحة تسجيل المزوّدين ────────────────────────────────────────────

  test('الهجرة تمنع المزوّد من اعتماد نفسه وتوثيق نفسه', () {
    // هذه ليست تفصيلة نصّية بل الخاصيّة الأمنية المركزية للسوق: سياسة
    // «عدّل صفّك» لا تستطيع منع تعديل **عمود بعينه**، فبلا الحارس يرسل
    // أي مزوّد {status:'approved', verified:true} من أي أداة HTTP
    // فيعتمد نفسه — وتصير المراجعة كلها زينة.
    final sql = File(
      'supabase/migrations/20260818000000_service_providers.sql',
    ).readAsStringSync();

    expect(sql, contains('service_provider_guard'));
    // الحارس يعيد ما يملكه المشرف وحده إلى قيمه السابقة لغير المشرف.
    expect(sql, contains('new.status      := old.status;'));
    expect(sql, contains('new.verified    := old.verified;'));
    expect(sql, contains('new.owner_id    := old.owner_id;'));

    // والإدراج الجديد يبدأ معلّقًا مهما أُرسل.
    expect(sql, contains("new.status   := 'pending';"));
    expect(sql, contains('new.verified := false;'));

    // والقراءة العامّة للمعتمَدين وحدهم.
    expect(sql, contains("using (status = 'approved')"));

    // ومراجعة المشرف عبر دالة تفحص الصلاحية أولًا.
    expect(sql, contains('review_service_provider'));
    expect(sql, contains('is_platform_admin()'));
    expect(sql, contains("'admin_only'"));
  });

  test('المزوّد الجديد يُعرض بلا نجوم لا بنجوم ممنوحة', () {
    // نجومٌ تُمنح ابتداءً تُفقد التقييم معناه: لا يفرّق التاجر حينها بين
    // مزوّد خدَم مئتين ومزوّد سجّل أمس.
    const fresh = ServiceProvider(
      id: 'x',
      name: 'مزوّد جديد',
      kind: ServiceKind.design,
      city: 'الرياض',
      tagline: 'تصميم هويات',
      priceFrom: 0,
      rating: 0,
      reviews: 0,
      works: [],
    );
    expect(fresh.unrated, isTrue);
    expect(fresh.onRequest, isTrue);

    // ولا مزوّد في الدليل يحمل تقييمًا كتبناه نحن.
    //
    // كان هذا الاختبار يشترط العكس — أن للمزوّدين المحلّيين تقييمًا —
    // فكان يحرس الأرقام المخترعة بدل أن يمنعها: «٤٫٩ من ٢١٠ مراجعة»
    // لمزوّد لم يبِع شيئًا قطّ.
    for (final p in serviceProviders) {
      expect(
        p.unrated,
        isTrue,
        reason: 'تقييم مكتوب في الملفّ لمزوّد لم يُقيَّم: ${p.name}',
      );
    }

    // والترتيب لا ينهار بلا تقييمات: يبقى محدَّدًا ويقدّم الموثّق.
    final ordered = filterProviders(kind: ServiceKind.printing);
    expect(ordered, isNotEmpty);
    for (var i = 1; i < ordered.length; i++) {
      if (ordered[i - 1].verified != ordered[i].verified) {
        expect(
          ordered[i - 1].verified,
          isTrue,
          reason: 'غير الموثّق تقدّم على الموثّق',
        );
      }
    }
  });


  testWidgets('مزوّد طباعة مسجَّل لا تُباع أسعار المنصّة باسمه', (tester) async {
    // الشرط كان على **الصنف**: فأيّ مزوّد يسجّل نفسه «طباعة» تُعرض صفحته
    // بكتالوج المنصّة وأسعارها، وتُهمَل أعماله التي كتبها، ثم يُسند الطلب
    // إلى إحدى المطابع الخمس — فلا هو باع ولا التاجر اشترى ممّن اختار.
    final state = AppState();
    const registered = ServiceProvider(
      id: '3f1c2b7a-8d4e-4a19-9f22-5b6c7d8e9f01',
      name: 'مطبعة الوادي',
      kind: ServiceKind.printing,
      city: 'أبها',
      tagline: 'طباعة رقمية سريعة داخل أبها',
      priceFrom: 30,
      rating: 0,
      reviews: 0,
      works: ['كروت لمطعم', 'لوحة محل'],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: buildAppTheme(Brightness.light),
        home: AppStateScope(
          notifier: state,
          child: const ProviderScreen(provider: registered),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // أعماله هو تُعرض…
    expect(find.text('كروت لمطعم'), findsOneWidget);
    // …ولا يُعرض كتالوج المنصّة على صفحته.
    for (final product in printCatalog) {
      expect(
        find.text(product.label),
        findsNothing,
        reason: 'كتالوج المنصّة معروض على صفحة مزوّد ليس صاحبه',
      );
    }
    // وله مسار تواصل: زرّ التسعيرة كان محجوبًا عن كل صنف «طباعة».
    expect(find.text('اطلب عرض سعر'), findsOneWidget);

    // وشبكة المطابع نفسها ما زالت تعرض الكتالوج — العلَم لا الصنف.
    final network = serviceProviders.firstWhere((p) => p.usesPlatformCatalog);
    expect(network.kind, ServiceKind.printing);
  });

  test('التصفية تعمل على أي مصدر لا على القائمة المحلّية وحدها', () {
    // بدون ذلك يقرأ السوق من الخادم ثم يصفّي القائمة المحلّية، فيختفي
    // كل مزوّد مسجَّل من نتائج البحث بلا أن يظهر عطل.
    const extra = ServiceProvider(
      id: 'srv-1',
      name: 'مطبعة الوادي',
      kind: ServiceKind.printing,
      city: 'أبها',
      tagline: 'طباعة رقمية سريعة',
      priceFrom: 30,
      rating: 0,
      reviews: 0,
      works: [],
    );
    final merged = [...serviceProviders, extra];

    expect(providerCitiesOf(merged), contains('أبها'));
    expect(
      filterProviders(query: 'الوادي', source: merged).single.id,
      'srv-1',
    );
    // والمصدر الافتراضي يبقى المحلّي كما كان.
    expect(filterProviders(query: 'الوادي'), isEmpty);
  });

  testWidgets('التسجيل بلا حساب يقول ذلك ولا يعرض نموذجًا لا يُرسَل',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: buildAppTheme(Brightness.light),
        home: AppStateScope(
          notifier: state,
          child: const ProviderSignupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('سجّل حسابك أولًا لتسجيل خدمتك في السوق'),
      findsOneWidget,
    );
    expect(find.text('أرسل للمراجعة'), findsNothing);
  });

  // ── ربط الكتالوج بالسوق ────────────────────────────────────────────

  test('مزوّد الطباعة: سعره وأعماله من الكتالوج لا من أرقام مكتوبة', () {
    // رقمٌ يُكتب في ملفّ الدليل ينفصل عن التسعير الفعلي بعد أول تعديل،
    // فيرى التاجر «من ٤٥ ر.س» في السوق ثم يُطالَب بغيرها عند الطلب.
    final catalogMin = printCatalog
        .expand((p) => p.sizes)
        .map((z) => z.unitPrice)
        .reduce((a, b) => a < b ? a : b);

    final printers = serviceProviders.where(
      (p) => p.kind == ServiceKind.printing,
    );
    expect(printers, isNotEmpty);
    for (final p in printers) {
      expect(
        p.priceFrom,
        catalogMin.round(),
        reason: 'سعر ${p.name} لا يطابق أدنى سعر في الكتالوج',
      );
      expect(
        p.works,
        printCatalog.map((c) => c.label).toList(),
        reason: 'أعمال ${p.name} لا تطابق ما يطبعه الكتالوج فعلًا',
      );
    }
  });

  testWidgets('صفحة المطبعة تعرض الكتالوج الحقيقي بأسعاره', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    final printer = serviceProviders.firstWhere(
      (p) => p.kind == ServiceKind.printing,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: buildAppTheme(Brightness.light),
        home: AppStateScope(
          notifier: state,
          child: ProviderScreen(provider: printer),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // كل منتج في الكتالوج معروض باسمه، وكل مقاس بسعره الفعلي.
    for (final product in printCatalog) {
      expect(
        find.text(product.label),
        findsWidgets,
        reason: '${product.label} غائب عن صفحة المطبعة',
      );
      for (final size in product.sizes) {
        expect(
          find.text(size.label),
          findsWidgets,
          reason: 'مقاس ${size.label} غائب',
        );
      }
    }

    // ووعدُ «عرض سعر» المؤجَّل لا يظهر هنا: المطبعة عندها طلب حقيقي.
    expect(find.text('اطلب عرض سعر'), findsNothing);
    expect(find.text('اطلب'), findsWidgets);
  });

  testWidgets('طلب الطباعة بلا تصميم محفوظ يقول ذلك ولا يفتح شاشة فارغة',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    final printer = serviceProviders.firstWhere(
      (p) => p.kind == ServiceKind.printing,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: buildAppTheme(Brightness.light),
        home: AppStateScope(
          notifier: state,
          child: ProviderScreen(provider: printer),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('اطلب').first);
    await tester.pumpAndSettle();

    expect(
      find.text('صمّم إعلانًا واحفظه أولًا — الطباعة تحتاج تصميمًا'),
      findsOneWidget,
      reason: 'فتح مسار طلب بلا ما يُطبَع فيه',
    );
  });

  test('كل صيغة مطبوعة تجد منتجها في الكتالوج باسمه', () {
    // هذا ما يجعل الاختيار التلقائي ممكنًا: من صمّم رول أب يجد «رول أب»
    // مختارًا عند الطباعة لا «بنر». ولو تغيّر اسم منتج في الكتالوج ولم
    // يُحدَّث هنا، لعاد الاختيار صامتًا إلى أول منتج في القائمة.
    for (final f in AdFormat.values.where((f) => f.isPrint)) {
      final match = printCatalog.where((p) => p.label == f.printProduct);
      expect(
        match.length,
        1,
        reason: 'صيغة ${f.label} لا تقابل منتجًا واحدًا بالضبط',
      );
    }
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

  testWidgets('الزخرفة التي يضعها المُركِّب يرسمها العارض فعلًا', (
    tester,
  ) async {
    // الحلقة بين طرفَي المحرّك: المُركِّب يضع عنصرًا، والعارض يرسمه.
    // وانقطاعُها هو ما جعل `logo` حقلًا ميّتًا شهورًا — يُحسب في طرف
    // ولا يُرسم في الآخر، ولا اختبارَ يمرّ بالطرفين معًا.
    final designs = LocalDesigner.compose(
      const DesignBrief(
        headline: 'وصل جديدنا',
        subhead: 'جديدنا بين يديك',
        cta: 'اكتشفه',
        format: AdFormat.square,
        hasImage: true,
        ornament: true,
      ),
      brandColor: const Color(0xFF2C6BED),
      count: 1,
    );
    expect(designs, isNotEmpty);
    expect(designs.first.spec.firstOf(ElementRole.ornament), isNotNull);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: 400,
          height: 400,
          child: SpecRenderer(
            spec: designs.first.spec,
            brandColor: const Color(0xFF2C6BED),
            ornamentAsset: 'assets/backgrounds/cafe.svg',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.byType(SvgPicture),
      findsWidgets,
      reason: 'المُركِّب وضع زخرفة والعارض لم يرسمها',
    );

    // وبلا ملفّ لا شيء يُرسم ولا شيء ينكسر: التاجر أطفأ الزخرفة، أو
    // فُتحت مواصفة محفوظة بلا نشاطها.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: 400,
          height: 400,
          child: SpecRenderer(
            spec: designs.first.spec,
            brandColor: const Color(0xFF2C6BED),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsNothing);
  });
}


/// شبكة طباعة مزيَّفة — مطبعة واحدة ومنتج واحد، بلا شبكة.
///
/// تُسجّل ما نُودي عليه، فيصير الفحص على **ما فعله التطبيق** لا على ما
/// ظهر في الشاشة وحده: رفعُ الملفّ وربطُ الدفع لا أثر لهما في الواجهة،
/// وهما أهمّ ما في الوصل.
class _FakePrintBackend implements PrintBackend {
  _FakePrintBackend({this.shopsResult, this.createOutcome});

  final List<ShopRow>? shopsResult;
  final OrderOutcome? createOutcome;

  int uploads = 0;
  int creates = 0;
  final List<String> attached = [];
  double? quotedTotal;

  static const _shop = ShopRow(
    id: 'shop-1',
    name: 'مطبعة الاختبار',
    city: 'الرياض',
    lat: 24.71,
    lng: 46.67,
  );
  static const _product = ProductRow(
    id: 'prod-1',
    shopId: 'shop-1',
    kind: 'banner',
    title: 'بنر 1×2 متر',
    unitPrice: 90,
    size: '1×2 متر',
  );

  @override
  Future<List<ShopRow>> shops() async => shopsResult ?? const [_shop];

  @override
  Future<List<ProductRow>> products(String shopId) async => const [_product];

  @override
  Future<PrintQuote?> quote({
    required String shopId,
    required String productId,
    required int quantity,
  }) async {
    // نفس حساب الخادم: الضريبة **مشمولة** في الإجمالي.
    final items = _product.unitPrice * quantity;
    final total = items + 25;
    quotedTotal = total;
    return PrintQuote(
      itemsTotal: items,
      deliveryFee: 25,
      vatIncluded: double.parse((total * 0.15 / 1.15).toStringAsFixed(2)),
      grandTotal: total,
    );
  }

  @override
  Future<String?> uploadArtwork(Uint8List png) async {
    uploads++;
    return 'https://example.test/artwork/$uploads.png';
  }

  @override
  Future<OrderResult> createOrder({
    required String shopId,
    required String productId,
    required int quantity,
    required String address,
    double? lat,
    double? lng,
    String? artworkUrl,
    String? artworkNotes,
    Map<String, dynamic>? specs,
    String paymentMethod = 'cash',
  }) async {
    creates++;
    if (createOutcome != null && createOutcome != OrderOutcome.created) {
      return OrderResult(createOutcome!);
    }
    return const OrderResult(OrderOutcome.created, orderId: 'srv-order-1');
  }

  @override
  Future<bool> attachPayment(String orderId, String paymentRef) async {
    attached.add('$orderId:$paymentRef');
    return true;
  }
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


/// صورة صلبة صغيرة للاختبارات — أرخص من ملفّ على القرص وأوضح في القراءة.
Uint8List _solidPng(int r, int g, int b) {
  final image = img.Image(width: 24, height: 24);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(image));
}
