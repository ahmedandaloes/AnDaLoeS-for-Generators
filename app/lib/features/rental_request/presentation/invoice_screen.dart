import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/tax.dart';
import '../../../core/widgets/app_error_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/company_info.dart';
import '../../../core/config/tax_config_provider.dart';
import '../providers/rental_providers.dart' show rentalRepositoryProvider;
import 'doc_widgets.dart';

final _invoiceDataProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, rentalId) async {
  return ref.read(rentalRepositoryProvider).fetchInvoiceById(rentalId);
});

class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({super.key, required this.rentalId});
  final String rentalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_invoiceDataProvider(rentalId));
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: AppBar(
        title: Text(l.invoice),
        backgroundColor: cs.surfaceContainerLow,
        elevation: 0,
        actions: [
          dataAsync.maybeWhen(
            data: (data) => IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share invoice',
              onPressed: () => _shareText(data),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const AppErrorState(),
        data: (data) {
          final tax = ref.watch(taxConfigProvider).valueOrNull;
          return _InvoiceDocument(
            data: data,
            cs: cs,
            taxRate: tax?.rate ?? CompanyInfo.vatRate,
            taxLabel: tax?.label ?? 'VAT',
          );
        },
      ),
    );
  }

  void _shareText(Map<String, dynamic> data) {
    final gen = data['generators'] as Map<String, dynamic>?;
    final company = data['companies'] as Map<String, dynamic>?;
    final customer = data['profiles'] as Map<String, dynamic>?;
    final invId = _invoiceId(data['id'].toString(), data['invoice_no']);
    final perDay = data['generators'] != null
        ? (data['generators'] as Map)['price_per_day'] ?? 0
        : 0;
    final days = data['total_days'] ?? 0;
    final total = data['price_total'] ?? 0;

    final text = '''
TAX INVOICE — $invId
━━━━━━━━━━━━━━━━━━━━━━━━━━
DATE: ${_fmt(data['created_at'])}

SUPPLIER: ${company?['name'] ?? 'Owner'}
CUSTOMER: ${customer?['full_name'] ?? 'Customer'}

DESCRIPTION OF SERVICE
Generator Rental — ${gen?['title'] ?? '-'}
Capacity: ${gen?['capacity_kva']} KVA
Location: ${gen?['city']}, ${gen?['governorate']}
Period: ${_fmt(data['start_date'])} → ${_fmt(data['end_date'])}
Duration: $days days × EGP $perDay/day

━━━━━━━━━━━━━━━━━━━━━━━━━━
TOTAL: EGP $total
Payment: Cash on delivery
Status: PAID ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━

AnDaLoeS for Generators''';
    Share.share(text, subject: 'Invoice $invId');
  }

  static String _invoiceId(String id, [Object? invoiceNo]) =>
      invoiceNo != null
          ? 'INV-${invoiceNo.toString().padLeft(6, '0')}'
          : 'INV-${id.substring(0, 8).toUpperCase()}';

  static String _fmt(dynamic d) {
    if (d == null) return '-';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return d.toString();
    }
  }
}

class _InvoiceDocument extends StatelessWidget {
  const _InvoiceDocument(
      {required this.data,
      required this.cs,
      this.taxRate = 0.14,
      this.taxLabel = 'VAT'});
  final double taxRate;
  final String taxLabel;
  final Map<String, dynamic> data;
  final ColorScheme cs;

  String get _invoiceId => data['invoice_no'] != null
      ? 'INV-${data['invoice_no'].toString().padLeft(6, '0')}'
      : 'INV-${data['id'].toString().substring(0, 8).toUpperCase()}';

