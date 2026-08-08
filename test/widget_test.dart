import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adcraft_marketplace/main.dart';

void main() {
  testWidgets('Home screen shows the main call-to-action', (WidgetTester tester) async {
    await tester.pumpWidget(const AdCraftApp());

    expect(find.text('أنشئ إعلانك الآن'), findsOneWidget);
    expect(find.byIcon(Icons.auto_fix_high), findsOneWidget);
  });

  testWidgets('Tapping the CTA opens the upload details screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AdCraftApp());

    await tester.tap(find.text('أنشئ إعلانك الآن'));
    await tester.pumpAndSettle();

    expect(find.text('نبرة الإعلان'), findsOneWidget);
  });
}
