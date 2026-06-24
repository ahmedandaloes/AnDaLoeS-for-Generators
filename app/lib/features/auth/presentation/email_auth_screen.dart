import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase.dart';
import '../../../core/routing/app_routes.dart';

/// Production email front door: sign in, or create an account (with email
/// confirmation when enabled on the Supabase project). Phone OTP lives on the
/// LoginScreen; this is the path that works without an SMS provider.
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _signUpMode = false;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _friendlyAuthError(Object e) {
    if (e is AuthException) {
      final m = e.message.toLowerCase();
      if (m.contains('not confirmed')) {
        return 'Please confirm your email first — check your inbox, then sign in.';
      }
      if (m.contains('invalid login')) {
        return 'Wrong email or password.';
      }
      if (m.contains('already registered') || m.contains('already exists')) {
        return 'That email already has an account. Try signing in instead.';
      }
      return e.message;
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || !email.contains('@')) {
      _snack(l.invalidEmail);
      return;
    }
    if (password.length < 6) {
      _snack(l.passwordMinLength);
      return;
    }
    setState(() => _loading = true);
    try {
      if (_signUpMode) {
        final res =
            await supabase.auth.signUp(email: email, password: password);
        // If the project requires email confirmation, no session is returned.
        if (res.session == null) {
          _snack('Account created! Check your email to confirm, then sign in.');
          setState(() => _signUpMode = false);
        } else if (mounted) {
          context.go(AppRoutes.home);
        }
      } else {
        await supabase.auth
            .signInWithPassword(email: email, password: password);
        if (mounted) context.go(AppRoutes.home);
      }
    } catch (e) {
      _snack(_friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _guest() async {
    setState(() => _loading = true);
    try {
      await supabase.auth.signInAnonymously();
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      _snack(_friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(_signUpMode ? l.createAccount : l.loginTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          children: [
            Icon(Icons.bolt_rounded, size: 48, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              _signUpMode ? l.createYourAccount : l.welcomeBack,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _signUpMode
                  ? l.signUpEmailDesc
                  : l.signInToContinue,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l.emailLabel,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: l.passwordLabel,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility),
                  tooltip: _obscure ? l.showPassword : l.hidePassword,
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_signUpMode ? l.createAccount : l.loginTitle),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() => _signUpMode = !_signUpMode),
              child: Text(_signUpMode
                  ? 'Already have an account? Sign in'
                  : "New here? Create an account"),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: Divider(
                      color: cs.outlineVariant.withValues(alpha: 0.5))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(l.orLabel,
                    style:
                        TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              ),
              Expanded(
                  child: Divider(
                      color: cs.outlineVariant.withValues(alpha: 0.5))),
            ]),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loading ? null : _guest,
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: Text(l.browseAsGuest),
            ),
          ],
        ),
      ),
    );
  }
}
