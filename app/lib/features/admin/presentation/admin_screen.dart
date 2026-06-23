import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';

// ── Role guard ────────────────────────────────────────────────────────────────

final _isAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return false;
  final data = await supabase
      .from('profiles')
      .select('role')
      .eq('id', uid)
      .single();
  return data['role'] == 'admin';
});

// ── Data providers ─────────────────────────────────────────────────────────────

final _pendingCompaniesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('companies')
      .select('*, profiles!owner_user_id(full_name, phone)')
      .inFilter('verification_status', ['pending', 'under_review']).order(
          'created_at');
  return (data as List).cast<Map<String, dynamic>>();
});


final _openReportsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('reports')
      .select('*')
      .inFilter('status', ['open', 'under_review']).order('created_at');
  return (data as List).cast<Map<String, dynamic>>();
});

final _platformStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final users = await supabase.from('profiles').select('id');
  final generators = await supabase.from('generators').select('id');
  final rentals = await supabase.from('rental_requests').select('id, status');
  final commissions =
      await supabase.from('commissions').select('commission_amount, status');

  final rentalList = (rentals as List).cast<Map<String, dynamic>>();
  final commissionList =
      (commissions as List).cast<Map<String, dynamic>>();

  final completed =
      rentalList.where((r) => r['status'] == 'completed').length;
  final totalCommissions = commissionList.fold<double>(
      0,
      (s, c) =>
          s +
          (double.tryParse(
                  c['commission_amount']?.toString() ?? '0') ??
              0));

  return {
    'users': (users as List).length,
    'generators': (generators as List).length,
    'total_rentals': rentalList.length,
    'completed_rentals': completed,
    'total_commission_earned': totalCommissions,
  };
});

// ── Screen ────────────────────────────────────────────────────────────────────

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(_isAdminProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined,
                    size: 13, color: cs.onErrorContainer),
                const SizedBox(width: 4),
                Text('Admin',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.onErrorContainer)),
              ],
            ),
          ),
        ],
      ),
      body: isAdminAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (isAdmin) {
          if (!isAdmin) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 48, color: cs.error),
                  const SizedBox(height: 16),
                  const Text('Access denied',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Admin access required.',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }
          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(tabs: [
                  Tab(text: 'Companies'),
                  Tab(text: 'Reports'),
                  Tab(text: 'Stats'),
                ]),
                Expanded(
                  child: TabBarView(
                    children: [
                      _CompaniesTab(ref: ref),
                      _ReportsTab(ref: ref),
                      _StatsTab(ref: ref),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Companies tab ─────────────────────────────────────────────────────────────

class _CompaniesTab extends StatelessWidget {
  const _CompaniesTab({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final companiesAsync = ref.watch(_pendingCompaniesProvider);
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
          onRefresh: () =>
              ref.refresh(_pendingCompaniesProvider.future),
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
      widget.ref.invalidate(_pendingCompaniesProvider);
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
      widget.ref.invalidate(_pendingCompaniesProvider);
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
    final owner =
        company['profiles'] as Map<String, dynamic>?;
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
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
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurfaceVariant),
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
                    owner['full_name'] ??
                        owner['phone'] ??
                        'Owner',
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
                  style: TextStyle(
                      fontSize: 13, color: cs.onSurfaceVariant)),
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
            // Document links
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
                      }[docType] ?? filename;
                      return ActionChip(
                        avatar: const Icon(Icons.description_outlined, size: 14),
                        label: Text(label, style: const TextStyle(fontSize: 11)),
                        onPressed: () async {
                          try {
                            final res = await supabase.storage
                                .from('company-docs')
                                .createSignedUrl(path, 300);
                            await Clipboard.setData(ClipboardData(text: res));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$label URL copied to clipboard'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                  action: SnackBarAction(
                                    label: 'Open',
                                    onPressed: () async {
                                      // Users can open from browser after copying.
                                    },
                                  ),
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
                          : () =>
                              setState(() => _showReject = true),
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
                      onPressed: () =>
                          setState(() => _showReject = false),
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
                                  strokeWidth: 2,
                                  color: Colors.white))
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

// ── Stats tab ─────────────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  const _StatsTab({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(_platformStatsProvider);
    final cs = Theme.of(context).colorScheme;

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (stats) => RefreshIndicator(
        onRefresh: () => ref.refresh(_platformStatsProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            Text('PLATFORM OVERVIEW',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            _StatGrid(stats: stats, cs: cs),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Commission earned',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'EGP ${(stats['total_commission_earned'] as double).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'from ${stats['completed_rentals']} completed rentals',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats, required this.cs});
  final Map<String, dynamic> stats;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Users', '${stats['users']}', Icons.people_outline, cs.primary),
      ('Generators', '${stats['generators']}', Icons.bolt,
          cs.secondary),
      ('Total rentals', '${stats['total_rentals']}',
          Icons.receipt_long_outlined, cs.tertiary),
      ('Completed', '${stats['completed_rentals']}',
          Icons.check_circle_outline, Colors.green.shade700),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: items
          .map((item) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(item.$3,
                          size: 20,
                          color: item.$4
                              .withValues(alpha: 0.7)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$2,
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: item.$4,
                                  letterSpacing: -1)),
                          Text(item.$1,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ── Reports tab ───────────────────────────────────────────────────────────────

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({required this.ref});
  final WidgetRef ref;

  static const _reasonLabels = {
    'misrepresentation': 'Misrepresentation',
    'no_show': 'No-show',
    'damage': 'Property damage',
    'fraud': 'Fraud / scam',
    'harassment': 'Harassment',
    'other': 'Other',
  };

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(_openReportsProvider);
    final cs = Theme.of(context).colorScheme;

    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (reports) {
        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                const SizedBox(height: 12),
                const Text('No open reports', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text('All clear!',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(_openReportsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final r = reports[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _reasonLabels[r['reason']] ?? r['reason'],
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onErrorContainer),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.tertiaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              r['reported_entity_type']?.toString().toUpperCase() ?? '',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onTertiaryContainer),
                            ),
                          ),
                        ],
                      ),
                      if (r['description'] != null) ...[
                        const SizedBox(height: 8),
                        Text(r['description'],
                            style: const TextStyle(fontSize: 13)),
                      ],
                      const SizedBox(height: 10),
                      Row(children: [
                        Icon(Icons.access_time,
                            size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(_fmtDate(r['created_at']),
                            style: TextStyle(
                                fontSize: 11, color: cs.onSurfaceVariant)),
                        const Spacer(),
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _dismiss(ctx, r['id']),
                          child: const Text('Dismiss',
                              style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _resolve(ctx, r['id']),
                          child: const Text('Resolve',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ]),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _dismiss(BuildContext ctx, String id) async {
    await supabase
        .from('reports')
        .update({'status': 'dismissed'}).eq('id', id);
    ref.invalidate(_openReportsProvider);
  }

  Future<void> _resolve(BuildContext ctx, String id) async {
    await supabase
        .from('reports')
        .update({'status': 'resolved'}).eq('id', id);
    ref.invalidate(_openReportsProvider);
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
