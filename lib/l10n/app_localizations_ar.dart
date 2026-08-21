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
      'طلبك يصل المزوّد المسجَّل مباشرة. ومزوّدو شبكة المطابع تصلهم رسالتك من زرّ «أرسله بنفسك».';

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
  String get roleHeadline => 'العنوان';

  @override
  String get roleSubhead => 'السطر الثانوي';

  @override
  String get roleProduct => 'المنتج';

  @override
  String get roleCta => 'زرّ الحثّ';

  @override
  String get roleBadge => 'الشارة';

  @override
  String get roleLogo => 'الشعار';

  @override
  String get roleTags => 'الهاشتاقات';

  @override
  String get roleShape => 'شكل';

  @override
  String get roleOrnament => 'الزخرفة';

  @override
  String get guideTitle => 'دليل الاستخدام';

  @override
  String get shopPanelTitle => 'لوحة المطبعة';

  @override
  String get orderNoShopYet =>
      'لا مطبعة معتمدة تخدم موقعك بعد. صمّم واحفظ الآن، ويمكنك طلب عرض سعر من تبويب السوق.';

  @override
  String orderShopLacksProduct(Object shop, Object product) {
    return 'مطبعة $shop لا تقدّم $product حاليًا. جرّب منتجًا آخر أو اطلب عرض سعر من السوق.';
  }

  @override
  String get orderQuoteFailed =>
      'تعذّر تسعير الطلب الآن. تحقّق من اتصالك وحاول ثانية.';

  @override
  String get orderArtworkCaptureFailed =>
      'تعذّر تجهيز ملفّ التصميم على هذا الجهاز.';

  @override
  String get orderArtworkUploadFailed =>
      'تعذّر رفع ملفّ التصميم. سجّل الدخول ثم أعد المحاولة.';

  @override
  String get orderPaymentIncomplete =>
      'لم يكتمل الدفع. طلبك محفوظ غير مدفوع ويمكنك إكماله.';

  @override
  String get orderNeedsAccount =>
      'يلزم تسجيل الدخول قبل طلب الطباعة — الطلب يُنسب إلى صاحبه.';

  @override
  String get orderOffline =>
      'تعذّر الوصول إلى الخادم. لم يُنشأ طلب ولم يُقبض شيء.';

  @override
  String get orderShopUnavailable => 'المطبعة غير متاحة الآن.';

  @override
  String get orderProductUnavailable => 'هذا المنتج غير متاح لدى المطبعة.';

  @override
  String get orderBelowMinQty => 'الكمية أقل من الحدّ الأدنى لدى المطبعة.';

  @override
  String get orderCreateFailed => 'تعذّر إنشاء الطلب. لم يُقبض شيء.';

  @override
  String get orderPriceChangedTitle => 'تغيّر السعر';

  @override
  String orderPriceChangedBody(Object actual, Object shown) {
    return 'سعر المطبعة $actual بدل $shown المعروض. المبلغ المعروض تقديريّ، والمعتمد ما تسعّره المطبعة.';
  }

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonContinue => 'متابعة';

  @override
  String priceVatIncluded(Object amount) {
    return 'شامل ضريبة القيمة المضافة $amount';
  }

  @override
  String get pricePlatformFee => 'رسم المنصّة';

  @override
  String get shopPanelHeading => 'لوحة المطبعة قيد البناء';

  @override
  String get shopPanelBody =>
      'طوابير الطباعة وحالاتها تحتاج صلاحية مطبعة في الخادم، وهي المرحلة التالية. ولم يصل طلب طباعة إلى أي مطبعة بعد، فلا شيء يُعرض هنا اليوم إلا هذا السطر الصادق.';

  @override
  String get shopPanelOpenMerchant => 'افتح واجهة التاجر';

  @override
  String get shopPanelEntrySubtitle => 'طوابير الطباعة وحالاتها';

  @override
  String get guideUnavailable => 'تعذّر فتح الدليل على هذا الجهاز.';

  @override
  String get editorTitle => 'تحرير التصميم';

  @override
  String get editorResizeHandle => 'مقبض التحجيم';

  @override
  String get editorSpecHint =>
      'المس عنصرًا لتحدّده، ثم اسحبه لتحريكه أو اسحب المقبض لتحجيمه';

  @override
  String get editorProductHint => 'اسحب لتحريك المنتج، وباعد إصبعيك لتكبيره';

  @override
  String get editorNoProductHint => 'أضف صورة منتج لتتمكن من تحريكها';

  @override
  String get editorResetProduct => 'إرجاع المنتج لوضعه';

  @override
  String get editorResetLayout => 'إرجاع التخطيط كما وُلِّد';

  @override
  String get editorEditText => 'تحرير النص';

  @override
  String get editorEditElement => 'تحرير العنصر المحدّد';

  @override
  String get editorElementText => 'نصّ العنصر';

  @override
  String get editorFieldHeadline => 'العنوان';

  @override
  String get editorFieldBody => 'النص الفرعي';

  @override
  String get editorFieldCta => 'زر الدعوة';

  @override
  String get editorApply => 'تطبيق';

  @override
  String get editorSaveChanges => 'حفظ التعديلات';

  @override
  String get editorDone => 'تم';

  @override
  String get executeEditTemplate => 'تحرير التصميم (نص وموضع المنتج)';

  @override
  String get executeEditSpec => 'تحرير التصميم (حرّك العناصر وغيّر نصّها)';

  @override
  String get executeGeneratedNote =>
      'هذا تخطيط ركّبه الذكاء لطلبك، فلا ينطبق عليه اختيار القوالب. حرّكه كما تشاء أو اطلب تخطيطًا آخر من شاشة السحر.';

  @override
  String get wishRefineChip => 'عدّل هذا التصميم';

  @override
  String get wishRefineHint =>
      'اكتب ما تريد تغييره… مثال: كبّر العنوان واجعل الخلفية فاتحة';

  @override
  String get wishRead => 'فهمتُ';

  @override
  String wishReadDiscount(int pct) {
    return 'خصم $pct٪';
  }

  @override
  String get wishOfferDiscount => 'خصم';

  @override
  String get wishOfferOpening => 'افتتاح';

  @override
  String get wishOfferNewItem => 'صنف جديد';

  @override
  String get wishOfferHiring => 'توظيف';

  @override
  String get wishOfferDelivery => 'توصيل';

  @override
  String get wishOfferSeason => 'موسم';

  @override
  String get wishOfferGeneral => 'إعلان عام';

  @override
  String get wishPresetDiscount => 'إعلان خصم ٥٠٪ لنهاية الأسبوع';

  @override
  String get wishPresetOpening => 'افتتاح فرع جديد';

  @override
  String get wishPresetNewItem => 'وصل منتج جديد';

  @override
  String get wishPresetHiring => 'نطلب موظفين';

  @override
  String get wishPresetDelivery => 'توصيل مجاني اليوم';

  @override
  String get wishPresetRamadan => 'عرض رمضان';

  @override
  String get quoteSheetTitle => 'اطلب تسعيرة';

  @override
  String get quoteNeedLabel => 'ما الذي تحتاجه؟';

  @override
  String get quoteNeedHelp =>
      'اكتب المطلوب بوضوح: الكمّية والمقاس والموعد إن وُجد';

  @override
  String get quoteNeedError => 'اكتب عشرة أحرف على الأقل ليفهم المزوّد طلبك';

  @override
  String get quoteBudgetLabel => 'الميزانية التقريبية بالريال (اختياري)';

  @override
  String get quoteContactLabel => 'كيف يردّ عليك؟';

  @override
  String get quoteContactHelp =>
      'رقم واتساب أو بريد — بلا وسيلة ردّ لا تصلك تسعيرة';

  @override
  String get quoteContactError => 'اكتب رقمًا أو بريدًا صحيحًا';

  @override
  String get quoteSend => 'أرسل الطلب';

  @override
  String get quoteShare => 'أرسله بنفسك';

  @override
  String get quoteDelivered => 'وصل طلبك إلى المزوّد';

  @override
  String get quoteOffline =>
      'تعذّر الإرسال عبر التطبيق — أرسِله بنفسك من الزرّ أدناه';

  @override
  String get quoteNeedsAccount =>
      'سجّل حسابك أوّلًا ليُنسب الطلب إليك ويصلك الردّ';

  @override
  String get quoteNotRoutable =>
      'هذا المزوّد من شبكة المطابع ولا يستقبل عبر التطبيق — انسخ الطلب وأرسله إليه';

  @override
  String get quoteCopied => 'نُسخ نصّ الطلب';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageSystem => 'لغة الجهاز';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageNote =>
      'تغيير اللغة يغيّر واجهة التطبيق فقط. نصّ الإعلان يبقى بلغة جمهورك.';

  @override
  String get onboardingSkip => 'تخطٍّ';

  @override
  String get onboardingNext => 'التالي';

  @override
  String get onboardingStart => 'ابدأ الآن';

  @override
  String get onboardingPickFirst => 'اختر نشاطك للمتابعة';

  @override
  String get onboardingT1 => 'إعلانك يولد في ثوانٍ';

  @override
  String get onboardingB1 =>
      'ارفع صورة منتجك واختر النبرة والمنصة، ونحن نخرج لك نصًا وتصميمًا جاهزين للنشر.';

  @override
  String get onboardingT2 => 'اطبعه عند أقرب مطبعة';

  @override
  String get onboardingB2 =>
      'بنرات، استيكرات، كروت ورول أب بأسعار فورية — ويُسند طلبك تلقائيًا لأقرب مطبعة شريكة لموقعك.';

  @override
  String get onboardingT3 => 'ويصلك حتى الباب';

  @override
  String get onboardingB3 =>
      'حدّد موقعك على الخريطة وتابع طلبك خطوة بخطوة حتى يصل بين يديك.';

  @override
  String get onboardingCategoryTitle => 'ما نشاطك؟';

  @override
  String get onboardingCategoryBody =>
      'نكتب لك نصوصًا بمفردات مجالك — لا جملًا عامة تصلح لأي شيء.';

  @override
  String get onboardingCategoryHint => 'يمكنك تغييره لاحقًا من الإعدادات';

  @override
  String get authEmailError => 'أدخل بريدًا إلكترونيًا صحيحًا';

  @override
  String get authPasswordError => 'كلمة المرور 6 أحرف على الأقل';

  @override
  String get authNameError => 'أدخل اسمك';

  @override
  String get authStoreError => 'أدخل اسم متجرك أو نشاطك';

  @override
  String get authTitleLogin => 'تسجيل الدخول';

  @override
  String get authTitleSignup => 'إنشاء حساب تاجر';

  @override
  String get authIntroLogin => 'سجّل دخولك لمتابعة إعلاناتك وطلباتك';

  @override
  String get authIntroSignup => 'أنشئ حساب تاجر لحفظ إعلاناتك وتتبع طلباتك';

  @override
  String get authFieldName => 'الاسم *';

  @override
  String get authHintName => 'اسمك الكامل';

  @override
  String get authFieldStore => 'اسم المتجر *';

  @override
  String get authHintStore => 'مثال: محمصة الفجر';

  @override
  String get authFieldEmail => 'البريد الإلكتروني *';

  @override
  String get authFieldPassword => 'كلمة المرور *';

  @override
  String get authHintPassword => '6 أحرف على الأقل';

  @override
  String get authSubmitLogin => 'دخول';

  @override
  String get authSubmitSignup => 'إنشاء الحساب';

  @override
  String get authSwitchToSignup => 'ليس لديك حساب؟ أنشئ حسابًا جديدًا';

  @override
  String get authSwitchToLogin => 'لديك حساب بالفعل؟ سجّل دخولك';

  @override
  String authWelcomeBack(String name) {
    return 'مرحبًا بعودتك، $name!';
  }

  @override
  String authAccountCreated(String name) {
    return 'تم إنشاء حسابك بنجاح، $name!';
  }

  @override
  String get wishLocalOnly =>
      'صُمّم على جهازك — تعذّر الوصول إلى الذكاء السحابي';

  @override
  String get magicTitle => 'شاشة السحر';

  @override
  String get magicRegenerate => 'إعادة توليد';

  @override
  String get magicFailed => 'تعذّر إكمال التوليد. حاول مجددًا.';

  @override
  String get magicSceneFailed => 'تعذّر توليد المشهد. حاول مجددًا.';

  @override
  String get magicQuotaTitle => 'انتهت حصتك لهذا الشهر';

  @override
  String get magicErrorTitle => 'تعذّر التوليد';

  @override
  String get magicRetry => 'إعادة المحاولة';

  @override
  String get magicBackAndEdit => 'العودة وتعديل الوصف';

  @override
  String get magicWorking => 'الذكاء الاصطناعي يعمل على إعلانك…';

  @override
  String get magicStepKicker => 'الخطوة 2 من 3';

  @override
  String get magicPickBest => 'اختر النسخة الأنسب';

  @override
  String get magicSaveAndPublish => 'حفظ ونشر';

  @override
  String get magicPrintAndDeliver => 'اطبعه وصلّه';

  @override
  String get magicSavedToLibrary => 'تم الحفظ في «إعلاناتي»';

  @override
  String get magicCopied => 'تم نسخ النص الإعلاني';

  @override
  String get magicRealScene => 'مشهد واقعي بالذكاء';

  @override
  String get magicAnotherScene => 'مشهد آخر';

  @override
  String get magicInviteTitle => 'صِف التصميم الذي تريده';

  @override
  String get magicInviteBody =>
      'اكتب في الصندوق أسفل الشاشة ما تريده بلغتك — يظهر التخطيط فورًا على جهازك، ثم يمكنك طلب مشهد بالذكاء أو تعديل ما ظهر.';

  @override
  String get magicInviteSamples =>
      'إعلان خصم ٣٠٪ لمقهى مختص، ألوان دافئة|إعلان افتتاح صالون، ستوري، فخم وهادئ|عرض توظيف: نبحث عن كاشير، مربّع';

  @override
  String get magicCopyText => 'نسخ النص';

  @override
  String get magicSave => 'حفظ';

  @override
  String magicMatchScore(int score) {
    return 'توافق $score%';
  }

  @override
  String get magicNextComposition => 'تكوين آخر';

  @override
  String get magicRegenerateConfirm =>
      'إعادة التوليد تمسح التصاميم التي صنعتها بطلبك. أتريد المتابعة؟';
}
