import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/tax_config_provider.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/db_error.dart';
import '../../../core/utils/tax.dart';
import '../../../l10n/app_localizations.dart';
import 'providers/rental_providers.dart' show rentalRepositoryProvider;

class PaymentConfirmationScreen extends ConsumerStatefulWidget {
  const PaymentConfirmationScreen({
    super.key,
    required this.generator,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.totalPrice,
    required this.note,
    this.deliveryAddress = '',
    this.deliveryTime = 'Flexible',
  });

  final Map<String, dynamic> generator;
  final DateTime startDate;
  final DateTime endDate;
  final int days;
  final double totalPrice;
  final String note;
  final String deliveryAddress;
  final String deliveryTime;

  @override
  ConsumerState<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState
    extends ConsumerState<PaymentConfirmationScreen> {
  String _paymentMethod = 'cash';
  bool _submitting = false;

  Future<void> _confirm() async {
    HapticFeedback.mediumImpact();
    // Guests who browsed the form without signing in are redirected here.
    final repo = ref.read(rentalRepositoryProvider);
    final uid = repo.currentUserId;
    if (uid == null || repo.isCurrentUserAnonymous) {
      if (mounted) context.push(AppRoutes.login);
      return;
    }
    setState(() => _submitting = true);
    try {
      await repo.insertRentalRequest({
        'customer_id': uid,
        'generator_id': widget.generator['id'],
        'company_id': widget.generator['company_id'],
        'start_date': widget.startDate.toIso8601String().substring(0, 10),
        'end_date': widget.endDate.toIso8601String().substring(0, 10),
        'total_days': widget.days,
        'price_total': widget.totalPrice,
        'rate_basis': _rateBasis(widget.days),
        'payment_method': _paymentMethod,
        'deposit_amount':
            (widget.generator['deposit_amount'] as num?)?.toDouble() ?? 0,
        'status': 'pending',
        if (widget.note.isNotEmpty) 'note': widget.note,
        if (widget.deliveryAddress.isNotEmpty)
          'delivery_address': widget.deliveryAddress,
        if (widget.deliveryTime.isNotEmpty && widget.deliveryTime != 'Flexible')
          'delivery_time': widget.deliveryTime,
      });
      if (mounted) {
        _showSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyDbError(e,
                fallback: 'Could not send your request. Please try again.')),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _submitting = false);
      }
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        final cs = Theme.of(context).colorScheme;
        final l = AppLocalizations.of(context)!;
        return AlertDialog(
          icon: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 40),
          ),
          title: Text(l.requestSent,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.requestSentBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.payments_outlined,
                        size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      _paymentMethod == 'cash'
                          ? l.cashOnDelivery
                          : l.digitalPayment,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.go(AppRoutes.myRentals);
              },
              child: Text(l.viewMyRentals),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final tax = ref.watch(taxConfigProvider).valueOrNull;
    final gen = widget.generator;
    String dtLabel(String v) => switch (v) {
          'Morning' => l.deliveryMorning,
          'Afternoon' => l.deliveryAfternoon,
          'Evening' => l.deliveryEvening,
          _ => l.deliveryFlexible,
        };

