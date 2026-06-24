import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'providers/rental_providers.dart' show rentalRepositoryProvider;

final _receiptProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, rentalId) async {
  return ref.read(rentalRepositoryProvider).fetchReceiptById(rentalId);
});

class RentalReceiptScreen extends ConsumerStatefulWidget {
  const RentalReceiptScreen({super.key, required this.rentalId});
  final String rentalId;

  @override
  ConsumerState<RentalReceiptScreen> createState() =>
      _RentalReceiptScreenState();
}

class _RentalReceiptScreenState extends ConsumerState<RentalReceiptScreen> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareAsImage(BuildContext context) async {
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    setState(() => _sharing = true);
    try {
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/receipt_${widget.rentalId.substring(0, 8)}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'Rental Receipt',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receiptAsync = ref.watch(_receiptProvider(widget.rentalId));
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.rentalReceipt),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: l.copyReceipt,
            onPressed: () => receiptAsync.whenData(
                (r) => _copyReceipt(context, r)),
          ),
          receiptAsync.maybeWhen(
            data: (_) => _sharing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child:
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: l.shareAsImage,
                    onPressed: () => _shareAsImage(context),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: receiptAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const AppErrorState(),
        data: (r) {
          // A paid receipt only exists for a completed rental.
          if (r['status']?.toString() != 'completed') {
            final cs = Theme.of(context).colorScheme;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 48, color: cs.onSurfaceVariant),
                    const SizedBox(height: 14),
                    Text(
                      l.receiptAvailableWhenCompleted,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }
          final gen = r['generators'] as Map<String, dynamic>?;
          final customer = r['profiles'] as Map<String, dynamic>?;
          final total = r['price_total'];
          final days = r['total_days'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: RepaintBoundary(
              key: _cardKey,
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
                      Text(
                        l.rentalCompletedTitle,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.receiptNumber(
                            widget.rentalId.substring(0, 8).toUpperCase()),
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Details card
                _ReceiptCard(children: [
                  _Row(l.generatorLabel,
                      gen?['title']?.toString() ?? '-'),
                  _Row(l.capacity,
                      '${gen?['capacity_kva']} KVA'),
                  _Row(l.location, [
                    gen?['city'],
                    gen?['governorate']
                  ].where((v) => v != null).join(', ')),
                  const Divider(height: 24),
                  _Row(l.customer,
                      customer?['full_name']?.toString() ??
                          customer?['phone']?.toString() ??
                          '-'),
                  _Row(l.startDate,
                      r['start_date']?.toString() ?? '-'),
                  _Row(l.endDate,
                      r['end_date']?.toString() ?? '-'),
                  _Row(l.durationLabel, l.daysCount(days)),
                  _Row(l.rateBasis,
                      r['rate_basis']?.toString() ?? '-'),
                  _Row(l.paymentMethod, l.cashOnDelivery),
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
                      Text(
                        l.totalPaid,
                        style: const TextStyle(
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
                    _Row(l.noteToOwnerShort, r['note'].toString()),
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
                  label: Text(l.copyReceiptText),
                ),
              ],
            ),
            ), // RepaintBoundary
          );
        },
      ),
    );
  }

  void _copyReceipt(
      BuildContext context, Map<String, dynamic> r) {
    final l = AppLocalizations.of(context)!;
    final gen = r['generators'] as Map<String, dynamic>?;
    final buffer = StringBuffer()
      ..writeln('AnDaLoeS for Generators — Rental Receipt')
      ..writeln('Receipt #${widget.rentalId.substring(0, 8).toUpperCase()}')
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
      SnackBar(
        content: Text(l.receiptCopied),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
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
