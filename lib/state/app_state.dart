import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/generated_ad.dart';
import '../models/merchant_account.dart';
import '../models/print_order.dart';

/// حالة التطبيق: إعلانات محفوظة، طلبات طباعة، سمة العرض.
/// تُحفظ دائمًا على الجهاز عبر SharedPreferences فلا تضيع عند إغلاق
/// التطبيق. (تُستبدل لاحقًا بمزامنة سحابية مع حساب التاجر.)
class AppState extends ChangeNotifier {
  AppState([this._prefs]);

  final SharedPreferences? _prefs;

  static const _adsKey = 'saved_ads';
  static const _ordersKey = 'orders';
  static const _themeKey = 'theme_mode';
  static const _orderNumberKey = 'next_order_number';
  static const _accountsKey = 'merchant_accounts';
  static const _sessionKey = 'session_email';
  static const _proKey = 'pro_active';
  static const _brandColorKey = 'brand_color';
  static const _brandLogoKey = 'brand_logo';
  static const _onboardedKey = 'onboarded';

  final List<GeneratedAd> savedAds = [];
  final List<PrintOrder> orders = [];
  ThemeMode themeMode = ThemeMode.light;

  /// حساب التاجر المسجَّل دخوله حاليًا (null = زائر).
  MerchantAccount? account;
  bool get isLoggedIn => account != null;

  /// الخطة الاحترافية مفعّلة؟ (تزيل العلامة المائية من التصاميم.)
  bool isPro = false;

  /// هل شاهد المستخدم شاشة الترحيب؟ تُعرض مرة واحدة عند أول تشغيل.
  bool hasOnboarded = false;

  /// هوية العلامة (Brand Kit — نمط Canva): لون العلامة وشعار المتجر
  /// يُطبَّقان تلقائيًا على كل التصاميم المولَّدة.
  int? brandColorValue;
  Uint8List? brandLogoBytes;
  Color? get brandColor =>
      brandColorValue == null ? null : Color(brandColorValue!);

  /// سجل الحسابات المحلية: بريد → {name, storeName, salt, hash}.
  /// يُستبدل بمزوّد مصادقة سحابي (Firebase Auth كما في zadgo2) عند
  /// بناء الخادم — واجهة register/login/logout تبقى كما هي.
  Map<String, dynamic> _accounts = {};

  int _nextOrderNumber = 1001;

