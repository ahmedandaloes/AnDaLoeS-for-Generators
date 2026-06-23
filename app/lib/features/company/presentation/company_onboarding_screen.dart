import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

const _docSlots = [
  ('commercial_register', 'Commercial Register', Icons.article_outlined),
  ('tax_card', 'Tax Card', Icons.credit_card_outlined),
  ('national_id', 'National ID', Icons.badge_outlined),
];

class CompanyOnboardingScreen extends StatefulWidget {
  const CompanyOnboardingScreen({super.key});

  @override
  State<CompanyOnboardingScreen> createState() =>
      _CompanyOnboardingScreenState();
}

class _CompanyOnboardingScreenState extends State<CompanyOnboardingScreen> {
  // Step 1 — company info
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _city;
  bool _submitting = false;

  // Step 2 — document upload
  int _step = 1;
  String? _companyId;
  final Map<String, String?> _uploadedPaths = {
    'commercial_register': null,
    'tax_card': null,
    'national_id': null,
  };
  final Map<String, bool> _uploading = {
    'commercial_register': false,
    'tax_card': false,
    'national_id': false,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Step 1: create company ─────────────────────────────────────────────────

  Future<void> _submitCompany() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty) { _snack('Enter your company name'); return; }
    if (_city == null) { _snack('Select your city / governorate'); return; }

    setState(() => _submitting = true);
    try {
      final data = await supabase.from('companies').insert({
        'owner_user_id': supabase.auth.currentUser!.id,
        'name': name,
        'contact_phone': phone.isNotEmpty ? phone : null,
        'city': _city,
        'verification_status': 'pending',
      }).select('id').single();

      if (mounted) {
        setState(() {
          _companyId = data['id'].toString();
          _step = 2;
        });
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Step 2: upload documents ───────────────────────────────────────────────

  Future<void> _pickAndUpload(String docType) async {
    final uid = supabase.auth.currentUser!.id;
    final cid = _companyId!;

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
    } catch (e) {
      _snack('Could not open file picker: $e');
      return;
    }

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) { _snack('Cannot read file path'); return; }

    final ext = file.extension ?? 'pdf';
    final remotePath = '$uid/$cid/${docType}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    setState(() => _uploading[docType] = true);
    try {
      await supabase.storage.from('company-docs').upload(
        remotePath,
        File(file.path!),
        fileOptions: const FileOptions(upsert: true),
      );

      // Save path into companies.document_urls (append)
      final existing = await supabase
          .from('companies')
          .select('document_urls')
          .eq('id', cid)
          .single();
      final urls = List<String>.from(
          existing['document_urls'] as List? ?? []);
      // Replace or append this slot's entry
      urls.removeWhere((u) => u.contains('/$docType'));
      urls.add(remotePath);
      await supabase
          .from('companies')
          .update({'document_urls': urls}).eq('id', cid);

      if (mounted) setState(() => _uploadedPaths[docType] = remotePath);
    } catch (e) {
      _snack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading[docType] = false);
    }
  }

  Future<void> _finish() async {
    if (mounted) context.go('/owner-dashboard');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 1 ? 'Register Company' : 'Upload Documents'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _step == 1 ? 0.5 : 1.0,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _step == 1
            ? _StepOne(
                key: const ValueKey(1),
                nameController: _nameController,
                phoneController: _phoneController,
                city: _city,
                onCityChanged: (v) => setState(() => _city = v),
                submitting: _submitting,
                onSubmit: _submitCompany,
              )
            : _StepTwo(
                key: const ValueKey(2),
                uploadedPaths: _uploadedPaths,
                uploading: _uploading,
                onPickAndUpload: _pickAndUpload,
                onFinish: _finish,
              ),
      ),
    );
  }
}

// ── Step 1 widget ─────────────────────────────────────────────────────────────

class _StepOne extends StatelessWidget {
  const _StepOne({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.city,
    required this.onCityChanged,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final String? city;
  final ValueChanged<String?> onCityChanged;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                cs.primaryContainer.withValues(alpha: 0.6),
                cs.secondaryContainer.withValues(alpha: 0.3),
              ]),
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
                  child:
                      Icon(Icons.business_outlined, color: cs.onPrimary, size: 22),
                ),
                const SizedBox(height: 12),
                const Text('Step 1 of 2 — Company info',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Your application will be reviewed before your generators go live.',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _Label('Company name'),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'e.g. AnDaLoeS for Generators',
              prefixIcon: Icon(Icons.business),
            ),
          ),
          const SizedBox(height: 16),

          _Label('Contact phone'),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: '01XXXXXXXXX',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),

          _Label('City / Governorate'),
          DropdownButtonFormField<String>(
            value: city,
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
            onChanged: onCityChanged,
          ),
          const SizedBox(height: 28),

          FilledButton(
            onPressed: submitting ? null : onSubmit,
            child: submitting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.onPrimary),
                  )
                : const Text('Continue to documents →'),
          ),
        ],
      ),
    );
  }
}

// ── Step 2 widget ─────────────────────────────────────────────────────────────

class _StepTwo extends StatelessWidget {
  const _StepTwo({
    super.key,
    required this.uploadedPaths,
    required this.uploading,
    required this.onPickAndUpload,
    required this.onFinish,
  });

  final Map<String, String?> uploadedPaths;
  final Map<String, bool> uploading;
  final void Function(String docType) onPickAndUpload;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final anyUploaded = uploadedPaths.values.any((v) => v != null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.secondaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.upload_file_outlined,
                    color: cs.secondary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Step 2 of 2 — Verification documents',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        'Upload PDF or image. All documents are optional now — you can add them later from your dashboard.',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Upload slots
          ..._docSlots.map((slot) {
            final (key, label, icon) = slot;
            final uploaded = uploadedPaths[key] != null;
            final busy = uploading[key] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DocTile(
                label: label,
                icon: icon,
                uploaded: uploaded,
                busy: busy,
                onTap: busy ? null : () => onPickAndUpload(key),
              ),
            );
          }),
          const SizedBox(height: 8),

          // Accepted formats note
          Row(
            children: [
              Icon(Icons.info_outline, size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Accepted: PDF, JPG, PNG — max 10 MB each',
                style:
                    TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 28),

          FilledButton(
            onPressed: onFinish,
            child: Text(anyUploaded
                ? 'Submit application'
                : 'Skip for now — go to dashboard'),
          ),
          if (!anyUploaded) ...[
            const SizedBox(height: 8),
            Text(
              'You can upload documents later from the Owner Dashboard.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.label,
    required this.icon,
    required this.uploaded,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool uploaded;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: uploaded
              ? cs.primaryContainer.withValues(alpha: 0.4)
              : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: uploaded ? cs.primary : cs.outlineVariant,
            width: uploaded ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: uploaded
                    ? cs.primary.withValues(alpha: 0.12)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.primary),
                    )
                  : Icon(
                      uploaded ? Icons.check_circle_rounded : icon,
                      size: 22,
                      color: uploaded ? cs.primary : cs.onSurfaceVariant,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: uploaded ? cs.primary : cs.onSurface)),
                  Text(
                    uploaded ? 'Uploaded ✓' : 'Tap to upload',
                    style: TextStyle(
                        fontSize: 12,
                        color: uploaded ? cs.primary : cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              uploaded ? Icons.edit_outlined : Icons.upload_outlined,
              size: 18,
              color: uploaded ? cs.primary : cs.onSurfaceVariant,
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
