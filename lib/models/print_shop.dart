import 'dart:math';

/// شبكة المطابع الشريكة — نموذج التوجيه التلقائي لأقرب مطبعة (نمط Gelato).
/// القائمة ثابتة محليًا الآن، وتُنقل إلى قاعدة بيانات الخادم مع لوحة تحكم
/// المطابع في المرحلة القادمة دون تغيير منطق التوجيه.
class PrintShop {
  const PrintShop({
    required this.name,
    required this.city,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String city;
  final double lat;
  final double lng;
}

const printShops = [
  PrintShop(name: 'مطبعة العليا', city: 'الرياض', lat: 24.6947, lng: 46.6853),
  PrintShop(name: 'مطبعة الشفا', city: 'الرياض', lat: 24.5541, lng: 46.7096),
  PrintShop(name: 'مطبعة الروضة', city: 'جدة', lat: 21.5623, lng: 39.1520),
  PrintShop(name: 'مطبعة الشاطئ', city: 'الدمام', lat: 26.4367, lng: 50.1039),
  PrintShop(name: 'مطبعة القصيم', city: 'بريدة', lat: 26.3260, lng: 43.9750),
];

/// مسافة هافرساين التقريبية بالكيلومترات.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a =
      pow(sin(dLat / 2), 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * pow(sin(dLng / 2), 2);
  return 2 * r * atan2(sqrt(a), sqrt(1 - a));
}

double _rad(double deg) => deg * pi / 180;

/// أقرب مطبعة شريكة لموقع التوصيل.
PrintShop nearestShop(double lat, double lng) {
  return printShops.reduce(
    (a, b) =>
        distanceKm(lat, lng, a.lat, a.lng) <= distanceKm(lat, lng, b.lat, b.lng)
        ? a
        : b,
  );
}
