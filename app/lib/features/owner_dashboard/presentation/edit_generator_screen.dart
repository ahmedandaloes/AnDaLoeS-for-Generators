import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/app_error_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../core/constants/generator_sizes.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_snack_bar.dart';
import 'providers/owner_providers.dart' show ownerRepositoryProvider;
import 'widgets/edit_generator_photos_section.dart';
import 'widgets/edit_generator_specs_section.dart';

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
  return ref.read(ownerRepositoryProvider).fetchGeneratorById(id);
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

  List<String> _existingPhotos = [];
  final List<File> _newPhotos = [];
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
    _pricePerMonthController.text =
        gen['price_per_month']?.toString() ?? '';
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
    final kept =
        _existingPhotos.length - _removedPhotos.length + _newPhotos.length;
    if (kept >= _maxPhotos) {
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
      final repo = ref.read(ownerRepositoryProvider);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final newUrls = <String>[];
      for (var i = 0; i < _newPhotos.length; i++) {
        final file = _newPhotos[i];
        final ext = file.path.split('.').last.toLowerCase();
        final remotePath =
            '$_companyId/${widget.generatorId}/${ts}_$i.$ext';
        final url = await repo.uploadGeneratorPhoto(
          remotePath,
          file,
          const FileOptions(upsert: true),
        );
        newUrls.add(url);
      }

      final finalPhotos = [
        ..._existingPhotos.where((u) => !_removedPhotos.contains(u)),
        ...newUrls,
      ];

      await repo.updateGenerator(widget.generatorId, {
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
      });

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

  void _snack(String msg) {
    if (!mounted) return;
    AppSnackBar.show(context, msg);
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
        loading: () => const AppLoadingIndicator(),
        error: (e, _) => const AppErrorState(),
        data: (gen) {
          _initFrom(gen);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Availability toggle ──────────────────────────────────
                Card(
                  child: SwitchListTile(
                    value: _available,
                    onChanged: (v) => setState(() => _available = v),
                    title: Text(
                      _available ? 'Available for rent' : 'Unavailable',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _available
                            ? cs.primary
                            : cs.onSurfaceVariant,
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
                      color:
                          _available ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Photos ───────────────────────────────────────────────
                EditFormSection(l.photosLabel),
                EditGeneratorPhotosSection(
                  existingPhotos: _existingPhotos,
                  removedPhotos: _removedPhotos,
                  newPhotos: _newPhotos,
                  maxPhotos: _maxPhotos,
                  onPickPhoto: _pickPhoto,
                  onRemoveExisting: (url) =>
                      setState(() => _removedPhotos.add(url)),
                  onRemoveNew: (i) =>
                      setState(() => _newPhotos.removeAt(i)),
                ),
                const SizedBox(height: 20),

                // ── Basic info ───────────────────────────────────────────
                EditFormSection(l.basicInfo),
                EditFormField('Title *', 'e.g. Cummins 100 KVA Diesel',
                    _titleController),
                const SizedBox(height: 12),
                EditFormLabel('Capacity *'),
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
                      prefixIcon:
                          const Icon(Icons.electric_bolt_outlined),
                    ),
                    hint: Text(l.selectSize),
                    items: [
                      for (final kva in sizes)
                        DropdownMenuItem(
                            value: kva,
                            child: Text(generatorSizeLabel(kva))),
                    ],
                    onChanged: (v) => setState(
                        () => _capacityController.text =
                            v?.toString() ?? ''),
                  );
                }),
                const SizedBox(height: 12),

                // ── Specs section (fuel, hire type, accessories…) ────────
                EditGeneratorSpecsSection(
                  fuelType: _fuelType,
                  hireType: _hireType,
                  fuelPolicy: _fuelPolicy,
                  useCases: _useCases,
                  accessories: _accessories,
                  onFuelTypeChanged: (v) =>
                      setState(() => _fuelType = v),
                  onHireTypeChanged: (v) =>
                      setState(() => _hireType = v),
                  onFuelPolicyChanged: (v) =>
                      setState(() => _fuelPolicy = v),
                  onUseCaseToggled: (uc, on) => setState(() {
                    if (on) {
                      _useCases.add(uc);
                    } else {
                      _useCases.remove(uc);
                    }
                  }),
                  onAccessoryToggled: (key, on) => setState(() {
                    if (on) {
                      _accessories.add(key);
                    } else {
                      _accessories.remove(key);
                    }
                  }),
                ),
                const SizedBox(height: 12),

                EditFormField(
                    'Description', 'Optional details', _descController,
                    maxLines: 3),
                const SizedBox(height: 20),

                // ── Location ─────────────────────────────────────────────
                EditFormSection(l.location),
                EditFormField(
                    'City', 'e.g. Nasr City', _cityController),
                const SizedBox(height: 12),
                EditFormLabel('Governorate'),
                DropdownButtonFormField<String>(
                  value: _governorate,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: cs.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon:
                        const Icon(Icons.location_on_outlined),
                  ),
                  hint: Text(l.selectGovernorate),
                  items: _editGovernorates
                      .map((g) => DropdownMenuItem(
                          value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setState(() => _governorate = v),
                ),
                const SizedBox(height: 20),

                // ── Pricing ──────────────────────────────────────────────
                EditFormSection(l.pricingEgp),
                EditNumField('Per day (8 hrs) *', '0',
                    _pricePerDayController),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: EditNumField('Per week', 'optional',
                            _pricePerWeekController)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: EditNumField('Per month', 'optional',
                            _pricePerMonthController)),
                  ],
                ),
                const SizedBox(height: 12),
                EditNumField('Refundable deposit', 'optional',
                    _depositController),
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
                  backgroundColor:
                      Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.deleteAction)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(ownerRepositoryProvider)
          .deleteGenerator(widget.generatorId);
      if (mounted) context.pop();
    } catch (e) {
      _snack('Error: $e');
    }
  }
}
