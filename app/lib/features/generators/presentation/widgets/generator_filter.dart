import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/generator_use_cases.dart';

// ── Sort enum ─────────────────────────────────────────────────────────────────

enum GeneratorSortBy { newest, priceLow, priceHigh, ratingTop, capacityLow }

const sortLabels = {
  GeneratorSortBy.newest: 'Newest first',
  GeneratorSortBy.priceLow: 'Price: low → high',
  GeneratorSortBy.priceHigh: 'Price: high → low',
  GeneratorSortBy.ratingTop: 'Top rated',
  GeneratorSortBy.capacityLow: 'Capacity: low → high',
};

// ── Filter model ──────────────────────────────────────────────────────────────

class GeneratorFilter {
  final String query;
  final String? governorate;
  final double? maxKva;
  final double? maxPrice;
  final String? fuelType;
  final Set<String> useCases;
  final GeneratorSortBy sort;

  const GeneratorFilter({
    this.query = '',
    this.governorate,
    this.maxKva,
    this.maxPrice,
    this.fuelType,
    this.useCases = const {},
    this.sort = GeneratorSortBy.newest,
  });

  bool get hasActiveFilters =>
      governorate != null ||
      maxKva != null ||
      maxPrice != null ||
      fuelType != null ||
      useCases.isNotEmpty;

  GeneratorFilter _copy({
    String? query,
    Object? governorate = _sentinel,
    Object? maxKva = _sentinel,
    Object? maxPrice = _sentinel,
    Object? fuelType = _sentinel,
    Set<String>? useCases,
    GeneratorSortBy? sort,
  }) =>
      GeneratorFilter(
        query: query ?? this.query,
        governorate: governorate == _sentinel
            ? this.governorate
            : governorate as String?,
        maxKva: maxKva == _sentinel ? this.maxKva : maxKva as double?,
        maxPrice: maxPrice == _sentinel ? this.maxPrice : maxPrice as double?,
        fuelType:
            fuelType == _sentinel ? this.fuelType : fuelType as String?,
        useCases: useCases ?? this.useCases,
        sort: sort ?? this.sort,
      );

  GeneratorFilter withQuery(String q) => _copy(query: q);
  GeneratorFilter withGovernorate(String? g) => _copy(governorate: g);
  GeneratorFilter withMaxKva(double? k) => _copy(maxKva: k);
  GeneratorFilter withMaxPrice(double? p) => _copy(maxPrice: p);
  GeneratorFilter withFuelType(String? f) => _copy(fuelType: f);
  GeneratorFilter withUseCases(Set<String> u) => _copy(useCases: u);
  GeneratorFilter withSort(GeneratorSortBy s) => _copy(sort: s);

  // Persisted fields only (query/search text is transient, not saved).
  Map<String, dynamic> toJson() => {
        if (governorate != null) 'gov': governorate,
        if (maxKva != null) 'kva': maxKva,
        if (maxPrice != null) 'price': maxPrice,
        if (fuelType != null) 'fuel': fuelType,
        if (useCases.isNotEmpty) 'uc': useCases.toList(),
        'sort': sort.index,
      };

  static GeneratorFilter fromJson(Map<String, dynamic> j) {
    final si = (j['sort'] as int?) ?? 0;
    return GeneratorFilter(
      governorate: j['gov'] as String?,
      maxKva: (j['kva'] as num?)?.toDouble(),
      maxPrice: (j['price'] as num?)?.toDouble(),
      fuelType: j['fuel'] as String?,
      useCases: ((j['uc'] as List?)?.cast<String>() ?? const <String>[]).toSet(),
      sort: (si >= 0 && si < GeneratorSortBy.values.length)
          ? GeneratorSortBy.values[si]
          : GeneratorSortBy.newest,
    );
  }
}

const Object _sentinel = Object();

const _filterPrefsKey = 'home_filter_v1';

/// Restores the user's last governorate/kVA/price/fuel/use-case/sort selection.
Future<GeneratorFilter> loadSavedFilter() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_filterPrefsKey);
    if (raw == null) return const GeneratorFilter();
    return GeneratorFilter.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return const GeneratorFilter();
  }
}

Future<void> saveFilter(GeneratorFilter f) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_filterPrefsKey, jsonEncode(f.toJson()));
  } catch (_) {
    // Non-blocking — persistence is best-effort.
  }
}

final filterProvider =
    StateProvider<GeneratorFilter>((ref) => const GeneratorFilter());

// ── Egypt governorates ────────────────────────────────────────────────────────

