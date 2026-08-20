import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zol/models/ad_format.dart';
import 'package:zol/models/design_spec.dart';
import 'package:zol/services/design_critic.dart';
import 'package:zol/services/local_designer.dart';

const brand = Color(0xFF1E6F5C);

String roles(DesignSpec s) => s.elements.map((e) => e.role.name).join('+');

void main() {
  test('A: badge / logo / tags survival in the picked designs', () {
    for (final f in AdFormat.values) {
      final brief = DesignBrief(
        headline: 'خصم ٣٠٪ على العسل',
        subhead: 'لفترة محدودة',
        cta: 'اطلب الآن',
        badge: 'خصم ٣٠٪',
        tags: '#عسل #خصم',
        format: f,
        hasImage: true,
        hasLogo: true,
      );
      final out = LocalDesigner.compose(brief, brandColor: brand);
      final withBadge = out
          .where((d) => d.spec.firstOf(ElementRole.badge) != null)
          .length;
      final withLogo =
          out.where((d) => d.spec.firstOf(ElementRole.logo) != null).length;
      final withTags =
          out.where((d) => d.spec.firstOf(ElementRole.tags) != null).length;
      print(
        '${f.name.padRight(13)} picked=${out.length} '
        'badgeIn=$withBadge logoIn=$withLogo tagsIn=$withTags',
      );
      for (final d in out) {
        print('    ${d.archetype.padRight(15)} ${roles(d.spec)}');
      }
    }
  });

  test('B: score distribution — how discriminating is the critic?', () {
    for (final f in AdFormat.values) {
      final brief = DesignBrief(
        headline: 'خصم ٣٠٪ على العسل',
        subhead: 'لفترة محدودة',
        cta: 'اطلب الآن',
        badge: 'خصم ٣٠٪',
        format: f,
        hasImage: true,
      );
      // نُعيد بناء نفس الفضاء يدويًّا بقراءة count كبير جدًّا
      final all = LocalDesigner.compose(brief, brandColor: brand, count: 10000);
      final scores = all.map((d) => d.score.total).toList()..sort();
      if (scores.isEmpty) {
        print('${f.name}: none');
        continue;
      }
      final top = scores.last;
      final tiesAtTop = scores.where((s) => (s - top).abs() < 0.001).length;
      final below70 = scores.where((s) => s < 70).length;
      final distinct = scores.map((s) => s.toStringAsFixed(1)).toSet().length;
      print(
        '${f.name.padRight(13)} candidates=${scores.length} '
        'min=${scores.first.toStringAsFixed(1)} '
        'max=${top.toStringAsFixed(1)} '
        'distinctScores=$distinct tiesAtMax=$tiesAtTop below70=$below70',
      );
    }
  });

  test('C: count larger than archetype count', () {
    final brief = DesignBrief(
      headline: 'خصم ٣٠٪',
      subhead: 'لفترة محدودة',
      cta: 'اطلب',
      format: AdFormat.square,
      hasImage: false,
    );
    for (final n in [1, 3, 5, 8, 12]) {
      final out = LocalDesigner.compose(brief, brandColor: brand, count: n);
      final sigs = out
          .map((d) => d.spec.elements
              .map((e) =>
                  '${e.role.name}${e.rect.x.toStringAsFixed(3)}${e.rect.y.toStringAsFixed(3)}')
              .join())
          .toSet();
      print(
        'count=$n -> got=${out.length} uniqueLayouts=${sigs.length} '
        'arch=${out.map((d) => d.archetype).toList()} '
        'variants=${out.map((d) => d.spec.variant).toList()} '
        'backdrops=${out.map((d) => d.spec.backdrop.name).toList()}',
      );
    }
  });

  test('D: determinism across calls + printed seed/variant', () {
    final brief = DesignBrief(
      headline: 'خصم ٣٠٪ على العسل',
      subhead: 'لفترة محدودة',
      cta: 'اطلب الآن',
      format: AdFormat.square,
      hasImage: true,
    );
    final a = LocalDesigner.compose(brief, brandColor: brand);
    final b = LocalDesigner.compose(brief, brandColor: brand);
    print('run1 arch=${a.map((d) => d.archetype).toList()} '
        'variants=${a.map((d) => d.spec.variant).toList()} '
        'backdrops=${a.map((d) => d.spec.backdrop.name).toList()}');
    print('run2 arch=${b.map((d) => d.archetype).toList()} '
        'variants=${b.map((d) => d.spec.variant).toList()} '
        'backdrops=${b.map((d) => d.spec.backdrop.name).toList()}');
    print('headline.hashCode=${brief.headline.hashCode}');
    print('archetype hashCodes: '
        '${LocalDesigner.archetypes.map((s) => s.hashCode).toList()}');
  });

  test('E: preferLight true/false paths', () {
    for (final pl in [null, true, false]) {
      for (final f in [AdFormat.square, AdFormat.rollUp, AdFormat.banner]) {
        final brief = DesignBrief(
          headline: 'خصم ٣٠٪ على العسل',
          subhead: 'لفترة محدودة',
          cta: 'اطلب الآن',
          format: f,
          hasImage: true,
          preferLight: pl,
        );
        final out = LocalDesigner.compose(brief, brandColor: brand);
        print('preferLight=$pl ${f.name.padRight(13)} n=${out.length} '
            'backdrops=${out.map((d) => d.spec.backdrop.name).toList()} '
            'scores=${out.map((d) => d.score.total.toStringAsFixed(1)).toList()}');
      }
    }
  });

  test('F: headline-only brief (no sub, no cta, no image, no badge)', () {
    for (final f in AdFormat.values) {
      final brief = DesignBrief(headline: 'افتتاح', format: f);
      final out = LocalDesigner.compose(brief, brandColor: brand);
      print('${f.name.padRight(13)} n=${out.length}');
    }
  });

  test('G: cta present but headline empty — what does the doctor say?', () {
    final brief = DesignBrief(
      headline: '',
      subhead: '',
      cta: 'اطلب الآن',
      format: AdFormat.rollUp,
      hasImage: true,
    );
    final out = LocalDesigner.compose(brief, brandColor: brand);
    print('n=${out.length}');
    for (final d in out) {
      final h = d.spec.firstOf(ElementRole.headline)!;
      print('  ${d.archetype} score=${d.score.total.toStringAsFixed(1)} '
          'headlineText="${h.text}" rect=${h.rect} sizeFactor=${h.sizeFactor}');
      print('   parts=${d.score.parts}');
    }
  });

  test('H: single-element edge — critic on a spec with one huge product', () {
    final spec = DesignSpec(
      format: AdFormat.rollUp,
      backdrop: SpecBackdrop.mesh,
      elements: const [
        DesignElement(
          role: ElementRole.headline,
          rect: SpecRect(0.062, 0.062, 0.876, 0.05),
          text: 'ع',
          sizeFactor: 0.084,
        ),
        DesignElement(
          role: ElementRole.product,
          rect: SpecRect(0.062, 0.15, 0.876, 0.70),
        ),
        DesignElement(
          role: ElementRole.cta,
          rect: SpecRect(0.062, 0.88, 0.30, 0.05),
          text: 'اطلب',
          sizeFactor: 0.030,
        ),
      ],
    );
    print(DesignCritic.score(spec, brandColor: brand));
  });
}
