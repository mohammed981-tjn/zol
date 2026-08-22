import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/ad_service.dart';
import '../services/quote_requests.dart';
import '../theme/app_theme.dart';

/// ورقة طلب التسعير — الطريق الذي كان مسدودًا.
///
/// قبلها كان الزرّ يعرض إشعارًا صادقًا: «سجّلنا اهتمامك». والصدق عن طريق
/// مسدود لا يفتحه — التاجر يرى مزوّدًا يناسبه ولا يملك أن يكلّمه.
///
/// والورقة تُخرج **نصًّا يصل** في كل الأحوال: تُسجّله على الخادم إن كان
/// المزوّد مسجَّلًا، وتُبقي زرّ «أرسله بنفسك» ظاهرًا دائمًا. الثاني ليس
/// احتياطًا للأول — أكثر مزوّدي السوق يعملون على واتساب، ورسالةٌ تصلهم
/// اليوم خيرٌ من صفٍّ في جدول ينتظر لوحةً لم يفتحوها قطّ.
class QuoteRequestSheet extends StatefulWidget {
  const QuoteRequestSheet({
    super.key,
    required this.provider,
    this.merchantName,
    this.debugShare,
  });

  final ServiceProvider provider;
  final String? merchantName;

  /// منفذ اختباري بدل ورقة المشاركة: `share_plus` ينادي المنصّة ولا
  /// يعمل تحت الاختبار، وتركُ الزرّ بلا اختبار يعيدنا إلى طريق مسدود لا
  /// نعرف أنه انسدّ.
  final void Function(String text)? debugShare;

  @override
  State<QuoteRequestSheet> createState() => _QuoteRequestSheetState();
}

class _QuoteRequestSheetState extends State<QuoteRequestSheet> {
  final _form = GlobalKey<FormState>();
  final _need = TextEditingController();
  final _budget = TextEditingController();
  final _contact = TextEditingController();

  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _need.dispose();
    _budget.dispose();
    _contact.dispose();
    super.dispose();
  }

  String get _composed => QuoteRequests.compose(
    provider: widget.provider,
    need: _need.text,
    contact: _contact.text,
    merchantName: widget.merchantName,
    budgetSar: int.tryParse(_budget.text.trim()) ?? 0,
  );

  Future<void> _send() async {
    if (!(_form.currentState?.validate() ?? false) || _busy) return;
    setState(() => _busy = true);
    final l = L.of(context);

    final result = await QuoteRequests.send(
      provider: widget.provider,
      body: _need.text,
      contact: _contact.text,
      budgetSar: int.tryParse(_budget.text.trim()) ?? 0,
    );
    if (!mounted) return;

    setState(() {
      _busy = false;
      _status = switch (result.outcome) {
        QuoteOutcome.delivered => l.quoteDelivered,
        QuoteOutcome.offline => l.quoteOffline,
        QuoteOutcome.needsAccount => l.quoteNeedsAccount,
        QuoteOutcome.notRoutable => l.quoteNotRoutable,
      };
    });

    // الوصول لا يُغلق الورقة فورًا: التاجر يستحق أن يقرأ أن طلبه وصل،
    // وورقةٌ تختفي في اللحظة نفسها تترك شكًّا لا خبرًا.
    if (result.delivered) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _shareIt() async {
    final text = _composed;
    final l = L.of(context);
    if (widget.debugShare != null) {
      widget.debugShare!(text);
    } else {
      await Share.share(text);
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.quoteCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${l.quoteSheetTitle} — ${widget.provider.name}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: context.scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _need,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l.quoteNeedLabel,
                  helperText: l.quoteNeedHelp,
                  helperMaxLines: 2,
                ),
                validator: (v) =>
                    (v ?? '').trim().length < 10 ? l.quoteNeedError : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _budget,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.quoteBudgetLabel),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _contact,
                decoration: InputDecoration(
                  labelText: l.quoteContactLabel,
                  helperText: l.quoteContactHelp,
                  helperMaxLines: 2,
                ),
                validator: (v) =>
                    (v ?? '').trim().length < 5 ? l.quoteContactError : null,
              ),
              if (_status != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _status!,
                  style: TextStyle(fontSize: 12.5, color: context.textMuted),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _busy ? null : _send,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(l.quoteSend),
              ),
              const SizedBox(height: AppSpacing.sm),
              // ظاهرٌ دائمًا لا عند الفشل وحده: هذا هو الطريق الذي يعمل
              // اليوم لأكثر المزوّدين، وإخفاؤه خلف عطلٍ يجعله سرًّا.
              OutlinedButton.icon(
                onPressed: _busy ? null : _shareIt,
                icon: const Icon(Icons.ios_share),
                label: Text(l.quoteShare),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
