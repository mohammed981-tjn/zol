import 'package:flutter/material.dart';
import '../models/generated_ad.dart';
import '../models/print_order.dart';

/// حالة التطبيق داخل الذاكرة (إعلانات محفوظة، طلبات طباعة، سمة العرض).
/// تُستبدل لاحقًا بتخزين سحابي مرتبط بحساب التاجر.
class AppState extends ChangeNotifier {
  final List<GeneratedAd> savedAds = [];
  final List<PrintOrder> orders = [];
  ThemeMode themeMode = ThemeMode.light;

  int _nextOrderNumber = 1001;

  void saveAd(GeneratedAd ad) {
    savedAds.insert(0, ad);
    notifyListeners();
  }

  void removeAd(GeneratedAd ad) {
    savedAds.remove(ad);
    notifyListeners();
  }

  String nextOrderId() => 'AD-${_nextOrderNumber++}';

  void addOrder(PrintOrder order) {
    orders.insert(0, order);
    notifyListeners();
  }

  void advanceOrder(PrintOrder order) {
    final index = orders.indexOf(order);
    if (index == -1 || order.status == OrderStatus.delivered) return;
    orders[index] = order.copyWith(
      status: OrderStatus.values[order.status.index + 1],
    );
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
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
