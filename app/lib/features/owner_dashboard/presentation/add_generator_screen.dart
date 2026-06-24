import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../core/constants/generator_sizes.dart';
import '../../../core/constants/generator_use_cases.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../providers/owner_providers.dart' show ownerRepositoryProvider;

const _governorates = [
  'Cairo', 'Giza', 'Alexandria', 'Dakahlia', 'Red Sea', 'Beheira',
  'Fayoum', 'Gharbia', 'Ismailia', 'Menofia', 'Minya', 'Qaliubiya',
  'New Valley', 'Suez', 'Aswan', 'Assiut', 'Beni Suef', 'Port Said',
  'Damietta', 'Sharqia', 'South Sinai', 'Kafr El Sheikh', 'Matrouh',
  'Luxor', 'Qena', 'North Sinai', 'Sohag',
];

class AddGeneratorScreen extends ConsumerStatefulWidget {
  const AddGeneratorScreen({
    super.key,
    required this.companyId,
    this.prefill,
  });
  final String companyId;
  final Map<String, dynamic>? prefill;

  @override
  ConsumerState<AddGeneratorScreen> createState() =>
      _AddGeneratorScreenState();
}

class _AddGeneratorScreenState extends ConsumerState<AddGeneratorScreen> {
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
  final Set<String> _accessories = {};
  final Set<String> _useCases = {};
  bool _submitting = false;

  // Photos
  final List<File> _photos = [];
  static const _maxPhotos = 5;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    if (p != null) {
      _titleController.text = p['title']?.toString() ?? '';
      _capacityController.text = p['capacity_kva']?.toString() ?? '';
      _descController.text = p['description']?.toString() ?? '';
      _pricePerDayController.text = p['price_per_day']?.toString() ?? '';
      _pricePerWeekController.text = p['price_per_week']?.toString() ?? '';
      _pricePerMonthController.text = p['price_per_month']?.toString() ?? '';
      final dep = (p['deposit_amount'] as num?)?.toDouble() ?? 0;
      _depositController.text = dep > 0 ? dep.toStringAsFixed(0) : '';
      _cityController.text = p['city']?.toString() ?? '';
      _governorate = p['governorate']?.toString();
      _fuelType = p['fuel_type']?.toString() ?? 'diesel';
      _hireType = p['hire_type']?.toString() ?? 'dry_hire';
      _fuelPolicy = p['fuel_policy']?.toString() ?? 'customer_provides';
      _useCases.addAll(
          (p['use_cases'] as List?)?.cast<String>() ?? const []);
      _accessories.addAll(
          (p['accessories'] as List?)?.cast<String>() ?? const []);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _capacityController.dispose();
    _descController.dispose();
    _pricePerDayController.dispose();
    _pricePerWeekController.dispose();
    _depositController.dispose();
    _pricePerMonthController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final l = AppLocalizations.of(context)!;
    if (_photos.length >= _maxPhotos) {
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
      setState(() => _photos.add(File(path)));
    } catch (e) {
      _snack(l.photoPickerError);
    }
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    final capacityStr = _capacityController.text.trim();
    final priceStr = _pricePerDayController.text.trim();

    if (title.isEmpty || capacityStr.isEmpty || priceStr.isEmpty) {
      _snack(l.requiredFieldsGenerator);
      return;
    }
    if (_governorate == null) {
      _snack(l.selectGovernorateError);
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(ownerRepositoryProvider);
      // 1 — insert generator
      final data = await repo.insertGenerator({
        'company_id': widget.companyId,
        'title': title,
        'capacity_kva': double.parse(capacityStr),
        'price_per_day': double.parse(priceStr),
        if (_depositController.text.trim().isNotEmpty)
          'deposit_amount': double.tryParse(_depositController.text.trim()) ?? 0,
        if (_pricePerWeekController.text.trim().isNotEmpty)
          'price_per_week': double.parse(_pricePerWeekController.text.trim()),
        if (_pricePerMonthController.text.trim().isNotEmpty)
          'price_per_month': double.parse(_pricePerMonthController.text.trim()),
        if (_descController.text.trim().isNotEmpty)
          'description': _descController.text.trim(),
        if (_cityController.text.trim().isNotEmpty)
          'city': _cityController.text.trim(),
        'governorate': _governorate,
        'fuel_type': _fuelType,
        'hire_type': _hireType,
        'fuel_policy': _fuelPolicy,
        'accessories': _accessories.toList(),
        'use_cases': _useCases.toList(),
        'status': 'available',
      });

      final generatorId = data['id'].toString();

      // 2 — upload photos if any
      if (_photos.isNotEmpty) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final urls = <String>[];
        for (var i = 0; i < _photos.length; i++) {
          final file = _photos[i];
          final ext = file.path.split('.').last.toLowerCase();
          final remotePath =
              '${widget.companyId}/$generatorId/${ts}_$i.$ext';
          final url = await repo.uploadGeneratorPhoto(
            remotePath,
            file,
            const FileOptions(upsert: true),
          );
          urls.add(url);
        }
        await repo.updateGeneratorPhotos(generatorId, urls);
      }

      if (mounted) {
        final addAnother = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.generatorAdded),
            content: Text(l.addAnotherGeneratorQ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.done),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.addAnotherGenerator),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (addAnother == true) {
          _resetForm();
        } else {
          context.pop();
        }
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resetForm() {
    setState(() {
      for (final c in [
        _titleController, _capacityController, _descController,
        _pricePerDayController, _pricePerWeekController,
        _pricePerMonthController, _depositController, _cityController,
      ]) {
        c.clear();
      }
      _governorate = null;
      _fuelType = 'diesel';
      _hireType = 'dry_hire';
      _fuelPolicy = 'customer_provides';
      _accessories.clear();
      _useCases.clear();
      _photos.clear();
    });
    // Scroll to top so owner starts fresh from the title field.
    Scrollable.maybeOf(context)?.position.jumpTo(0);
  }

