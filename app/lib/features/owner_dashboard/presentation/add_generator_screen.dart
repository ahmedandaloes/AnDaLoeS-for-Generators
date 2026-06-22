import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

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
  bool _submitting = false;

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
      await supabase.from('generators').insert({
        'company_id': widget.companyId,
        'title': title,
        'capacity_kva': double.parse(capacityStr),
        'price_per_day': double.parse(priceStr),
        if (_pricePerWeekController.text.trim().isNotEmpty)
          'price_per_week':
              double.parse(_pricePerWeekController.text.trim()),
        if (_pricePerMonthController.text.trim().isNotEmpty)
          'price_per_month':
              double.parse(_pricePerMonthController.text.trim()),
        if (_descController.text.trim().isNotEmpty)
          'description': _descController.text.trim(),
        if (_cityController.text.trim().isNotEmpty)
          'city': _cityController.text.trim(),
        'governorate': _governorate,
        'status': 'available',
      });
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
            _Section('Basic info'),
            _Field('Title *', 'e.g. Cummins 100 KVA Diesel',
                _titleController),
            const SizedBox(height: 12),
            _NumField('Capacity (KVA) *', 'e.g. 100', _capacityController),
            const SizedBox(height: 12),
            _Field('Description', 'Optional details about the generator',
                _descController,
                maxLines: 3),
            const SizedBox(height: 20),

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

            _Section('Pricing (EGP)'),
            Row(
              children: [
                Expanded(
                  child: _NumField(
                      'Per day (8 hrs) *', '0', _pricePerDayController),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _NumField(
                        'Per week', 'optional', _pricePerWeekController)),
                const SizedBox(width: 12),
                Expanded(
                    child: _NumField('Per month', 'optional',
                        _pricePerMonthController)),
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
                  : const Text('Add generator'),
            ),
          ],
        ),
      ),
    );
  }
}

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
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
      ],
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}
