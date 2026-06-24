import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/generator_use_cases.dart';
import '../../../../l10n/app_localizations.dart';

/// Specs form section for the edit-generator screen.
/// Renders fuel type, hire type, fuel policy, accessories, and use-case chips.
/// All state lives in the parent; mutations are communicated via callbacks.
class EditGeneratorSpecsSection extends StatelessWidget {
  const EditGeneratorSpecsSection({
    super.key,
    required this.fuelType,
    required this.hireType,
    required this.fuelPolicy,
    required this.useCases,
    required this.accessories,
    required this.onFuelTypeChanged,
    required this.onHireTypeChanged,
    required this.onFuelPolicyChanged,
    required this.onUseCaseToggled,
    required this.onAccessoryToggled,
  });

  final String fuelType;
  final String hireType;
  final String fuelPolicy;
  final Set<String> useCases;
  final Set<String> accessories;
  final void Function(String) onFuelTypeChanged;
  final void Function(String) onHireTypeChanged;
  final void Function(String) onFuelPolicyChanged;
  final void Function(String uc, bool selected) onUseCaseToggled;
  final void Function(String key, bool selected) onAccessoryToggled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Fuel type ──────────────────────────────────────────────────────
        EditFormLabel(l.fuelTypeRequired),
        DropdownButtonFormField<String>(
          value: fuelType,
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
          onChanged: (v) => onFuelTypeChanged(v ?? 'diesel'),
        ),
        const SizedBox(height: 12),

        // ── Use cases ──────────────────────────────────────────────────────
        EditFormLabel(l.bestForUseCases),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kGeneratorUseCases.map((uc) {
            final selected = useCases.contains(uc);
            return FilterChip(
              label: Text(useCaseLabel(uc)),
              selected: selected,
              onSelected: (on) => onUseCaseToggled(uc, on),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // ── Hire type ──────────────────────────────────────────────────────
        EditFormLabel(l.hireTypeLabel),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
                value: 'dry_hire', label: Text(l.hireTypeDryHire)),
            ButtonSegment(
                value: 'operated', label: Text(l.hireTypeOperated)),
          ],
          selected: {hireType},
          onSelectionChanged: (s) => onHireTypeChanged(s.first),
        ),
        const SizedBox(height: 12),

        // ── Fuel policy ────────────────────────────────────────────────────
        EditFormLabel(l.fuelPolicyLabel),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
                value: 'customer_provides',
                label: Text(l.fuelPolicyCustomerProvides)),
            ButtonSegment(
                value: 'included', label: Text(l.fuelPolicyIncluded)),
          ],
          selected: {fuelPolicy},
          onSelectionChanged: (s) => onFuelPolicyChanged(s.first),
        ),
        const SizedBox(height: 12),

        // ── Accessories ────────────────────────────────────────────────────
        EditFormLabel(l.accessoriesLabel),
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
      ],
    );
  }

  Widget _accChip(String key, String label) => FilterChip(
        label: Text(label),
        selected: accessories.contains(key),
        onSelected: (on) => onAccessoryToggled(key, on),
      );
}

// ── Shared form helpers ───────────────────────────────────────────────────────

class EditFormSection extends StatelessWidget {
  const EditFormSection(this.text, {super.key});
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

class EditFormLabel extends StatelessWidget {
  const EditFormLabel(this.text, {super.key});
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

class EditFormField extends StatelessWidget {
  const EditFormField(this.label, this.hint, this.controller,
      {super.key, this.maxLines = 1});
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

class EditNumField extends StatelessWidget {
  const EditNumField(this.label, this.hint, this.controller, {super.key});
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
