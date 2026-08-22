import 'print_catalog.dart';
import 'print_shop.dart';

/// دليل مزوّدي خدمات الدعاية — الجزء الذي كان اسمًا بلا مسمّى.
///
/// شعار التطبيق «سوق الدعاية والإعلان الشامل» كان سطرًا على الشاشة
/// الأولى لا غير: تحته أداة توليد إعلان ثم طلب طباعة، وليس فيه سوق ولا
/// مزوّد ولا عرض. التاجر يصنع إعلانه ثم يخرج من التطبيق ليبحث عن مصمّم
/// أو مصوّر أو مدير حملة في مكان آخر — وذلك المكان الآخر هو المنافس.
///
/// هنا يصير المزوّدون داخل التطبيق: يعرضون أعمالهم وأسعارهم، والتاجر
/// يتصفّح ويطلب دون أن يغادر.

/// أصناف الخدمة الإعلانية. الترتيب هو ترتيب العرض في السوق: الأقرب إلى
/// ما ينتجه التطبيق أولًا (طباعة ما صمّمه)، ثم ما يكمّله.
enum ServiceKind {
  printing,
  design,
  photography,
  video,
  campaign,
  signage,
  giveaways,
}

extension ServiceKindInfo on ServiceKind {
  String get label => switch (this) {
    ServiceKind.printing => 'طباعة',
    ServiceKind.design => 'تصميم',
    ServiceKind.photography => 'تصوير منتجات',
    ServiceKind.video => 'مونتاج وفيديو',
    ServiceKind.campaign => 'إدارة حملات',
    ServiceKind.signage => 'لوحات ولافتات',
    ServiceKind.giveaways => 'هدايا دعائية',
  };

  /// وصف قصير يظهر تحت الصنف في شريط التصفية — التاجر الصغير لا يعرف
  /// بالضرورة ما الذي يشتريه حين يقرأ «إدارة حملات».
  String get hint => switch (this) {
    ServiceKind.printing => 'استاندات، فلايرز، ملصقات، أكواب',
    ServiceKind.design => 'هوية بصرية، شعار، دليل ألوان',
    ServiceKind.photography => 'جلسة تصوير للمنتج بخلفية بيضاء أو مشهدية',
    ServiceKind.video => 'ريلز قصيرة ومونتاج لمقاطعك',
    ServiceKind.campaign => 'إدارة إعلانات سناب وتيك توك وانستغرام',
    ServiceKind.signage => 'لوحة المحل، واجهة، ستيكر سيارة',
    ServiceKind.giveaways => 'أقلام وأكياس وتيشيرتات بشعارك',
  };
}

/// مزوّد خدمة في السوق.
class ServiceProvider {
  const ServiceProvider({
    required this.id,
    required this.name,
    required this.kind,
    required this.city,
    required this.tagline,
    required this.priceFrom,
    required this.rating,
    required this.reviews,
    required this.works,
    this.verified = false,
    this.respondsInHours,
    this.usesPlatformCatalog = false,
  });

  final String id;
  final String name;
  final ServiceKind kind;
  final String city;

  /// سطر واحد يقول ما الذي يجيده — لا شعار تسويقي.
  final String tagline;

  /// أقلّ سعر بالريال. صفر يعني «حسب الطلب» — وهو حال الخدمات التي لا
  /// تُسعَّر بوحدة (إدارة حملة مثلًا).
  final int priceFrom;

  final double rating;
  final int reviews;

  /// عناوين أعمال سابقة. نصوص لا صور: الصور تُرفَع من لوحة المزوّد على
  /// الخادم لاحقًا، وحجزُ مكانها بصور وهمية الآن يخدع العين ويكذب.
  final List<String> works;

  final bool verified;

  /// متوسط زمن الردّ بالساعات. `null` يعني غير معلوم بعد.
  final int? respondsInHours;

  /// هل كتالوج المنصّة كتالوجُ هذا المزوّد فعلًا؟
  ///
  /// علَمٌ صريح لا استدلالٌ من الصنف. الصنف «طباعة» يشترك فيه طرفان
  /// مختلفان تمامًا: شبكةُ المطابع الخمس التي نعرف أسعارها وإحداثياتها
  /// ونوجّه إليها الطلب المدفوع، ومزوّدٌ سجّل نفسه بسعره هو. وعرضُ
  /// كتالوج المنصّة على صفحة الثاني يبيع أسعارًا ليست أسعاره، ثم يُسند
  /// الطلب إلى مطبعة أخرى — فلا هو باع ولا التاجر اشترى ممّن اختار.
  ///
  /// ويبقى `false` لكل مزوّد يأتي من الخادم: لا إحداثيات له في الجدول،
  /// ولا قناة تُبلّغه بطلب. وطلبٌ مدفوع بالبطاقة إلى جهة لا تُبلَّغ خسارةُ
  /// مالٍ لا تناقضُ أرقام.
  final bool usesPlatformCatalog;

