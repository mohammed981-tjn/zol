import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/ad_brief.dart';
import '../../models/ad_template.dart';
import '../../models/generated_ad.dart';
import '../../services/ad_generator.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ad_design_preview.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/print_cost_calculator.dart';
import '../../widgets/section_header.dart';
import 'execute_screen.dart';

class MagicScreen extends StatefulWidget {
  const MagicScreen({super.key, required this.brief, this.initialTemplate});

  final AdBrief brief;

  /// القالب القادم من معرض القوالب (إن وُجد).
  final AdTemplate? initialTemplate;

  @override
  State<MagicScreen> createState() => _MagicScreenState();
}

class _MagicScreenState extends State<MagicScreen> {
  List<GeneratedAd>? _ads;
  int _stage = 0;
  int _seed = 0;
  int _selectedCard = 0;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _ads = null;
      _stage = 0;
      _selectedCard = 0;
    });
    for (var i = 0; i < AdGenerator.generationStages.length; i++) {
      await Future<void>.delayed(AdGenerator.stageDuration);
      if (!mounted) return;
      setState(() => _stage = i + 1);
    }
    if (!mounted) return;
    setState(() => _ads = AdGenerator.preview(widget.brief, seed: _seed));
  }

  void _regenerate() {
    _seed++;
    _generate();
  }

  @override
  Widget build(BuildContext context) {
    final ads = _ads;

    return Scaffold(
      appBar: AppBar(
        title: const Text('شاشة السحر'),
        actions: [
          if (ads != null)
            IconButton(
              tooltip: 'إعادة توليد',
              onPressed: _regenerate,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: ads == null ? _buildGenerating() : _buildResults(ads),
      ),
    );
  }

  Widget _buildGenerating() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const IconCircle(
            icon: Icons.auto_awesome,
            background: AppColors.coral,
            diameter: 80,
          ),
          const SizedBox(height: 28),
          Text(
            'الذكاء الاصطناعي يعمل على إعلانك…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: context.scheme.onSurface,
            ),
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < AdGenerator.generationStages.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  if (i < _stage)
                    const Icon(Icons.check_circle,
                        color: AppColors.coral, size: 22)
                  else if (i == _stage)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.coral,
                      ),
                    )
                  else
                    Icon(Icons.circle_outlined,
                        color: context.textMuted, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    AdGenerator.generationStages[i],
                    style: TextStyle(
                      color: i <= _stage
                          ? context.scheme.onSurface
                          : context.textMuted,
                      fontWeight:
                          i == _stage ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults(List<GeneratedAd> ads) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SectionHeader(
              kicker: 'الخطوة 2 من 3',
              title: 'اختر النسخة الأنسب',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: PageView.builder(
            itemCount: ads.length,
            controller: PageController(viewportFraction: 0.88),
            onPageChanged: (i) => setState(() => _selectedCard = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: _AdPreviewCard(
                ad: ads[i],
                onSave: () => _saveAd(ads[i]),
                onCopy: () => _copyAd(ads[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            ads.length,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _selectedCard ? AppColors.coral : context.cardBg,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: PrintCostCalculator(
            onProceed: (product, sizeIndex, quantity) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExecuteScreen(
                    ad: ads[_selectedCard],
                    isDigital: false,
                    initialTemplate: widget.initialTemplate,
                    initialProduct: product,
                    initialSizeIndex: sizeIndex,
                    initialQuantity: quantity,
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _goExecute(ads, isDigital: true),
                  child: const Text('حفظ ونشر'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _goExecute(ads, isDigital: false),
                  child: const Text('اطبعه وصلّه'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _saveAd(GeneratedAd ad) {
    AppStateScope.of(context).saveAd(ad);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم الحفظ في «إعلاناتي»')),
    );
  }

  Future<void> _copyAd(GeneratedAd ad) async {
    await Clipboard.setData(ClipboardData(text: ad.shareText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ النص الإعلاني')),
    );
  }

  void _goExecute(List<GeneratedAd> ads, {required bool isDigital}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExecuteScreen(
          ad: ads[_selectedCard],
          isDigital: isDigital,
          initialTemplate: widget.initialTemplate,
        ),
      ),
    );
  }
}

class _AdPreviewCard extends StatelessWidget {
  const _AdPreviewCard({
    required this.ad,
    required this.onSave,
    required this.onCopy,
  });

  final GeneratedAd ad;
  final VoidCallback onSave;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconCircle(
                  icon: ad.kind.icon,
                  background: AppColors.coral,
                  diameter: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ad.kind.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: context.scheme.onSurface,
                    ),
                  ),
                ),
                _ScoreBadge(score: ad.score),
              ],
            ),
            if (ad.kind == AdKind.image) ...[
              const SizedBox(height: 14),
              // معاينة التصميم الحقيقي من محرك القوالب (صورة المنتج مركّبة
              // على القالب) — وليست أيقونة رمزية.
              Center(
                child: SizedBox(
                  height: 250,
                  child: AdDesignPreview(
                    ad: ad,
                    showWatermark: !AppStateScope.of(context).isPro,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              ad.headline,
              style: const TextStyle(
                color: AppColors.coral,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ad.body,
              style: TextStyle(color: context.textMuted, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ad.hashtags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.scheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: context.scheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('نسخ النص'),
                ),
                TextButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('حفظ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 14, color: Color(0xFF8A6D00)),
          const SizedBox(width: 2),
          Text(
            'توافق $score%',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8A6D00),
            ),
          ),
        ],
      ),
    );
  }
}
