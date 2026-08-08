import 'package:flutter/material.dart';
import '../../models/ad_brief.dart';
import '../../theme/app_theme.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/section_header.dart';
import 'execute_screen.dart';

class MagicScreen extends StatefulWidget {
  const MagicScreen({super.key, required this.brief});

  final AdBrief brief;

  @override
  State<MagicScreen> createState() => _MagicScreenState();
}

class _MagicScreenState extends State<MagicScreen> {
  int _selectedCard = 0;

  @override
  Widget build(BuildContext context) {
    final cards = _buildMockCards(widget.brief);

    return Scaffold(
      appBar: AppBar(title: const Text('شاشة السحر')),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: SectionHeader(
                  kicker: 'المُخرجات الذكية',
                  title: 'اختر البطاقة التي تناسبك',
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 340,
              child: PageView.builder(
                itemCount: cards.length,
                controller: PageController(viewportFraction: 0.86),
                onPageChanged: (i) => setState(() => _selectedCard = i),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _AdPreviewCard(data: cards[i]),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                cards.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _selectedCard ? AppColors.coral : AppColors.cardBg,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _goExecute(context, isDigital: true),
                      child: const Text('حفظ ونشر'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _goExecute(context, isDigital: false),
                      child: const Text('اطبعه وصلّه'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goExecute(BuildContext context, {required bool isDigital}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExecuteScreen(brief: widget.brief, isDigital: isDigital),
      ),
    );
  }

  List<_AdCardData> _buildMockCards(AdBrief brief) {
    return [
      _AdCardData(
        icon: Icons.videocam_outlined,
        title: 'فيديو قصير',
        caption: 'بنبرة ${brief.tone} لمنصة ${brief.platform}',
        detail: 'مع تعليق صوتي وموسيقى بصيغة Reels/Shorts',
      ),
      _AdCardData(
        icon: Icons.image_outlined,
        title: 'صورة تسويقية',
        caption: 'بنبرة ${brief.tone} لمنصة ${brief.platform}',
        detail: 'خلفية احترافية مصمّمة بالذكاء الاصطناعي',
      ),
      _AdCardData(
        icon: Icons.tag_outlined,
        title: 'نص وهاشتاقات',
        caption: 'بنبرة ${brief.tone} لمنصة ${brief.platform}',
        detail: 'نص إعلاني جذاب مع هاشتاقات مهيأة للمنصة',
      ),
    ];
  }
}

class _AdCardData {
  const _AdCardData({
    required this.icon,
    required this.title,
    required this.caption,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String caption;
  final String detail;
}

class _AdPreviewCard extends StatelessWidget {
  const _AdPreviewCard({required this.data});

  final _AdCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconCircle(icon: data.icon, background: AppColors.coral, diameter: 76),
          const SizedBox(height: 20),
          Text(
            data.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            data.caption,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.coral, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            data.detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
