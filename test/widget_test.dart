import 'dart:convert';

import 'package:adcraft_marketplace/main.dart';
import 'package:adcraft_marketplace/models/ad_brief.dart';
import 'package:adcraft_marketplace/models/generation.dart';
import 'package:adcraft_marketplace/screens/create_ad/magic_screen.dart';
import 'package:adcraft_marketplace/services/ai_gateway.dart';
import 'package:adcraft_marketplace/widgets/ad_composite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _brief = AdBrief(
  productName: 'قهوة مختصة',
  tone: 'عاطفي',
  platform: 'إنستغرام',
);

/// رد ناجح مطابق لشكل ما يعيده المنسّق فعلاً.
String _successBody({bool withImage = true, bool critiqued = true}) {
  return jsonEncode({
    'copy': {
      'variants': [
        {
          'angle': 'المنفعة المباشرة',
          'headline': 'قهوتك تبدأ يومك',
          'body': 'حبوب محمّصة محلياً كل أسبوع.',
          'cta': 'اطلبها الآن',
          'hashtags': ['#قهوة', '#السعودية'],
        },
        {
          'angle': 'الموقف اليومي',
          'headline': 'رفيقة صباحك',
          'body': 'نكهة تعرفها من أول رشفة.',
          'cta': 'تعرّف أكثر',
          'hashtags': ['#قهوة_مختصة'],
        },
      ],
      'bestIndex': 1,
      'critiqued': critiqued,
    },
    'image': withImage
        ? {
            // أصغر PNG صالح (1×1) — يكفي لإثبات فك الترميز والعرض.
            'base64':
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==',
            'mimeType': 'image/png',
            'aspectRatio': '4:5',
          }
        : null,
    'quota': {'used': 2, 'limit': 5},
    'textOverlayRequired': true,
  });
}


/// نافذة الاختبار الافتراضية (800×600) أقصر من هذه الشاشات، فتبقى عناصر
/// أسفل القائمة بلا عنصر شجرة ولا يجدها الباحث. نوسّعها لتغطي الشاشة كاملة.
void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

AiGateway _gatewayReturning(http.Response Function(http.Request) handler) {
  return AiGateway(
    baseUrl: 'http://test.local',
    client: MockClient((req) async => handler(req)),
  );
}

