import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/ad_brief.dart';
import '../../models/generation.dart';
import '../../services/ai_gateway.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ad_composite.dart';
import 'execute_screen.dart';

class MagicScreen extends StatefulWidget {
  const MagicScreen({super.key, required this.brief, this.gateway});

  final AdBrief brief;

  /// يُمرَّر في الاختبارات ببوابة وهمية بلا شبكة.
  final AiGateway? gateway;

  @override
  State<MagicScreen> createState() => _MagicScreenState();
}

class _MagicScreenState extends State<MagicScreen> {
  late final AiGateway _gateway =
      widget.gateway ?? AiGateway(baseUrl: AppConfig.orchestratorUrl);

  PreviewResult? _result;
  GatewayException? _error;
  bool _loading = true;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    if (widget.gateway == null) _gateway.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _gateway.generatePreview(widget.brief);
      if (!mounted) return;
      setState(() {
        _result = result;
        _selected = result.bestIndex.clamp(0, result.variants.length - 1);
        _loading = false;
      });
    } on GatewayException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شاشة السحر'),
        actions: [
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: Text(
                  'تبقّى ${_result!.quota.remaining}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _GeneratingView();
    final error = _error;
    if (error != null) {
      return _ErrorView(error: error, onRetry: error.isQuota ? null : _generate);
    }

    final result = _result!;
    final variant = result.variants[_selected];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            children: [
              AdComposite(
                variant: variant,
                aspectRatio: result.aspectRatioValue,
                background: result.backgroundImage,
              ),
              const SizedBox(height: 16),
              if (result.critiqued)
                _Badge(
                  icon: Icons.verified_outlined,
                  text: 'رشّح المحكّم الصيغة رقم ${result.bestIndex + 1} من ${result.variants.length}',
                ),
              const SizedBox(height: 12),
              const Text(
                'الصيغ المقترحة',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              ...List.generate(result.variants.length, (i) {
                final v = result.variants[i];
                final isSelected = i == _selected;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _selected = i),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.navy : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  v.angle.isEmpty ? 'صيغة ${i + 1}' : v.angle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? AppColors.gold : AppColors.coral,
                                  ),
                                ),
                              ),
                              if (i == result.bestIndex)
                                Icon(
                                  Icons.star,
                                  size: 15,
                                  color: isSelected ? AppColors.gold : AppColors.coral,
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            v.headline,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isSelected ? Colors.white : AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            v.body,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: isSelected
                                  ? const Color(0xFFCADCFC)
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _goExecute(isDigital: true),
                  child: const Text('حفظ ونشر'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _goExecute(isDigital: false),
                  child: const Text('اطبعه وصلّه'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _goExecute({required bool isDigital}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExecuteScreen(brief: widget.brief, isDigital: isDigital),
      ),
    );
  }
}

class _GeneratingView extends StatelessWidget {
  const _GeneratingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(),
          SizedBox(height: 22),
          Text(
            'نكتب إعلانك الآن',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'ثلاث صيغ مختلفة، ثم يرشّح المحكّم أفضلها',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, this.onRetry});

  final GatewayException error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isQuota = error.isQuota;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isQuota ? Icons.hourglass_bottom : Icons.cloud_off_outlined,
              size: 46,
              color: isQuota ? AppColors.coral : AppColors.textMuted,
            ),
            const SizedBox(height: 18),
            Text(
              isQuota ? 'انتهت معايناتك اليوم' : 'تعذّر التوليد',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, height: 1.6),
            ),
            const SizedBox(height: 24),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('أعد المحاولة'),
              )
            else
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('رجوع'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.navy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}
