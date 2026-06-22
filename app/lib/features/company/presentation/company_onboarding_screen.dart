import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase.dart';

const _governorates = [
  'Cairo', 'Giza', 'Alexandria', 'Dakahlia', 'Red Sea', 'Beheira',
  'Fayoum', 'Gharbia', 'Ismailia', 'Menofia', 'Minya', 'Qaliubiya',
  'New Valley', 'Suez', 'Aswan', 'Assiut', 'Beni Suef', 'Port Said',
  'Damietta', 'Sharqia', 'South Sinai', 'Kafr El Sheikh', 'Matrouh',
  'Luxor', 'Qena', 'North Sinai', 'Sohag',
];

class CompanyOnboardingScreen extends StatefulWidget {
  const CompanyOnboardingScreen({super.key});

  @override
  State<CompanyOnboardingScreen> createState() =>
      _CompanyOnboardingScreenState();
}

class _CompanyOnboardingScreenState extends State<CompanyOnboardingScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _city;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty) {
      _snack('Enter your company name');
      return;
    }
    if (_city == null) {
      _snack('Select your city / governorate');
      return;
    }
    setState(() => _submitting = true);
    try {
      await supabase.from('companies').insert({
        'owner_user_id': supabase.auth.currentUser!.id,
        'name': name,
        'contact_phone': phone.isNotEmpty ? phone : null,
        'city': _city,
        'verification_status': 'pending',
      });
      if (mounted) {
        context.go('/owner-dashboard');
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
      appBar: AppBar(title: const Text('Register Company')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primaryContainer.withOpacity(0.6),
                    cs.secondaryContainer.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.business_outlined,
                        color: cs.onPrimary, size: 22),
                  ),
                  const SizedBox(height: 12),
                  const Text('Register your company',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Your application will be reviewed by our team before your generators go live.',
                    style:
                        TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _Label('Company name'),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g. AnDaLoeS for Generators',
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 16),

            _Label('Contact phone'),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '01XXXXXXXXX',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),

            _Label('City / Governorate'),
            DropdownButtonFormField<String>(
              value: _city,
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
              onChanged: (v) => setState(() => _city = v),
            ),
            const SizedBox(height: 24),

            // Documents notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: cs.outlineVariant.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'After submitting, our team will contact you to collect verification documents (commercial register, tax card, national ID).',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.onPrimary),
                    )
                  : const Text('Submit application'),
            ),
          ],
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
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
