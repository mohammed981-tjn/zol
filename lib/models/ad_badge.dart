/// شارات ترويجية جاهزة تُركَّب على أي قالب — أول قطعة من «مكتبة العناصر»
/// التي تتفوق بها أدوات التصميم الكبرى: التاجر يختار شارة فتظهر على
/// تصميمه فورًا بلون هويته، بلا بحث عن ملصقات ولا برامج خارجية.
///
/// المفردات سعودية تجارية صرفة — ما يكتبه التاجر على واجهة محله فعلًا.
enum AdBadge {
  discount,
  special,
  fresh,
  freeDelivery,
  limited,
  halal,
}

extension AdBadgeInfo on AdBadge {
  String get label => switch (this) {
    AdBadge.discount => 'خصم',
    AdBadge.special => 'عرض خاص',
    AdBadge.fresh => 'جديد',
    AdBadge.freeDelivery => 'توصيل مجاني',
    AdBadge.limited => 'الكمية محدودة',
    AdBadge.halal => 'حلال ١٠٠٪',
  };
}
