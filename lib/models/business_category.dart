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

  /// عبارات جذب خاصة بالنشاط — تُصاغ حسب النبرة في العنوان. الثلاثة
  /// الأولى هي الأصلية (تبقى بترتيبها لثبات النتيجة عند seed=0)، والباقي
  /// تنويعات إضافية تمنع تكرار نفس العبارات عند إعادة التوليد المتكرر.
  List<String> get hooks => switch (this) {
    BusinessCategory.restaurant => [
      'طبق يستاهل التجربة',
      'نكهة تعيدك مرة ثانية',
      'من مطبخنا إلى طاولتك',
      'طعم يخلّي العزيمة تتكرر',
      'وصفة أصلية بلمسة عصرية',
      'أطباقنا تحكي حكاية',
    ],
    BusinessCategory.cafe => [
      'رائحة توقظ يومك',
      'حبّة مختصة محمّصة طازجة',
      'قهوتك بمزاج ثاني',
      'استراحتك المفضّلة بانتظارك',
      'كل رشفة قصة تحميص',
      'فنجانك القادم أفضل من الأول',
    ],
    BusinessCategory.fashion => [
      'إطلالة تلفت الأنظار',
      'وصلت التشكيلة الجديدة',
      'ستايلك بلمستك',
      'قطع تختصر بحثك عن الإطلالة',
      'موضة تناسب كل مناسبة',
      'خزانتك تستاهل تجديدًا',
    ],
    BusinessCategory.beauty => [
      'جمالك يستاهل العناية',
      'نتيجة تشوفها من أول استخدام',
      'دلّل بشرتك اليوم',
      'روتين عناية يستحق وقتك',
      'إشراقة تلاحظها من حولك',
      'اهتمام يليق بك',
    ],
    BusinessCategory.sweets => [
      'حلا يفتح النفس',
      'طازج من الفرن',
      'لأحلى المناسبات',
      'حلاوة تليق بضيوفك',
      'كل قطعة صنعت بعناية',
      'تحلية تكمّل فرحتك',
    ],
    BusinessCategory.realEstate => [
      'بيتك القادم بانتظارك',
      'موقع يستحق',
      'فرصة استثمارية لا تتكرر',
      'مساحة تليق بعائلتك',
      'استثمار اليوم أساس غدك',
      'وحدة تجمع الموقع والتشطيب',
    ],
    BusinessCategory.services => [
      'خدمة تعتمد عليها',
      'نصل إليك بسرعة',
      'حلّ مشكلتك اليوم',
      'خبرة توفّر عليك الوقت والمجهود',
      'راحة بالك تبدأ من هنا',
      'فريق جاهز أينما كنت',
    ],
    BusinessCategory.retail => [
      'منتج يستاهل التجربة',
      'وصل حديثًا',
      'الجودة اللي تدوّر عليها',
      'اختيار يناسب ذوقك',
      'تسوّق أذكى، تسوّق أوفر',
      'كل ما تحتاجه في مكان واحد',
    ],
  };

  /// جمل المنفعة التي تُبنى عليها متون الإعلان.
  List<String> get benefits => switch (this) {
    BusinessCategory.restaurant => [
      'مكوّنات طازجة تُحضَّر يوميًا',
      'تحضير على الطلب وتقديم سريع',
      'حصص تكفي وتفيض',
      'نكهات مدروسة ترضي كل الأذواق',
      'نظافة وجودة لا تتنازل عنها',
      'توصيل سريع وطعام يصلك ساخنًا',
    ],
    BusinessCategory.cafe => [
      'تحميص طازج كل أسبوع',
      'أجواء هادئة تريح البال',
      'باريستا يعرف شغله',
      'حبوب مختارة من أفضل المزارع',
      'قائمة تناسب كل الأذواق',
      'مكان يصلح للعمل وللقاء الأصدقاء',
    ],
    BusinessCategory.fashion => [
      'خامات مريحة تدوم طويلًا',
      'مقاسات تناسب الجميع',
      'تشكيلة محدودة لا تتكرر',
      'تصاميم تواكب أحدث صيحات الموضة',
      'ألوان وخامات مختارة بعناية',
      'قطع تناسب اليومي والمناسبات',
    ],
    BusinessCategory.beauty => [
      'مكوّنات آمنة ومجرّبة',
      'مناسب لكل أنواع البشرة',
      'نتائج تدوم مع الاستخدام المنتظم',
      'اختصاصيات مدرَّبات بأحدث التقنيات',
      'أجواء هادئة تليق بجلسة استرخاء',
      'منتجات معتمدة وآمنة تمامًا',
    ],
    BusinessCategory.sweets => [
      'مكوّنات طبيعية بلا إضافات',
      'تجهيز خاص للمناسبات',
      'أحجام تناسب كل عزيمة',
      'وصفات تقليدية بلمسة مبتكرة',
      'تغليف أنيق يليق بالإهداء',
      'طلبات مسبقة تضمن طزاجتها',
    ],
    BusinessCategory.realEstate => [
      'تشطيب فاخر وتسليم فوري',
      'موقع قريب من كل الخدمات',
      'أسعار تنافسية وتمويل ميسّر',
      'مخططات مرنة تناسب احتياجك',
      'ضمانات واضحة وتوثيق موثوق',
      'مرافق متكاملة داخل المشروع',
    ],
    BusinessCategory.services => [
      'فريق متخصص ومعتمد',
      'ضمان على العمل',
      'أسعار واضحة بلا مفاجآت',
      'معاينة سريعة قبل البدء',
      'أدوات ومعدات حديثة',
      'متابعة بعد انتهاء الخدمة',
    ],
    BusinessCategory.retail => [
      'ضمان واستبدال سهل',
      'شحن سريع لكل المدن',
      'أسعار منافسة',
      'تشكيلة تتجدد باستمرار',
      'دعم عملاء يرد بسرعة',
      'طرق دفع متعددة وآمنة',
    ],
  };

  /// دعوة الإجراء الافتراضية — تظهر على زر التصميم وتبقى ثابتة للتوافق
  /// مع أي كود يعتمد قيمة واحدة مستقرة.
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

  /// دعوات إجراء بديلة تُضاف إلى [cta] عند التوليد لتنويع الصياغة —
  /// [cta] نفسها تبقى دائمًا أول خيار فلا يتغيّر سلوك seed=0.
  List<String> get ctaVariants => switch (this) {
    BusinessCategory.restaurant => ['جرّب طبقك المفضّل', 'اطلب توصيلك الآن'],
    BusinessCategory.cafe => ['تفضّل بزيارتنا', 'اطلب قهوتك الآن'],
    BusinessCategory.fashion => ['اكتشف التشكيلة', 'أضِف لطلتك الجديدة'],
    BusinessCategory.beauty => ['احجزي جلستك', 'دلّلي نفسك اليوم'],
    BusinessCategory.sweets => ['اطلب طلبك الآن', 'احجز طلبك مسبقًا'],
    BusinessCategory.realEstate => ['تواصل معنا الآن', 'اطلب كتيّب المشروع'],
    BusinessCategory.services => ['احجز موعدك', 'تواصل معنا الآن'],
    BusinessCategory.retail => ['تسوّق الآن', 'اطلب توصيلك اليوم'],
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
