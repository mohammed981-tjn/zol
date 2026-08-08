import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_circle.dart';
import 'create_ad/upload_details_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const IconCircle(
                icon: Icons.auto_fix_high,
                background: AppColors.coral,
                diameter: 96,
              ),
              const SizedBox(height: 32),
              const Text(
                'سوق الدعاية والإعلان الشامل',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'AdCraft AI Marketplace',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'من الفكرة إلى الإعلان المطبوع والمُوصَّل خلال دقائق',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFCADCFC), fontSize: 15),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const UploadDetailsScreen(),
                      ),
                    );
                  },
                  child: const Text('أنشئ إعلانك الآن'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'معاينة فورية في أقل من 90 ثانية',
                style: TextStyle(color: Color(0xFF8B98C4), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
