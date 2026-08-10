import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../models/generated_ad.dart';
import '../models/business_category.dart';
import '../models/brand_font.dart';
import '../models/merchant_account.dart';
import '../models/print_order.dart';
import '../models/trashed_ad.dart';
import '../services/image_store.dart';

/// حالة التطبيق: إعلانات محفوظة، طلبات طباعة، سمة العرض، وحساب التاجر.
/// تُحفظ دائمًا على الجهاز عبر SharedPreferences فلا تضيع عند إغلاق
/// التطبيق. حساب التاجر يُصادَق عبر Supabase عند توفر عميل سحابي.
class AppState extends ChangeNotifier {
  AppState({SharedPreferences? prefs, supa.SupabaseClient? client})
    : _prefs = prefs,
      _client = client;

  final SharedPreferences? _prefs;

  /// عميل Supabase الحقيقي عند توفره (يُمرَّر من main.dart بعد التهيئة).
  /// عند تركه null (كما في كل اختبارات الودجت الحالية) تبقى المصادقة
  /// محلية بالكامل تمامًا كسابقًا — بلا أي اتصال شبكة.
  final supa.SupabaseClient? _client;

  static const _adsKey = 'saved_ads';
  static const _ordersKey = 'orders';
  static const _themeKey = 'theme_mode';
  static const _orderNumberKey = 'next_order_number';
  static const _accountsKey = 'merchant_accounts';
  static const _sessionKey = 'session_email';
  static const _proKey = 'pro_active';
  static const _brandColorKey = 'brand_color';
  static const _brandLogoKey = 'brand_logo';
  static const _brandFontKey = 'brand_font';
  static const _onboardedKey = 'onboarded';
  static const _categoryKey = 'business_category';
  static const _trashKey = 'trashed_ads';

  final List<GeneratedAd> savedAds = [];
  final List<PrintOrder> orders = [];

  /// إعلانات محذوفة من المكتبة بانتظار الاستعادة أو الحذف النهائي —
  /// سلة مهملات تمنع فقدان عمل التاجر بضغطة خاطئة.
  final List<TrashedAd> trashedAds = [];
  ThemeMode themeMode = ThemeMode.light;

  /// حساب التاجر المسجَّل دخوله حاليًا (null = زائر).
  MerchantAccount? account;
  bool get isLoggedIn => account != null;

  /// الخطة الاحترافية مفعّلة؟ (تزيل العلامة المائية من التصاميم.)
  bool isPro = false;

  /// هل شاهد المستخدم شاشة الترحيب؟ تُعرض مرة واحدة عند أول تشغيل.
  bool hasOnboarded = false;

  /// نشاط التاجر — يُسأل عنه عند أول تشغيل ويوجّه النص المولَّد كله.
  BusinessCategory businessCategory = BusinessCategory.retail;

  /// هوية العلامة (Brand Kit — نمط Canva): لون العلامة وشعار المتجر
  /// يُطبَّقان تلقائيًا على كل التصاميم المولَّدة.
  int? brandColorValue;
  Uint8List? brandLogoBytes;
  BrandFont? brandFont;
  Color? get brandColor =>
      brandColorValue == null ? null : Color(brandColorValue!);

  /// سجل الحسابات المحلية (وضع عدم الاتصال بـ Supabase فقط، ومنه
  /// الاختبارات): بريد → {name, storeName, salt, hash}.
  Map<String, dynamic> _accounts = {};

  int _nextOrderNumber = 1001;

  /// تحميل الحالة المحفوظة من الجهاز، وجلسة حساب التاجر — من Supabase إن
  /// مُرِّر [client]، وإلا من التخزين المحلي كسابقًا.
  static Future<AppState> load({supa.SupabaseClient? client}) async {
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(prefs: prefs, client: client);
    state._restore();
    if (client != null) {
      await state._restoreSupabaseSession();
    }
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
    try {
      final trash = jsonDecode(prefs.getString(_trashKey) ?? '[]') as List;
      trashedAds.addAll(
        trash.map((e) => TrashedAd.fromJson(e as Map<String, dynamic>)),
      );
    } catch (_) {
      trashedAds.clear();
    }
    _purgeExpiredTrash();
    themeMode = ThemeMode.values[prefs.getInt(_themeKey) ?? 1];
    _nextOrderNumber = prefs.getInt(_orderNumberKey) ?? 1001;
    isPro = prefs.getBool(_proKey) ?? false;
    hasOnboarded = prefs.getBool(_onboardedKey) ?? false;
    businessCategory = BusinessCategory.values.firstWhere(
      (c) => c.name == prefs.getString(_categoryKey),
      orElse: () => BusinessCategory.retail,
    );
    brandColorValue = prefs.getInt(_brandColorKey);
    final fontName = prefs.getString(_brandFontKey);
    brandFont = BrandFont.values.cast<BrandFont?>().firstWhere(
          (f) => f?.name == fontName,
          orElse: () => null,
        );
    final logo = prefs.getString(_brandLogoKey);
    if (logo != null && logo.isNotEmpty) {
      try {
        brandLogoBytes = base64Decode(logo);
      } catch (_) {
        brandLogoBytes = null;
      }
    }

    // جلسة Supabase (إن وُجدت) تُستعاد لاحقًا في _restoreSupabaseSession —
    // لا حاجة للحساب المحلي حين يكون هناك عميل سحابي حقيقي.
    if (_client == null) {
      _restoreLocalAccount(prefs);
    }
  }

