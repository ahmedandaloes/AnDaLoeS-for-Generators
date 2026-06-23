import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase.dart';
import '../../../core/routing/app_routes.dart';

class PaymentConfirmationScreen extends ConsumerStatefulWidget {
  const PaymentConfirmationScreen({
    super.key,
    required this.generator,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.totalPrice,
    required this.note,
  });

  final Map<String, dynamic> generator;
  final DateTime startDate;
  final DateTime endDate;
  final int days;
  final double totalPrice;
  final String note;

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
    setState(() => _submitting = true);
    try {
      await supabase.from('rental_requests').insert({
        'customer_id': supabase.auth.currentUser!.id,
        'generator_id': widget.generator['id'],
        'company_id': widget.generator['company_id'],
        'start_date': widget.startDate.toIso8601String().substring(0, 10),
        'end_date': widget.endDate.toIso8601String().substring(0, 10),
        'total_days': widget.days,
        'price_total': widget.totalPrice,
        'rate_basis': _rateBasis(widget.days),
        'payment_method': _paymentMethod,
        'status': 'pending',
        if (widget.note.isNotEmpty) 'note': widget.note,
      });
      if (mounted) {
        _showSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
          title: const Text('Request sent!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your rental request has been sent to the owner. You\'ll be notified once they respond.',
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
                          ? 'Cash on delivery'
                          : 'Digital payment',
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
              child: const Text('View my rentals'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gen = widget.generator;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Request')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Generator summary
            _SectionLabel('Generator'),
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
            _SectionLabel('Rental dates'),
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

            // Price
            _SectionLabel('Total'),
            Card(
              color: cs.primaryContainer.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Text(
                    'EGP ${widget.totalPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Best rate',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cs.primary),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // Note
            if (widget.note.isNotEmpty) ...[
              _SectionLabel('Note to owner'),
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
            _SectionLabel('Payment method'),
            _PaymentMethodTile(
              label: 'Cash on delivery',
              subtitle: 'Pay the owner in cash when the generator arrives.',
              icon: Icons.payments_outlined,
              value: 'cash',
              groupValue: _paymentMethod,
              onChanged: (v) => setState(() => _paymentMethod = v),
            ),
            const SizedBox(height: 8),
            _PaymentMethodTile(
              label: 'Digital payment',
              subtitle: 'Vodafone Cash, InstaPay — coming soon.',
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
                      'You\'ll pay the owner directly in cash when the generator is delivered.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.amber.shade900),
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
              label: Text(_submitting ? 'Sending…' : 'Send rental request'),
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 12),
            Text(
              'The owner will review and accept or reject your request.',
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
                        'Soon',
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
