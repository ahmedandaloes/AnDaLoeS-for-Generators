import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase.dart';
import '../../../l10n/app_localizations.dart';

// Search + filter state
class _Filter {
  final String query;
  final String? governorate;
  final double? maxKva;

  const _Filter({this.query = '', this.governorate, this.maxKva});

  _Filter withQuery(String q) => _Filter(query: q, governorate: governorate, maxKva: maxKva);
  _Filter withGovernorate(String? g) => _Filter(query: query, governorate: g, maxKva: maxKva);
  _Filter withMaxKva(double? k) => _Filter(query: query, governorate: governorate, maxKva: k);
}

final _filterProvider = StateProvider<_Filter>((ref) => const _Filter());

final generatorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('generators')
      .select('id, title, capacity_kva, price_per_day, city, governorate')
      .eq('status', 'available')
      .order('created_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final allGenerators = ref.watch(generatorsProvider);
    final filter = ref.watch(_filterProvider);
    final loggedIn = supabase.auth.currentSession != null;
    final cs = Theme.of(context).colorScheme;

    // Apply client-side filter
    final generators = allGenerators.whenData((items) => items.where((g) {
      final q = filter.query.toLowerCase();
      if (q.isNotEmpty) {
        final title = (g['title'] ?? '').toString().toLowerCase();
        final city = (g['city'] ?? '').toString().toLowerCase();
        final gov = (g['governorate'] ?? '').toString().toLowerCase();
        if (!title.contains(q) && !city.contains(q) && !gov.contains(q)) {
          return false;
        }
      }
      if (filter.governorate != null &&
          filter.governorate!.isNotEmpty &&
          (g['governorate'] ?? '') != filter.governorate) {
        return false;
      }
      if (filter.maxKva != null) {
        final kva = double.tryParse(g['capacity_kva']?.toString() ?? '0') ?? 0;
        if (kva > filter.maxKva!) return false;
      }
      return true;
    }).toList());

    final hasFilter = filter.query.isNotEmpty ||
        filter.governorate != null ||
        filter.maxKva != null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Brand header ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: cs.surface,
            actions: [
              if (loggedIn) ...[
                IconButton(
                  icon: const Icon(Icons.receipt_long_outlined),
                  tooltip: 'My Rentals',
                  onPressed: () => context.push('/my-rentals'),
                ),
                IconButton(
                  icon: CircleAvatar(
                    radius: 16,
                    backgroundColor: cs.primaryContainer,
                    child: Icon(Icons.person_outline,
                        size: 18, color: cs.onPrimaryContainer),
                  ),
                  onPressed: () => context.push('/profile'),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(80, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => context.push('/login'),
                    child: Text(l.loginTitle,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.blurBackground],
              background: _HeroBanner(cs: cs, l: l),
            ),
          ),

          // ── Search bar + filter ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => ref
                          .read(_filterProvider.notifier)
                          .state = filter.withQuery(v),
                      decoration: InputDecoration(
                        hintText: 'Search generators, city…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: filter.query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => ref
                                    .read(_filterProvider.notifier)
                                    .state = filter.withQuery(''),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Badge(
                    isLabelVisible: hasFilter && filter.query.isEmpty
                        ? (filter.governorate != null || filter.maxKva != null)
                        : false,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: hasFilter
                            ? cs.primary
                            : cs.surfaceContainerHighest,
                        foregroundColor:
                            hasFilter ? cs.onPrimary : cs.onSurfaceVariant,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.tune),
                      onPressed: () =>
                          _showFilterSheet(context, ref, filter, cs),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Section title ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Text(
                    hasFilter ? 'Results' : 'Available generators',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                  ),
                  const Spacer(),
                  generators.maybeWhen(
                    data: (items) => Text(
                      '${items.length} found',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          // ── Generator list ────────────────────────────────────────────
          generators.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorState(
                  message: '$e',
                  onRetry: () => ref.invalidate(generatorsProvider)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return SliverFillRemaining(
                  child: hasFilter
                      ? _NoResultsState(
                          onClear: () => ref
                              .read(_filterProvider.notifier)
                              .state = const _Filter(),
                        )
                      : _EmptyState(l: l),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _GeneratorCard(generator: items[i], cs: cs),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(
      BuildContext context, WidgetRef ref, _Filter filter, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(filter: filter, ref: ref, cs: cs),
    );
  }
}

// ── Hero banner ──────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.cs, required this.l});
  final ColorScheme cs;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withOpacity(0.6),
            cs.secondaryContainer.withOpacity(0.3),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.bolt,
                        color: cs.onPrimary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AnDaLoeS',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l.welcomeSubtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Generator card ───────────────────────────────────────────────────────────
class _GeneratorCard extends StatelessWidget {
  const _GeneratorCard({required this.generator, required this.cs});
  final Map<String, dynamic> generator;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final location = [
      generator['city'],
      generator['governorate'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(', ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/generators/${generator['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon accent
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.bolt, color: cs.primary, size: 28),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      generator['title']?.toString() ?? '-',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Chip(
                          icon: Icons.electric_bolt,
                          label:
                              '${generator['capacity_kva']} KVA',
                          cs: cs,
                        ),
                        if (location.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _Chip(
                            icon: Icons.location_on_outlined,
                            label: location,
                            cs: cs,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${generator['price_per_day']}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'EGP/day',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.cs});
  final IconData icon;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: cs.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Empty & error states ──────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bolt, size: 40, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'No generators yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generators listed by owners will appear here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text('Something went wrong',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('No generators match',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Try adjusting your filters.',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 20),
            FilledButton.tonal(
                onPressed: onClear, child: const Text('Clear filters')),
          ],
        ),
      ),
    );
  }
}

// ── Filter sheet ──────────────────────────────────────────────────────────────
const _egyptGovernorates = [
  'Cairo', 'Giza', 'Alexandria', 'Dakahlia', 'Red Sea', 'Beheira',
  'Fayoum', 'Gharbia', 'Ismailia', 'Menofia', 'Minya', 'Qaliubiya',
  'New Valley', 'Suez', 'Aswan', 'Assiut', 'Beni Suef', 'Port Said',
  'Damietta', 'Sharqia', 'South Sinai', 'Kafr El Sheikh', 'Matrouh',
  'Luxor', 'Qena', 'North Sinai', 'Sohag',
];

class _FilterSheet extends StatefulWidget {
  const _FilterSheet(
      {required this.filter, required this.ref, required this.cs});
  final _Filter filter;
  final WidgetRef ref;
  final ColorScheme cs;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _governorate;
  late double? _maxKva;

  @override
  void initState() {
    super.initState();
    _governorate = widget.filter.governorate;
    _maxKva = widget.filter.maxKva;
  }

  void _apply() {
    widget.ref.read(_filterProvider.notifier).state =
        widget.filter.withGovernorate(_governorate).withMaxKva(_maxKva);
    Navigator.pop(context);
  }

  void _clear() {
    setState(() {
      _governorate = null;
      _maxKva = null;
    });
    widget.ref.read(_filterProvider.notifier).state =
        widget.filter.withGovernorate(null).withMaxKva(null);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Filter',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(onPressed: _clear, child: const Text('Clear all')),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Governorate',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
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
            hint: const Text('Any governorate'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Any')),
              ..._egyptGovernorates
                  .map((g) => DropdownMenuItem(value: g, child: Text(g))),
            ],
            onChanged: (v) => setState(() => _governorate = v),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Max capacity (KVA)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const Spacer(),
              Text(
                _maxKva == null ? 'Any' : '≤ ${_maxKva!.toInt()} KVA',
                style:
                    TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          Slider(
            value: _maxKva ?? 1000,
            min: 10,
            max: 1000,
            divisions: 99,
            label: _maxKva == null
                ? 'Any'
                : '${_maxKva!.toInt()} KVA',
            onChanged: (v) => setState(() => _maxKva = v),
          ),
          if (_maxKva != null && _maxKva == 1000)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _maxKva = null),
                child: const Text('Remove limit'),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _apply, child: const Text('Apply filters')),
        ],
      ),
    );
  }
}