  static String _fmt(dynamic d) {
    if (d == null) return '-';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return d.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final gen = data['generators'] as Map<String, dynamic>?;
    final company = data['companies'] as Map<String, dynamic>?;
    final customer = data['profiles'] as Map<String, dynamic>?;
    final days = data['total_days'] ?? 0;
    final total = data['price_total'] ?? 0;
    final perDay = gen?['price_per_day'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: cs.shadow.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade700,
                    Colors.green.shade500,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bolt,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AnDaLoeS',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5)),
                        Text('for Generators',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 10)),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(l.taxInvoice,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_invoiceId,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Text(l.issueDate(_fmt(data['created_at'])),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(l.paid,
                            style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ]),
                ],
              ),
            ),

            // ── Bill from / to ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DocPartyBox(
                      label: 'SUPPLIER',
                      name: company?['name'] ?? 'Owner',
                      detail: company?['phone']?.toString(),
                      cs: cs,
                      color: Colors.green.withValues(alpha: 0.15),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DocPartyBox(
                      label: 'BILLED TO',
                      name: customer?['full_name'] ?? 'Customer',
                      detail: customer?['phone']?.toString(),
                      cs: cs,
                      color: cs.secondaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            // ── Line items table ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DocSectionLabel(l.servicesRendered),
                  const SizedBox(height: 8),
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10)),
                    ),
                    child: Row(children: [
                      Expanded(
                          flex: 3,
                          child: Text(l.descriptionCol,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurfaceVariant))),
                      Expanded(
                          child: Text(l.qtyCol,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurfaceVariant))),
                      Expanded(
                          child: Text(l.rateCol,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurfaceVariant))),
                      Expanded(
                          child: Text(l.amountCol,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurfaceVariant))),
                    ]),
                  ),
                  // Item row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(10)),
                    ),
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gen?['title']?.toString() ?? l.generatorRentalItem,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                              maxLines: 2,
                            ),
                            Text(
                              '${gen?['capacity_kva']} KVA · ${gen?['city']}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '$days days',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'EGP $perDay',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'EGP $total',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),

            // ── VAT breakdown (displayed totals are VAT-inclusive) ─────────
            Builder(builder: (_) {
              final t = (total is num)
                  ? total.toDouble()
                  : double.tryParse('$total') ?? 0;
              if (t <= 0 || taxRate <= 0) return const SizedBox.shrink();
              // Displayed total is tax-inclusive — shared helper splits it.
              final b = vatBreakdown(t, taxRate);
              final tax = b.vat;
              final net = b.subtotal;
              final pctLabel =
                  (taxRate * 100).toStringAsFixed(taxRate * 100 % 1 == 0 ? 0 : 1);
              final s = TextStyle(fontSize: 12, color: cs.onSurfaceVariant);
              Widget row(String l, String r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Text(l, style: s),
                      const Spacer(),
                      Text(r, style: s),
                    ]),
                  );
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: Column(children: [
                  row(l.subtotalExcl(taxLabel),
                      'EGP ${net.toStringAsFixed(2)}'),
                  row('$taxLabel ($pctLabel%)', 'EGP ${tax.toStringAsFixed(2)}'),
                ]),
              );
            }),

            // ── Total ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.totalAmountDue,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600)),
                      Text('EGP $total',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.green.shade700,
                              letterSpacing: -1)),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(l.paymentMethod,
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade700)),
                      const SizedBox(height: 2),
                      Text(l.cashOnDelivery,
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ]),
              ),
            ),

            // ── Rental details ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DocSectionLabel(l.rentalDetails),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        DocRow(l.rentalPeriod,
                            '${_fmt(data['start_date'])} → ${_fmt(data['end_date'])}'),
                        DocRow(l.durationLabel, l.daysCount(days)),
                        DocRow(l.filterStatus, l.completedCheck),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Footer ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                children: [
                  Divider(color: cs.outlineVariant),
                  const SizedBox(height: 12),
                  if (CompanyInfo.hasTaxIds)
                    Text(
                      '${CompanyInfo.legalName} · Tax Reg. ${CompanyInfo.taxRegistrationNumber} · CR ${CompanyInfo.commercialRegister}',
                      style: TextStyle(
                          fontSize: 9.5, color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'Thank you for using AnDaLoeS for Generators.\n'
                    'This is an official tax invoice for services rendered.',
                    style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurfaceVariant,
                        height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
