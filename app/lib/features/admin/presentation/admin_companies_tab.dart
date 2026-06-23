import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';

final pendingCompaniesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('companies')
      .select('*, profiles!owner_user_id(full_name, phone)')
      .inFilter('verification_status', ['pending', 'under_review']).order(
          'created_at');
  return (data as List).cast<Map<String, dynamic>>();
});

class AdminCompaniesTab extends StatelessWidget {
  const AdminCompaniesTab({super.key, required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final companiesAsync = ref.watch(pendingCompaniesProvider);
    final cs = Theme.of(context).colorScheme;

    return companiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (companies) {
        if (companies.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 48, color: Colors.green),
                const SizedBox(height: 16),
                const Text('No pending companies'),
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
    setState(() => _loading = true);
    try {
      await supabase.from('companies').update({
        'verification_status': 'approved',
        'reviewed_by': supabase.auth.currentUser!.id,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.company['id'].toString());
      widget.ref.invalidate(pendingCompaniesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a rejection reason')));
      return;
    }
    setState(() => _loading = true);
    try {
      await supabase.from('companies').update({
        'verification_status': 'rejected',
        'rejection_reason': reason,
        'reviewed_by': supabase.auth.currentUser!.id,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.company['id'].toString());
      widget.ref.invalidate(pendingCompaniesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
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
              final docs = (company['document_urls'] as List? ?? [])
                  .cast<String>();
              if (docs.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: docs.map((path) {
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
                            final res = await supabase.storage
                                .from('company-docs')
                                .createSignedUrl(path, 300);
                            await Clipboard.setData(
                                ClipboardData(text: res));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('$label URL copied to clipboard'),
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
                decoration: const InputDecoration(
                  labelText: 'Rejection reason',
                  hintText: 'Tell the owner why they were rejected…',
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
                      child: const Text('Reject'),
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
                          : const Text('Approve'),
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
                      child: const Text('Cancel'),
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
                          : const Text('Confirm reject'),
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
