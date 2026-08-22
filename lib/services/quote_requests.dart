import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ad_service.dart';

/// نتيجة إرسال طلب تسعير.
///
/// ثلاث حالات لا حالتان: «وصل» و«لم يصل» و«لا يمكن أن يصل بهذه الطريقة».
/// الثالثة ليست فشلًا بل حقيقة عن المزوّد — مزوّدو الكتالوج المحلّي
/// (شبكة المطابع) ليس لهم صفٌّ على الخادم يستقبل، وطلبهم يمرّ بمسار
/// الطباعة لا بهذا.
enum QuoteOutcome {
  /// وصل الخادم وسُجّل باسم التاجر.
  delivered,

  /// تعذّر الوصول — شبكة أو خادم. النصّ جاهز والتاجر يرسله بنفسه.
  offline,

  /// التاجر غير مسجّل دخول، فلا هوية يُنسب إليها الطلب.
  needsAccount,

  /// المزوّد محلّي لا صفّ له على الخادم.
  notRoutable,
}

class QuoteResult {
  const QuoteResult(this.outcome, {this.detail});

  final QuoteOutcome outcome;
  final String? detail;

  bool get delivered => outcome == QuoteOutcome.delivered;
}

/// طلبات التسعير — من إشعارٍ صادق إلى طلبٍ يصل.
///
/// كان زرّ «اطلب تسعيرة» يعرض إشعارًا ثم لا شيء، وإشعارُه صادق يقول إن
/// الطلب لا يصل. لكن الصدق عن طريق مسدود لا يفتحه.
///
/// وهنا مساران متعمَّدان: التسجيل على الخادم حين يكون المزوّد مسجَّلًا،
/// و**نصٌّ جاهز يرسله التاجر بنفسه** في كل الأحوال. الثاني ليس احتياطًا
/// للأول: أكثر المزوّدين في السوق السعودي يعملون على واتساب، ورسالةٌ
/// تصلهم اليوم خيرٌ من صفٍّ في جدول ينتظر أن يفتحوا لوحةً لم يفتحوها قطّ.
class QuoteRequests {
  const QuoteRequests._();

  static SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      // التطبيق يعمل في الاختبارات وفي وضع بلا خادم بلا تهيئة.
      return null;
    }
  }

  /// معرّفات المزوّدين المحلّيين ليست UUID، وهي علامة أنهم من الكتالوج
  /// لا من الجدول.
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool isRoutable(ServiceProvider p) => _uuid.hasMatch(p.id);

  static Future<QuoteResult> send({
    required ServiceProvider provider,
    required String body,
    required String contact,
    int budgetSar = 0,
  }) async {
    if (!isRoutable(provider)) {
      return const QuoteResult(QuoteOutcome.notRoutable);
    }

    final db = _db;
    final uid = db?.auth.currentUser?.id;
    if (db == null) return const QuoteResult(QuoteOutcome.offline);
    if (uid == null) return const QuoteResult(QuoteOutcome.needsAccount);

    try {
      await db.from('quote_requests').insert({
        'provider_id': provider.id,
        'merchant_id': uid,
        'body': body.trim(),
        'contact': contact.trim(),
        'budget_sar': budgetSar,
      });
      return const QuoteResult(QuoteOutcome.delivered);
    } on PostgrestException catch (e) {
      return QuoteResult(QuoteOutcome.offline, detail: e.message);
    } catch (e) {
      return QuoteResult(QuoteOutcome.offline, detail: e.toString());
    }
  }

  /// نصّ الطلب كما يُرسل — عربيّ، مرتّب، ويحمل ما يسأل عنه المزوّد أوّلًا.
  ///
  /// الترتيب مقصود: الخدمة والمدينة أوّلًا لأن المزوّد يقرّر بهما إن كان
  /// الطلب له أصلًا، ثم التفاصيل، ثم كيف يردّ. ورسالةٌ تبدأ بالتحية
  /// وتنتهي بالمطلوب تُقرأ نصفها ويُردّ عليها بسؤال.
  static String compose({
    required ServiceProvider provider,
    required String need,
    required String contact,
    String? merchantName,
    int budgetSar = 0,
  }) {
    final b = StringBuffer()
      ..writeln('طلب تسعير عبر zol')
      ..writeln('المزوّد: ${provider.name} — ${provider.city}')
      ..writeln('الخدمة: ${provider.kind.label}');
    if (merchantName != null && merchantName.trim().isNotEmpty) {
      b.writeln('من: ${merchantName.trim()}');
    }
    b
      ..writeln()
      ..writeln('المطلوب:')
      ..writeln(need.trim());
    if (budgetSar > 0) {
      b
        ..writeln()
        ..writeln('الميزانية التقريبية: $budgetSar ريال');
    }
    b
      ..writeln()
      ..writeln('للردّ: ${contact.trim()}');
    return b.toString();
  }
}
