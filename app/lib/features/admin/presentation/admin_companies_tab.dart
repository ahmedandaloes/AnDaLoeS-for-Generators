import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/db_error.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_snack_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/admin_repository.dart';
import '../../auth/data/repositories/auth_repository.dart';

final pendingCompaniesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(adminRepositoryProvider).fetchPendingCompaniesAdmin();
});

class AdminCompaniesTab extends StatelessWidget {
  const AdminCompaniesTab({super.key, required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final companiesAsync = ref.watch(pendingCompaniesProvider);
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;

    return companiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const AppErrorState(),
      data: (companies) {
        if (companies.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 48, color: Colors.green),
                const SizedBox(height: 16),
                Text(l.noPendingCompanies),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(pendingCompaniesProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: companies.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) =>
                _CompanyCard(company: companies[i], cs: cs, ref: ref),
          ),
        );
      },
    );
  }
}

class _CompanyCard extends StatefulWidget {
  const _CompanyCard(
      {required this.company, required this.cs, required this.ref});
  final Map<String, dynamic> company;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  State<_CompanyCard> createState() => _CompanyCardState();
}

class _CompanyCardState extends State<_CompanyCard> {
  final _reasonController = TextEditingController();
  bool _showReject = false;
  bool _loading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _loading = true);
    final companyName = widget.company['name']?.toString() ?? 'Company';
    try {
      final uid = widget.ref.read(authRepositoryProvider).currentUserId ?? '';
      await widget.ref.read(adminRepositoryProvider).approveCompany(
            widget.company['id'].toString(),
            uid,
          );
      widget.ref.invalidate(pendingCompaniesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l.companyApproved(companyName),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, friendlyDbError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    final l = AppLocalizations.of(context)!;
    final reason = _reasonController.text.trim();
    final companyName = widget.company['name']?.toString() ?? 'Company';
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.enterRejectionReason),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }
    setState(() => _loading = true);
    try {
      final uid = widget.ref.read(authRepositoryProvider).currentUserId ?? '';
      await widget.ref.read(adminRepositoryProvider).rejectCompany(
            widget.company['id'].toString(),
            uid,
            reason,
          );
      widget.ref.invalidate(pendingCompaniesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.cancel_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l.companyRejected(companyName),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, friendlyDbError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final l = AppLocalizations.of(context)!;
    final company = widget.company;
    final owner = company['profiles'] as Map<String, dynamic>?;
    final status = company['verification_status']?.toString() ?? 'pending';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange),
                  ),
                ),
                const Spacer(),
                Text(
                  _fmtDate(company['created_at']?.toString()),
                  style:
                      TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(company['name']?.toString() ?? '-',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            if (owner != null) ...[
              Row(children: [
                Icon(Icons.person_outline,
                    size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                    owner['full_name'] ?? owner['phone'] ?? 'Owner',
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurfaceVariant)),
              ]),
              const SizedBox(height: 2),
            ],
            Row(children: [
              Icon(Icons.location_on_outlined,
                  size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(company['city']?.toString() ?? '-',
                  style:
                      TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ]),
            if (company['contact_phone'] != null) ...[
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.phone_outlined,
                    size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(company['contact_phone'].toString(),
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurfaceVariant)),
              ]),
            ],
            Builder(builder: (_) {
              // Prefer structured company_documents rows (KYC v1).
              // Fall back to legacy document_urls array for backwards compat.
              final kycDocs = (company['company_documents'] as List? ?? [])
                  .cast<Map<String, dynamic>>();
              final legacyPaths = kycDocs.isEmpty
                  ? (company['document_urls'] as List? ?? []).cast<String>()
                  : <String>[];

              if (kycDocs.isEmpty && legacyPaths.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // KYC structured rows with verified status
                  if (kycDocs.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: kycDocs.map((doc) {
                        final docId = doc['id']?.toString() ?? '';
                        final docType = doc['doc_type']?.toString() ?? '';
                        final path = doc['file_url']?.toString() ?? '';
                        final verified = doc['verified'] == true;
                        final label = const {
                              'commercial_register': 'Comm. Register',
                              'tax_card': 'Tax Card',
                              'national_id': 'National ID',
                            }[docType] ??
                            docType;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ActionChip(
                              avatar: Icon(
                                verified
                                    ? Icons.verified_rounded
                                    : Icons.description_outlined,
                                size: 14,
                                color: verified ? Colors.green : null,
                              ),
                              label: Text(label,
                                  style: const TextStyle(fontSize: 11)),
                              onPressed: () async {
                                if (path.isEmpty) return;
                                try {
                                  final res = await widget.ref
                                      .read(adminRepositoryProvider)
                                      .getCompanyDocSignedUrl(path);
                                  await Clipboard.setData(
                                      ClipboardData(text: res));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(l.urlCopied(label)),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 3),
                                    ));
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    AppSnackBar.error(
                                        context, friendlyDbError(e));
                                  }
                                }
                              },
                            ),
                            if (!verified) ...[
                              const SizedBox(width: 4),
                              _VerifyDocButton(
                                docId: docId,
                                label: label,
                                adminRef: widget.ref,
                              ),
                            ],
                          ],
                        );
                      }).toList(),
                    ),
                  // Legacy array fallback
                  if (legacyPaths.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: legacyPaths.map((path) {
                        final filename = path.split('/').last;
                        final docType = filename.split('_').first;
                        final label = const {
                              'commercial': 'Comm. Register',
                              'tax': 'Tax Card',
                              'national': 'National ID',
                            }[docType] ??
                            filename;
                        return ActionChip(
                          avatar: const Icon(Icons.description_outlined,
                              size: 14),
                          label: Text(label,
                              style: const TextStyle(fontSize: 11)),
                          onPressed: () async {
                            try {
                              final res = await widget.ref
                                  .read(adminRepositoryProvider)
                                  .getCompanyDocSignedUrl(path);
                              await Clipboard.setData(
                                  ClipboardData(text: res));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l.urlCopied(label)),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$e')));
                              }
                            }
                          },
                        );
                      }).toList(),
                    ),
                ],
              );
            }),
            if (_showReject) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l.rejectionReason,
                  hintText: l.rejectionReasonHint,
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (!_showReject)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(
                            color: cs.error.withValues(alpha: 0.4)),
                        minimumSize: const Size.fromHeight(40),
                      ),
                      onPressed: _loading
                          ? null
                          : () => setState(() => _showReject = true),
                      child: Text(l.reject),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(40)),
                      onPressed: _loading ? null : _approve,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : Text(l.approve),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => _showReject = false),
                      child: Text(l.cancel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: cs.error,
                          minimumSize: const Size.fromHeight(40)),
                      onPressed: _loading ? null : _reject,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(l.confirmReject),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(String? d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return d;
    }
  }
}

/// Small button an admin taps to mark one company_document as verified.
class _VerifyDocButton extends StatefulWidget {
  const _VerifyDocButton({
    required this.docId,
    required this.label,
    required this.adminRef,
  });
  final String docId;
  final String label;
  final WidgetRef adminRef;

  @override
  State<_VerifyDocButton> createState() => _VerifyDocButtonState();
}

class _VerifyDocButtonState extends State<_VerifyDocButton> {
  bool _busy = false;

  Future<void> _verify() async {
    if (widget.docId.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.adminRef
          .read(adminRepositoryProvider)
          .verifyCompanyDocument(widget.docId);
      widget.adminRef.invalidate(pendingCompaniesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${widget.label} verified'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const SizedBox(
          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    }
    return GestureDetector(
      onTap: _verify,
      child: Tooltip(
        message: 'Mark as verified',
        child: Icon(Icons.check_circle_outline_rounded,
            size: 18, color: Colors.green.shade600),
      ),
    );
  }
}
