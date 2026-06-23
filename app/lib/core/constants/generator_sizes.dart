/// Standard diesel-genset capacities (kVA). Generators are sold in standard
/// sizes, so the owner forms offer a dropdown rather than free text — fewer
/// mistakes, more premium. kW is derived (kW ≈ kVA × 0.8 power factor) and shown
/// alongside so owners can pick by either unit.
const List<int> kGeneratorKvaSizes = [
  10, 15, 20, 25, 30, 40, 50, 60, 75, 100,
  125, 150, 200, 250, 300, 350, 400, 500, 625, 750,
  1000, 1250, 1500, 2000,
];

/// kW equivalent at the standard 0.8 power factor.
int kvaToKw(num kva) => (kva * 0.8).round();

/// Dropdown label showing both units, e.g. "100 kVA · 80 kW".
String generatorSizeLabel(num kva) {
  final k = kva % 1 == 0 ? kva.toInt() : kva;
  return '$k kVA · ${kvaToKw(kva)} kW';
}
