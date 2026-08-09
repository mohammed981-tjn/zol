import 'package:flutter/material.dart';

/// مواسم محلية ذروة الطلب — تمنح التصميم طابعًا احتفاليًا فوريًا (لون
/// وهاشتاق وجملة حملة) دون الحاجة لقالب رسومي منفصل لكل موسم. قوالب
/// Canva العربية للمواسم مجرد ترجمة لتصاميم غربية؛ هذه مواسم حقيقية
/// لذروة الطلب المحلي.
enum SeasonalTheme { nationalDay, ramadan, eid, whiteFriday, riyadhSeason }

extension SeasonalThemeInfo on SeasonalTheme {
  String get label => switch (this) {
    SeasonalTheme.nationalDay => 'اليوم الوطني',
    SeasonalTheme.ramadan => 'رمضان',
    SeasonalTheme.eid => 'العيد',
    SeasonalTheme.whiteFriday => 'الجمعة البيضاء',
    SeasonalTheme.riyadhSeason => 'موسم الرياض',
  };

  String get emoji => switch (this) {
    SeasonalTheme.nationalDay => '🇸🇦',
    SeasonalTheme.ramadan => '🌙',
    SeasonalTheme.eid => '🎉',
    SeasonalTheme.whiteFriday => '🏷️',
    SeasonalTheme.riyadhSeason => '🎪',
  };

  /// جملة حملة قصيرة تُدمج في نص الإعلان — تضيف طابعًا احتفاليًا فوق
  /// مفردات النشاط، لا تستبدلها.
  String get campaignPhrase => switch (this) {
    SeasonalTheme.nationalDay => 'احتفالًا باليوم الوطني',
    SeasonalTheme.ramadan => 'في أجواء رمضان',
    SeasonalTheme.eid => 'بمناسبة فرحة العيد',
    SeasonalTheme.whiteFriday => 'ضمن عروض الجمعة البيضاء',
    SeasonalTheme.riyadhSeason => 'ضمن فعاليات موسم الرياض',
  };

  String get hashtag => switch (this) {
    SeasonalTheme.nationalDay => '#اليوم_الوطني',
    SeasonalTheme.ramadan => '#رمضان',
    SeasonalTheme.eid => '#عيدكم_مبارك',
    SeasonalTheme.whiteFriday => '#الجمعة_البيضاء',
    SeasonalTheme.riyadhSeason => '#موسم_الرياض',
  };

  /// لون الموسم — شارة التصميم ولوحة الألوان حين لا يوجد لون علامة
  /// (Brand Kit) محدَّد.
  Color get color => switch (this) {
    SeasonalTheme.nationalDay => const Color(0xFF006C35),
    SeasonalTheme.ramadan => const Color(0xFF241748),
    SeasonalTheme.eid => const Color(0xFF0F7B6C),
    SeasonalTheme.whiteFriday => const Color(0xFF111111),
    SeasonalTheme.riyadhSeason => const Color(0xFF6A1B9A),
  };

  int get colorValue => color.toARGB32();
}

/// هل موسم [season] قريب من [now]؟ يُستخدم لوضع إشارة «قريبًا» على
/// المواسم ذات التاريخ الميلادي الثابت أو التقريبي فقط (اليوم الوطني،
/// الجمعة البيضاء، موسم الرياض). رمضان والعيد بالتقويم الهجري المتغيّر
/// كل سنة بمقدار ~11 يومًا، فلا نقترحهما تلقائيًا بلا تقويم هجري
/// مضمَّن — يبقى اختيارهما يدويًا الخيار الوحيد الموثوق.
bool isSeasonApproaching(SeasonalTheme season, DateTime now) {
  switch (season) {
    case SeasonalTheme.nationalDay:
      // 23 سبتمبر — نافذة الاقتراب: من 30 يومًا قبله وحتى يوم الاحتفال.
      final target = DateTime(now.year, 9, 23);
      final diff = target.difference(DateTime(now.year, now.month, now.day)).inDays;
      return diff >= 0 && diff <= 30;
    case SeasonalTheme.whiteFriday:
      // النصف الثاني من نوفمبر تقريبًا (موعدها الفعلي يختلف قليلًا كل سنة).
      return now.month == 11 && now.day >= 15;
    case SeasonalTheme.riyadhSeason:
      // أكتوبر–مارس تقريبًا — موسم طويل بخلاف باقي المواسم هنا.
      return now.month >= 10 || now.month <= 3;
    case SeasonalTheme.ramadan:
    case SeasonalTheme.eid:
      return false;
  }
}
