/// Pure helpers for projecting the platform commission BEFORE a rental
/// completes. After completion the exact amount is stored on the `commissions`
/// row by the handle_rental_completion DB trigger; this projects it for preview
/// (e.g. showing an owner their net payout when reviewing a request).

/// Active commission rule. `type` is 'percentage' (value e.g. 0.10 = 10%) or
/// 'fixed' (value in EGP).
typedef CommissionRule = ({String type, double value});

/// Given a rental total and the active rule, returns the projected commission,
/// the owner's net payout, and a short human label for the fee.
({double commission, double net, String label}) projectCommission(
  num total,
  CommissionRule? rule,
) {
  final t = total.toDouble();
  if (rule == null) return (commission: 0, net: t, label: '');
  final raw = rule.type == 'percentage' ? t * rule.value : rule.value;
  final commission = raw.clamp(0, t).toDouble();
  final label = rule.type == 'percentage'
      ? '${(rule.value * 100).round()}% platform fee'
      : 'EGP ${rule.value.toStringAsFixed(0)} platform fee';
  return (commission: commission, net: t - commission, label: label);
}
