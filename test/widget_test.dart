import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:image/image.dart' as img;

import 'package:adcraft_marketplace/main.dart';
import 'package:adcraft_marketplace/models/ad_brief.dart';
import 'package:adcraft_marketplace/models/print_order.dart';
import 'package:adcraft_marketplace/screens/create_ad/upload_details_screen.dart';
import 'package:adcraft_marketplace/services/ad_generator.dart';
import 'package:adcraft_marketplace/services/background_remover.dart';
import 'package:adcraft_marketplace/state/app_state.dart';

/// صورة PNG صالحة 1×1 بكسل تُستخدم بدل منتقي الصور الأصلي في الاختبارات.
final _fakeImage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
  'AAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Future<void> _pumpApp(WidgetTester tester, [AppState? state]) async {
  await tester.pumpWidget(AdCraftApp(state: state ?? AppState()));
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
  await tester.tap(find.text('اعرض شاشة السحر'));
  await tester.pump();

  // ثلاث مراحل توليد ثم إخراج النتائج.
  final total = AdGenerator.stageDuration * AdGenerator.generationStages.length;
  await tester.pump(total + const Duration(milliseconds: 100));
  await tester.pump();
}

void main() {
  setUpAll(() {
    UploadDetailsScreen.debugPickImageOverride = () async => _fakeImage;
    BackgroundRemover.debugRunSynchronously = true;
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

    await tester.enterText(find.byType(TextField).first, 'قهوة مختصة');
    await tester.scrollUntilVisible(
      find.text('اضغط لرفع صورة المنتج'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('اضغط لرفع صورة المنتج'));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('اعرض شاشة السحر'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<ElevatedButton>(button).enabled, isTrue);
  });

  testWidgets('Magic screen generates variants with compatibility scores',
      (tester) async {
    await _pumpApp(tester);
    await _reachMagicResults(tester);

    expect(find.text('اختر النسخة الأنسب'), findsOneWidget);
    expect(find.textContaining('توافق'), findsWidgets);
    expect(find.text('حفظ ونشر'), findsOneWidget);
    expect(find.text('اطبعه وصلّه'), findsOneWidget);
  });

  testWidgets('Saving a variant adds it to the My Ads library',
      (tester) async {
    final state = AppState();
    await _pumpApp(tester, state);
    await _reachMagicResults(tester);

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
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    // ملخص السعر ظاهر وزر التأكيد معطل قبل إدخال العنوان.
    expect(find.text('الإجمالي'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(confirm).enabled, isFalse);

    await tester.enterText(find.byType(TextField), 'الرياض، حي النرجس');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
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
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بطاقة (mada / Visa / Mastercard)'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'الرياض، حي النرجس');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
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
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بطاقة (mada / Visa / Mastercard)'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'الرياض');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
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
      first.register(
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
      first.register(
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
      second.login(email: 'm@example.com', password: 'wrong'),
      isNotNull,
    );
    expect(
      second.login(email: 'm@example.com', password: 'secret123'),
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

  testWidgets('Settings screen toggles dark mode', (tester) async {
    final state = AppState();
    await _pumpApp(tester, state);

    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('داكن'));
    await tester.pumpAndSettle();

    expect(state.themeMode, ThemeMode.dark);
    final context = tester.element(find.text('المظهر'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
