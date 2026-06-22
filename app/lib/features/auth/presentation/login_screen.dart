import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase.dart';
import '../../../l10n/app_localizations.dart';

/// Phone + OTP sign-in. Step 1: send code. Step 2: verify code.
/// Requires the Phone auth provider + an SMS gateway enabled in Supabase.
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

  /// Supabase expects E.164 (e.g. +20...). Convert a local Egyptian number.
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
      // On success, the router redirect sends the user home.
    } on AuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
    return Scaffold(
      appBar: AppBar(title: Text(l.loginTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(l.welcomeTitle,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(l.welcomeSubtitle,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 32),
            TextField(
              controller: _phoneController,
              enabled: !_codeSent,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l.phoneLabel,
                hintText: l.phoneHint,
                prefixIcon: const Icon(Icons.phone),
              ),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'OTP',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading
                  ? null
                  : (_codeSent ? _verifyCode : _sendCode),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_codeSent ? 'Verify' : l.sendCode),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/dev-login'),
              child: const Text('Developer sign-in (email)'),
            ),
          ],
        ),
      ),
    );
  }
}
