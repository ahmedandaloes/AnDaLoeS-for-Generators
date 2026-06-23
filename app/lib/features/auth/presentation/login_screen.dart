import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/routing/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;

  String get _phone {
    var p = _phoneController.text.trim();
    if (p.startsWith('0')) p = p.substring(1);
    if (!p.startsWith('+')) p = '+20$p';
    return p;
  }

  Future<void> _sendCode() async {
    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithOtp(phone: _phone);
      if (mounted) setState(() => _codeSent = true);
    } on AuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    setState(() => _loading = true);
    try {
      await supabase.auth.verifyOTP(
        phone: _phone,
        token: _codeController.text.trim(),
        type: OtpType.sms,
      );
      if (mounted) context.go(AppRoutes.home);
    } on AuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Brand header ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(28, 48, 28, 36),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primaryContainer.withValues(alpha: 0.7),
                      cs.secondaryContainer.withValues(alpha: 0.4),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => context.canPop() ? context.pop() : null,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.arrow_back_rounded,
                            size: 20, color: cs.onSurface),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child:
                          Icon(Icons.bolt, color: cs.onPrimary, size: 28),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l.welcomeTitle,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.welcomeSubtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      _codeSent ? 'Enter your code' : 'Your phone number',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneController,
                      enabled: !_codeSent,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: l.phoneHint,
                        prefixIcon: const Icon(Icons.phone_outlined),
                        prefixText: '+20 ',
                      ),
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 8,
                        ),
                        decoration: const InputDecoration(
                          hintText: '• • • • • •',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We sent a code to your phone',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading
                          ? null
                          : (_codeSent ? _verifyCode : _sendCode),
                      child: _loading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimary,
                              ),
                            )
                          : Text(
                              _codeSent ? 'Verify code' : l.sendCode),
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                  _codeSent = false;
                                  _codeController.clear();
                                }),
                        child: const Text('Change phone number'),
                      ),
                    ],
                    const SizedBox(height: 32),
                    Row(children: [
                      Expanded(
                          child: Divider(
                              color:
                                  cs.outlineVariant.withValues(alpha: 0.5))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or',
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 13)),
                      ),
                      Expanded(
                          child: Divider(
                              color:
                                  cs.outlineVariant.withValues(alpha: 0.5))),
                    ]),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => context.push(AppRoutes.devLogin),
                      child: const Text('Developer sign-in'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
