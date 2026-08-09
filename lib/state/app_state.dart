import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/generated_ad.dart';
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

  final List<GeneratedAd> savedAds = [];
  final List<PrintOrder> orders = [];
  ThemeMode themeMode = ThemeMode.light;

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
