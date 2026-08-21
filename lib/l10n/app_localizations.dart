import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// اسم التطبيق — لا يُترجَم
  ///
  /// In ar, this message translates to:
  /// **'zol'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// No description provided for @navMarket.
  ///
  /// In ar, this message translates to:
  /// **'السوق'**
  String get navMarket;

  /// No description provided for @navTemplates.
  ///
  /// In ar, this message translates to:
  /// **'القوالب'**
  String get navTemplates;

  /// No description provided for @navMyAds.
  ///
  /// In ar, this message translates to:
  /// **'إعلاناتي'**
  String get navMyAds;

  /// No description provided for @navOrders.
  ///
  /// In ar, this message translates to:
  /// **'طلباتي'**
  String get navOrders;

  /// No description provided for @navSettings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get navSettings;

  /// No description provided for @homeTagline.
  ///
  /// In ar, this message translates to:
  /// **'سوق الدعاية والإعلان الشامل'**
  String get homeTagline;

  /// No description provided for @homeSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'من الفكرة إلى الإعلان المطبوع والمُوصَّل خلال دقائق'**
  String get homeSubtitle;

  /// No description provided for @homeCta.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ إعلانك الآن'**
  String get homeCta;

  /// No description provided for @homeCtaHint.
  ///
  /// In ar, this message translates to:
  /// **'معاينة فورية في أقل من 90 ثانية'**
  String get homeCtaHint;

  /// No description provided for @homeStatAds.
  ///
  /// In ar, this message translates to:
  /// **'إعلان محفوظ'**
  String get homeStatAds;

  /// No description provided for @homeStatOrders.
  ///
  /// In ar, this message translates to:
  /// **'طلب طباعة'**
  String get homeStatOrders;

  /// No description provided for @homeWelcome.
  ///
  /// In ar, this message translates to:
  /// **'مرحبًا، {name} 👋'**
  String homeWelcome(String name);

  /// No description provided for @templatesSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في القوالب — ستوري، بنر، كرت…'**
  String get templatesSearchHint;

  /// No description provided for @templatesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد قوالب مطابقة لبحثك'**
  String get templatesEmpty;

  /// No description provided for @templatesKicker.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ من قالب'**
  String get templatesKicker;

  /// No description provided for @templatesTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر الشكل الذي تريده'**
  String get templatesTitle;

  /// No description provided for @templatesSampleProduct.
  ///
  /// In ar, this message translates to:
  /// **'اسم منتجك'**
  String get templatesSampleProduct;

  /// No description provided for @templatesSampleTone.
  ///
  /// In ar, this message translates to:
  /// **'حماسي'**
  String get templatesSampleTone;

  /// No description provided for @templatesPrintable.
  ///
  /// In ar, this message translates to:
  /// **'قابل للطباعة'**
  String get templatesPrintable;

  /// No description provided for @templatesTrending.
  ///
  /// In ar, this message translates to:
  /// **'🔥 رائج'**
  String get templatesTrending;

  /// No description provided for @myAdsTrash.
  ///
  /// In ar, this message translates to:
  /// **'سلة المهملات'**
  String get myAdsTrash;

  /// No description provided for @myAdsEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'مكتبتك فارغة'**
  String get myAdsEmptyTitle;

  /// No description provided for @myAdsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'احفظ النسخ التي تعجبك من «شاشة السحر» لتجدها هنا جاهزة لإعادة الاستخدام أو الطباعة.'**
  String get myAdsEmptyBody;

  /// No description provided for @myAdsKicker.
  ///
  /// In ar, this message translates to:
  /// **'المكتبة'**
  String get myAdsKicker;

  /// No description provided for @myAdsTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعلاناتك المحفوظة'**
  String get myAdsTitle;

  /// No description provided for @myAdsOpenHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لفتح التصميم وإعادة تصديره أو طباعته'**
  String get myAdsOpenHint;

  /// No description provided for @myAdsCopyText.
  ///
  /// In ar, this message translates to:
  /// **'نسخ النص'**
  String get myAdsCopyText;

  /// No description provided for @myAdsDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get myAdsDelete;

  /// No description provided for @myAdsCopied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ النص الإعلاني'**
  String get myAdsCopied;

  /// No description provided for @myAdsMovedToTrash.
  ///
  /// In ar, this message translates to:
  /// **'نُقل الإعلان إلى سلة المهملات'**
  String get myAdsMovedToTrash;

  /// No description provided for @actionUndo.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get actionUndo;

  /// No description provided for @ordersEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات بعد'**
  String get ordersEmptyTitle;

  /// No description provided for @ordersEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'عند اختيار «اطبعه وصلّه» بعد توليد إعلانك، سيظهر الطلب هنا مع خط زمني لتتبع حالته.'**
  String get ordersEmptyBody;

  /// No description provided for @ordersKicker.
  ///
  /// In ar, this message translates to:
  /// **'التتبع'**
  String get ordersKicker;

  /// No description provided for @ordersTitle.
  ///
  /// In ar, this message translates to:
  /// **'حالة طلبات الطباعة'**
  String get ordersTitle;

  /// No description provided for @ordersDeliverTo.
  ///
  /// In ar, this message translates to:
  /// **'التوصيل إلى: {address}'**
  String ordersDeliverTo(String address);

  /// No description provided for @ordersShop.
  ///
  /// In ar, this message translates to:
  /// **'المطبعة: {shop}'**
  String ordersShop(String shop);

  /// No description provided for @ordersPaidByCard.
  ///
  /// In ar, this message translates to:
  /// **'مدفوع بالبطاقة ✓'**
  String get ordersPaidByCard;

  /// No description provided for @ordersCashOnDelivery.
  ///
  /// In ar, this message translates to:
  /// **'الدفع عند الاستلام'**
  String get ordersCashOnDelivery;

  /// No description provided for @ordersShowOnMap.
  ///
  /// In ar, this message translates to:
  /// **'عرض على الخريطة'**
  String get ordersShowOnMap;

  /// No description provided for @ordersSimulate.
  ///
  /// In ar, this message translates to:
  /// **'محاكاة التقدم (تجريبي)'**
  String get ordersSimulate;

  /// No description provided for @trashTitle.
  ///
  /// In ar, this message translates to:
  /// **'سلة المهملات'**
  String get trashTitle;

  /// No description provided for @trashEmptyAction.
  ///
  /// In ar, this message translates to:
  /// **'إفراغ السلة'**
  String get trashEmptyAction;

  /// No description provided for @trashEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'سلة المهملات فارغة'**
  String get trashEmptyTitle;

  /// No description provided for @trashEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'الإعلانات التي تحذفها من «إعلاناتي» تبقى هنا لمدة {days} يومًا قبل حذفها نهائيًا،\nوتقدر تسترجعها في أي وقت قبل ذلك.'**
  String trashEmptyBody(int days);

  /// No description provided for @trashKicker.
  ///
  /// In ar, this message translates to:
  /// **'استعادة أو حذف نهائي'**
  String get trashKicker;

  /// No description provided for @trashCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{إعلان واحد في السلة} =2{إعلانان في السلة} few{{count} إعلانات في السلة} other{{count} إعلانًا في السلة}}'**
  String trashCount(int count);

  /// No description provided for @trashConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'إفراغ السلة نهائيًا؟'**
  String get trashConfirmTitle;

  /// No description provided for @trashConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{سيُحذف إعلان واحد نهائيًا ولا يمكن التراجع.} =2{سيُحذف إعلانان نهائيًا ولا يمكن التراجع.} few{سيُحذف {count} إعلانات نهائيًا ولا يمكن التراجع.} other{سيُحذف {count} إعلانًا نهائيًا ولا يمكن التراجع.}}'**
  String trashConfirmBody(int count);

  /// No description provided for @actionCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get actionCancel;

  /// No description provided for @trashConfirmAction.
  ///
  /// In ar, this message translates to:
  /// **'إفراغ نهائيًا'**
  String get trashConfirmAction;

  /// No description provided for @trashExpiringSoon.
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف نهائيًا قريبًا'**
  String get trashExpiringSoon;

  /// No description provided for @trashExpiresIn.
  ///
  /// In ar, this message translates to:
  /// **'يُحذف نهائيًا خلال {days} يومًا'**
  String trashExpiresIn(int days);

  /// No description provided for @trashRestore.
  ///
  /// In ar, this message translates to:
  /// **'استعادة'**
  String get trashRestore;

  /// No description provided for @trashDeleteForever.
  ///
  /// In ar, this message translates to:
  /// **'حذف نهائي'**
  String get trashDeleteForever;

  /// No description provided for @marketTitle.
  ///
  /// In ar, this message translates to:
  /// **'السوق'**
  String get marketTitle;

  /// No description provided for @marketSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن مصوّر، مطبعة، مصمّم…'**
  String get marketSearchHint;

  /// No description provided for @marketClearSearch.
  ///
  /// In ar, this message translates to:
  /// **'مسح البحث'**
  String get marketClearSearch;

  /// No description provided for @marketAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get marketAll;

  /// No description provided for @marketAllCities.
  ///
  /// In ar, this message translates to:
  /// **'كل المدن'**
  String get marketAllCities;

  /// No description provided for @marketEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا مزوّد يطابق بحثك'**
  String get marketEmptyTitle;

  /// No description provided for @marketEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'جرّب مدينة أخرى أو أزل المرشّحات'**
  String get marketEmptyBody;

  /// No description provided for @marketClearFilters.
  ///
  /// In ar, this message translates to:
  /// **'إزالة المرشّحات'**
  String get marketClearFilters;

  /// No description provided for @marketVerified.
  ///
  /// In ar, this message translates to:
  /// **'موثّق'**
  String get marketVerified;

  /// No description provided for @marketPriceFrom.
  ///
  /// In ar, this message translates to:
  /// **'من {price} ر.س'**
  String marketPriceFrom(int price);

  /// No description provided for @marketOnRequest.
  ///
  /// In ar, this message translates to:
  /// **'حسب الطلب'**
  String get marketOnRequest;

  /// No description provided for @marketRespondsIn.
  ///
  /// In ar, this message translates to:
  /// **'يردّ خلال {hours} ساعات'**
  String marketRespondsIn(int hours);

  /// No description provided for @marketRatingSemantics.
  ///
  /// In ar, this message translates to:
  /// **'التقييم {rating} من ٥، {reviews} مراجعة'**
  String marketRatingSemantics(String rating, int reviews);

  /// No description provided for @marketReviewsCount.
  ///
  /// In ar, this message translates to:
  /// **'({reviews} مراجعة)'**
  String marketReviewsCount(int reviews);

  /// No description provided for @storefrontMine.
  ///
  /// In ar, this message translates to:
  /// **'متجري'**
  String get storefrontMine;

  /// No description provided for @storefrontNamed.
  ///
  /// In ar, this message translates to:
  /// **'متجر {store}'**
  String storefrontNamed(String store);

  /// No description provided for @storefrontEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'اعرض هويتك وأعمالك — ابدأ بحفظ إعلان'**
  String get storefrontEmptyHint;

  /// No description provided for @storefrontAdsCount.
  ///
  /// In ar, this message translates to:
  /// **'واجهة عرضك: {count, plural, =1{إعلان واحد} =2{إعلانان} few{{count} إعلانات} other{{count} إعلانًا}}'**
  String storefrontAdsCount(int count);

  /// No description provided for @storefrontShare.
  ///
  /// In ar, this message translates to:
  /// **'شارك واجهتك'**
  String get storefrontShare;

  /// No description provided for @storefrontEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'واجهتك جاهزة وتنتظر أول عمل'**
  String get storefrontEmptyTitle;

  /// No description provided for @storefrontEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'كل إعلان تحفظه من شاشة السحر يظهر هنا معروضًا.'**
  String get storefrontEmptyBody;

  /// No description provided for @storefrontShowcase.
  ///
  /// In ar, this message translates to:
  /// **'المعروض ({count})'**
  String storefrontShowcase(int count);

  /// No description provided for @storefrontShareEmpty.
  ///
  /// In ar, this message translates to:
  /// **'احفظ إعلانًا أولًا لتصير واجهتك قابلة للمشاركة'**
  String get storefrontShareEmpty;

  /// No description provided for @storefrontSharePending.
  ///
  /// In ar, this message translates to:
  /// **'الرابط العام لواجهة {store} قيد التجهيز'**
  String storefrontSharePending(String store);

  /// No description provided for @storefrontHarmony.
  ///
  /// In ar, this message translates to:
  /// **'الانسجام: {scheme}'**
  String storefrontHarmony(String scheme);

  /// No description provided for @storefrontBrandColor.
  ///
  /// In ar, this message translates to:
  /// **'لون العلامة'**
  String get storefrontBrandColor;

  /// No description provided for @storefrontSupportColor.
  ///
  /// In ar, this message translates to:
  /// **'لون مساند'**
  String get storefrontSupportColor;

  /// No description provided for @providerPrice.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get providerPrice;

  /// No description provided for @providerResponseTime.
  ///
  /// In ar, this message translates to:
  /// **'زمن الردّ'**
  String get providerResponseTime;

  /// No description provided for @providerResponseHours.
  ///
  /// In ar, this message translates to:
  /// **'~{hours} ساعات'**
  String providerResponseHours(int hours);

  /// No description provided for @providerStatus.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get providerStatus;

  /// No description provided for @providerWorks.
  ///
  /// In ar, this message translates to:
  /// **'أعمال سابقة'**
  String get providerWorks;

  /// No description provided for @providerRequestQuote.
  ///
  /// In ar, this message translates to:
  /// **'اطلب عرض سعر'**
  String get providerRequestQuote;

  /// No description provided for @providerDisclaimer.
  ///
  /// In ar, this message translates to:
  /// **'طلبك يصل المزوّد المسجَّل مباشرة. ومزوّدو شبكة المطابع تصلهم رسالتك من زرّ «أرسله بنفسك».'**
  String get providerDisclaimer;

  /// No description provided for @providerReviewsCount.
  ///
  /// In ar, this message translates to:
  /// **'({reviews} مراجعة)'**
  String providerReviewsCount(int reviews);

  /// No description provided for @printPricesNote.
  ///
  /// In ar, this message translates to:
  /// **'الأسعار لكل وحدة قبل التوصيل ({delivery}) وضريبة القيمة المضافة {vat}٪.'**
  String printPricesNote(String delivery, int vat);

  /// No description provided for @printOrder.
  ///
  /// In ar, this message translates to:
  /// **'اطلب'**
  String get printOrder;

  /// No description provided for @printNeedsDesign.
  ///
  /// In ar, this message translates to:
  /// **'صمّم إعلانًا واحفظه أولًا — الطباعة تحتاج تصميمًا'**
  String get printNeedsDesign;

  /// No description provided for @printWhichDesign.
  ///
  /// In ar, this message translates to:
  /// **'أيّ تصميم تطبع؟'**
  String get printWhichDesign;

  /// No description provided for @marketNewProvider.
  ///
  /// In ar, this message translates to:
  /// **'جديد — بلا تقييمات بعد'**
  String get marketNewProvider;

  /// No description provided for @providerSignupTitle.
  ///
  /// In ar, this message translates to:
  /// **'سجّل خدمتك في السوق'**
  String get providerSignupTitle;

  /// No description provided for @providerSignupIntro.
  ///
  /// In ar, this message translates to:
  /// **'اعرض خدمتك على تجّار zol. التسجيل مجاني، والمراجعة بشرية وتستغرق يومًا أو يومين — لا يظهر إدراجك في السوق قبلها.'**
  String get providerSignupIntro;

  /// No description provided for @providerSignupKind.
  ///
  /// In ar, this message translates to:
  /// **'نوع الخدمة'**
  String get providerSignupKind;

  /// No description provided for @providerSignupName.
  ///
  /// In ar, this message translates to:
  /// **'اسم النشاط'**
  String get providerSignupName;

  /// No description provided for @providerSignupNameError.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسمًا من حرفين على الأقل'**
  String get providerSignupNameError;

  /// No description provided for @providerSignupCity.
  ///
  /// In ar, this message translates to:
  /// **'المدينة'**
  String get providerSignupCity;

  /// No description provided for @providerSignupCityError.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم المدينة'**
  String get providerSignupCityError;

  /// No description provided for @providerSignupTagline.
  ///
  /// In ar, this message translates to:
  /// **'ماذا تقدّم؟'**
  String get providerSignupTagline;

  /// No description provided for @providerSignupTaglineHelp.
  ///
  /// In ar, this message translates to:
  /// **'سطر واحد يقول ما تجيده — لا شعارًا تسويقيًّا'**
  String get providerSignupTaglineHelp;

  /// No description provided for @providerSignupTaglineError.
  ///
  /// In ar, this message translates to:
  /// **'اكتب عشرة أحرف على الأقل ليفهم التاجر خدمتك'**
  String get providerSignupTaglineError;

  /// No description provided for @providerSignupPrice.
  ///
  /// In ar, this message translates to:
  /// **'أقلّ سعر بالريال (اختياري)'**
  String get providerSignupPrice;

  /// No description provided for @providerSignupPriceHelp.
  ///
  /// In ar, this message translates to:
  /// **'اتركه فارغًا إن كانت خدمتك «حسب الطلب»'**
  String get providerSignupPriceHelp;

  /// No description provided for @providerSignupPriceError.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رقمًا صحيحًا'**
  String get providerSignupPriceError;

  /// No description provided for @providerSignupHours.
  ///
  /// In ar, this message translates to:
  /// **'زمن الردّ بالساعات (اختياري)'**
  String get providerSignupHours;

  /// No description provided for @providerSignupHoursHelp.
  ///
  /// In ar, this message translates to:
  /// **'متوسط ما تستغرقه للردّ على طلب'**
  String get providerSignupHoursHelp;

  /// No description provided for @providerSignupHoursError.
  ///
  /// In ar, this message translates to:
  /// **'اكتب عدد ساعات بين ١ و٧٢٠'**
  String get providerSignupHoursError;

  /// No description provided for @providerSignupWorks.
  ///
  /// In ar, this message translates to:
  /// **'أعمال سابقة (اختياري)'**
  String get providerSignupWorks;

  /// No description provided for @providerSignupWorksHelp.
  ///
  /// In ar, this message translates to:
  /// **'عنوان كل عمل في سطر — حتى اثني عشر عملًا'**
  String get providerSignupWorksHelp;

  /// No description provided for @providerSignupSubmit.
  ///
  /// In ar, this message translates to:
  /// **'أرسل للمراجعة'**
  String get providerSignupSubmit;

  /// No description provided for @providerSignupReviewNote.
  ///
  /// In ar, this message translates to:
  /// **'التوثيق (الشارة الذهبية) يُمنح بعد مراجعة سجلك التجاري، ولا يُطلب من هنا.'**
  String get providerSignupReviewNote;

  /// No description provided for @providerSignupSent.
  ///
  /// In ar, this message translates to:
  /// **'وصل طلبك — سنراجعه ونبلغك'**
  String get providerSignupSent;

  /// No description provided for @providerSignupDuplicate.
  ///
  /// In ar, this message translates to:
  /// **'لديك إدراج بهذا النوع من الخدمة بالفعل'**
  String get providerSignupDuplicate;

  /// No description provided for @providerSignupFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الإرسال — تحقّق من اتصالك وحاول مجددًا'**
  String get providerSignupFailed;

  /// No description provided for @providerSignupNeedsAccount.
  ///
  /// In ar, this message translates to:
  /// **'سجّل حسابك أولًا لتسجيل خدمتك في السوق'**
  String get providerSignupNeedsAccount;

  /// No description provided for @providerSignupOneListing.
  ///
  /// In ar, this message translates to:
  /// **'إدراج واحد لكل نوع خدمة. لتعديل بياناتك أو إضافة نوع آخر، راسلنا من الإعدادات.'**
  String get providerSignupOneListing;

  /// No description provided for @marketJoin.
  ///
  /// In ar, this message translates to:
  /// **'سجّل خدمتك'**
  String get marketJoin;

  /// No description provided for @wishHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب ما تريد… مثال: استاند رول بخصم ٣٠٪ وفخم'**
  String get wishHint;

  /// No description provided for @wishRun.
  ///
  /// In ar, this message translates to:
  /// **'نفّذ'**
  String get wishRun;

  /// No description provided for @wishFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تنفيذ الطلب. حاول مجددًا.'**
  String get wishFailed;

  /// No description provided for @roleHeadline.
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get roleHeadline;

  /// No description provided for @roleSubhead.
  ///
  /// In ar, this message translates to:
  /// **'السطر الثانوي'**
  String get roleSubhead;

  /// No description provided for @roleProduct.
  ///
  /// In ar, this message translates to:
  /// **'المنتج'**
  String get roleProduct;

  /// No description provided for @roleCta.
  ///
  /// In ar, this message translates to:
  /// **'زرّ الحثّ'**
  String get roleCta;

  /// No description provided for @roleBadge.
  ///
  /// In ar, this message translates to:
  /// **'الشارة'**
  String get roleBadge;

  /// No description provided for @roleLogo.
  ///
  /// In ar, this message translates to:
  /// **'الشعار'**
  String get roleLogo;

  /// No description provided for @roleTags.
  ///
  /// In ar, this message translates to:
  /// **'الهاشتاقات'**
  String get roleTags;

  /// No description provided for @roleShape.
  ///
  /// In ar, this message translates to:
  /// **'شكل'**
  String get roleShape;

  /// No description provided for @roleOrnament.
  ///
  /// In ar, this message translates to:
  /// **'الزخرفة'**
  String get roleOrnament;

  /// No description provided for @guideTitle.
  ///
  /// In ar, this message translates to:
  /// **'دليل الاستخدام'**
  String get guideTitle;

  /// No description provided for @shopPanelTitle.
  ///
  /// In ar, this message translates to:
  /// **'لوحة المطبعة'**
  String get shopPanelTitle;

  /// No description provided for @orderNoShopYet.
  ///
  /// In ar, this message translates to:
  /// **'لا مطبعة معتمدة تخدم موقعك بعد. صمّم واحفظ الآن، ويمكنك طلب عرض سعر من تبويب السوق.'**
  String get orderNoShopYet;

  /// No description provided for @orderShopLacksProduct.
  ///
  /// In ar, this message translates to:
  /// **'مطبعة {shop} لا تقدّم {product} حاليًا. جرّب منتجًا آخر أو اطلب عرض سعر من السوق.'**
  String orderShopLacksProduct(Object shop, Object product);

  /// No description provided for @orderQuoteFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تسعير الطلب الآن. تحقّق من اتصالك وحاول ثانية.'**
  String get orderQuoteFailed;

  /// No description provided for @orderArtworkCaptureFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تجهيز ملفّ التصميم على هذا الجهاز.'**
  String get orderArtworkCaptureFailed;

  /// No description provided for @orderArtworkUploadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر رفع ملفّ التصميم. سجّل الدخول ثم أعد المحاولة.'**
  String get orderArtworkUploadFailed;

  /// No description provided for @orderPaymentIncomplete.
  ///
  /// In ar, this message translates to:
  /// **'لم يكتمل الدفع. طلبك محفوظ غير مدفوع ويمكنك إكماله.'**
  String get orderPaymentIncomplete;

  /// No description provided for @orderNeedsAccount.
  ///
  /// In ar, this message translates to:
  /// **'يلزم تسجيل الدخول قبل طلب الطباعة — الطلب يُنسب إلى صاحبه.'**
  String get orderNeedsAccount;

  /// No description provided for @orderOffline.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الوصول إلى الخادم. لم يُنشأ طلب ولم يُقبض شيء.'**
  String get orderOffline;

  /// No description provided for @orderShopUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'المطبعة غير متاحة الآن.'**
  String get orderShopUnavailable;

  /// No description provided for @orderProductUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'هذا المنتج غير متاح لدى المطبعة.'**
  String get orderProductUnavailable;

  /// No description provided for @orderBelowMinQty.
  ///
  /// In ar, this message translates to:
  /// **'الكمية أقل من الحدّ الأدنى لدى المطبعة.'**
  String get orderBelowMinQty;

  /// No description provided for @orderCreateFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إنشاء الطلب. لم يُقبض شيء.'**
  String get orderCreateFailed;

  /// No description provided for @orderPriceChangedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر السعر'**
  String get orderPriceChangedTitle;

  /// No description provided for @orderPriceChangedBody.
  ///
  /// In ar, this message translates to:
  /// **'سعر المطبعة {actual} بدل {shown} المعروض. المبلغ المعروض تقديريّ، والمعتمد ما تسعّره المطبعة.'**
  String orderPriceChangedBody(Object actual, Object shown);

  /// No description provided for @commonCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get commonCancel;

  /// No description provided for @commonContinue.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get commonContinue;

  /// No description provided for @priceVatIncluded.
  ///
  /// In ar, this message translates to:
  /// **'شامل ضريبة القيمة المضافة {amount}'**
  String priceVatIncluded(Object amount);

  /// No description provided for @pricePlatformFee.
  ///
  /// In ar, this message translates to:
  /// **'رسم المنصّة'**
  String get pricePlatformFee;

  /// No description provided for @shopPanelHeading.
  ///
  /// In ar, this message translates to:
  /// **'لوحة المطبعة قيد البناء'**
  String get shopPanelHeading;

  /// No description provided for @shopPanelBody.
  ///
  /// In ar, this message translates to:
  /// **'طوابير الطباعة وحالاتها تحتاج صلاحية مطبعة في الخادم، وهي المرحلة التالية. ولم يصل طلب طباعة إلى أي مطبعة بعد، فلا شيء يُعرض هنا اليوم إلا هذا السطر الصادق.'**
  String get shopPanelBody;

  /// No description provided for @shopPanelOpenMerchant.
  ///
  /// In ar, this message translates to:
  /// **'افتح واجهة التاجر'**
  String get shopPanelOpenMerchant;

  /// No description provided for @shopPanelEntrySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'طوابير الطباعة وحالاتها'**
  String get shopPanelEntrySubtitle;

  /// No description provided for @guideUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الدليل على هذا الجهاز.'**
  String get guideUnavailable;

  /// No description provided for @editorTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحرير التصميم'**
  String get editorTitle;

  /// No description provided for @editorResizeHandle.
  ///
  /// In ar, this message translates to:
  /// **'مقبض التحجيم'**
  String get editorResizeHandle;

  /// No description provided for @editorSpecHint.
  ///
  /// In ar, this message translates to:
  /// **'المس عنصرًا لتحدّده، ثم اسحبه لتحريكه أو اسحب المقبض لتحجيمه'**
  String get editorSpecHint;

  /// No description provided for @editorProductHint.
  ///
  /// In ar, this message translates to:
  /// **'اسحب لتحريك المنتج، وباعد إصبعيك لتكبيره'**
  String get editorProductHint;

  /// No description provided for @editorNoProductHint.
  ///
  /// In ar, this message translates to:
  /// **'أضف صورة منتج لتتمكن من تحريكها'**
  String get editorNoProductHint;

  /// No description provided for @editorResetProduct.
  ///
  /// In ar, this message translates to:
  /// **'إرجاع المنتج لوضعه'**
  String get editorResetProduct;

  /// No description provided for @editorResetLayout.
  ///
  /// In ar, this message translates to:
  /// **'إرجاع التخطيط كما وُلِّد'**
  String get editorResetLayout;

  /// No description provided for @editorEditText.
  ///
  /// In ar, this message translates to:
  /// **'تحرير النص'**
  String get editorEditText;

  /// No description provided for @editorEditElement.
  ///
  /// In ar, this message translates to:
  /// **'تحرير العنصر المحدّد'**
  String get editorEditElement;

  /// No description provided for @editorElementText.
  ///
  /// In ar, this message translates to:
  /// **'نصّ العنصر'**
  String get editorElementText;

  /// No description provided for @editorFieldHeadline.
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get editorFieldHeadline;

  /// No description provided for @editorFieldBody.
  ///
  /// In ar, this message translates to:
  /// **'النص الفرعي'**
  String get editorFieldBody;

  /// No description provided for @editorFieldCta.
  ///
  /// In ar, this message translates to:
  /// **'زر الدعوة'**
  String get editorFieldCta;

  /// No description provided for @editorApply.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق'**
  String get editorApply;

  /// No description provided for @editorSaveChanges.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التعديلات'**
  String get editorSaveChanges;

  /// No description provided for @editorDone.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get editorDone;

  /// No description provided for @executeEditTemplate.
  ///
  /// In ar, this message translates to:
  /// **'تحرير التصميم (نص وموضع المنتج)'**
  String get executeEditTemplate;

  /// No description provided for @executeEditSpec.
  ///
  /// In ar, this message translates to:
  /// **'تحرير التصميم (حرّك العناصر وغيّر نصّها)'**
  String get executeEditSpec;

  /// No description provided for @executeGeneratedNote.
  ///
  /// In ar, this message translates to:
  /// **'هذا تخطيط ركّبه الذكاء لطلبك، فلا ينطبق عليه اختيار القوالب. حرّكه كما تشاء أو اطلب تخطيطًا آخر من شاشة السحر.'**
  String get executeGeneratedNote;

  /// No description provided for @wishRefineChip.
  ///
  /// In ar, this message translates to:
  /// **'عدّل هذا التصميم'**
  String get wishRefineChip;

  /// No description provided for @wishRefineHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب ما تريد تغييره… مثال: كبّر العنوان واجعل الخلفية فاتحة'**
  String get wishRefineHint;

  /// No description provided for @wishRead.
  ///
  /// In ar, this message translates to:
  /// **'فهمتُ'**
  String get wishRead;

  /// No description provided for @wishReadDiscount.
  ///
  /// In ar, this message translates to:
  /// **'خصم {pct}٪'**
  String wishReadDiscount(int pct);

  /// No description provided for @wishOfferDiscount.
  ///
  /// In ar, this message translates to:
  /// **'خصم'**
  String get wishOfferDiscount;

  /// No description provided for @wishOfferOpening.
  ///
  /// In ar, this message translates to:
  /// **'افتتاح'**
  String get wishOfferOpening;

  /// No description provided for @wishOfferNewItem.
  ///
  /// In ar, this message translates to:
  /// **'صنف جديد'**
  String get wishOfferNewItem;

  /// No description provided for @wishOfferHiring.
  ///
  /// In ar, this message translates to:
  /// **'توظيف'**
  String get wishOfferHiring;

  /// No description provided for @wishOfferDelivery.
  ///
  /// In ar, this message translates to:
  /// **'توصيل'**
  String get wishOfferDelivery;

  /// No description provided for @wishOfferSeason.
  ///
  /// In ar, this message translates to:
  /// **'موسم'**
  String get wishOfferSeason;

  /// No description provided for @wishOfferGeneral.
  ///
  /// In ar, this message translates to:
  /// **'إعلان عام'**
  String get wishOfferGeneral;

  /// No description provided for @wishPresetDiscount.
  ///
  /// In ar, this message translates to:
  /// **'إعلان خصم ٥٠٪ لنهاية الأسبوع'**
  String get wishPresetDiscount;

  /// No description provided for @wishPresetOpening.
  ///
  /// In ar, this message translates to:
  /// **'افتتاح فرع جديد'**
  String get wishPresetOpening;

  /// No description provided for @wishPresetNewItem.
  ///
  /// In ar, this message translates to:
  /// **'وصل منتج جديد'**
  String get wishPresetNewItem;

  /// No description provided for @wishPresetHiring.
  ///
  /// In ar, this message translates to:
  /// **'نطلب موظفين'**
  String get wishPresetHiring;

  /// No description provided for @wishPresetDelivery.
  ///
  /// In ar, this message translates to:
  /// **'توصيل مجاني اليوم'**
  String get wishPresetDelivery;

  /// No description provided for @wishPresetRamadan.
  ///
  /// In ar, this message translates to:
  /// **'عرض رمضان'**
  String get wishPresetRamadan;

  /// No description provided for @quoteSheetTitle.
  ///
  /// In ar, this message translates to:
  /// **'اطلب تسعيرة'**
  String get quoteSheetTitle;

  /// No description provided for @quoteNeedLabel.
  ///
  /// In ar, this message translates to:
  /// **'ما الذي تحتاجه؟'**
  String get quoteNeedLabel;

  /// No description provided for @quoteNeedHelp.
  ///
  /// In ar, this message translates to:
  /// **'اكتب المطلوب بوضوح: الكمّية والمقاس والموعد إن وُجد'**
  String get quoteNeedHelp;

  /// No description provided for @quoteNeedError.
  ///
  /// In ar, this message translates to:
  /// **'اكتب عشرة أحرف على الأقل ليفهم المزوّد طلبك'**
  String get quoteNeedError;

  /// No description provided for @quoteBudgetLabel.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية التقريبية بالريال (اختياري)'**
  String get quoteBudgetLabel;

  /// No description provided for @quoteContactLabel.
  ///
  /// In ar, this message translates to:
  /// **'كيف يردّ عليك؟'**
  String get quoteContactLabel;

  /// No description provided for @quoteContactHelp.
  ///
  /// In ar, this message translates to:
  /// **'رقم واتساب أو بريد — بلا وسيلة ردّ لا تصلك تسعيرة'**
  String get quoteContactHelp;

  /// No description provided for @quoteContactError.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رقمًا أو بريدًا صحيحًا'**
  String get quoteContactError;

  /// No description provided for @quoteSend.
  ///
  /// In ar, this message translates to:
  /// **'أرسل الطلب'**
  String get quoteSend;

  /// No description provided for @quoteShare.
  ///
  /// In ar, this message translates to:
  /// **'أرسله بنفسك'**
  String get quoteShare;

  /// No description provided for @quoteDelivered.
  ///
  /// In ar, this message translates to:
  /// **'وصل طلبك إلى المزوّد'**
  String get quoteDelivered;

  /// No description provided for @quoteOffline.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الإرسال عبر التطبيق — أرسِله بنفسك من الزرّ أدناه'**
  String get quoteOffline;

  /// No description provided for @quoteNeedsAccount.
  ///
  /// In ar, this message translates to:
  /// **'سجّل حسابك أوّلًا ليُنسب الطلب إليك ويصلك الردّ'**
  String get quoteNeedsAccount;

  /// No description provided for @quoteNotRoutable.
  ///
  /// In ar, this message translates to:
  /// **'هذا المزوّد من شبكة المطابع ولا يستقبل عبر التطبيق — انسخ الطلب وأرسله إليه'**
  String get quoteNotRoutable;

  /// No description provided for @quoteCopied.
  ///
  /// In ar, this message translates to:
  /// **'نُسخ نصّ الطلب'**
  String get quoteCopied;

  /// No description provided for @settingsLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In ar, this message translates to:
  /// **'لغة الجهاز'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageArabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get settingsLanguageArabic;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageNote.
  ///
  /// In ar, this message translates to:
  /// **'تغيير اللغة يغيّر واجهة التطبيق فقط. نصّ الإعلان يبقى بلغة جمهورك.'**
  String get settingsLanguageNote;

  /// No description provided for @onboardingSkip.
  ///
  /// In ar, this message translates to:
  /// **'تخطٍّ'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الآن'**
  String get onboardingStart;

  /// No description provided for @onboardingPickFirst.
  ///
  /// In ar, this message translates to:
  /// **'اختر نشاطك للمتابعة'**
  String get onboardingPickFirst;

  /// No description provided for @onboardingT1.
  ///
  /// In ar, this message translates to:
  /// **'إعلانك يولد في ثوانٍ'**
  String get onboardingT1;

  /// No description provided for @onboardingB1.
  ///
  /// In ar, this message translates to:
  /// **'ارفع صورة منتجك واختر النبرة والمنصة، ونحن نخرج لك نصًا وتصميمًا جاهزين للنشر.'**
  String get onboardingB1;

  /// No description provided for @onboardingT2.
  ///
  /// In ar, this message translates to:
  /// **'اطبعه عند أقرب مطبعة'**
  String get onboardingT2;

  /// No description provided for @onboardingB2.
  ///
  /// In ar, this message translates to:
  /// **'بنرات، استيكرات، كروت ورول أب بأسعار فورية — ويُسند طلبك تلقائيًا لأقرب مطبعة شريكة لموقعك.'**
  String get onboardingB2;

  /// No description provided for @onboardingT3.
  ///
  /// In ar, this message translates to:
  /// **'ويصلك حتى الباب'**
  String get onboardingT3;

  /// No description provided for @onboardingB3.
  ///
  /// In ar, this message translates to:
  /// **'حدّد موقعك على الخريطة وتابع طلبك خطوة بخطوة حتى يصل بين يديك.'**
  String get onboardingB3;

  /// No description provided for @onboardingCategoryTitle.
  ///
  /// In ar, this message translates to:
  /// **'ما نشاطك؟'**
  String get onboardingCategoryTitle;

  /// No description provided for @onboardingCategoryBody.
  ///
  /// In ar, this message translates to:
  /// **'نكتب لك نصوصًا بمفردات مجالك — لا جملًا عامة تصلح لأي شيء.'**
  String get onboardingCategoryBody;

  /// No description provided for @onboardingCategoryHint.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك تغييره لاحقًا من الإعدادات'**
  String get onboardingCategoryHint;

  /// No description provided for @authEmailError.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بريدًا إلكترونيًا صحيحًا'**
  String get authEmailError;

  /// No description provided for @authPasswordError.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور 6 أحرف على الأقل'**
  String get authPasswordError;

  /// No description provided for @authNameError.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسمك'**
  String get authNameError;

  /// No description provided for @authStoreError.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم متجرك أو نشاطك'**
  String get authStoreError;

  /// No description provided for @authTitleLogin.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get authTitleLogin;

  /// No description provided for @authTitleSignup.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب تاجر'**
  String get authTitleSignup;

  /// No description provided for @authIntroLogin.
  ///
  /// In ar, this message translates to:
  /// **'سجّل دخولك لمتابعة إعلاناتك وطلباتك'**
  String get authIntroLogin;

  /// No description provided for @authIntroSignup.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ حساب تاجر لحفظ إعلاناتك وتتبع طلباتك'**
  String get authIntroSignup;

  /// No description provided for @authFieldName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم *'**
  String get authFieldName;

  /// No description provided for @authHintName.
  ///
  /// In ar, this message translates to:
  /// **'اسمك الكامل'**
  String get authHintName;

  /// No description provided for @authFieldStore.
  ///
  /// In ar, this message translates to:
  /// **'اسم المتجر *'**
  String get authFieldStore;

  /// No description provided for @authHintStore.
  ///
  /// In ar, this message translates to:
  /// **'مثال: محمصة الفجر'**
  String get authHintStore;

  /// No description provided for @authFieldEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني *'**
  String get authFieldEmail;

  /// No description provided for @authFieldPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور *'**
  String get authFieldPassword;

  /// No description provided for @authHintPassword.
  ///
  /// In ar, this message translates to:
  /// **'6 أحرف على الأقل'**
  String get authHintPassword;

  /// No description provided for @authSubmitLogin.
  ///
  /// In ar, this message translates to:
  /// **'دخول'**
  String get authSubmitLogin;

  /// No description provided for @authSubmitSignup.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الحساب'**
  String get authSubmitSignup;

  /// No description provided for @authSwitchToSignup.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟ أنشئ حسابًا جديدًا'**
  String get authSwitchToSignup;

  /// No description provided for @authSwitchToLogin.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب بالفعل؟ سجّل دخولك'**
  String get authSwitchToLogin;

  /// No description provided for @authWelcomeBack.
  ///
  /// In ar, this message translates to:
  /// **'مرحبًا بعودتك، {name}!'**
  String authWelcomeBack(String name);

  /// No description provided for @authAccountCreated.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء حسابك بنجاح، {name}!'**
  String authAccountCreated(String name);

  /// No description provided for @wishLocalOnly.
  ///
  /// In ar, this message translates to:
  /// **'صُمّم على جهازك — تعذّر الوصول إلى الذكاء السحابي'**
  String get wishLocalOnly;

  /// No description provided for @magicTitle.
  ///
  /// In ar, this message translates to:
  /// **'شاشة السحر'**
  String get magicTitle;

  /// No description provided for @magicRegenerate.
  ///
  /// In ar, this message translates to:
  /// **'إعادة توليد'**
  String get magicRegenerate;

  /// No description provided for @magicFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إكمال التوليد. حاول مجددًا.'**
  String get magicFailed;

  /// No description provided for @magicSceneFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر توليد المشهد. حاول مجددًا.'**
  String get magicSceneFailed;

  /// No description provided for @magicQuotaTitle.
  ///
  /// In ar, this message translates to:
  /// **'انتهت حصتك لهذا الشهر'**
  String get magicQuotaTitle;

  /// No description provided for @magicErrorTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التوليد'**
  String get magicErrorTitle;

  /// No description provided for @magicRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get magicRetry;

  /// No description provided for @magicBackAndEdit.
  ///
  /// In ar, this message translates to:
  /// **'العودة وتعديل الوصف'**
  String get magicBackAndEdit;

  /// No description provided for @magicWorking.
  ///
  /// In ar, this message translates to:
  /// **'الذكاء الاصطناعي يعمل على إعلانك…'**
  String get magicWorking;

  /// No description provided for @magicStepKicker.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة 2 من 3'**
  String get magicStepKicker;

  /// No description provided for @magicPickBest.
  ///
  /// In ar, this message translates to:
  /// **'اختر النسخة الأنسب'**
  String get magicPickBest;

  /// No description provided for @magicSaveAndPublish.
  ///
  /// In ar, this message translates to:
  /// **'حفظ ونشر'**
  String get magicSaveAndPublish;

  /// No description provided for @magicPrintAndDeliver.
  ///
  /// In ar, this message translates to:
  /// **'اطبعه وصلّه'**
  String get magicPrintAndDeliver;

  /// No description provided for @magicSavedToLibrary.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ في «إعلاناتي»'**
  String get magicSavedToLibrary;

  /// No description provided for @magicCopied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ النص الإعلاني'**
  String get magicCopied;

  /// No description provided for @magicRealScene.
  ///
  /// In ar, this message translates to:
  /// **'مشهد واقعي بالذكاء'**
  String get magicRealScene;

  /// No description provided for @magicAnotherScene.
  ///
  /// In ar, this message translates to:
  /// **'مشهد آخر'**
  String get magicAnotherScene;

  /// No description provided for @magicInviteTitle.
  ///
  /// In ar, this message translates to:
  /// **'صِف التصميم الذي تريده'**
  String get magicInviteTitle;

  /// No description provided for @magicInviteBody.
  ///
  /// In ar, this message translates to:
  /// **'اكتب في الصندوق أسفل الشاشة ما تريده بلغتك — يظهر التخطيط فورًا على جهازك، ثم يمكنك طلب مشهد بالذكاء أو تعديل ما ظهر.'**
  String get magicInviteBody;

  /// أمثلة مفصولة بـ`|` — تُنقر فتملأ صندوق الأمنية.
  ///
  /// In ar, this message translates to:
  /// **'إعلان خصم ٣٠٪ لمقهى مختص، ألوان دافئة|إعلان افتتاح صالون، ستوري، فخم وهادئ|عرض توظيف: نبحث عن كاشير، مربّع'**
  String get magicInviteSamples;

  /// No description provided for @magicCopyText.
  ///
  /// In ar, this message translates to:
  /// **'نسخ النص'**
  String get magicCopyText;

  /// No description provided for @magicSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get magicSave;

  /// No description provided for @magicMatchScore.
  ///
  /// In ar, this message translates to:
  /// **'توافق {score}%'**
  String magicMatchScore(int score);

  /// No description provided for @magicNextComposition.
  ///
  /// In ar, this message translates to:
  /// **'تكوين آخر'**
  String get magicNextComposition;

  /// No description provided for @magicRegenerateConfirm.
  ///
  /// In ar, this message translates to:
  /// **'إعادة التوليد تمسح التصاميم التي صنعتها بطلبك. أتريد المتابعة؟'**
  String get magicRegenerateConfirm;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return LAr();
    case 'en':
      return LEn();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