  bool get onRequest => priceFrom <= 0;

  /// مزوّد جديد بلا طلبات بعد. يُعرض بلا نجوم — ونجومٌ تُمنح ابتداءً
  /// تجعل التقييم كلّه بلا معنى، لأن التاجر لا يفرّق حينها بين مزوّد
  /// خدَم مئتين ومزوّد سجّل أمس.
  bool get unrated => reviews <= 0;
}

/// دليل الإطلاق.
///
/// ثابت محليًا كما هي شبكة المطابع (`print_shop.dart`) وللسبب نفسه:
/// لوحة تسجيل المزوّدين على الخادم تأتي في مرحلتها، ويبقى منطق التصفية
/// والعرض هنا كما هو حين تُوصَل. المطابع تُضاف تلقائيًا أدناه فلا
/// تُكتَب مرتين ولا تفترق قائمتان.
final List<ServiceProvider> serviceProviders = [
  ...printShops.map(
    (s) => ServiceProvider(
      id: 'print-${s.name}',
      name: s.name,
      kind: ServiceKind.printing,
      city: s.city,
      tagline: 'طباعة استاندات وفلايرز وملصقات — تسليم داخل المدينة',
      // السعر والأعمال من كتالوج الطباعة الحقيقي لا من أرقام مكتوبة
      // هنا. رقمٌ يُكتب في ملفّ الدليل ينفصل عن التسعير الفعلي بعد أول
      // تعديل، فيرى التاجر «من ٤٥ ر.س» ثم يُطالَب بغيرها عند الطلب.
      priceFrom: printCatalogMinPrice,
      rating: 0,
      reviews: 0,
      works: printCatalogLabels,
      verified: true,
      respondsInHours: 3,
      usesPlatformCatalog: true,
    ),
  ),
  const ServiceProvider(
    id: 'design-hawiya',
    name: 'استوديو هوية',
    kind: ServiceKind.design,
    city: 'الرياض',
    tagline: 'هوية بصرية كاملة: شعار ودليل ألوان وخطوط جاهزة للتطبيق',
    priceFrom: 1200,
    rating: 0,
    reviews: 0,
    works: ['هوية مقهى تخصصي', 'شعار عيادة أسنان', 'دليل ألوان متجر أزياء'],
    verified: true,
    respondsInHours: 6,
  ),
  const ServiceProvider(
    id: 'design-raqsh',
    name: 'رقش للتصميم',
    kind: ServiceKind.design,
    city: 'جدة',
    tagline: 'تصميم عربي بخطّ يدوي — لمن يريد هوية لا تشبه القوالب',
    priceFrom: 800,
    rating: 0,
    reviews: 0,
    works: ['شعار مطعم شعبي', 'قائمة طعام مخطوطة'],
    respondsInHours: 12,
  ),
  const ServiceProvider(
    id: 'photo-lqta',
    name: 'لقطة استوديو',
    kind: ServiceKind.photography,
    city: 'الرياض',
    tagline: 'تصوير منتجات بخلفية بيضاء معزولة — جاهزة للرفع مباشرة',
    priceFrom: 35,
    rating: 0,
    reviews: 0,
    works: ['٣٠ منتج عناية', 'تشكيلة عطور', 'حلويات بإضاءة طبيعية'],
    verified: true,
    respondsInHours: 2,
  ),
  const ServiceProvider(
    id: 'photo-daw',
    name: 'ضوء ومنتج',
    kind: ServiceKind.photography,
    city: 'الدمام',
    tagline: 'تصوير مشهدي للمأكولات — الطبق كما يُشتهى لا كما هو',
    priceFrom: 60,
    rating: 0,
    reviews: 0,
    works: ['قائمة مطعم بحري', 'مقهى مختص'],
    respondsInHours: 8,
  ),
  const ServiceProvider(
    id: 'video-rils',
    name: 'ريلز ستديو',
    kind: ServiceKind.video,
    city: 'جدة',
    tagline: 'مقاطع ١٥ ثانية للسناب والتيك توك من صورك الحالية',
    priceFrom: 250,
    rating: 0,
    reviews: 0,
    works: ['ريل افتتاح فرع', 'إعلان عرض نهاية الأسبوع'],
    respondsInHours: 5,
  ),
  const ServiceProvider(
    id: 'campaign-madar',
    name: 'مدار الحملات',
    kind: ServiceKind.campaign,
    city: 'الرياض',
    tagline: 'إدارة ميزانية إعلانك على سناب وتيك توك وتقرير أسبوعي',
    priceFrom: 0, // حسب الميزانية
    rating: 0,
    reviews: 0,
    works: ['حملة مطعم — ٣٫٢ ضعف عائد', 'إطلاق متجر أزياء'],
    verified: true,
    respondsInHours: 4,
  ),
  const ServiceProvider(
    id: 'signage-lawh',
    name: 'لوح للدعاية',
    kind: ServiceKind.signage,
    city: 'بريدة',
    tagline: 'لوحة المحل من التصميم إلى التركيب — مع رخصة البلدية',
    priceFrom: 900,
    rating: 0,
    reviews: 0,
    works: ['واجهة صيدلية', 'ستيكر سيارة توصيل'],
    respondsInHours: 24,
  ),
  const ServiceProvider(
    id: 'gift-hadaya',
    name: 'هدايا بشعارك',
    kind: ServiceKind.giveaways,
    city: 'الرياض',
    tagline: 'أكواب وأقلام وأكياس بشعارك — من ٥٠ قطعة',
    priceFrom: 6,
    rating: 0,
    reviews: 0,
    works: ['أكواب مقهى', 'أكياس متجر', 'تيشيرتات فريق'],
    respondsInHours: 10,
  ),
];

