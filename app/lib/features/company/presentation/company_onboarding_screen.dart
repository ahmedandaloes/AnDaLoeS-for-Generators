import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/utils/db_error.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../data/repositories/company_data_repository.dart';

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

String _docLabel(String key, AppLocalizations l) => switch (key) {
      'commercial_register' => l.docCommercialRegister,
      'tax_card' => l.docTaxCard,
      _ => l.docNationalId,
    };

class CompanyOnboardingScreen extends ConsumerStatefulWidget {
  const CompanyOnboardingScreen({super.key});

  @override
  ConsumerState<CompanyOnboardingScreen> createState() =>
      _CompanyOnboardingScreenState();
}

class _CompanyOnboardingScreenState
    extends ConsumerState<CompanyOnboardingScreen> {
  // Step 1 — company info
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
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
    _descriptionController.dispose();
    super.dispose();
  }

  // ── Step 1: create company ─────────────────────────────────────────────────

  Future<void> _submitCompany() async {
    if (!_formKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty) { _snack(l.enterCompanyName); return; }
    if (_city == null) { _snack(l.selectCityGovernorate); return; }

    setState(() => _submitting = true);
    try {
      final uid = ref.read(authRepositoryProvider).currentUserId;
      if (uid == null) { _snack(l.createAnAccountFirst); return; }
      final desc = _descriptionController.text.trim();
      final repo = ref.read(companyDataRepositoryProvider);
      final data = await repo.createCompany(
        ownerUserId: uid,
        name: name,
        contactPhone: phone.isNotEmpty ? phone : null,
        description: desc.isNotEmpty ? desc : null,
        city: _city!,
      );

      // Promote user to owner role on first company creation
      await repo.promoteToOwner(uid);

      if (mounted) {
        setState(() {
          _companyId = data['id'].toString();
          _step = 2;
        });
      }
    } catch (e) {
      _snack(friendlyDbError(e,
          fallback: l.couldNotCreateCompany));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Step 2: upload documents ───────────────────────────────────────────────

  Future<void> _pickAndUpload(String docType) async {
    final l = AppLocalizations.of(context)!;
    final uid = ref.read(authRepositoryProvider).currentUserId;
    if (uid == null) { _snack(l.createAnAccountFirst); return; }
    final cid = _companyId!;

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
    } catch (e) {
      _snack(l.filePickerError);
      return;
    }

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) { _snack(l.cannotReadFile); return; }

    final ext = file.extension ?? 'pdf';
    final remotePath =
        '$uid/$cid/${docType}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    setState(() => _uploading[docType] = true);
    try {
      final bytes = await File(file.path!).readAsBytes();
      final repo = ref.read(companyDataRepositoryProvider);
      await repo.uploadCompanyDocument(
        uid: uid,
        companyId: cid,
        remotePath: remotePath,
        bytes: bytes,
        contentType: 'application/$ext',
      );
      await repo.appendDocumentUrl(cid, remotePath, docType);
      if (mounted) setState(() => _uploadedPaths[docType] = remotePath);
    } catch (e) {
      _snack(l.uploadFailed);
    } finally {
      if (mounted) setState(() => _uploading[docType] = false);
    }
  }

  Future<void> _finish() async {
    if (mounted) context.go(AppRoutes.ownerDashboard);
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
    final l = AppLocalizations.of(context)!;
    // Owners must have a real (non-anonymous) account before listing.
    final authRepo = ref.read(authRepositoryProvider);
    final uid = authRepo.currentUserId;
    if (uid == null || authRepo.isCurrentUserAnonymous) {
      final cs = Theme.of(context).colorScheme;
      return Scaffold(
        appBar: AppBar(title: Text(l.registerCompany)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_circle_outlined,
                    size: 56, color: cs.primary),
                const SizedBox(height: 16),
                Text(l.createAnAccountFirst,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  l.accountRequiredBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.push(AppRoutes.emailAuth),
                  child: Text(l.createAccount),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 1 ? l.registerCompany : l.uploadDocuments),
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
                formKey: _formKey,
                nameController: _nameController,
                phoneController: _phoneController,
                descriptionController: _descriptionController,
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
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.descriptionController,
    required this.city,
    required this.onCityChanged,
    required this.submitting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController descriptionController;
  final String? city;
  final ValueChanged<String?> onCityChanged;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: formKey,
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
                Text(l.step1Of2,
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

          _Label(l.companyName),
          TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: l.companyNameHint,
              prefixIcon: const Icon(Icons.business),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (v.trim().length < 3) return 'At least 3 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),

          _Label(l.contactPhone),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: l.phoneHintNumber,
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          _Label(l.descriptionOptionalLabel),
          TextFormField(
            controller: descriptionController,
            maxLines: 3,
            maxLength: 250,
            decoration: InputDecoration(
              hintText: l.companyDescHint,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 42),
                child: Icon(Icons.description_outlined),
              ),
            ),
          ),
          const SizedBox(height: 16),

          _Label(l.cityGovernorate),
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
            hint: Text(l.selectGovernorate),
            items: _governorates
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: onCityChanged,
            validator: (v) =>
                v == null ? l.selectGovernorateError : null,
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
                : Text(l.continueToDocuments),
          ),
          const SizedBox(height: 24),

          // Live preview card
          ValueListenableBuilder(
            valueListenable: nameController,
            builder: (_, __, ___) => ValueListenableBuilder(
              valueListenable: descriptionController,
              builder: (_, __, ___) {
                final name = nameController.text.trim();
                final desc = descriptionController.text.trim();
                if (name.isEmpty && desc.isEmpty && city == null) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(l.previewLabel,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(l.liveLabel,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: cs.onPrimaryContainer,
                                letterSpacing: 0.5)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: cs.outline.withValues(alpha: 0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: cs.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isNotEmpty
                                        ? name
                                        : l.companyName,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  if (city != null) ...[
                                    const SizedBox(height: 2),
                                    Row(children: [
                                      Icon(Icons.location_on_outlined,
                                          size: 12,
                                          color: cs.onSurfaceVariant),
                                      const SizedBox(width: 3),
                                      Text(city!,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: cs.onSurfaceVariant)),
                                    ]),
                                  ],
                                  if (desc.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(desc,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurfaceVariant,
                                            height: 1.4),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        ),
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
    final l = AppLocalizations.of(context)!;
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
                      Text(l.step2Of2,
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
            final (key, _, icon) = slot;
            final uploaded = uploadedPaths[key] != null;
            final busy = uploading[key] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DocTile(
                label: _docLabel(key, l),
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
                ? l.submitApplication
                : l.skipForNow),
          ),
          if (!anyUploaded) ...[
            const SizedBox(height: 8),
            Text(
              l.uploadLaterNote,
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
