import 'package:flutter/material.dart';

/// نشاط التاجر — أكبر قفزة في جودة النص المولَّد بأقل تكلفة.
///
/// المولّد العام يكتب جملًا محايدة تصلح لأي شيء ولا تُقنع أحدًا. حين يعرف
/// أن التاجر كافيه يكتب عن الرائحة والتحميص والأجواء، وحين يعرف أنه عقار
/// يكتب عن الموقع والتشطيب والتمويل. لا يحتاج هذا أي خدمة سحابية.
enum BusinessCategory {
  restaurant,
  cafe,
  fashion,
  beauty,
  sweets,
  realEstate,
  services,
  retail,
}

extension BusinessCategoryInfo on BusinessCategory {
  String get label => switch (this) {
    BusinessCategory.restaurant => 'مطعم ومأكولات',
    BusinessCategory.cafe => 'كافيه وقهوة',
    BusinessCategory.fashion => 'ملابس وأزياء',
    BusinessCategory.beauty => 'تجميل وعناية',
    BusinessCategory.sweets => 'حلويات ومخبوزات',
    BusinessCategory.realEstate => 'عقار',
    BusinessCategory.services => 'خدمات وصيانة',
    BusinessCategory.retail => 'متجر ومنتجات',
  };

  IconData get icon => switch (this) {
    BusinessCategory.restaurant => Icons.restaurant_outlined,
    BusinessCategory.cafe => Icons.local_cafe_outlined,
    BusinessCategory.fashion => Icons.checkroom_outlined,
    BusinessCategory.beauty => Icons.spa_outlined,
    BusinessCategory.sweets => Icons.cake_outlined,
    BusinessCategory.realEstate => Icons.apartment_outlined,
    BusinessCategory.services => Icons.handyman_outlined,
    BusinessCategory.retail => Icons.storefront_outlined,
  };

  /// عبارات جذب خاصة بالنشاط — تُصاغ حسب النبرة في العنوان.
  List<String> get hooks => switch (this) {
    BusinessCategory.restaurant => [
      'طبق يستاهل التجربة',
      'نكهة تعيدك مرة ثانية',
      'من مطبخنا إلى طاولتك',
    ],
    BusinessCategory.cafe => [
      'رائحة توقظ يومك',
      'حبّة مختصة محمّصة طازجة',
      'قهوتك بمزاج ثاني',
    ],
    BusinessCategory.fashion => [
      'إطلالة تلفت الأنظار',
      'وصلت التشكيلة الجديدة',
      'ستايلك بلمستك',
    ],
    BusinessCategory.beauty => [
      'جمالك يستاهل العناية',
      'نتيجة تشوفها من أول استخدام',
      'دلّل بشرتك اليوم',
    ],
    BusinessCategory.sweets => [
      'حلا يفتح النفس',
      'طازج من الفرن',
      'لأحلى المناسبات',
    ],
    BusinessCategory.realEstate => [
      'بيتك القادم بانتظارك',
      'موقع يستحق',
      'فرصة استثمارية لا تتكرر',
    ],
    BusinessCategory.services => [
      'خدمة تعتمد عليها',
      'نصل إليك بسرعة',
      'حلّ مشكلتك اليوم',
    ],
    BusinessCategory.retail => [
      'منتج يستاهل التجربة',
      'وصل حديثًا',
      'الجودة اللي تدوّر عليها',
    ],
  };

  /// جمل المنفعة التي تُبنى عليها متون الإعلان.
  List<String> get benefits => switch (this) {
    BusinessCategory.restaurant => [
      'مكوّنات طازجة تُحضَّر يوميًا',
      'تحضير على الطلب وتقديم سريع',
      'حصص تكفي وتفيض',
    ],
    BusinessCategory.cafe => [
      'تحميص طازج كل أسبوع',
      'أجواء هادئة تريح البال',
      'باريستا يعرف شغله',
    ],
    BusinessCategory.fashion => [
      'خامات مريحة تدوم طويلًا',
      'مقاسات تناسب الجميع',
      'تشكيلة محدودة لا تتكرر',
    ],
    BusinessCategory.beauty => [
      'مكوّنات آمنة ومجرّبة',
      'مناسب لكل أنواع البشرة',
      'نتائج تدوم مع الاستخدام المنتظم',
    ],
    BusinessCategory.sweets => [
      'مكوّنات طبيعية بلا إضافات',
      'تجهيز خاص للمناسبات',
      'أحجام تناسب كل عزيمة',
    ],
    BusinessCategory.realEstate => [
      'تشطيب فاخر وتسليم فوري',
      'موقع قريب من كل الخدمات',
      'أسعار تنافسية وتمويل ميسّر',
    ],
    BusinessCategory.services => [
      'فريق متخصص ومعتمد',
      'ضمان على العمل',
      'أسعار واضحة بلا مفاجآت',
    ],
    BusinessCategory.retail => [
      'ضمان واستبدال سهل',
      'شحن سريع لكل المدن',
      'أسعار منافسة',
    ],
  };

  /// دعوة الإجراء التي تظهر على زر التصميم وفي نهاية النص.
  String get cta => switch (this) {
    BusinessCategory.restaurant => 'اطلب الآن',
    BusinessCategory.cafe => 'زورونا اليوم',
    BusinessCategory.fashion => 'تسوّق الآن',
    BusinessCategory.beauty => 'احجز موعدك',
    BusinessCategory.sweets => 'جهّز مناسبتك',
    BusinessCategory.realEstate => 'احجز معاينتك',
    BusinessCategory.services => 'اطلب الخدمة',
    BusinessCategory.retail => 'اطلب الآن',
  };

  List<String> get hashtags => switch (this) {
    BusinessCategory.restaurant => ['#مطاعم', '#فودي'],
    BusinessCategory.cafe => ['#قهوة_مختصة', '#كوفي'],
    BusinessCategory.fashion => ['#أزياء', '#تشكيلة_جديدة'],
    BusinessCategory.beauty => ['#عناية', '#جمال'],
    BusinessCategory.sweets => ['#حلويات', '#مخبوزات'],
    BusinessCategory.realEstate => ['#عقار', '#استثمار'],
    BusinessCategory.services => ['#خدمات', '#احترافية'],
    BusinessCategory.retail => ['#تسوق', '#منتجات'],
  };
}
