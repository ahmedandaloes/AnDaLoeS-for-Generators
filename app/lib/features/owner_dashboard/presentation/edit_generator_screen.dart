import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/app_error_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../core/config/supabase.dart';
import '../../../core/constants/generator_sizes.dart';
import '../../../core/constants/generator_use_cases.dart';

const _editGovernorates = [
  'Cairo', 'Giza', 'Alexandria', 'Dakahlia', 'Red Sea', 'Beheira',
  'Fayoum', 'Gharbia', 'Ismailia', 'Menofia', 'Minya', 'Qaliubiya',
  'New Valley', 'Suez', 'Aswan', 'Assiut', 'Beni Suef', 'Port Said',
  'Damietta', 'Sharqia', 'South Sinai', 'Kafr El Sheikh', 'Matrouh',
  'Luxor', 'Qena', 'North Sinai', 'Sohag',
];

final _editGeneratorProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, id) async {
  final data = await supabase
      .from('generators')
      .select('*')
      .eq('id', id)
      .single();
  return data;
});

class EditGeneratorScreen extends ConsumerStatefulWidget {
  const EditGeneratorScreen({super.key, required this.generatorId});
  final String generatorId;

  @override
  ConsumerState<EditGeneratorScreen> createState() =>
      _EditGeneratorScreenState();
}