  Widget _accessoryChip(String key, String label) => FilterChip(
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
    AppSnackBar.show(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.addGenerator)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Photos ──────────────────────────────────────────────────
            _Section(l.photosOptional),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Add button
                  if (_photos.length < _maxPhotos)
                    _PhotoAddButton(onTap: _pickPhoto, cs: cs),
                  // Picked photos
                  ..._photos.asMap().entries.map(
                        (e) => _PhotoThumb(
                          file: e.value,
                          index: e.key,
                          total: _photos.length,
                          onRemove: () =>
                              setState(() => _photos.removeAt(e.key)),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.photosUpToNote(_maxPhotos),
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            // ── Basic info ──────────────────────────────────────────────
            _Section(l.basicInfo),
            _Field(l.titleRequired, l.titleHint, _titleController),
            const SizedBox(height: 12),
            _Label(l.capacityRequired),
            DropdownButtonFormField<int>(
              value: int.tryParse(_capacityController.text),
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
                for (final kva in kGeneratorKvaSizes)
                  DropdownMenuItem(
                      value: kva, child: Text(generatorSizeLabel(kva))),
              ],
              onChanged: (v) => setState(
                  () => _capacityController.text = v?.toString() ?? ''),
            ),
            const SizedBox(height: 12),
            _Label(l.fuelTypeRequired),
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
                DropdownMenuItem(value: 'gas', child: Text(l.fuelGasLpg)),
                DropdownMenuItem(
                    value: 'natural_gas', child: Text(l.fuelNaturalGas)),
                DropdownMenuItem(value: 'solar', child: Text(l.fuelSolar)),
              ],
              onChanged: (v) => setState(() => _fuelType = v ?? 'diesel'),
            ),
            const SizedBox(height: 12),
            _Label(l.bestForUseCases),
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

            // Hire type
            _Label(l.hireTypeLabel),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                    value: 'dry_hire', label: Text(l.hireTypeDryHire)),
                ButtonSegment(
                    value: 'operated', label: Text(l.hireTypeOperated)),
              ],
              selected: {_hireType},
              onSelectionChanged: (s) =>
                  setState(() => _hireType = s.first),
            ),
            const SizedBox(height: 12),

            // Fuel policy
            _Label(l.fuelPolicyLabel),
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

            // Accessories
            _Label(l.accessoriesLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _accessoryChip('cables', l.accessoryCables),
                _accessoryChip(
                    'extension_board', l.accessoryExtensionBoard),
                _accessoryChip('fuel_tank', l.accessoryFuelTank),
                _accessoryChip(
                    'transfer_switch', l.accessoryTransferSwitch),
              ],
            ),
            const SizedBox(height: 12),

            _Field(l.descriptionCol, l.descriptionHint,
                _descController,
                maxLines: 3),
            const SizedBox(height: 20),

            // ── Location ────────────────────────────────────────────────
            _Section(l.location),
            _Field(l.cityLabel, l.cityHint, _cityController),
            const SizedBox(height: 12),
            _Label(l.governorateRequired),
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
              items: _governorates
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _governorate = v),
            ),
            const SizedBox(height: 20),

            // ── Pricing ─────────────────────────────────────────────────
            _Section(l.pricingEgp),
            _NumField(l.perDay8hRequired, '0', _pricePerDayController),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _NumField(
                        l.perWeek, l.optionalField, _pricePerWeekController)),
                const SizedBox(width: 12),
                Expanded(
                    child: _NumField(
                        l.perMonth, l.optionalField, _pricePerMonthController)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.pricingNote,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _NumField(l.refundableDeposit, l.optionalField, _depositController),
            const SizedBox(height: 4),
            Text(
              l.depositNote,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 28),

            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.onPrimary),
                    )
                  : Text(l.addGeneratorWithPhotos(_photos.length)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photo widgets ─────────────────────────────────────────────────────────────

class _PhotoAddButton extends StatelessWidget {
  const _PhotoAddButton({required this.onTap, required this.cs});
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
          border: Border.all(
            color: cs.outlineVariant,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined,
                size: 28, color: cs.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(l.addPhoto,
                style:
                    TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.file, required this.onRemove, required this.index, required this.total});
  final File file;
  final VoidCallback onRemove;
  final int index;
  final int total;

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
            top: 40,
            right: 16,
            child: SafeArea(
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${index + 1} / $total',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onRemove();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.white),
                  ),
                ),
              ]),
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
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.15)],
                ),
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

// ── Shared form widgets ───────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.hint, this.controller, {this.maxLines = 1});
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

class _NumField extends StatelessWidget {
  const _NumField(this.label, this.hint, this.controller);
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
