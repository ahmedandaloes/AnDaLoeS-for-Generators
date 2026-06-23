import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/supabase.dart';
import '../../../core/config/tax_config_provider.dart';

/// Egypt standard VAT rate, applied to the platform's commission (its service
/// fee) for accounting/reporting. Confirm treatment with an accountant.
const double kVatRate = 0.14;

/// Active platform commission rule (type + value).
final commissionRateProvider =
    FutureProvider.autoDispose<({String type, double value})?>((ref) async {
  final rows = await supabase
      .from('commission_config')
      .select('type, value')
      .eq('active', true)
      .isFilter('company_id', null)
      .limit(1);
  final list = (rows as List).cast<Map<String, dynamic>>();
  if (list.isEmpty) return null;
  return (
    type: list.first['type']?.toString() ?? 'percentage',
    value: (list.first['value'] as num?)?.toDouble() ?? 0,
  );
});

/// All commission rows (admin view) with company + generator context.
final adminCommissionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await supabase
      .from('commissions')
      .select(
          'id, commission_amount, status, created_at, rental_requests(companies(name), generators(title))')
      .order('created_at', ascending: false);
  return (rows as List).cast<Map<String, dynamic>>();
});

class AdminRevenueTab extends ConsumerWidget {
  const AdminRevenueTab({super.key, required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef wRef) {
    final cs = Theme.of(context).colorScheme;
    final rateAsync = wRef.watch(commissionRateProvider);
    final commsAsync = wRef.watch(adminCommissionsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        wRef.invalidate(commissionRateProvider);
        wRef.invalidate(adminCommissionsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // ── Commission rate (editable) ──────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.percent_rounded, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Platform commission',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        rateAsync.when(
                          loading: () => const Text('…'),
                          error: (_, __) => const Text('—'),
                          data: (r) => Text(
                            r == null
                                ? 'Not set'
                                : r.type == 'percentage'
                                    ? '${(r.value * 100).toStringAsFixed(r.value * 100 % 1 == 0 ? 0 : 1)}% per completed rental'
                                    : 'EGP ${r.value.toStringAsFixed(0)} per rental',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _editRate(context, wRef,
                        rateAsync.valueOrNull),
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Customer tax (editable) ─────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_outlined, color: cs.tertiary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer tax (on invoices)',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        wRef.watch(taxConfigProvider).when(
                              loading: () => const Text('…'),
                              error: (_, __) => const Text('—'),
                              data: (t) => Text(
                                '${(t.rate * 100).toStringAsFixed(t.rate * 100 % 1 == 0 ? 0 : 1)}% ${t.label}'
                                '${t.appliesWhen == 'on_invoice_request' ? ' · on invoice request' : ''}',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _editTax(
                        context, wRef, wRef.read(taxConfigProvider).valueOrNull),
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Accrued vs settled summary ──────────────────────────────
          commsAsync.maybeWhen(
            data: (rows) {
              double accrued = 0, settled = 0;
              for (final r in rows) {
                final amt =
                    (r['commission_amount'] as num?)?.toDouble() ?? 0;
                if (r['status'] == 'settled') {
                  settled += amt;
                } else {
                  accrued += amt;
                }
              }
              return Row(children: [
                Expanded(
                    child: _MoneyCard(
                        label: 'Owed to you (accrued)',
                        value: accrued,
                        color: Colors.orange.shade700,
                        cs: cs)),
                const SizedBox(width: 12),
                Expanded(
                    child: _MoneyCard(
                        label: 'Collected (settled)',
                        value: settled,
                        color: Colors.green.shade700,
                        cs: cs)),
              ]);
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),

          Row(children: [
            Text('COMMISSIONS',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: cs.onSurfaceVariant)),
            const Spacer(),
            commsAsync.maybeWhen(
              data: (rows) => rows.isEmpty
                  ? const SizedBox.shrink()
                  : TextButton.icon(
                      onPressed: () => _exportCsv(context, rows),
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('Export (VAT)'),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          ]),
          const SizedBox(height: 8),
          commsAsync.when(
            loading: () =>
                const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator())),
            error: (e, _) => Text('$e'),
            data: (rows) {
              if (rows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.payments_outlined,
                          size: 40, color: cs.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text('No commissions yet',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text('They accrue when a rental is completed.',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ]),
                  ),
                );
              }
              return Column(
                children: [
                  for (final r in rows)
                    _CommissionRow(row: r, cs: cs, onSettle: () => _settle(wRef, r)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _settle(WidgetRef wRef, Map<String, dynamic> row) async {
    await supabase
        .from('commissions')
        .update({'status': 'settled'}).eq('id', row['id']);
    wRef.invalidate(adminCommissionsProvider);
  }

  /// Exports the commission ledger with VAT for the accountant / tax filing.
  Future<void> _exportCsv(
      BuildContext context, List<Map<String, dynamic>> rows) async {
    String esc(Object? v) => '"${v?.toString().replaceAll('"', '""') ?? ''}"';
    final buf = StringBuffer(
        'Date,Company,Generator,Commission (EGP),VAT 14% (EGP),Total incl VAT (EGP),Status\n');
    double totalComm = 0, totalVat = 0;
    for (final r in rows) {
      final rr = r['rental_requests'] as Map<String, dynamic>?;
      final company = (rr?['companies'] as Map?)?['name'] ?? '';
      final gen = (rr?['generators'] as Map?)?['title'] ?? '';
      final comm = (r['commission_amount'] as num?)?.toDouble() ?? 0;
      final vat = comm * kVatRate;
      totalComm += comm;
      totalVat += vat;
      final date = r['created_at']?.toString().split('T').first ?? '';
      buf.writeln([
        esc(date),
        esc(company),
        esc(gen),
        comm.toStringAsFixed(2),
        vat.toStringAsFixed(2),
        (comm + vat).toStringAsFixed(2),
        esc(r['status']),
      ].join(','));
    }
    buf.writeln();
    buf.writeln('${esc('TOTAL commission')},,,${totalComm.toStringAsFixed(2)},${totalVat.toStringAsFixed(2)},${(totalComm + totalVat).toStringAsFixed(2)},');
    buf.writeln('${esc('VAT rate')},,,,,${(kVatRate * 100).toStringAsFixed(0)}%,');

    final now = DateTime.now();
    final label =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final file = File('${Directory.systemTemp.path}/andaloes_commission_vat_$label.csv');
    await file.writeAsString(buf.toString());
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'AnDaLoeS commission + VAT — $label',
    );
  }

  Future<void> _editRate(
      BuildContext context, WidgetRef wRef, ({String type, double value})? current) async {
    final controller = TextEditingController(
        text: current != null && current.type == 'percentage'
            ? (current.value * 100).toStringAsFixed(0)
            : '10');
    final pct = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set commission rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Percentage of each completed rental charged to the owner.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v == null || v < 0 || v > 100) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Enter a percentage between 0 and 100.')));
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (pct == null) return;
    try {
      // Deactivate the old platform default, insert the new active rate.
      await supabase
          .from('commission_config')
          .update({'active': false})
          .eq('active', true)
          .isFilter('company_id', null);
      await supabase.from('commission_config').insert({
        'company_id': null,
        'type': 'percentage',
        'value': pct / 100.0,
        'active': true,
      });
      wRef.invalidate(commissionRateProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Commission set to ${pct.toStringAsFixed(0)}%.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not update the rate. Please try again.')));
      }
    }
  }

  Future<void> _editTax(
      BuildContext context, WidgetRef wRef, TaxConfig? current) async {
    final rateC = TextEditingController(
        text: current != null
            ? (current.rate * 100).toStringAsFixed(
                current.rate * 100 % 1 == 0 ? 0 : 1)
            : '14');
    final labelC = TextEditingController(text: current?.label ?? 'VAT');
    var onInvoiceOnly = current?.appliesWhen == 'on_invoice_request';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Customer tax'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: rateC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Rate', suffixText: '%',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelC,
                decoration: const InputDecoration(
                    labelText: 'Label (e.g. VAT, Invoice tax)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Only when customer requests an invoice',
                    style: TextStyle(fontSize: 13)),
                value: onInvoiceOnly,
                onChanged: (v) => setD(() => onInvoiceOnly = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(rateC.text.trim());
                if (v == null || v < 0 || v > 100) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Enter a percentage between 0 and 100.')));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await supabase
          .from('tax_config')
          .update({'active': false}).eq('active', true);
      await supabase.from('tax_config').insert({
        'rate': (double.tryParse(rateC.text.trim()) ?? 14) / 100.0,
        'label': labelC.text.trim().isEmpty ? 'Tax' : labelC.text.trim(),
        'applies_when': onInvoiceOnly ? 'on_invoice_request' : 'always',
        'active': true,
      });
      wRef.invalidate(taxConfigProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer tax updated.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not update tax. Please try again.')));
      }
    }
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.cs});
  final String label;
  final double value;
  final Color color;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EGP ${value.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _CommissionRow extends StatelessWidget {
  const _CommissionRow(
      {required this.row, required this.cs, required this.onSettle});
  final Map<String, dynamic> row;
  final ColorScheme cs;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    final rr = row['rental_requests'] as Map<String, dynamic>?;
    final company = (rr?['companies'] as Map?)?['name']?.toString() ?? 'Company';
    final gen = (rr?['generators'] as Map?)?['title']?.toString() ?? 'Generator';
    final amount = (row['commission_amount'] as num?)?.toDouble() ?? 0;
    final settled = row['status'] == 'settled';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(company,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(gen,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('EGP ${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                if (settled)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle,
                        size: 14, color: Colors.green.shade600),
                    const SizedBox(width: 3),
                    Text('Settled',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700)),
                  ])
                else
                  SizedBox(
                    height: 30,
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          visualDensity: VisualDensity.compact),
                      onPressed: onSettle,
                      child: const Text('Mark collected',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