class _EditGeneratorScreenState
    extends ConsumerState<EditGeneratorScreen> {
  final _titleController = TextEditingController();
  final _capacityController = TextEditingController();
  final _descController = TextEditingController();
  final _pricePerDayController = TextEditingController();
  final _pricePerWeekController = TextEditingController();
  final _pricePerMonthController = TextEditingController();
  final _depositController = TextEditingController();
  final _cityController = TextEditingController();

  String? _governorate;
  String _fuelType = 'diesel';
  String _hireType = 'dry_hire';
  String _fuelPolicy = 'customer_provides';
  final Set<String> _useCases = {};
  final Set<String> _accessories = {};
  bool _available = true;
  bool _initialised = false;
  bool _saving = false;

  // Existing remote photo URLs (from DB)
  List<String> _existingPhotos = [];
  // New local photos to upload
  final List<File> _newPhotos = [];
  // Which existing photos to remove
  final Set<String> _removedPhotos = {};

  static const _maxPhotos = 5;
  String? _companyId;

  @override
  void dispose() {
    _titleController.dispose();
    _capacityController.dispose();
    _descController.dispose();
    _pricePerDayController.dispose();
    _pricePerWeekController.dispose();
    _pricePerMonthController.dispose();
    _depositController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _initFrom(Map<String, dynamic> gen) {
    if (_initialised) return;
    _titleController.text = gen['title']?.toString() ?? '';
    _capacityController.text = gen['capacity_kva']?.toString() ?? '';
    _descController.text = gen['description']?.toString() ?? '';
    _pricePerDayController.text = gen['price_per_day']?.toString() ?? '';
    _pricePerWeekController.text = gen['price_per_week']?.toString() ?? '';
    _pricePerMonthController.text = gen['price_per_month']?.toString() ?? '';
    final dep = (gen['deposit_amount'] as num?)?.toDouble() ?? 0;
    _depositController.text = dep > 0 ? dep.toStringAsFixed(0) : '';
    _cityController.text = gen['city']?.toString() ?? '';
    _governorate = gen['governorate']?.toString();
    _fuelType = gen['fuel_type']?.toString() ?? 'diesel';
    _hireType = gen['hire_type']?.toString() ?? 'dry_hire';
    _fuelPolicy = gen['fuel_policy']?.toString() ?? 'customer_provides';
    _useCases
      ..clear()
      ..addAll((gen['use_cases'] as List?)?.cast<String>() ?? const []);
    _accessories
      ..clear()
      ..addAll(
          (gen['accessories'] as List?)?.cast<String>() ?? const []);
    _available = gen['status']?.toString() == 'available';
    _existingPhotos =
        (gen['photos'] as List?)?.cast<String>().toList() ?? [];
    _companyId = gen['company_id']?.toString();
    _initialised = true;
  }

  Future<void> _pickPhoto() async {
    final l = AppLocalizations.of(context)!;
    final total = (_existingPhotos.length - _removedPhotos.length) +
        _newPhotos.length;
    if (total >= _maxPhotos) {
      _snack(l.maxPhotosAllowed(_maxPhotos));
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;
      setState(() => _newPhotos.add(File(path)));
    } catch (e) {
      _snack(l.photoPickerError);
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    final capacityStr = _capacityController.text.trim();
    final priceStr = _pricePerDayController.text.trim();

    if (title.isEmpty || capacityStr.isEmpty || priceStr.isEmpty) {
      _snack(l.requiredFieldsGenerator);
      return;
    }

    setState(() => _saving = true);
    try {
      // 1 — upload new photos
      final ts = DateTime.now().millisecondsSinceEpoch;
      final newUrls = <String>[];
      for (var i = 0; i < _newPhotos.length; i++) {
        final file = _newPhotos[i];
        final ext = file.path.split('.').last.toLowerCase();
        final remotePath =
            '$_companyId/${widget.generatorId}/${ts}_$i.$ext';
        await supabase.storage.from('generator-photos').upload(
              remotePath,
              file,
              fileOptions: const FileOptions(upsert: true),
            );
        final url = supabase.storage
            .from('generator-photos')
            .getPublicUrl(remotePath);
        newUrls.add(url);
      }

      // 2 — build final photos list
      final finalPhotos = [
        ..._existingPhotos.where((u) => !_removedPhotos.contains(u)),
        ...newUrls,
      ];

      // 3 — update generator
      await supabase.from('generators').update({
        'title': title,
        'capacity_kva': double.parse(capacityStr),
        'price_per_day': double.parse(priceStr),
        'deposit_amount':
            double.tryParse(_depositController.text.trim()) ?? 0,
        'price_per_week': _pricePerWeekController.text.trim().isNotEmpty
            ? double.parse(_pricePerWeekController.text.trim())
            : null,
        'price_per_month': _pricePerMonthController.text.trim().isNotEmpty
            ? double.parse(_pricePerMonthController.text.trim())
            : null,
        'description': _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        'city': _cityController.text.trim().isNotEmpty
            ? _cityController.text.trim()
            : null,
        'governorate': _governorate,
        'fuel_type': _fuelType,
        'hire_type': _hireType,
        'fuel_policy': _fuelPolicy,
        'accessories': _accessories.toList(),
        'use_cases': _useCases.toList(),
        'status': _available ? 'available' : 'unavailable',
        'photos': finalPhotos,
      }).eq('id', widget.generatorId);

      if (mounted) {
        _snack(l.generatorUpdated);
        context.pop();
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _accChip(String key, String label) => FilterChip(
        label: Text(label),
        selected: _accessories.contains(key),
        onSelected: (on) => setState(() {
          if (on) {
            _accessories.add(key);
          } else {
            _accessories.remove(key);
          }
        }),
      );

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final genAsync =
        ref.watch(_editGeneratorProvider(widget.generatorId));
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.editGenerator)),
      body: genAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const AppErrorState(),
        data: (gen) {
          _initFrom(gen);
          final keptExisting = _existingPhotos
              .where((u) => !_removedPhotos.contains(u))
              .toList();
          final totalPhotos =
              keptExisting.length + _newPhotos.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Availability toggle ────────────────────────────────
                Card(
                  child: SwitchListTile(
                    value: _available,
                    onChanged: (v) => setState(() => _available = v),
                    title: Text(
                      _available ? 'Available for rent' : 'Unavailable',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _available ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                    subtitle: Text(
                      _available
                          ? 'Customers can see and request this generator'
                          : 'Hidden from customers until you re-enable',
                      style: const TextStyle(fontSize: 12),
                    ),
                    secondary: Icon(
                      _available
                          ? Icons.bolt
                          : Icons.bolt_outlined,
                      color: _available ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Photos ─────────────────────────────────────────────
                _Section(l.photosLabel),
                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      if (totalPhotos < _maxPhotos)
                        _EditPhotoAddButton(onTap: _pickPhoto, cs: cs),
                      // Existing network photos
                      ...keptExisting.map((url) => _NetworkPhotoThumb(
                            url: url,
                            onRemove: () =>
                                setState(() => _removedPhotos.add(url)),
                          )),
                      // New local photos
                      ..._newPhotos.asMap().entries.map(
                            (e) => _LocalPhotoThumb(
                              file: e.value,
                              onRemove: () =>
                                  setState(() => _newPhotos.removeAt(e.key)),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Basic info ─────────────────────────────────────────
                _Section(l.basicInfo),
                _EditField('Title *', 'e.g. Cummins 100 KVA Diesel',
                    _titleController),
                const SizedBox(height: 12),
                _EditLabel('Capacity *'),
                Builder(builder: (_) {
                  final current =
                      double.tryParse(_capacityController.text)?.round();
                  final sizes = [
                    ...kGeneratorKvaSizes,
                    if (current != null &&
                        !kGeneratorKvaSizes.contains(current))
                      current,
                  ]..sort();
                  return DropdownButtonFormField<int>(
                    value: current,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cs.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.electric_bolt_outlined),
                    ),
                    hint: Text(l.selectSize),
                    items: [
                      for (final kva in sizes)
                        DropdownMenuItem(
                            value: kva,
                            child: Text(generatorSizeLabel(kva))),
                    ],
                    onChanged: (v) => setState(
                        () => _capacityController.text = v?.toString() ?? ''),
                  );
                }),
                const SizedBox(height: 12),
                _EditLabel(l.fuelTypeRequired),
                DropdownButtonFormField<String>(
                  value: _fuelType,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: cs.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.local_gas_station_outlined),
                  ),
                  items: [
                    DropdownMenuItem(value: 'diesel', child: Text(l.fuelDiesel)),
                    DropdownMenuItem(value: 'petrol', child: Text(l.fuelPetrol)),
                    DropdownMenuItem(
                        value: 'gas', child: Text(l.fuelGasLpg)),
                    DropdownMenuItem(
                        value: 'natural_gas', child: Text(l.fuelNaturalGas)),
                    DropdownMenuItem(value: 'solar', child: Text(l.fuelSolar)),
                  ],
                  onChanged: (v) =>
                      setState(() => _fuelType = v ?? 'diesel'),
                ),
                const SizedBox(height: 12),
                _EditLabel(l.bestForUseCases),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kGeneratorUseCases.map((uc) {
                    final selected = _useCases.contains(uc);
                    return FilterChip(
                      label: Text(useCaseLabel(uc)),
                      selected: selected,
                      onSelected: (on) => setState(() {
                        if (on) {
                          _useCases.add(uc);
                        } else {
                          _useCases.remove(uc);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                _EditLabel(l.hireTypeLabel),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                        value: 'dry_hire',
                        label: Text(l.hireTypeDryHire)),
                    ButtonSegment(
                        value: 'operated',
                        label: Text(l.hireTypeOperated)),
                  ],
                  selected: {_hireType},
                  onSelectionChanged: (s) =>
                      setState(() => _hireType = s.first),
                ),
                const SizedBox(height: 12),
                _EditLabel(l.fuelPolicyLabel),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                        value: 'customer_provides',
                        label: Text(l.fuelPolicyCustomerProvides)),
                    ButtonSegment(
                        value: 'included',
                        label: Text(l.fuelPolicyIncluded)),
                  ],
                  selected: {_fuelPolicy},
                  onSelectionChanged: (s) =>
                      setState(() => _fuelPolicy = s.first),
                ),
                const SizedBox(height: 12),
                _EditLabel(l.accessoriesLabel),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _accChip('cables', l.accessoryCables),
                    _accChip('extension_board', l.accessoryExtensionBoard),
                    _accChip('fuel_tank', l.accessoryFuelTank),
                    _accChip('transfer_switch', l.accessoryTransferSwitch),
                  ],
                ),
                const SizedBox(height: 12),
                _EditField(
                    'Description', 'Optional details', _descController,
                    maxLines: 3),
                const SizedBox(height: 20),

                // ── Location ───────────────────────────────────────────
                _Section(l.location),
                _EditField('City', 'e.g. Nasr City', _cityController),
                const SizedBox(height: 12),
                _EditLabel('Governorate'),
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
                  hint: Text(l.selectGovernorate),
                  items: _editGovernorates
                      .map((g) =>
                          DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setState(() => _governorate = v),
                ),
                const SizedBox(height: 20),

                // ── Pricing ────────────────────────────────────────────
                _Section(l.pricingEgp),
                _EditNumField(
                    'Per day (8 hrs) *', '0', _pricePerDayController),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _EditNumField(
                            'Per week', 'optional', _pricePerWeekController)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _EditNumField('Per month', 'optional',
                            _pricePerMonthController)),
                  ],
                ),
                const SizedBox(height: 12),
                _EditNumField(
                    'Refundable deposit', 'optional', _depositController),
                const SizedBox(height: 28),

                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: cs.onPrimary),
                        )
                      : Text(l.saveChanges),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    side: BorderSide(
                        color: cs.error.withValues(alpha: 0.4)),
                  ),
                  onPressed: _saving ? null : _confirmDelete,
                  child: Text(l.deleteGenerator),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.deleteGeneratorQ),
        content: const Text(
            'This will permanently remove the generator and all its data. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel)),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.deleteAction)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await supabase
          .from('generators')
          .delete()
          .eq('id', widget.generatorId);
      if (mounted) context.pop();
    } catch (e) {
      _snack('Error: $e');
    }
  }
}

