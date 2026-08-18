import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/ad_service.dart';
import '../services/provider_directory.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// لوحة تسجيل المزوّد — الباب الذي يجعل السوق سوقًا.
///
/// كان الدليل قائمةً نكتبها نحن في ملفّ داخل التطبيق: كل مزوّد جديد يحتاج
/// بناءً ونشرًا وتحديثًا على كل جهاز. هنا يسجّل المزوّد نفسه، ويُراجَع، ثم
/// يظهر — وينمو السوق بلا إصدار جديد.
///
/// وثلاثة أشياء تقولها هذه الشاشة صراحةً لأن إخفاءها يُنتج شكاوى لا
/// تسجيلات: أن التسجيل لا يعني الظهور، وأن المراجعة بشرية وتأخذ وقتًا،
/// وأن التوثيق ليس شيئًا يمنحه المزوّد لنفسه.
class ProviderSignupScreen extends StatefulWidget {
  const ProviderSignupScreen({super.key});

  @override
  State<ProviderSignupScreen> createState() => _ProviderSignupScreenState();
}

class _ProviderSignupScreenState extends State<ProviderSignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // المتحكّمات يملكها الـState لا الـbuild: إنشاؤها في build يفقد ما كُتب
  // مع كل إعادة رسم، وعدم التخلّص منها تسريب.
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _tagline = TextEditingController();
  final _price = TextEditingController();
  final _hours = TextEditingController();
  final _works = TextEditingController();

  ServiceKind _kind = ServiceKind.design;
  bool _sending = false;
  ProviderListing? _existing;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    for (final c in [_name, _city, _tagline, _price, _hours, _works]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final listing = await ProviderDirectory.mine();
    if (!mounted) return;
    setState(() {
      _existing = listing;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(L.of(context).providerSignupTitle)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : !state.isLoggedIn
            ? _needsAccount(context)
            : _existing != null
            ? _statusCard(context, _existing!)
            : _form(context),
      ),
    );
  }

  Widget _needsAccount(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.badge_outlined, size: 44, color: context.textMuted),
        const SizedBox(height: AppSpacing.md),
        Text(
          L.of(context).providerSignupNeedsAccount,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  /// حالة الإدراج القائم. المزوّد الذي لا يعرف أنه قيد المراجعة يعيد
  /// التسجيل ثم يشتكي، والمرفوض بلا سبب يعيدها بالخطأ نفسه.
  Widget _statusCard(BuildContext context, ProviderListing listing) {
    final color = switch (listing.status) {
      ProviderStatus.approved => const Color(0xFF1B7F4D),
      ProviderStatus.rejected => AppColors.coral,
      ProviderStatus.pending => const Color(0xFF8F650C),
    };
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                listing.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                listing.kind.label,
                style: TextStyle(fontSize: 13, color: context.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    switch (listing.status) {
                      ProviderStatus.approved => Icons.check_circle_outline,
                      ProviderStatus.rejected => Icons.cancel_outlined,
                      ProviderStatus.pending => Icons.hourglass_top_outlined,
                    },
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    listing.status.label,
                    style: TextStyle(fontWeight: FontWeight.w700, color: color),
                  ),
                ],
              ),
              if (listing.reviewNote != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(listing.reviewNote!, style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          L.of(context).providerSignupOneListing,
          style: TextStyle(fontSize: 12.5, color: context.textMuted),
        ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    final l = L.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            l.providerSignupIntro,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<ServiceKind>(
            initialValue: _kind,
            decoration: InputDecoration(labelText: l.providerSignupKind),
            items: [
              for (final k in ServiceKind.values)
                DropdownMenuItem(value: k, child: Text(k.label)),
            ],
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _name,
            decoration: InputDecoration(labelText: l.providerSignupName),
            validator: (v) => (v == null || v.trim().length < 2)
                ? l.providerSignupNameError
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _city,
            decoration: InputDecoration(labelText: l.providerSignupCity),
            validator: (v) => (v == null || v.trim().length < 2)
                ? l.providerSignupCityError
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _tagline,
            maxLines: 2,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: l.providerSignupTagline,
              helperText: l.providerSignupTaglineHelp,
            ),
            // الحدّ الأدنى مطابق لقيد القاعدة: رفضٌ هنا برسالة عربية
            // أوضح من رفض Postgres بعد رحلة إلى الخادم.
            validator: (v) => (v == null || v.trim().length < 10)
                ? l.providerSignupTaglineError
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l.providerSignupPrice,
              helperText: l.providerSignupPriceHelp,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final n = int.tryParse(v.trim());
              if (n == null || n < 0) return l.providerSignupPriceError;
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _hours,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l.providerSignupHours,
              helperText: l.providerSignupHoursHelp,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final n = int.tryParse(v.trim());
              if (n == null || n <= 0 || n > 720) {
                return l.providerSignupHoursError;
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _works,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l.providerSignupWorks,
              helperText: l.providerSignupWorksHelp,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(l.providerSignupSubmit),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.providerSignupReviewNote,
            style: TextStyle(fontSize: 12, color: context.textMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);

    final error = await ProviderDirectory.submit(
      kind: _kind,
      name: _name.text,
      city: _city.text,
      tagline: _tagline.text,
      priceFrom: int.tryParse(_price.text.trim()) ?? 0,
      respondsInHours: int.tryParse(_hours.text.trim()),
      works: _works.text.split('\n'),
    );

    if (!mounted) return;
    setState(() => _sending = false);
    final l = L.of(context);

    if (error == null) {
      await _loadExisting();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.providerSignupSent)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (error) {
          'not_signed_in' => l.providerSignupNeedsAccount,
          'duplicate' => l.providerSignupDuplicate,
          _ => l.providerSignupFailed,
        }),
      ),
    );
  }
}
