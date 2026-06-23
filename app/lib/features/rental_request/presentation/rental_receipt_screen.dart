import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';

final _receiptProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, rentalId) async {
  final data = await supabase
      .from('rental_requests')
      .select(
          '*, generators(title, capacity_kva, city, governorate), '
          'profiles!customer_id(full_name, phone)')
      .eq('id', rentalId)
      .single();
  return data;
});

class RentalReceiptScreen extends ConsumerWidget {
  const RentalReceiptScreen({super.key, required this.rentalId});
  final String rentalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptAsync = ref.watch(_receiptProvider(rentalId));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rental Receipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy receipt',
            onPressed: () => receiptAsync.whenData(
                (r) => _copyReceipt(context, r)),
          ),
        ],
      ),
      body: receiptAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (r) {
          final gen = r['generators'] as Map<String, dynamic>?;
          final customer = r['profiles'] as Map<String, dynamic>?;
          final total = r['price_total'];
          final days = r['total_days'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Receipt header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primaryContainer.withValues(alpha: 0.7),
                        cs.secondaryContainer.withValues(alpha: 0.4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_rounded,
                            color: cs.onPrimary, size: 30),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Rental Completed',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Receipt #${rentalId.substring(0, 8).toUpperCase()}',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Details card
                _ReceiptCard(children: [
                  _Row('Generator',
                      gen?['title']?.toString() ?? '-'),
                  _Row('Capacity',
                      '${gen?['capacity_kva']} KVA'),
                  _Row('Location', [
                    gen?['city'],
                    gen?['governorate']
                  ].where((v) => v != null).join(', ')),
                  const Divider(height: 24),
                  _Row('Customer',
                      customer?['full_name']?.toString() ??
                          customer?['phone']?.toString() ??
                          '-'),
                  _Row('Start date',
                      r['start_date']?.toString() ?? '-'),
                  _Row('End date',
                      r['end_date']?.toString() ?? '-'),
                  _Row('Duration',
                      '$days day${days == 1 ? '' : 's'}'),
                  _Row('Rate basis',
                      r['rate_basis']?.toString() ?? '-'),
                  _Row('Payment method', 'Cash on delivery'),
                ]),
                const SizedBox(height: 16),

                // Total
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: cs.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total paid',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'EGP $total',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Note
                if (r['note'] != null &&
                    r['note'].toString().isNotEmpty) ...[
                  _ReceiptCard(children: [
                    _Row('Note to owner', r['note'].toString()),
                  ]),
                  const SizedBox(height: 16),
                ],

                // Timestamp
                Center(
                  child: Text(
                    'Completed on ${_fmt(r['updated_at']?.toString())}',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 32),

                OutlinedButton.icon(
                  onPressed: () =>
                      receiptAsync.whenData((r) => _copyReceipt(context, r)),
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('Copy receipt as text'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _copyReceipt(
      BuildContext context, Map<String, dynamic> r) {
    final gen = r['generators'] as Map<String, dynamic>?;
    final buffer = StringBuffer()
      ..writeln('AnDaLoeS for Generators — Rental Receipt')
      ..writeln('Receipt #${rentalId.substring(0, 8).toUpperCase()}')
      ..writeln()
      ..writeln('Generator: ${gen?['title']} (${gen?['capacity_kva']} KVA)')
      ..writeln('Location: ${gen?['city']}, ${gen?['governorate']}')
      ..writeln()
      ..writeln('Start: ${r['start_date']}')
      ..writeln('End:   ${r['end_date']}')
      ..writeln('Days:  ${r['total_days']}')
      ..writeln()
      ..writeln('Total: EGP ${r['price_total']}')
      ..writeln('Payment: Cash on delivery');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _fmt(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso.substring(0, 10);
    }
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
