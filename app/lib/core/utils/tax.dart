/// VAT breakdown for a VAT-INCLUSIVE total (the rental price_total already
/// includes tax, matching how the invoice is computed). Splits it into the
/// pre-tax subtotal and the tax portion:
///   subtotal = total / (1 + rate),  vat = total - subtotal.
/// Showing this is transparency only — the amount payable (total) is unchanged.
({double subtotal, double vat}) vatBreakdown(double total, double rate) {
  if (rate <= 0 || total <= 0) return (subtotal: total, vat: 0);
  final subtotal = total / (1 + rate);
  return (subtotal: subtotal, vat: total - subtotal);
}

/// Whether a VAT line should be shown at BOOKING time for the given
/// tax_config.applies_when. Only when tax applies to every rental ('always').
/// 'on_invoice_request' means VAT surfaces on the invoice, not at booking.
bool vatShownAtBooking(String appliesWhen) => appliesWhen == 'always';
