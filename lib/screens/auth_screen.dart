import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_circle.dart';

/// تسجيل الدخول / إنشاء حساب تاجر عبر Supabase Auth (أو محليًا حين لا
/// يتوفر عميل سحابي، كما في الاختبارات).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isSubmitting = false;
  final _nameController = TextEditingController();
  final _storeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _storeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = AppStateScope.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    String? error;
    if (email.isEmpty || !email.contains('@')) {
      error = 'أدخل بريدًا إلكترونيًا صحيحًا';
    } else if (password.length < 6) {
      error = 'كلمة المرور 6 أحرف على الأقل';
    } else if (!_isLogin && _nameController.text.trim().isEmpty) {
      error = 'أدخل اسمك';
    } else if (!_isLogin && _storeController.text.trim().isEmpty) {
      error = 'أدخل اسم متجرك أو نشاطك';
    }

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    error = _isLogin
        ? await state.login(email: email, password: password)
        : await state.register(
            name: _nameController.text,
            storeName: _storeController.text,
            email: email,
            password: password,
          );
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isSubmitting = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isLogin
              ? 'مرحبًا بعودتك، ${state.account!.name}!'
              : 'تم إنشاء حسابك بنجاح، ${state.account!.name}!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'تسجيل الدخول' : 'إنشاء حساب تاجر'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const Center(
              child: IconCircle(
                icon: Icons.storefront_outlined,
                background: AppColors.navy,
                diameter: 72,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isLogin
                  ? 'سجّل دخولك لمتابعة إعلاناتك وطلباتك'
                  : 'أنشئ حساب تاجر لحفظ إعلاناتك وتتبع طلباتك',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textMuted),
            ),
            const SizedBox(height: 24),
            if (!_isLogin) ...[
              TextField(
                controller: _nameController,
                decoration: _decoration('الاسم *', 'اسمك الكامل'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _storeController,
                decoration: _decoration('اسم المتجر *', 'مثال: محمصة الفجر'),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _decoration(
                'البريد الإلكتروني *',
                'name@example.com',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: _decoration('كلمة المرور *', '6 أحرف على الأقل'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.coral,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.coral,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(_isLogin ? 'دخول' : 'إنشاء الحساب'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => setState(() {
                      _isLogin = !_isLogin;
                      _error = null;
                    }),
              child: Text(
                _isLogin
                    ? 'ليس لديك حساب؟ أنشئ حسابًا جديدًا'
                    : 'لديك حساب بالفعل؟ سجّل دخولك',
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: context.cardBg,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}