  /// تحميل الحالة المحفوظة من الجهاز.
  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(prefs);
    state._restore();
    return state;
  }

  void _restore() {
    final prefs = _prefs;
    if (prefs == null) return;

    try {
      final ads = jsonDecode(prefs.getString(_adsKey) ?? '[]') as List;
      savedAds.addAll(
        ads.map((e) => GeneratedAd.fromJson(e as Map<String, dynamic>)),
      );
      final storedOrders =
          jsonDecode(prefs.getString(_ordersKey) ?? '[]') as List;
      orders.addAll(
        storedOrders.map((e) => PrintOrder.fromJson(e as Map<String, dynamic>)),
      );
    } catch (_) {
      // بيانات تالفة من نسخة قديمة — نبدأ بقائمة فارغة بدل تعطيل التطبيق.
      savedAds.clear();
      orders.clear();
    }
    themeMode = ThemeMode.values[prefs.getInt(_themeKey) ?? 1];
    _nextOrderNumber = prefs.getInt(_orderNumberKey) ?? 1001;
    isPro = prefs.getBool(_proKey) ?? false;
    hasOnboarded = prefs.getBool(_onboardedKey) ?? false;
    brandColorValue = prefs.getInt(_brandColorKey);
    final logo = prefs.getString(_brandLogoKey);
    if (logo != null && logo.isNotEmpty) {
      try {
        brandLogoBytes = base64Decode(logo);
      } catch (_) {
        brandLogoBytes = null;
      }
    }

    try {
      _accounts =
          jsonDecode(prefs.getString(_accountsKey) ?? '{}')
              as Map<String, dynamic>;
    } catch (_) {
      _accounts = {};
    }
    final sessionEmail = prefs.getString(_sessionKey);
    final stored = sessionEmail == null ? null : _accounts[sessionEmail];
    if (stored != null) {
      account = MerchantAccount(
        name: stored['name'] as String? ?? '',
        storeName: stored['storeName'] as String? ?? '',
        email: sessionEmail!,
      );
    }
  }

  void _persist() {
    final prefs = _prefs;
    if (prefs == null) return;
    prefs.setString(
      _adsKey,
      jsonEncode(savedAds.map((a) => a.toJson()).toList()),
    );
    prefs.setString(
      _ordersKey,
      jsonEncode(orders.map((o) => o.toJson()).toList()),
    );
    prefs.setInt(_themeKey, themeMode.index);
    prefs.setInt(_orderNumberKey, _nextOrderNumber);
  }

  void saveAd(GeneratedAd ad) {
    savedAds.insert(0, ad);
    _persist();
    notifyListeners();
  }

  void removeAd(GeneratedAd ad) {
    savedAds.remove(ad);
    _persist();
    notifyListeners();
  }

  String nextOrderId() {
    final id = 'AD-${_nextOrderNumber++}';
    _persist();
    return id;
  }

  void addOrder(PrintOrder order) {
    orders.insert(0, order);
    _persist();
    notifyListeners();
  }

  void advanceOrder(PrintOrder order) {
    final index = orders.indexOf(order);
    if (index == -1 || order.status == OrderStatus.delivered) return;
    orders[index] = order.copyWith(
      status: OrderStatus.values[order.status.index + 1],
    );
    _persist();
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _persist();
    notifyListeners();
  }

  void completeOnboarding() {
    hasOnboarded = true;
    _prefs?.setBool(_onboardedKey, true);
    notifyListeners();
  }

  void setBrandColor(int? value) {
    brandColorValue = value;
    if (value == null) {
      _prefs?.remove(_brandColorKey);
    } else {
      _prefs?.setInt(_brandColorKey, value);
    }
    notifyListeners();
  }

  void setBrandLogo(Uint8List? bytes) {
    brandLogoBytes = bytes;
    if (bytes == null) {
      _prefs?.remove(_brandLogoKey);
    } else {
      _prefs?.setString(_brandLogoKey, base64Encode(bytes));
    }
    notifyListeners();
  }

  /// تفعيل الخطة الاحترافية بعد تأكيد الدفع من البوابة.
  void activatePro() {
    isPro = true;
    _prefs?.setBool(_proKey, true);
    notifyListeners();
  }

  // ── حساب التاجر ──

  static String _hashPassword(String password, String salt) =>
      sha256.convert(utf8.encode('$salt$password')).toString();

  /// إنشاء حساب تاجر جديد. يعيد رسالة خطأ بالعربية أو null عند النجاح.
  String? register({
    required String name,
    required String storeName,
    required String email,
    required String password,
  }) {
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      return 'هذا البريد مسجَّل مسبقًا — سجّل دخولك بدلًا من ذلك';
    }
    final salt = List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _accounts[key] = {
      'name': name.trim(),
      'storeName': storeName.trim(),
      'salt': salt,
      'hash': _hashPassword(password, salt),
    };
    account = MerchantAccount(
      name: name.trim(),
      storeName: storeName.trim(),
      email: key,
    );
    _prefs?.setString(_sessionKey, key);
    _persistAccounts();
    notifyListeners();
    return null;
  }

  /// تسجيل الدخول. يعيد رسالة خطأ بالعربية أو null عند النجاح.
  String? login({required String email, required String password}) {
    final key = email.trim().toLowerCase();
    final stored = _accounts[key];
    if (stored == null ||
        stored['hash'] != _hashPassword(password, stored['salt'] as String)) {
      return 'البريد أو كلمة المرور غير صحيحة';
    }
    account = MerchantAccount(
      name: stored['name'] as String? ?? '',
      storeName: stored['storeName'] as String? ?? '',
      email: key,
    );
    _prefs?.setString(_sessionKey, key);
    notifyListeners();
    return null;
  }

  void logout() {
    account = null;
    _prefs?.remove(_sessionKey);
    notifyListeners();
  }

  void _persistAccounts() {
    _prefs?.setString(_accountsKey, jsonEncode(_accounts));
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState super.notifier,
    required super.child,
  });

  static AppState of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppStateScope>()!
      .notifier!;
}
