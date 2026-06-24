import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

import '../../../../l10n/app_localizations.dart';

/// Referral card — generates an invite code, lets the user copy and share it.
class ProfileReferralCard extends StatelessWidget {
  const ProfileReferralCard({
    super.key,
    required this.userId,
    required this.cs,
  });

  final String userId;
  final ColorScheme cs;

  String get _code =>
      'AL-${userId.replaceAll('-', '').substring(0, 6).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final code = _code;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withValues(alpha: 0.8),
            cs.secondaryContainer.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.card_giftcard_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              l.yourReferralCode,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: cs.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(l.referralCodeCopied),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  duration: const Duration(seconds: 2),
                ));
              },
              icon: const Icon(Icons.copy_outlined, size: 18),
              tooltip: 'Copy code',
            ),
            IconButton.filled(
              onPressed: () => Share.share(
                'Join AnDaLoeS for Generators — Egypt\'s generator rental marketplace.'
                '\n\nUse my referral code $code when you sign up!',
                subject: 'AnDaLoeS Referral',
              ),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.share_outlined, size: 18),
              tooltip: 'Share',
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            'Share with friends and get rewarded when they complete their first rental.',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
