import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adcraft_marketplace/main.dart';
import 'package:adcraft_marketplace/models/ad_brief.dart';
import 'package:adcraft_marketplace/models/print_order.dart';
import 'package:adcraft_marketplace/screens/create_ad/upload_details_screen.dart';
import 'package:adcraft_marketplace/services/ad_generator.dart';
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
    await tester.scrollUntilVisible(
      confirm,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // ملخص السعر ظاهر وزر التأكيد معطل قبل إدخال العنوان.
    expect(find.text('الإجمالي'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(confirm).enabled, isFalse);

    await tester.enterText(find.byType(TextField), 'الرياض، حي النرجس');
    await tester.pump();
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