const egyptGovernorates = [
  'Cairo', 'Giza', 'Alexandria', 'Dakahlia', 'Red Sea', 'Beheira',
  'Fayoum', 'Gharbia', 'Ismailia', 'Menofia', 'Minya', 'Qaliubiya',
  'New Valley', 'Suez', 'Aswan', 'Assiut', 'Beni Suef', 'Port Said',
  'Damietta', 'Sharqia', 'South Sinai', 'Kafr El Sheikh', 'Matrouh',
  'Luxor', 'Qena', 'North Sinai', 'Sohag',
];

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.filter, required this.ref});
  final GeneratorFilter filter;
  final WidgetRef ref;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late String? _governorate;
  late double? _maxKva;
  late double? _maxPrice;
  late String? _fuelType;
  late Set<String> _useCases;

  static const _fuelOptions = [
    ('diesel', 'Diesel'),
    ('petrol', 'Petrol'),
    ('gas', 'Gas'),
    ('natural_gas', 'Natural Gas'),
    ('solar', 'Solar'),
  ];

  @override
  void initState() {
    super.initState();
    _governorate = widget.filter.governorate;
    _maxKva = widget.filter.maxKva;
    _maxPrice = widget.filter.maxPrice;
    _fuelType = widget.filter.fuelType;
    _useCases = Set<String>.from(widget.filter.useCases);
  }

  void _apply() {
    widget.ref.read(filterProvider.notifier).state = widget.filter
        .withGovernorate(_governorate)
        .withMaxKva(_maxKva)
        .withMaxPrice(_maxPrice)
        .withFuelType(_fuelType)
        .withUseCases(_useCases);
    Navigator.pop(context);
  }

  void _clear() {
    setState(() {
      _governorate = null;
      _maxKva = null;
      _maxPrice = null;
      _fuelType = null;
      _useCases = {};
    });
    widget.ref.read(filterProvider.notifier).state = widget.filter
        .withGovernorate(null)
        .withMaxKva(null)
        .withMaxPrice(null)
        .withFuelType(null)
        .withUseCases({});
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(l.filterTitle,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(onPressed: _clear, child: Text(l.clearAll)),
            ],
          ),
          const SizedBox(height: 16),
          Text(l.governorate,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _governorate,
            decoration: InputDecoration(
              filled: true,
              fillColor: cs.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
            hint: Text(l.anyGovernorate),
            items: [
              DropdownMenuItem(value: null, child: Text(l.any)),
              ...egyptGovernorates
                  .map((g) => DropdownMenuItem(value: g, child: Text(g))),
            ],
            onChanged: (v) => setState(() => _governorate = v),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Text(l.maxCapacityKva,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const Spacer(),
            Text(
              _maxKva == null ? l.any : l.maxKvaValue(_maxKva!.toInt()),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ]),
          Slider(
            value: _maxKva ?? 1000,
            min: 10,
            max: 1000,
            divisions: 99,
            label: _maxKva == null ? l.any : '${_maxKva!.toInt()} KVA',
            onChanged: (v) => setState(() => _maxKva = v),
          ),
          if (_maxKva != null && _maxKva == 1000)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _maxKva = null),
                child: Text(l.removeLimit),
              ),
            ),
          const SizedBox(height: 16),
          Row(children: [
            Text(l.maxDailyPriceEgp,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const Spacer(),
            Text(
              _maxPrice == null ? l.any : l.maxPriceValue(_maxPrice!.toInt()),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ]),
          Slider(
            value: _maxPrice ?? 5000,
            min: 100,
            max: 5000,
            divisions: 49,
            label: _maxPrice == null ? l.any : '${_maxPrice!.toInt()} EGP',
            onChanged: (v) => setState(() => _maxPrice = v < 5000 ? v : null),
          ),
          if (_maxPrice != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _maxPrice = null),
                child: Text(l.removeLimit),
              ),
            ),
          const SizedBox(height: 20),
          Text(l.fuelTypeUpper,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _fuelOptions.map((opt) {
              final (value, label) = opt;
              final selected = _fuelType == value;
              return FilterChip(
                avatar: Icon(Icons.local_gas_station_outlined,
                    size: 12,
                    color: selected
                        ? cs.onSecondaryContainer
                        : cs.onSurfaceVariant),
                label: Text(label, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (on) =>
                    setState(() => _fuelType = on ? value : null),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(l.useCaseUpper,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kGeneratorUseCases.map((uc) {
              final selected = _useCases.contains(uc);
              return FilterChip(
                label: Text(useCaseLabel(uc),
                    style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (on) => setState(() {
                  final next = Set<String>.from(_useCases);
                  if (on) {
                    next.add(uc);
                  } else {
                    next.remove(uc);
                  }
                  _useCases = next;
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _apply, child: Text(l.applyFilters)),
        ],
      ),
    );
  }
}
