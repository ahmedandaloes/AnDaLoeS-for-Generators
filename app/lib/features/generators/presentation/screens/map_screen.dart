import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/app_error_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/supabase.dart';
import '../../../../core/routing/app_routes.dart';

// Approximate center coordinates for Egyptian governorates
const _govCoords = <String, LatLng>{
  'Cairo': LatLng(30.0444, 31.2357),
  'Giza': LatLng(30.0131, 31.2089),
  'Alexandria': LatLng(31.2001, 29.9187),
  'Sharqia': LatLng(30.7374, 31.7217),
  'Dakahlia': LatLng(31.1656, 31.4913),
  'Beheira': LatLng(30.8480, 30.3436),
  'Qalyubia': LatLng(30.3292, 31.2169),
  'Monufia': LatLng(30.5966, 30.9876),
  'Gharbia': LatLng(30.8754, 31.0344),
  'Kafr el-Sheikh': LatLng(31.1107, 30.9388),
  'Damietta': LatLng(31.4165, 31.8133),
  'Ismailia': LatLng(30.5965, 32.2715),
  'Port Said': LatLng(31.2653, 32.3019),
  'Suez': LatLng(29.9668, 32.5498),
  'North Sinai': LatLng(30.2832, 33.6116),
  'South Sinai': LatLng(28.9590, 33.5938),
  'Red Sea': LatLng(27.2579, 33.8116),
  'Matrouh': LatLng(31.3543, 27.2373),
  'Fayyum': LatLng(29.3084, 30.8428),
  'Beni Suef': LatLng(29.0661, 31.0994),
  'Minya': LatLng(28.1099, 30.7503),
  'Asyut': LatLng(27.1809, 31.1837),
  'Sohag': LatLng(26.5591, 31.6957),
  'Qena': LatLng(26.1551, 32.7160),
  'Luxor': LatLng(25.6872, 32.6396),
  'Aswan': LatLng(24.0889, 32.8998),
  'New Valley': LatLng(25.4481, 29.2077),
};

final _mapGeneratorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('generators')
      .select(
          'id, title, capacity_kva, price_per_day, city, governorate, photos, avg_score, status')
      .eq('status', 'available')
      .order('avg_score', ascending: false)
      .limit(200);
  return (data as List).cast<Map<String, dynamic>>();
});

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  Map<String, dynamic>? _selected;

  static const _egypt = LatLng(26.8206, 30.8025);

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  LatLng _coordsFor(Map<String, dynamic> gen) {
    final gov = gen['governorate']?.toString() ?? '';
    final city = gen['city']?.toString() ?? '';
    return _govCoords[gov] ??
        _govCoords[city] ??
        const LatLng(30.0444, 31.2357); // Default: Cairo
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final generatorsAsync = ref.watch(_mapGeneratorsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l.generatorMap),
        backgroundColor: cs.surface.withValues(alpha: 0.92),
        elevation: 0,
      ),
      body: generatorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const AppErrorState(),
        data: (generators) {
          // Group by governorate to count
          final byGov = <String, List<Map<String, dynamic>>>{};
          for (final g in generators) {
            final key = g['governorate']?.toString() ?? 'Other';
            byGov.putIfAbsent(key, () => []).add(g);
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _egypt,
                  initialZoom: 6.0,
                  onTap: (_, __) => setState(() => _selected = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.andaloes.generators',
                  ),
                  MarkerLayer(
                    markers: generators.map((g) {
                      final coords = _coordsFor(g);
                      final isSelected = _selected?['id'] == g['id'];
                      return Marker(
                        point: coords,
                        width: isSelected ? 48 : 36,
                        height: isSelected ? 48 : 36,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selected = g);
                            _mapController.move(coords, 10.0);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isSelected ? cs.primary : cs.primaryContainer,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.35),
                                  blurRadius: isSelected ? 12 : 4,
                                  spreadRadius: isSelected ? 2 : 0,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.bolt,
                              size: isSelected ? 26 : 20,
                              color: isSelected ? cs.onPrimary : cs.primary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // Count badge bottom-left
              Positioned(
                bottom: _selected != null ? 200 : 16,
                left: 16,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    key: ValueKey(generators.length),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: cs.shadow.withValues(alpha: 0.1),
                            blurRadius: 8),
                      ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bolt, size: 14, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${generators.length} generators',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface),
                      ),
                    ]),
                  ),
                ),
              ),

              // Re-center button
              Positioned(
                bottom: _selected != null ? 200 : 16,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'recenter',
                  backgroundColor: cs.surface,
                  foregroundColor: cs.primary,
                  onPressed: () =>
                      _mapController.move(_egypt, 6.0),
                  child: const Icon(Icons.my_location_outlined),
                ),
              ),

              // Selected generator card
              if (_selected != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _GeneratorMapCard(
                    generator: _selected!,
                    cs: cs,
                    onClose: () => setState(() => _selected = null),
                    onView: () => context.push(AppRoutes.generatorDetail(_selected!['id'].toString())),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GeneratorMapCard extends StatelessWidget {
  const _GeneratorMapCard({
    required this.generator,
    required this.cs,
    required this.onClose,
    required this.onView,
  });
  final Map<String, dynamic> generator;
  final ColorScheme cs;
  final VoidCallback onClose;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final photo = (generator['photos'] as List?)?.isNotEmpty == true
        ? generator['photos'][0].toString()
        : null;
    final score = (generator['avg_score'] as num?)?.toStringAsFixed(1) ?? '–';
    final location = [
      generator['city']?.toString(),
      generator['governorate']?.toString(),
    ].where((v) => v != null && v.isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: cs.shadow.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(children: [
              // Photo
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: photo != null
                    ? Image.network(photo,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(cs))
                    : _placeholder(cs),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      generator['title']?.toString() ?? 'Generator',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(location,
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${generator['capacity_kva']} KVA',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: cs.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.star_rounded,
                          size: 14, color: Colors.amber.shade600),
                      const SizedBox(width: 2),
                      Text(score,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        'EGP ${generator['price_per_day']}/day',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.primary),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onClose,
                tooltip: l.close,
                icon: const Icon(Icons.close),
                iconSize: 18,
                style: IconButton.styleFrom(
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton.icon(
              onPressed: onView,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(l.viewDetails),
              style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      width: 72,
      height: 72,
      color: cs.primaryContainer,
      child: Icon(Icons.bolt, size: 32, color: cs.primary),
    );
  }
}
