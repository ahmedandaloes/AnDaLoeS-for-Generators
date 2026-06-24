import 'package:flutter/material.dart';

/// Single source of truth for rental-status and quality colors, so status
/// chips read as one consistent system everywhere (My Rentals, owner request
/// cards, admin) instead of duplicated local mappings.
Color rentalStatusColor(String status, ColorScheme cs) => switch (status) {
      'pending' => Colors.orange.shade700,
      'accepted' => Colors.green.shade600,
      'active' => cs.primary,
      'completed' => Colors.green.shade700,
      'rejected' => cs.error,
      'cancelled' => cs.onSurfaceVariant,
      _ => cs.onSurfaceVariant,
    };

/// A 0–100 quality rate (acceptance / on-time) → green / amber / red.
Color qualityColor(num pct) => pct >= 80
    ? Colors.green.shade700
    : pct >= 50
        ? Colors.orange.shade800
        : Colors.red.shade700;
