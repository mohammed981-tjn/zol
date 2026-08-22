import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

/// شاشة اختيار موقع التوصيل على الخريطة — منقولة من تطبيق zadgo2
/// (فرع split-customer) مع تكييفها لسمة zol.
class PickLocationScreen extends StatefulWidget {
  const PickLocationScreen({super.key, this.initialLocation});

  final LatLng? initialLocation;

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  final MapController _mapController = MapController();

  /// مركز مبدئي للخريطة حين لا يتوفّر موقع بعد — لعرض الخريطة فقط، ولا
  /// يُعامَل موقعًا مختارًا. (درس منقول من zadgo2: إسناده مباشرة للموقع
  /// المختار جعل عملاء يؤكدون «الرياض» ظنًا أنها موقعهم، فنشأت طلبات
  /// بمسافات مئات الكيلومترات.)
  static const LatLng _mapStartCenter = LatLng(24.7136, 46.6753);

  /// الموقع المختار فعليًا: من GPS أو بنقرة العميل. null يعني «لم يُختر
  /// بعد» فيبقى زر التأكيد معطلًا.
  LatLng? _selected;

  bool _loadingGps = true;
  String? _gpsError;

  /// هل الموقع المُلتقط من GPS مُحاكى (محاكي أو تطبيق موقع وهمي)؟
  bool _mockedLocation = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _fetchCurrentLocation(),
    );
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _loadingGps = true;
      _gpsError = null;
      _mockedLocation = false;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() {
          _loadingGps = false;
          _gpsError = 'خدمة الموقع غير مفعّلة على الجهاز';
        });
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _loadingGps = false;
          _gpsError = 'تم رفض إذن الوصول للموقع — اختر موقعك بنقرة على الخريطة';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _selected = point;
        _loadingGps = false;
        _mockedLocation = pos.isMocked;
      });
      _mapController.move(point, 16);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingGps = false;
        _gpsError = 'تعذّر تحديد موقعك الحالي — اختر موقعك بنقرة على الخريطة';
      });
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selected = point;
      _gpsError = null;
      _mockedLocation = false;
    });
    _mapController.move(point, 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديد موقع التوصيل'),
        actions: [
          IconButton(
            tooltip: 'تحديد موقعي الحالي',
            icon: _loadingGps
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            onPressed: _loadingGps ? null : _fetchCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selected ?? _mapStartCenter,
              initialZoom: 15,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.zol.app',
              ),
              if (_selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selected!,
                      width: 50,
                      height: 50,
                      child: Icon(
                        Icons.location_on,
                        color: _mockedLocation
                            ? Colors.orange
                            : AppColors.coral,
                        size: 44,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_mockedLocation)
            _banner(
              color: const Color(0xFFC62828),
              icon: Icons.gps_off_rounded,
              text:
                  'الموقع المُلتقط مُحاكى وليس حقيقيًا — اضغط على الخريطة لتحديد موقعك الفعلي',
            ),
          if (_gpsError != null && !_mockedLocation)
            _banner(
              color: const Color(0xFFF9A825),
              icon: Icons.warning_amber_rounded,
              text: _gpsError!,
            ),
          Positioned(
            bottom: 90,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _selected == null
                      ? 'اضغط على الخريطة لتحديد موقعك'
                      : 'اضغط على الخريطة لتعديل الموقع',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            // لا تأكيد بلا موقع مختار فعلًا.
            onPressed: _selected == null
                ? null
                : () => Navigator.pop(context, _selected),
            child: Text(
              _selected == null ? 'حدّد موقعًا أولًا' : 'تأكيد هذا الموقع',
            ),
          ),
        ),
      ),
    );
  }

  Widget _banner({
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