    return Scaffold(
      appBar: AppBar(title: Text(l.confirmRequest)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Generator summary
            _SectionLabel(l.generatorLabel),
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.bolt, color: cs.primary, size: 24),
                ),
                title: Text(gen['title']?.toString() ?? 'Generator',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${gen['capacity_kva']} KVA  •  '
                  '${[gen['city'], gen['governorate']].where((v) => v != null).join(', ')}',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Rental dates
            _SectionLabel(l.rentalDates),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 18, color: cs.primary),
                      const SizedBox(width: 10),
                      Text(
                        '${_fmt(widget.startDate)}  →  ${_fmt(widget.endDate)}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.access_time_outlined,
                          size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Text(
                        '${widget.days} day${widget.days == 1 ? '' : 's'}  ·  8 hrs/day',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Itemized payment summary (transparency = our differentiator)
            _SectionLabel(l.paymentSummary),
            Builder(builder: (_) {
              final deposit =
                  (widget.generator['deposit_amount'] as num?)?.toDouble() ?? 0;
              final rental = widget.totalPrice;
              final grand = rental + deposit;
              Widget line(String l, String r,
                  {bool bold = false, Color? color, String? sub}) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(l,
                              style: TextStyle(
                                  fontSize: bold ? 15 : 13,
                                  fontWeight: bold
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: color ?? cs.onSurface)),
                        ),
                        Text(r,
                            style: TextStyle(
                                fontSize: bold ? 20 : 14,
                                fontWeight: bold
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                color: color ?? cs.onSurface)),
                      ]),
                      if (sub != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(sub,
                              style: TextStyle(
                                  fontSize: 11, color: cs.onSurfaceVariant)),
                        ),
                    ],
                  ),
                );
              }

              return Card(
                color: cs.primaryContainer.withValues(alpha: 0.4),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    line(
                        l.rentalDaysLine(widget.days),
                        'EGP ${rental.toStringAsFixed(0)}',
                        sub: l.bestRateApplied),
                    // VAT breakdown (transparency; total unchanged) — only when
                    // tax applies at booking. price_total is VAT-inclusive.
                    if (tax != null &&
                        tax.rate > 0 &&
                        vatShownAtBooking(tax.appliesWhen)) ...[
                      line(l.subtotalExcl(tax.label),
                          'EGP ${vatBreakdown(rental, tax.rate).subtotal.toStringAsFixed(0)}'),
                      line(
                          '${tax.label} (${(tax.rate * 100).toStringAsFixed(tax.rate * 100 % 1 == 0 ? 0 : 1)}%)',
                          'EGP ${vatBreakdown(rental, tax.rate).vat.toStringAsFixed(0)}'),
                    ],
                    if (deposit > 0)
                      line(l.refundableDeposit,
                          'EGP ${deposit.toStringAsFixed(0)}',
                          sub:
                              l.depositReturnNote),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Divider(
                          height: 1,
                          color: cs.primary.withValues(alpha: 0.2)),
                    ),
                    line(l.totalPayableOnDelivery,
                        'EGP ${grand.toStringAsFixed(0)}',
                        bold: true, color: cs.primary),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 16),

            // Delivery details
            if (widget.deliveryAddress.isNotEmpty ||
                (widget.deliveryTime.isNotEmpty &&
                    widget.deliveryTime != 'Flexible')) ...[
              _SectionLabel(l.deliveryLabel),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.deliveryAddress.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 16, color: cs.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(widget.deliveryAddress,
                                  style: const TextStyle(fontSize: 14)),
                            ),
                          ],
                        ),
                      if (widget.deliveryTime.isNotEmpty &&
                          widget.deliveryTime != 'Flexible') ...[
                        if (widget.deliveryAddress.isNotEmpty)
                          const SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.schedule,
                              size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(l.preferredTimeLabel(dtLabel(widget.deliveryTime)),
                              style: const TextStyle(fontSize: 14)),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Note
            if (widget.note.isNotEmpty) ...[
              _SectionLabel(l.noteToOwnerShort),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes, size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(widget.note,
                            style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Payment method
            _SectionLabel(l.paymentMethod),
            _PaymentMethodTile(
              label: l.cashOnDelivery,
              subtitle: l.codSubtitle,
              icon: Icons.payments_outlined,
              value: 'cash',
              groupValue: _paymentMethod,
              onChanged: (v) => setState(() => _paymentMethod = v),
            ),
            const SizedBox(height: 8),
            _PaymentMethodTile(
              label: l.digitalPayment,
              subtitle: l.digitalSubtitle,
              icon: Icons.phone_android_outlined,
              value: 'digital',
              groupValue: _paymentMethod,
              onChanged: null,
              comingSoon: true,
            ),
            const SizedBox(height: 28),

            // COD info banner
            if (_paymentMethod == 'cash')
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.amber.shade300.withValues(alpha: 0.6)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      size: 18, color: Colors.amber.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.codBannerText,
                      style: TextStyle(
                          fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ]),
              ),

            // Cancellation policy (clarity up front)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.event_busy_outlined,
                    size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.cancellationPolicy,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
              ]),
            ),

            // Confirm button
            FilledButton.icon(
              onPressed: _submitting ? null : _confirm,
              icon: _submitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_submitting ? l.sending : l.sendRentalRequest),
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 12),
            Text(
              l.reviewNote,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  static String _rateBasis(int days) {
    if (days >= 30) return 'month';
    if (days >= 7) return 'week';
    return 'day';
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.comingSoon = false,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final String value;
  final String groupValue;
  final void Function(String)? onChanged;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final selected = value == groupValue && !comingSoon;
    return GestureDetector(
      onTap: comingSoon ? null : () => onChanged?.call(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? cs.primaryContainer.withValues(alpha: 0.5)
              : comingSoon
                  ? cs.surfaceContainerLowest
                  : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: comingSoon
                  ? cs.surfaceContainerHighest
                  : selected
                      ? cs.primary
                      : cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: comingSoon
                  ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                  : selected
                      ? cs.onPrimary
                      : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: comingSoon
                          ? cs.onSurface.withValues(alpha: 0.4)
                          : cs.onSurface,
                    ),
                  ),
                  if (comingSoon) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l.soon,
                        style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: comingSoon
                        ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                        : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!comingSoon)
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) => onChanged?.call(v!),
              activeColor: cs.primary,
            ),
        ]),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
