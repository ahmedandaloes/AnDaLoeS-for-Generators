import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/supabase.dart';
import '../routing/app_routes.dart';

/// Sample ids used to reach parameterised routes (generator/rental/company),
/// so every page is openable from the hub even when it needs an id.
final _hubSamplesProvider =
    FutureProvider.autoDispose<Map<String, String?>>((ref) async {
  Future<String?> first(String table, String filterColumn) async {
    try {
      final rows = await supabase.from(table).select('id').limit(1);
      final list = (rows as List).cast<Map<String, dynamic>>();
      return list.isEmpty ? null : list.first['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  final uid = supabase.auth.currentUser?.id;
  String? companyId;
  if (uid != null) {
    try {
      final c = await supabase
          .from('companies')
          .select('id')
          .eq('owner_user_id', uid)
          .maybeSingle();
      companyId = c?['id']?.toString();
    } catch (_) {}
  }
  companyId ??= await first('companies', 'id');

  return {
    'generator': await first('generators', 'id'),
    'rental': await first('rental_requests', 'id'),
    'company': companyId,
  };
});

/// A navigation hub / sitemap: links to EVERY page in the app, grouped by area.
/// Reachable from the profile screen so any screen can be opened directly for
/// review or testing — including role/data-gated ones.
class PageHubScreen extends ConsumerWidget {
  const PageHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final samples = ref.watch(_hubSamplesProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('All Pages')),
      body: samples.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildList(context, ref, cs, const {}),
        data: (s) => _buildList(context, ref, cs, s),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, ColorScheme cs,
      Map<String, String?> s) {
    final genId = s['generator'];
    final rentalId = s['rental'];
    final companyId = s['company'];

    final sections = <String, List<_HubLink>>{
      'Browse & discovery': [
        _HubLink('Home / browse', AppRoutes.home),
        _HubLink('Map view', AppRoutes.map),
        _HubLink('Generator detail', genId == null ? null : AppRoutes.generatorDetail(genId),
            need: 'a generator'),
        _HubLink('Company profile', companyId == null ? null : AppRoutes.companyProfile(companyId),
            need: 'a company'),
      ],
      'Booking & rentals': [
        _HubLink('Rental request', genId == null ? null : AppRoutes.generatorRequest(genId),
            need: 'a generator'),
        _HubLink('My rentals', AppRoutes.myRentals),
        _HubLink('Receipt', rentalId == null ? null : AppRoutes.receipt(rentalId), need: 'a rental'),
        _HubLink('Rental offer', rentalId == null ? null : AppRoutes.offer(rentalId), need: 'a rental'),
        _HubLink('Tax invoice', rentalId == null ? null : AppRoutes.invoice(rentalId), need: 'a rental'),
        _HubLink('Rate rental', rentalId == null
            ? null
            : AppRoutes.rate(rentalId, rateeId: '', rateeName: 'User'), need: 'a rental'),
        _HubLink('Chat', rentalId == null
            ? null
            : AppRoutes.chat(rentalId, otherName: 'User'), need: 'a rental'),
      ],
      'Owner': [
        _HubLink('Owner dashboard', AppRoutes.ownerDashboard),
        _HubLink('Company onboarding', AppRoutes.companyOnboard),
        _HubLink('Add generator', companyId == null ? null : AppRoutes.addGenerator(companyId),
            need: 'a company'),
        _HubLink('Edit generator', genId == null ? null : AppRoutes.editGenerator(genId),
            need: 'a generator'),
        _HubLink('Owner earnings', companyId == null ? null : AppRoutes.ownerEarnings(companyId),
            need: 'a company'),
      ],
      'Admin': [
        _HubLink('Admin panel', AppRoutes.admin),
      ],
      'Account & system': [
        _HubLink('Profile', AppRoutes.profile),
        _HubLink('Notifications', AppRoutes.notifications),
        _HubLink('Report a problem', AppRoutes.report(type: 'company', id: companyId ?? '')),
        _HubLink('Onboarding splash', AppRoutes.onboarding),
        _HubLink('Login (phone)', AppRoutes.login),
        _HubLink('Email sign-in / sign-up', AppRoutes.emailAuth),
      ],
    };

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final entry in sections.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(entry.key.toUpperCase(),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: cs.onSurfaceVariant)),
          ),
          ...entry.value.map((link) => ListTile(
                title: Text(link.label),
                subtitle: link.path == null
                    ? Text('Needs ${link.need} to open',
                        style: TextStyle(color: cs.error, fontSize: 12))
                    : Text(link.path!,
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 12)),
                trailing: Icon(Icons.chevron_right,
                    color: link.path == null
                        ? cs.outlineVariant
                        : cs.onSurfaceVariant),
                enabled: link.path != null,
                onTap: link.path == null
                    ? null
                    : () => context.push(link.path!),
              )),
        ],
      ],
    );
  }
}

class _HubLink {
  const _HubLink(this.label, this.path, {this.need = 'data'});
  final String label;
  final String? path;
  final String need;
}
