import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';

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
  static const List<Locale> supportedLocales = <Locale>[Locale('ar')];

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
  /// **'الدليل في مرحلته الأولى: طلبك يُحفظ ويصلك تأكيد حين يُفعَّل حساب المزوّد.'**
  String get providerDisclaimer;

  /// No description provided for @providerInterestLogged.
  ///
  /// In ar, this message translates to:
  /// **'سجّلنا اهتمامك بـ{name}'**
  String providerInterestLogged(String name);

  /// No description provided for @providerReviewsCount.
  ///
  /// In ar, this message translates to:
  /// **'({reviews} مراجعة)'**
  String providerReviewsCount(int reviews);
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return LAr();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
