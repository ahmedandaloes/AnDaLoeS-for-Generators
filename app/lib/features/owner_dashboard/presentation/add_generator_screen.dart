import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../core/config/supabase.dart';

const _governorates = [
  'Cairo', 'Giza', 'Alexandria', 'Dakahlia', 'Red Sea', 'Beheira',
  'Fayoum', 'Gharbia', 'Ismailia', 'Menofia', 'Minya', 'Qaliubiya',
  'New Valley', 'Suez', 'Aswan', 'Assiut', 'Beni Suef', 'Port Said',
  'Damietta', 'Sharqia', 'South Sinai', 'Kafr El Sheikh', 'Matrouh',
  'Luxor', 'Qena', 'North Sinai', 'Sohag',
];

class AddGeneratorScreen extends StatefulWidget {
  const AddGeneratorScreen({super.key, required this.companyId});
  final String companyId;

  @override
  State<AddGeneratorScreen> createState() => _AddGeneratorScreenState();
}

class _AddGeneratorScreenState extends State<AddGeneratorScreen> {
  final _titleController = TextEditingController();
  final _capacityController = TextEditingController();
  final _descController = TextEditingController();
  final _pricePerDayController = TextEditingController();
  final _pricePerWeekController = TextEditingController();
  final _pricePerMonthController = TextEditingController();
  final _cityController = TextEditingController();
  String? _governorate;
  String _fuelType = 'diesel';
  bool _submitting = false;

  // Photos
  final List<File> _photos = [];
  static const _maxPhotos = 5;

  @override
  void dispose() {
    _titleController.dispose();
    _capacityController.dispose();
    _descController.dispose();
    _pricePerDayController.dispose();
    _pricePerWeekController.dispose();
    _pricePerMonthController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= _maxPhotos) {
      _snack('Maximum $_maxPhotos photos allowed');
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
      _snack('Could not open photo picker: $e');
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final capacityStr = _capacityController.text.trim();
    final priceStr = _pricePerDayController.text.trim();

    if (title.isEmpty || capacityStr.isEmpty || priceStr.isEmpty) {
      _snack('Title, capacity, and daily price are required');
      return;
    }
    if (_governorate == null) {
      _snack('Select a governorate');
      return;
    }

    setState(() => _submitting = true);
    try {
      // 1 — insert generator
      final data = await supabase.from('generators').insert({
        'company_id': widget.companyId,
        'title': title,
        'capacity_kva': double.parse(capacityStr),
        'price_per_day': double.parse(priceStr),
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
        'status': 'available',
      }).select('id').single();

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
          await supabase.storage.from('generator-photos').upload(
                remotePath,
                file,
                fileOptions: const FileOptions(upsert: true),
              );
          final url = supabase.storage
              .from('generator-photos')
              .getPublicUrl(remotePath);
          urls.add(url);
        }
        await supabase.from('generators').update({'photos': urls}).eq(
            'id', generatorId);
      }

      if (mounted) {
        _snack('Generator added!');
        context.pop();
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Generator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Photos ──────────────────────────────────────────────────
            _Section('Photos (optional)'),
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
              'Up to $_maxPhotos photos — shown in the generator listing',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            // ── Basic info ──────────────────────────────────────────────
            _Section('Basic info'),
            _Field('Title *', 'e.g. Cummins 100 KVA Diesel', _titleController),
            const SizedBox(height: 12),
            _NumField('Capacity (KVA) *', 'e.g. 100', _capacityController),
            const SizedBox(height: 12),
            _Label('Fuel type *'),
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
              items: const [
                DropdownMenuItem(value: 'diesel', child: Text('Diesel')),
                DropdownMenuItem(value: 'petrol', child: Text('Petrol')),
                DropdownMenuItem(value: 'gas', child: Text('Gas (LPG)')),
                DropdownMenuItem(
                    value: 'natural_gas', child: Text('Natural Gas')),
                DropdownMenuItem(value: 'solar', child: Text('Solar')),
              ],
              onChanged: (v) => setState(() => _fuelType = v ?? 'diesel'),
            ),
            const SizedBox(height: 12),
            _Field('Description', 'Optional details about the generator',
                _descController,
                maxLines: 3),
            const SizedBox(height: 20),

            // ── Location ────────────────────────────────────────────────
            _Section('Location'),
            _Field('City', 'e.g. Nasr City', _cityController),
            const SizedBox(height: 12),
            _Label('Governorate *'),
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
              hint: const Text('Select governorate'),
              items: _governorates
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _governorate = v),
            ),
            const SizedBox(height: 20),

            // ── Pricing ─────────────────────────────────────────────────
            _Section('Pricing (EGP)'),
            _NumField('Per day (8 hrs) *', '0', _pricePerDayController),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _NumField(
                        'Per week', 'optional', _pricePerWeekController)),
                const SizedBox(width: 12),
                Expanded(
                    child: _NumField(
                        'Per month', 'optional', _pricePerMonthController)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '1 day = 8 operating hours. Lower week/month rates attract more bookings.',
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
                  : Text(_photos.isEmpty
                      ? 'Add generator'
                      : 'Add generator + ${_photos.length} photo${_photos.length == 1 ? '' : 's'}'),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        height: 96,
        margin: const EdgeInsets.only(right: 10),
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
            Text('Add photo',
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
            margin: const EdgeInsets.only(right: 10),
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
