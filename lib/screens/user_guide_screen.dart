import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// دليل الاستخدام داخل التطبيق.
///
/// الملفّ **واحد** لا نسختان: `docs/USER_GUIDE.md` نفسه يُقرأ على GitHub
/// ويُحزَم مع التطبيق ويُعرض هنا. ونسختان تفترقان بعد أسبوعين، فيقرأ
/// التاجر شرحًا لميزة تغيّرت.
///
/// ولأنه مُحزَم مع التطبيق فهو **يصل التاجر مع كل تحديث** بلا تنزيل ولا
/// شبكة — وهذا هو معنى «يُحدَّث تلقائيًّا» هنا: لا نافذة يفتحها على
/// موقع قد يُحجب، بل نصٌّ في يده يعمل في الطائرة.
///
/// والعرض بعارضٍ صغير لا بحزمة markdown: التطبيق يحزم خطوطه وCanvasKit
/// محليًّا هربًا من الاعتماديات الخارجية، وإضافة حزمة كاملة لعرض عناوين
/// ونقاط وعريض مخالفةٌ للعادة بلا مقابل.
class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key});

  static const assetPath = 'docs/USER_GUIDE.md';

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> {
  String? _text;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(UserGuideScreen.assetPath);
      if (mounted) setState(() => _text = raw);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.guideTitle)),
      body: switch ((_text, _failed)) {
        (final String raw, _) => _GuideBody(source: raw),
        (_, true) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.guideUnavailable, textAlign: TextAlign.center),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// عارض markdown مصغَّر — العناوين والنقاط والاقتباس والعريض.
///
/// ما لا يفهمه يعرضه نصًّا عاديًّا بدل أن يبتلعه: سطرٌ يختفي من دليلٍ
/// أسوأ من سطرٍ يظهر بلا تنسيق.
class _GuideBody extends StatelessWidget {
  const _GuideBody({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final blocks = <Widget>[];

    for (final rawLine in source.split('\n')) {
      final line = rawLine.trimRight();
      final trimmed = line.trimLeft();

      if (trimmed.isEmpty) {
        blocks.add(const SizedBox(height: 10));
        continue;
      }
      // الفاصل الأفقي.
      if (trimmed == '---') {
        blocks.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: context.hairline),
          ),
        );
        continue;
      }

      if (trimmed.startsWith('# ')) {
        blocks.add(_head(context, trimmed.substring(2), 24, FontWeight.w800));
        continue;
      }
      if (trimmed.startsWith('## ')) {
        blocks.add(_head(context, trimmed.substring(3), 19, FontWeight.w700));
        continue;
      }
      if (trimmed.startsWith('### ')) {
        blocks.add(_head(context, trimmed.substring(4), 16, FontWeight.w700));
        continue;
      }

      // اقتباس: ملاحظة صريحة يجب أن تُرى.
      if (trimmed.startsWith('> ')) {
        blocks.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: BorderDirectional(
                start: BorderSide(color: AppColors.coral, width: 3),
              ),
            ),
            child: _rich(context, trimmed.substring(2), 14),
          ),
        );
        continue;
      }

      if (trimmed.startsWith('- ')) {
        blocks.add(
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 6, color: scheme.primary),
                ),
                const SizedBox(width: 8),
                Expanded(child: _rich(context, trimmed.substring(2), 14.5)),
              ],
            ),
          ),
        );
        continue;
      }

      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _rich(context, trimmed, 14.5),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: blocks,
    );
  }

  Widget _head(BuildContext c, String text, double size, FontWeight w) =>
      Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: w,
            color: c.scheme.onSurface,
          ),
        ),
      );

  /// يفكّ `**عريض**` ويترك ما عداه كما هو.
  Widget _rich(BuildContext c, String text, double size) {
    final spans = <TextSpan>[];
    final base = TextStyle(
      fontSize: size,
      height: 1.7,
      color: c.scheme.onSurface,
    );
    var rest = text;
    while (true) {
      final open = rest.indexOf('**');
      if (open < 0) break;
      final close = rest.indexOf('**', open + 2);
      if (close < 0) break;
      if (open > 0) spans.add(TextSpan(text: rest.substring(0, open)));
      spans.add(
        TextSpan(
          text: rest.substring(open + 2, close),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      rest = rest.substring(close + 2);
    }
    if (rest.isNotEmpty) spans.add(TextSpan(text: rest));
    return Text.rich(TextSpan(style: base, children: spans));
  }
}
