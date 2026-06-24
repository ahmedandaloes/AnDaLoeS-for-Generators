import 'package:flutter/material.dart';

enum SnackVariant { success, error, info }

class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    SnackVariant variant = SnackVariant.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (variant) {
      SnackVariant.success => (cs.primaryContainer, cs.onPrimaryContainer),
      SnackVariant.error => (cs.errorContainer, cs.onErrorContainer),
      SnackVariant.info => (cs.surfaceContainerHighest, cs.onSurface),
    };
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: fg)),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: duration,
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, variant: SnackVariant.success);

  static void error(BuildContext context, String message) =>
      show(context, message, variant: SnackVariant.error);
}
