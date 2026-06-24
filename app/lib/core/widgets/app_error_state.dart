import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Friendly, branded error state with an optional Retry — replaces bare
/// `Center(child: Text('$e'))` across screens so failures never leak raw
/// exceptions and always look premium. Localized (en + ar/RTL).
class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              message ?? l.errorGeneric,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              l.errorConnection,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l.tryAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
