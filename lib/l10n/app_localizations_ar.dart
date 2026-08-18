// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class LAr extends L {
  LAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'zol';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navMarket => 'السوق';

  @override
  String get navTemplates => 'القوالب';

  @override
  String get navMyAds => 'إعلاناتي';

  @override
  String get navOrders => 'طلباتي';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get homeTagline => 'سوق الدعاية والإعلان الشامل';

  @override
  String get homeSubtitle =>
      'من الفكرة إلى الإعلان المطبوع والمُوصَّل خلال دقائق';

  @override
  String get homeCta => 'أنشئ إعلانك الآن';

  @override
  String get homeCtaHint => 'معاينة فورية في أقل من 90 ثانية';

  @override
  String get homeStatAds => 'إعلان محفوظ';

  @override
  String get homeStatOrders => 'طلب طباعة';

  @override
  String homeWelcome(String name) {
    return 'مرحبًا، $name 👋';
  }

  @override
  String get templatesSearchHint => 'ابحث في القوالب — ستوري، بنر، كرت…';

  @override
  String get templatesEmpty => 'لا توجد قوالب مطابقة لبحثك';

  @override
  String get templatesKicker => 'ابدأ من قالب';

  @override
  String get templatesTitle => 'اختر الشكل الذي تريده';

  @override
  String get templatesSampleProduct => 'اسم منتجك';

  @override
  String get templatesSampleTone => 'حماسي';

  @override
  String get templatesPrintable => 'قابل للطباعة';

  @override
  String get templatesTrending => '🔥 رائج';

  @override
  String get myAdsTrash => 'سلة المهملات';

  @override
  String get myAdsEmptyTitle => 'مكتبتك فارغة';

  @override
  String get myAdsEmptyBody =>
      'احفظ النسخ التي تعجبك من «شاشة السحر» لتجدها هنا جاهزة لإعادة الاستخدام أو الطباعة.';

  @override
  String get myAdsKicker => 'المكتبة';

  @override
  String get myAdsTitle => 'إعلاناتك المحفوظة';

  @override
  String get myAdsOpenHint => 'اضغط لفتح التصميم وإعادة تصديره أو طباعته';

  @override
  String get myAdsCopyText => 'نسخ النص';

  @override
  String get myAdsDelete => 'حذف';

  @override
  String get myAdsCopied => 'تم نسخ النص الإعلاني';

  @override
  String get myAdsMovedToTrash => 'نُقل الإعلان إلى سلة المهملات';

  @override
  String get actionUndo => 'تراجع';

  @override
  String get ordersEmptyTitle => 'لا توجد طلبات بعد';

  @override
  String get ordersEmptyBody =>
      'عند اختيار «اطبعه وصلّه» بعد توليد إعلانك، سيظهر الطلب هنا مع خط زمني لتتبع حالته.';

  @override
  String get ordersKicker => 'التتبع';

  @override
  String get ordersTitle => 'حالة طلبات الطباعة';

  @override
  String ordersDeliverTo(String address) {
    return 'التوصيل إلى: $address';
  }

  @override
  String ordersShop(String shop) {
    return 'المطبعة: $shop';
  }

  @override
  String get ordersPaidByCard => 'مدفوع بالبطاقة ✓';

  @override
  String get ordersCashOnDelivery => 'الدفع عند الاستلام';

  @override
  String get ordersShowOnMap => 'عرض على الخريطة';

  @override
  String get ordersSimulate => 'محاكاة التقدم (تجريبي)';

  @override
  String get trashTitle => 'سلة المهملات';

  @override
  String get trashEmptyAction => 'إفراغ السلة';

  @override
  String get trashEmptyTitle => 'سلة المهملات فارغة';

  @override
  String trashEmptyBody(int days) {
    return 'الإعلانات التي تحذفها من «إعلاناتي» تبقى هنا لمدة $days يومًا قبل حذفها نهائيًا،\nوتقدر تسترجعها في أي وقت قبل ذلك.';
  }

  @override
  String get trashKicker => 'استعادة أو حذف نهائي';

  @override
  String trashCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إعلانًا في السلة',
      few: '$count إعلانات في السلة',
      two: 'إعلانان في السلة',
      one: 'إعلان واحد في السلة',
    );
    return '$_temp0';
  }

  @override
  String get trashConfirmTitle => 'إفراغ السلة نهائيًا؟';

  @override
  String trashConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سيُحذف $count إعلانًا نهائيًا ولا يمكن التراجع.',
      few: 'سيُحذف $count إعلانات نهائيًا ولا يمكن التراجع.',
      two: 'سيُحذف إعلانان نهائيًا ولا يمكن التراجع.',
      one: 'سيُحذف إعلان واحد نهائيًا ولا يمكن التراجع.',
    );
    return '$_temp0';
  }

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get trashConfirmAction => 'إفراغ نهائيًا';

  @override
  String get trashExpiringSoon => 'سيُحذف نهائيًا قريبًا';

  @override
  String trashExpiresIn(int days) {
    return 'يُحذف نهائيًا خلال $days يومًا';
  }

  @override
  String get trashRestore => 'استعادة';

  @override
  String get trashDeleteForever => 'حذف نهائي';

  @override
  String get marketTitle => 'السوق';

  @override
  String get marketSearchHint => 'ابحث عن مصوّر، مطبعة، مصمّم…';

  @override
  String get marketClearSearch => 'مسح البحث';

  @override
  String get marketAll => 'الكل';

  @override
  String get marketAllCities => 'كل المدن';

  @override
  String get marketEmptyTitle => 'لا مزوّد يطابق بحثك';

  @override
  String get marketEmptyBody => 'جرّب مدينة أخرى أو أزل المرشّحات';

  @override
  String get marketClearFilters => 'إزالة المرشّحات';

  @override
  String get marketVerified => 'موثّق';

  @override
  String marketPriceFrom(int price) {
    return 'من $price ر.س';
  }

  @override
  String get marketOnRequest => 'حسب الطلب';

  @override
  String marketRespondsIn(int hours) {
    return 'يردّ خلال $hours ساعات';
  }

  @override
  String marketRatingSemantics(String rating, int reviews) {
    return 'التقييم $rating من ٥، $reviews مراجعة';
  }

  @override
  String marketReviewsCount(int reviews) {
    return '($reviews مراجعة)';
  }

  @override
  String get storefrontMine => 'متجري';

  @override
  String storefrontNamed(String store) {
    return 'متجر $store';
  }

  @override
  String get storefrontEmptyHint => 'اعرض هويتك وأعمالك — ابدأ بحفظ إعلان';

  @override
  String storefrontAdsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إعلانًا',
      few: '$count إعلانات',
      two: 'إعلانان',
      one: 'إعلان واحد',
    );
    return 'واجهة عرضك: $_temp0';
  }

  @override
  String get storefrontShare => 'شارك واجهتك';

  @override
  String get storefrontEmptyTitle => 'واجهتك جاهزة وتنتظر أول عمل';

  @override
  String get storefrontEmptyBody =>
      'كل إعلان تحفظه من شاشة السحر يظهر هنا معروضًا.';

  @override
  String storefrontShowcase(int count) {
    return 'المعروض ($count)';
  }

  @override
  String get storefrontShareEmpty =>
      'احفظ إعلانًا أولًا لتصير واجهتك قابلة للمشاركة';

  @override
  String storefrontSharePending(String store) {
    return 'الرابط العام لواجهة $store قيد التجهيز';
  }

  @override
  String storefrontHarmony(String scheme) {
    return 'الانسجام: $scheme';
  }

  @override
  String get storefrontBrandColor => 'لون العلامة';

  @override
  String get storefrontSupportColor => 'لون مساند';

  @override
  String get providerPrice => 'السعر';

  @override
  String get providerResponseTime => 'زمن الردّ';

  @override
  String providerResponseHours(int hours) {
    return '~$hours ساعات';
  }

  @override
  String get providerStatus => 'الحالة';

  @override
  String get providerWorks => 'أعمال سابقة';

  @override
  String get providerRequestQuote => 'اطلب عرض سعر';

  @override
  String get providerDisclaimer =>
      'الدليل في مرحلته الأولى: طلبك يُحفظ ويصلك تأكيد حين يُفعَّل حساب المزوّد.';

  @override
  String providerInterestLogged(String name) {
    return 'سجّلنا اهتمامك بـ$name';
  }

  @override
  String providerReviewsCount(int reviews) {
    return '($reviews مراجعة)';
  }

  @override
  String printPricesNote(String delivery, int vat) {
    return 'الأسعار لكل وحدة قبل التوصيل ($delivery) وضريبة القيمة المضافة $vat٪.';
  }

  @override
  String get printOrder => 'اطلب';

  @override
  String get printNeedsDesign =>
      'صمّم إعلانًا واحفظه أولًا — الطباعة تحتاج تصميمًا';

  @override
  String get printWhichDesign => 'أيّ تصميم تطبع؟';

  @override
  String get marketNewProvider => 'جديد — بلا تقييمات بعد';

  @override
  String get providerSignupTitle => 'سجّل خدمتك في السوق';

  @override
  String get providerSignupIntro =>
      'اعرض خدمتك على تجّار zol. التسجيل مجاني، والمراجعة بشرية وتستغرق يومًا أو يومين — لا يظهر إدراجك في السوق قبلها.';

  @override
  String get providerSignupKind => 'نوع الخدمة';

  @override
  String get providerSignupName => 'اسم النشاط';

  @override
  String get providerSignupNameError => 'اكتب اسمًا من حرفين على الأقل';

  @override
  String get providerSignupCity => 'المدينة';

  @override
  String get providerSignupCityError => 'اكتب اسم المدينة';

  @override
  String get providerSignupTagline => 'ماذا تقدّم؟';

  @override
  String get providerSignupTaglineHelp =>
      'سطر واحد يقول ما تجيده — لا شعارًا تسويقيًّا';

  @override
  String get providerSignupTaglineError =>
      'اكتب عشرة أحرف على الأقل ليفهم التاجر خدمتك';

  @override
  String get providerSignupPrice => 'أقلّ سعر بالريال (اختياري)';

  @override
  String get providerSignupPriceHelp =>
      'اتركه فارغًا إن كانت خدمتك «حسب الطلب»';

  @override
  String get providerSignupPriceError => 'اكتب رقمًا صحيحًا';

  @override
  String get providerSignupHours => 'زمن الردّ بالساعات (اختياري)';

  @override
  String get providerSignupHoursHelp => 'متوسط ما تستغرقه للردّ على طلب';

  @override
  String get providerSignupHoursError => 'اكتب عدد ساعات بين ١ و٧٢٠';

  @override
  String get providerSignupWorks => 'أعمال سابقة (اختياري)';

  @override
  String get providerSignupWorksHelp =>
      'عنوان كل عمل في سطر — حتى اثني عشر عملًا';

  @override
  String get providerSignupSubmit => 'أرسل للمراجعة';

  @override
  String get providerSignupReviewNote =>
      'التوثيق (الشارة الذهبية) يُمنح بعد مراجعة سجلك التجاري، ولا يُطلب من هنا.';

  @override
  String get providerSignupSent => 'وصل طلبك — سنراجعه ونبلغك';

  @override
  String get providerSignupDuplicate =>
      'لديك إدراج بهذا النوع من الخدمة بالفعل';

  @override
  String get providerSignupFailed =>
      'تعذّر الإرسال — تحقّق من اتصالك وحاول مجددًا';

  @override
  String get providerSignupNeedsAccount =>
      'سجّل حسابك أولًا لتسجيل خدمتك في السوق';

  @override
  String get providerSignupOneListing =>
      'إدراج واحد لكل نوع خدمة. لتعديل بياناتك أو إضافة نوع آخر، راسلنا من الإعدادات.';

  @override
  String get marketJoin => 'سجّل خدمتك';

  @override
  String get wishHint => 'اكتب ما تريد… مثال: استاند رول بخصم ٣٠٪ وفخم';

  @override
  String get wishRun => 'نفّذ';

  @override
  String get wishFailed => 'تعذّر تنفيذ الطلب. حاول مجددًا.';

  @override
  String get wishDefaultCta => 'اطلب الآن';
}