// ── Photo widgets ─────────────────────────────────────────────────────────────

class _EditPhotoAddButton extends StatelessWidget {
  const _EditPhotoAddButton({required this.onTap, required this.cs});
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        height: 96,
        margin: const EdgeInsetsDirectional.only(end: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined,
                size: 28, color: cs.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(l.addPhoto,
                style: TextStyle(
                    fontSize: 10, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _NetworkPhotoThumb extends StatelessWidget {
  const _NetworkPhotoThumb({required this.url, required this.onRemove});
  final String url;
  final VoidCallback onRemove;

  void _preview(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(children: [
          Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 40, right: 16,
            child: SafeArea(
              child: GestureDetector(
                onTap: () { Navigator.pop(context); onRemove(); },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _preview(context),
          child: Container(
            width: 96,
            height: 96,
            margin: const EdgeInsetsDirectional.only(end: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: NetworkImage(url),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.15)]),
              ),
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 5),
              child: const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white54),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 14,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocalPhotoThumb extends StatelessWidget {
  const _LocalPhotoThumb({required this.file, required this.onRemove});
  final File file;
  final VoidCallback onRemove;

  void _preview(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(children: [
          Center(
            child: InteractiveViewer(
              child: Image.file(file, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 40, right: 16,
            child: SafeArea(
              child: GestureDetector(
                onTap: () { Navigator.pop(context); onRemove(); },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _preview(context),
          child: Container(
            width: 96,
            height: 96,
            margin: const EdgeInsetsDirectional.only(end: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: FileImage(file),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.15)]),
              ),
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 5),
              child: const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white54),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 14,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared form helpers ───────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          )),
    );
  }
}

class _EditLabel extends StatelessWidget {
  const _EditLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField(this.label, this.hint, this.controller,
      {this.maxLines = 1});
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class _EditNumField extends StatelessWidget {
  const _EditNumField(this.label, this.hint, this.controller);
  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}
