import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/supabase.dart';
import 'doc_widgets.dart';

final _offerDataProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, rentalId) async {
  return await supabase
      .from('rental_requests')
      .select('''
        id, start_date, end_date, total_days, price_total, note, owner_note,
        status, created_at,
        generators(title, capacity_kva, city, governorate, fuel_type),
        companies(name, phone),
        profiles!rental_requests_customer_id_fkey(full_name, phone)
      ''')
      .eq('id', rentalId)
      .single();
});

class RentalOfferScreen extends ConsumerWidget {
  const RentalOfferScreen({super.key, required this.rentalId});
  final String rentalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_offerDataProvider(rentalId));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Rental Offer'),
        backgroundColor: Colors.grey.shade100,
        elevation: 0,
        actions: [
          dataAsync.maybeWhen(
            data: (data) => IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share as text',
              onPressed: () => _shareText(data),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) => _OfferDocument(data: data, cs: cs),
      ),
    );
  }

  void _shareText(Map<String, dynamic> data) {
    final gen = data['generators'] as Map<String, dynamic>?;
    final company = data['companies'] as Map<String, dynamic>?;
    final customer = data['profiles'] as Map<String, dynamic>?;
    final offerId = _offerId(data['id'].toString());
    final text = '''
RENTAL OFFER — $offerId
━━━━━━━━━━━━━━━━━━━━━━━━━━
FROM: ${company?['name'] ?? 'Owner'}
TO: ${customer?['full_name'] ?? 'Customer'}

GENERATOR: ${gen?['title'] ?? '-'}
CAPACITY: ${gen?['capacity_kva']} KVA
LOCATION: ${gen?['city']}, ${gen?['governorate']}

RENTAL PERIOD
From: ${_fmt(data['start_date'])}
To:   ${_fmt(data['end_date'])}
Days: ${data['total_days']}

TOTAL PRICE: EGP ${data['price_total']}

${data['owner_note'] != null && data['owner_note'].toString().isNotEmpty ? 'NOTE FROM OWNER:\n${data['owner_note']}\n' : ''}
AnDaLoeS for Generators
━━━━━━━━━━━━━━━━━━━━━━━━━━''';
    Share.share(text, subject: 'Rental Offer $offerId');
  }

  static String _offerId(String id) =>
      'OFFER-${id.substring(0, 8).toUpperCase()}';
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

class _OfferDocument extends StatelessWidget {
  const _OfferDocument({required this.data, required this.cs});
  final Map<String, dynamic> data;
  final ColorScheme cs;

  String get _offerId =>
      'OFFER-${data['id'].toString().substring(0, 8).toUpperCase()}';

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
    final gen = data['generators'] as Map<String, dynamic>?;
    final company = data['companies'] as Map<String, dynamic>?;
    final customer = data['profiles'] as Map<String, dynamic>?;
    final issueDate = _fmt(data['created_at']);
    final days = data['total_days'] ?? 0;
    final total = data['price_total'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header band ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                color: cs.primary,
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
                        color: cs.onPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.bolt,
                          color: cs.onPrimary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AnDaLoeS',
                            style: TextStyle(
                                color: cs.onPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5)),
                        Text('for Generators',
                            style: TextStyle(
                                color: cs.onPrimary.withValues(alpha: 0.7),
                                fontSize: 10)),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('RENTAL OFFER',
                            style: TextStyle(
                                color: cs.onPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.onPrimary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_offerId,
                              style: TextStyle(
                                  color: cs.onPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Text('Date issued: $issueDate',
                      style: TextStyle(
                          color: cs.onPrimary.withValues(alpha: 0.8),
                          fontSize: 11)),
                ],
              ),
            ),

            // ── From / To ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DocPartyBox(
                      label: 'FROM (Owner)',
                      name: company?['name'] ?? 'Owner',
                      detail: company?['phone']?.toString(),
                      cs: cs,
                      color: cs.primaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DocPartyBox(
                      label: 'TO (Customer)',
                      name: customer?['full_name'] ?? 'Customer',
                      detail: customer?['phone']?.toString(),
                      cs: cs,
                      color: cs.secondaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            // ── Generator details ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DocSectionLabel('Generator'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        DocRow('Model / Title',
                            gen?['title']?.toString() ?? '-'),
                        DocRow('Capacity',
                            '${gen?['capacity_kva']} KVA'),
                        DocRow('Fuel Type',
                            _fuelLabel(gen?['fuel_type']?.toString())),
                        DocRow('Location',
                            '${gen?['city'] ?? ''}, ${gen?['governorate'] ?? ''}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Rental period ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DocSectionLabel('Rental Period'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        DocRow('Start Date', _fmt(data['start_date'])),
                        DocRow('End Date', _fmt(data['end_date'])),
                        DocRow('Total Days', '$days day${days == 1 ? '' : 's'}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Pricing ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DocSectionLabel('Pricing'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: cs.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Amount',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('EGP $total',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: cs.primary,
                                  letterSpacing: -1)),
                          Text('for $days days',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Text('ACCEPTED',
                            style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8)),
                      ),
                    ]),
                  ),
                ],
              ),
            ),

            // ── Notes ────────────────────────────────────────────────────
            if (data['owner_note'] != null &&
                data['owner_note'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DocSectionLabel('Note from Owner'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.amber.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['owner_note'].toString(),
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.amber.shade900,
                                  height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ── Footer ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                children: [
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 12),
                  Text(
                    'This offer was generated by AnDaLoeS for Generators.\n'
                    'Both parties agreed to the terms upon confirmation.',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
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

  static String _fuelLabel(String? f) => switch (f) {
        'petrol' => 'Petrol',
        'gas' => 'Gas',
        'natural_gas' => 'Natural Gas',
        'solar' => 'Solar',
        _ => 'Diesel',
      };
}

