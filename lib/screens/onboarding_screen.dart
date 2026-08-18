import 'package:flutter/material.dart';
import '../models/business_category.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/zol_logo.dart';

/// شاشة الترحيب لأول تشغيل — البنية منقولة من مستودع wasl
/// (PageView + مؤشرات نقطية + زر «ابدأ الآن») ومكيّفة لرحلة zol الثلاثية.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      icon: Icons.auto_awesome,
      title: 'إعلانك يولد في ثوانٍ',
      text:
          'ارفع صورة منتجك واختر النبرة والمنصة، '
          'ونحن نخرج لك نصًا وتصميمًا جاهزين للنشر.',
    ),
    (
      icon: Icons.print_outlined,
      title: 'اطبعه عند أقرب مطبعة',
      text:
          'بنرات، استيكرات، كروت ورول أب بأسعار فورية — '
          'ويُسند طلبك تلقائيًا لأقرب مطبعة شريكة لموقعك.',
    ),
    (
      icon: Icons.delivery_dining,
      title: 'ويصلك حتى الباب',
      text:
          'حدّد موقعك على الخريطة وتابع طلبك خطوة بخطوة '
          'حتى يصل بين يديك.',
    ),
  ];

  /// الصفحة الأخيرة هي سؤال النشاط (بعد صفحات التعريف الثلاث).
  int get _lastIndex => _pages.length;
  bool get _isCategoryPage => _page == _lastIndex;

  BusinessCategory? _category;

  void _finish() {
    final state = AppStateScope.of(context);
    if (_category != null) state.setBusinessCategory(_category!);
    state.completeOnboarding();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// سؤال النشاط — الإجابة توجّه مفردات النص المولَّد ومنافعه ودعوة
  /// الإجراء في كل إعلان يُنشئه التاجر لاحقًا.
  Widget _buildCategoryPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'ما نشاطك؟',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'نكتب لك نصوصًا بمفردات مجالك — لا جملًا عامة تصلح لأي شيء.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFCADCFC),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: BusinessCategory.values.map((category) {
              final isSelected = category == _category;
              return GestureDetector(
                key: ValueKey('category-${category.name}'),
                onTap: () => setState(() => _category = category),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.coral
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.coral
                          : Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(category.icon, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        category.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          const Text(
            'يمكنك تغييره لاحقًا من الإعدادات',
            style: TextStyle(color: Color(0xFF8B98C4), fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _finish,
                child: const Text(
                  'تخطٍّ',
                  style: TextStyle(color: Color(0xFF8B98C4)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const ZolLogo(height: 64, color: Colors.white),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length + 1,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  if (i == _lastIndex) return _buildCategoryPage();
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 132,
                          height: 132,
                          decoration: BoxDecoration(
                            color: AppColors.coral.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page.icon,
                            size: 58,
                            color: AppColors.coral,
                          ),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          page.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFCADCFC),
                            fontSize: 14.5,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length + 1,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? AppColors.coral
                        : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCategoryPage && _category == null
                      ? null
                      : () {
                          if (_isCategoryPage) {
                            _finish();
                          } else {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                  child: Text(
                    _isCategoryPage
                        ? (_category == null
                              ? 'اختر نشاطك للمتابعة'
                              : 'ابدأ الآن')
                        : 'التالي',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
