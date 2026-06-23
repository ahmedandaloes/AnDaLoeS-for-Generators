/// Greedy best-price for a rental: combines month / week / day tiers to find
/// the lowest possible total for [days]. 1 rental day = 8 operating hours
/// (business rule). Used at request time to compute price_total.
double bestRentalPrice({
  required int days,
  required double perDay,
  double? perWeek,
  double? perMonth,
}) {
  var best = days * perDay;
  for (int m = (perMonth != null ? days ~/ 30 : 0); m >= 0; m--) {
    final afterMonths = days - m * 30;
    final baseCost = m * (perMonth ?? 0);
    for (int w = (perWeek != null ? afterMonths ~/ 7 : 0); w >= 0; w--) {
      final rem = afterMonths - w * 7;
      final c = baseCost + w * (perWeek ?? 0) + rem * perDay;
      if (c < best) best = c;
    }
    if (perMonth == null) break;
  }
  return best;
}
