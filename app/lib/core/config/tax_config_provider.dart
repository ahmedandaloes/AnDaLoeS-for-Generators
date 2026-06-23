import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase.dart';

/// Configurable customer tax (rate, display label, and when it applies).
typedef TaxConfig = ({double rate, String label, String appliesWhen});

/// The active tax configuration (admin-editable via tax_config). Public read.
final taxConfigProvider = FutureProvider.autoDispose<TaxConfig>((ref) async {
  final rows = await supabase
      .from('tax_config')
      .select('rate, label, applies_when')
      .eq('active', true)
      .limit(1);
  final list = (rows as List).cast<Map<String, dynamic>>();
  if (list.isEmpty) {
    return (rate: 0.14, label: 'VAT', appliesWhen: 'always');
  }
  final r = list.first;
  return (
    rate: (r['rate'] as num?)?.toDouble() ?? 0.14,
    label: r['label']?.toString() ?? 'VAT',
    appliesWhen: r['applies_when']?.toString() ?? 'always',
  );
});
