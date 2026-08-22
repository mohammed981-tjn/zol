import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
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

  /// الأيقونات ثابتة، والنصّ يُقرأ من الترجمة **وقت البناء**: ثابتٌ ساكن
  /// يُقرأ مرّة واحدة عند تحميل الصنف فلا يتغيّر حين يبدّل التاجر لغته.
  static const _icons = [
    Icons.auto_awesome,
    Icons.print_outlined,
    Icons.delivery_dining,
  ];

  static List<({String title, String text})> _pageText(L l) => [
    (title: l.onboardingT1, text: l.onboardingB1),
    (title: l.onboardingT2, text: l.onboardingB2),
    (title: l.onboardingT3, text: l.onboardingB3),
  ];

  /// الصفحة الأخيرة هي سؤال النشاط (بعد صفحات التعريف الثلاث).
  int get _lastIndex => _icons.length;
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
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l.onboardingCategoryTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l.onboardingCategoryBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
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
          Text(
            l.onboardingCategoryHint,
            style: const TextStyle(color: Color(0xFF8B98C4), fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pages = _pageText(l);
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  l.onboardingSkip,
                  style: const TextStyle(color: Color(0xFF8B98C4)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const ZolLogo(height: 64, color: Colors.white),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length + 1,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  if (i == _lastIndex) return _buildCategoryPage();
                  final page = pages[i];
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
                            _icons[i],
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
                pages.length + 1,
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
                              ? l.onboardingPickFirst
                              : l.onboardingStart)
                        : l.onboardingNext,
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