/// المدن التي فيها مزوّدون — تُشتقّ ولا تُكتب، فلا تظهر مدينة فارغة في
/// المرشّح ولا تغيب مدينة أُضيف فيها مزوّد.
List<String> providerCitiesOf(List<ServiceProvider> list) {
  final cities = list.map((p) => p.city).toSet().toList()..sort();
  return cities;
}

List<String> get providerCities => providerCitiesOf(serviceProviders);

/// تصفية الدليل. كل المعايير اختيارية وتتراكم.
List<ServiceProvider> filterProviders({
  ServiceKind? kind,
  String? city,
  String query = '',
  List<ServiceProvider>? source,
}) {
  final q = query.trim();
  return (source ?? serviceProviders).where((p) {
      if (kind != null && p.kind != kind) return false;
      if (city != null && p.city != city) return false;
      if (q.isEmpty) return true;
      return p.name.contains(q) ||
          p.tagline.contains(q) ||
          p.kind.label.contains(q) ||
          p.works.any((w) => w.contains(q));
    }).toList()
    // الترتيب على ما نعرفه حقًّا.
    //
    // كان على التقييم: الأعلى نجومًا أوّلًا. والنجوم كانت **مكتوبة في
    // هذا الملفّ** — «٤٫٩ من ٢١٠ مراجعة» لمزوّد لم يبِع شيئًا قطّ. فكان
    // الترتيبُ ترتيبًا بأرقام اخترعناها، والعرضُ إيهامًا بسوق قائم.
    //
    // فبقي ما نعرفه: التوثيق (راجعناه بأنفسنا)، ثم سرعة الردّ (يقولها
    // المزوّد ويُحاسَب عليها)، ثم السعر. والتقييم يبقى في الترتيب أوّلًا
    // ليعمل من تلقائه يوم توجد مراجعات حقيقية.
    ..sort((a, b) {
      if (a.unrated != b.unrated) return a.unrated ? 1 : -1;
      if (!a.unrated) {
        final byRating = b.rating.compareTo(a.rating);
        if (byRating != 0) return byRating;
        final byReviews = b.reviews.compareTo(a.reviews);
        if (byReviews != 0) return byReviews;
      }
      if (a.verified != b.verified) return a.verified ? -1 : 1;
      final ah = a.respondsInHours ?? 1 << 20;
      final bh = b.respondsInHours ?? 1 << 20;
      if (ah != bh) return ah.compareTo(bh);
      return a.priceFrom.compareTo(b.priceFrom);
    });
}


/// أدنى سعر وحدة في كتالوج الطباعة — «من كذا ر.س» في بطاقة المزوّد.
///
/// يُحسب ولا يُكتب: كل تعديل على الكتالوج ينعكس في السوق تلقائيًّا، فلا
/// يعد الدليلُ بسعرٍ لا يجده التاجر عند الطلب.
int get printCatalogMinPrice => printCatalog
    .expand((p) => p.sizes)
    .map((z) => z.unitPrice)
    .reduce((a, b) => a < b ? a : b)
    .round();

/// ما تطبعه المطابع فعلًا — من الكتالوج نفسه لا من قائمة موازية.
List<String> get printCatalogLabels =>
    printCatalog.map((p) => p.label).toList();