void main() {
  group('الشاشة الرئيسية', () {
    testWidgets('تعرض زر البدء', (tester) async {
      await tester.pumpWidget(const AdCraftApp());
      expect(find.text('أنشئ إعلانك الآن'), findsOneWidget);
    });

    testWidgets('الضغط على الزر يفتح شاشة التفاصيل', (tester) async {
      _useTallScreen(tester);
      await tester.pumpWidget(const AdCraftApp());
      await tester.tap(find.text('أنشئ إعلانك الآن'));
      await tester.pumpAndSettle();
      expect(find.text('نبرة الإعلان'), findsOneWidget);
      expect(find.text('اسم المنتج'), findsOneWidget);
    });
  });

  group('AiGateway', () {
    test('يحوّل رد النجاح إلى نتيجة مكتملة', () async {
      final gateway = _gatewayReturning(
        (_) => http.Response(_successBody(), 200,
            headers: {'content-type': 'application/json; charset=utf-8'}),
      );

      final result = await gateway.generatePreview(_brief);

      expect(result.variants, hasLength(2));
      expect(result.bestIndex, 1);
      expect(result.critiqued, isTrue);
      expect(result.quota.remaining, 3);
      expect(result.backgroundImage, isNotNull);
      expect(result.aspectRatioValue, closeTo(4 / 5, 0.001));
    });

    test('يرسل النبرة والمنصة واسم المنتج إلى الخادم', () async {
      Map<String, dynamic>? sent;
      final gateway = _gatewayReturning((req) {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(_successBody(), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });

      await gateway.generatePreview(_brief);

      expect(sent!['productName'], 'قهوة مختصة');
      expect(sent!['tone'], 'عاطفي');
      expect(sent!['platform'], 'إنستغرام');
      expect(sent!['includeImage'], isTrue);
    });

    test('يميّز تجاوز الحصة عن بقية الأخطاء', () async {
      final gateway = _gatewayReturning(
        (_) => http.Response(
          jsonEncode({'error': 'quota_exceeded', 'message': 'تجاوزت حدّ خطتك'}),
          429,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      await expectLater(
        gateway.generatePreview(_brief),
        throwsA(isA<GatewayException>()
            .having((e) => e.isQuota, 'isQuota', isTrue)
            .having((e) => e.message, 'message', contains('حدّ خطتك'))),
      );
    });

    test('يصف خطأ المزوّد المؤقت كقابل لإعادة المحاولة', () async {
      final gateway = _gatewayReturning(
        (_) => http.Response(
          jsonEncode({'error': 'provider_error', 'message': 'مشغول'}),
          503,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      await expectLater(
        gateway.generatePreview(_brief),
        throwsA(isA<GatewayException>().having((e) => e.retryable, 'retryable', isTrue)),
      );
    });

    test('يرفض رداً بلا صيغ', () async {
      final gateway = _gatewayReturning(
        (_) => http.Response(
          jsonEncode({
            'copy': {'variants': <dynamic>[], 'bestIndex': 0, 'critiqued': false},
            'quota': {'used': 1, 'limit': 5},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      await expectLater(
        gateway.generatePreview(_brief),
        throwsA(isA<GatewayException>()),
      );
    });
  });

  group('شاشة السحر', () {
    testWidgets('تعرض حالة التوليد ثم النتيجة', (tester) async {
      _useTallScreen(tester);
      final gateway = _gatewayReturning(
        (_) => http.Response(_successBody(), 200,
            headers: {'content-type': 'application/json; charset=utf-8'}),
      );

      await tester.pumpWidget(
        MaterialApp(home: MagicScreen(brief: _brief, gateway: gateway)),
      );

      expect(find.text('نكتب إعلانك الآن'), findsOneWidget);

      await tester.pumpAndSettle();

      // الصيغة المرشّحة (bestIndex = 1) هي المعروضة في التركيب
      expect(find.text('رفيقة صباحك'), findsWidgets);
      expect(find.byType(AdComposite), findsOneWidget);
      expect(find.textContaining('رشّح المحكّم الصيغة رقم 2'), findsOneWidget);
      expect(find.text('تبقّى 3'), findsOneWidget);
    });

    testWidgets('تعرض رسالة الحصة بلا زر إعادة محاولة', (tester) async {
      final gateway = _gatewayReturning(
        (_) => http.Response(
          jsonEncode({'error': 'quota_exceeded', 'message': 'تجاوزت حدّ خطتك: 5 من 5'}),
          429,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: MagicScreen(brief: _brief, gateway: gateway)),
      );
      await tester.pumpAndSettle();

      expect(find.text('انتهت معايناتك اليوم'), findsOneWidget);
      expect(find.text('أعد المحاولة'), findsNothing);
    });

    testWidgets('خطأ الشبكة يتيح إعادة المحاولة وتنجح', (tester) async {
      var calls = 0;
      final gateway = AiGateway(
        baseUrl: 'http://test.local',
        client: MockClient((req) async {
          calls += 1;
          if (calls == 1) {
            return http.Response(
              jsonEncode({'error': 'provider_error', 'message': 'مشغول'}),
              503,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(_successBody(), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: MagicScreen(brief: _brief, gateway: gateway)),
      );
      await tester.pumpAndSettle();

      expect(find.text('تعذّر التوليد'), findsOneWidget);

      await tester.tap(find.text('أعد المحاولة'));
      await tester.pumpAndSettle();

      expect(find.byType(AdComposite), findsOneWidget);
      expect(calls, 2);
    });
  });

  group('AdComposite', () {
    testWidgets('يرسم النص العربي كطبقة نصية حقيقية فوق الخلفية', (tester) async {
      const variant = CopyVariant(
        angle: 'تجربة',
        headline: 'عنوان عربي مترابط',
        body: 'نص إعلاني عربي كامل.',
        cta: 'اطلبه الآن',
        hashtags: ['#وسم'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdComposite(variant: variant, aspectRatio: 4 / 5),
          ),
        ),
      );

      // النص موجود كـ Text لا كبكسلات داخل صورة — وهذا هو بيت القصيد:
      // محرّك Flutter يشكّل العربية تشكيلاً صحيحاً، بخلاف نماذج توليد الصور.
      expect(find.text('عنوان عربي مترابط'), findsOneWidget);
      expect(find.text('نص إعلاني عربي كامل.'), findsOneWidget);
      expect(find.text('اطلبه الآن'), findsOneWidget);
      expect(find.text('#وسم'), findsOneWidget);
    });
  });
}