  void _restoreLocalAccount(SharedPreferences prefs) {
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

  /// يستعيد حساب التاجر من جلسة Supabase محفوظة (بعد إغلاق التطبيق وفتحه
  /// من جديد) بجلب صفه من جدول merchants. فشل الشبكة هنا لا يُسقط
  /// الجلسة — تبقى صالحة ويُعاد المحاولة عند أول عملية تحتاج الحساب.
  Future<void> _restoreSupabaseSession() async {
    final user = _client!.auth.currentUser;
    if (user == null) return;
    try {
      account = await _fetchMerchantProfile(user);
    } catch (_) {
      // لا اتصال إنترنت الآن — نتابع بلا حساب مُحمَّل ونحاول لاحقًا.
    }
  }

  Future<MerchantAccount> _fetchMerchantProfile(supa.User user) async {
    final row = await _client!
        .from('merchants')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    return MerchantAccount(
      name:
          row?['owner_name'] as String? ??
          (user.userMetadata?['name'] as String? ?? ''),
      storeName: row?['business_name'] as String? ?? '',
      email: user.email ?? '',
    );
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
    prefs.setString(
      _trashKey,
      jsonEncode(trashedAds.map((t) => t.toJson()).toList()),
    );
  }

  /// يحفظ الإعلان في المكتبة. تُضغط صورة المنتج أولًا حتى لا ينتفخ
  /// التخزين المحلي، ثم يُحفظ الإعلان بالصورة المضغوطة نفسها فيبقى
  /// قابلًا لإعادة الفتح والتصدير بعد إغلاق التطبيق.
  Future<void> saveAd(GeneratedAd ad) async {
    final image = ad.brief.imageBytes;
    var stored = ad;
    if (image != null) {
      final compressed = await ImageStore.compressForStorage(image);
      stored = ad.copyWith(brief: ad.brief.copyWith(imageBytes: compressed));
    }
    savedAds.insert(0, stored);
    _persist();
    notifyListeners();
  }

  /// ينقل الإعلان إلى سلة المهملات بدل حذفه نهائيًا — يمكن استعادته خلال
  /// [TrashedAd.retentionDays] يومًا قبل أن يُحذف تلقائيًا.
  void removeAd(GeneratedAd ad) {
    savedAds.remove(ad);
    trashedAds.insert(0, TrashedAd(ad: ad, deletedAt: DateTime.now()));
    _persist();
    notifyListeners();
  }

  void restoreAd(TrashedAd item) {
    if (!trashedAds.remove(item)) return;
    savedAds.insert(0, item.ad);
    _persist();
    notifyListeners();
  }

  void permanentlyDeleteAd(TrashedAd item) {
    trashedAds.remove(item);
    _persist();
    notifyListeners();
  }

  void emptyTrash() {
    trashedAds.clear();
    _persist();
    notifyListeners();
  }

  /// يحذف نهائيًا كل عنصر تجاوز مدة الاحتفاظ — يُستدعى عند كل تحميل
  /// للحالة فلا تتراكم عناصر سلة منسية إلى الأبد.
  void _purgeExpiredTrash() {
    trashedAds.removeWhere((t) => t.daysRemaining <= 0);
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

  void setBusinessCategory(BusinessCategory category) {
    businessCategory = category;
    _prefs?.setString(_categoryKey, category.name);
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

  void setBrandFont(BrandFont? font) {
    brandFont = font;
    if (font == null) {
      _prefs?.remove(_brandFontKey);
    } else {
      _prefs?.setString(_brandFontKey, font.name);
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
  /// يستخدم Supabase Auth الحقيقي عند توفر عميل، وإلا حسابًا محليًا
  /// مُجزَّأ بكلمة مرور مملّحة (كما في كل اختبارات الودجت).
  Future<String?> register({
    required String name,
    required String storeName,
    required String email,
    required String password,
  }) {
    final key = email.trim().toLowerCase();
    if (_client != null) {
      return _registerWithSupabase(
        name: name.trim(),
        storeName: storeName.trim(),
        email: key,
        password: password,
      );
    }
    return _registerLocally(
      name: name,
      storeName: storeName,
      email: key,
      password: password,
    );
  }

  Future<String?> _registerLocally({
    required String name,
    required String storeName,
    required String email,
    required String password,
  }) async {
    if (_accounts.containsKey(email)) {
      return 'هذا البريد مسجَّل مسبقًا — سجّل دخولك بدلًا من ذلك';
    }
    final salt = List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _accounts[email] = {
      'name': name.trim(),
      'storeName': storeName.trim(),
      'salt': salt,
      'hash': _hashPassword(password, salt),
    };
    account = MerchantAccount(
      name: name.trim(),
      storeName: storeName.trim(),
      email: email,
    );
    _prefs?.setString(_sessionKey, email);
    _persistAccounts();
    notifyListeners();
    return null;
  }

  Future<String?> _registerWithSupabase({
    required String name,
    required String storeName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client!.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      final user = response.user;
      if (user == null) {
        return 'تعذّر إنشاء الحساب — حاول مجددًا';
      }
      await _client.from('merchants').upsert({
        'id': user.id,
        'owner_name': name,
        'business_name': storeName,
        'category': businessCategory.name,
      });
      account = MerchantAccount(name: name, storeName: storeName, email: email);
      notifyListeners();
      return null;
    } on supa.AuthException catch (e) {
      return _translateAuthError(e.message);
    } catch (_) {
      return 'تعذّر الاتصال بالخادم — تحقق من الإنترنت وحاول مجددًا';
    }
  }

  /// تسجيل الدخول. يعيد رسالة خطأ بالعربية أو null عند النجاح.
  Future<String?> login({required String email, required String password}) {
    final key = email.trim().toLowerCase();
    if (_client != null) {
      return _loginWithSupabase(email: key, password: password);
    }
    return _loginLocally(email: key, password: password);
  }

  Future<String?> _loginLocally({
    required String email,
    required String password,
  }) async {
    final stored = _accounts[email];
    if (stored == null ||
        stored['hash'] != _hashPassword(password, stored['salt'] as String)) {
      return 'البريد أو كلمة المرور غير صحيحة';
    }
    account = MerchantAccount(
      name: stored['name'] as String? ?? '',
      storeName: stored['storeName'] as String? ?? '',
      email: email,
    );
    _prefs?.setString(_sessionKey, email);
    notifyListeners();
    return null;
  }

  Future<String?> _loginWithSupabase({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client!.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        return 'البريد أو كلمة المرور غير صحيحة';
      }
      account = await _fetchMerchantProfile(user);
      notifyListeners();
      return null;
    } on supa.AuthException catch (e) {
      return _translateAuthError(e.message);
    } catch (_) {
      return 'تعذّر الاتصال بالخادم — تحقق من الإنترنت وحاول مجددًا';
    }
  }

  /// يمسح الحساب محليًا فورًا (بلا انتظار)، ويرسل طلب تسجيل الخروج
  /// الحقيقي لـ Supabase في الخلفية عند وجود عميل سحابي.
  void logout() {
    account = null;
    if (_client != null) {
      unawaited(_client.auth.signOut());
    } else {
      _prefs?.remove(_sessionKey);
    }
    notifyListeners();
  }

  String _translateAuthError(String message) {
    final m = message.toLowerCase();
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'هذا البريد مسجَّل مسبقًا — سجّل دخولك بدلًا من ذلك';
    }
    if (m.contains('invalid login credentials') ||
        m.contains('invalid_credentials')) {
      return 'البريد أو كلمة المرور غير صحيحة';
    }
    if (m.contains('password') &&
        (m.contains('character') || m.contains('short'))) {
      return 'كلمة المرور 6 أحرف على الأقل';
    }
    if (m.contains('email') && m.contains('invalid')) {
      return 'أدخل بريدًا إلكترونيًا صحيحًا';
    }
    return 'تعذّر إتمام العملية — حاول مجددًا';
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
