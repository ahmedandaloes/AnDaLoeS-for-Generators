import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../l10n/app_localizations.dart';

// Fetches the user's profile row (full_name, phone, role).
final _profileDataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return null;
  final data = await supabase
      .from('profiles')
      .select('full_name, phone, role')
      .eq('id', uid)
      .maybeSingle();
  return data;
});

// Customer rental statistics (total, active, completed).
final _rentalStatsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return {};
  final data = await supabase
      .from('rental_requests')
      .select('status')
      .eq('customer_id', uid);
  final list = (data as List).cast<Map<String, dynamic>>();
  return {
    'total': list.length,
    'active': list.where((r) => r['status'] == 'active').length,
    'completed': list.where((r) => r['status'] == 'completed').length,
    'pending': list.where((r) => r['status'] == 'pending').length,
  };
});

// Counts pending rental requests across all generators the user owns.
final _pendingRequestsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return 0;
  final data = await supabase
      .from('rental_requests')
      .select('id, generators!inner(company_id, companies!inner(owner_user_id))')
      .eq('status', 'pending')
      .eq('generators.companies.owner_user_id', uid);
  return (data as List).length;
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final user = supabase.auth.currentUser;
    final cs = Theme.of(context).colorScheme;
    final profileAsync = ref.watch(_profileDataProvider);
    final statsAsync = ref.watch(_rentalStatsProvider);
    final themeMode = ref.watch(themeModeProvider);

    final email = user?.email;
    final phone = user?.phone;
    final isAnon = user?.isAnonymous ?? false;
    final fullName = profileAsync.valueOrNull?['full_name']?.toString();
    final displayName = fullName?.isNotEmpty == true
        ? fullName!
        : (email ?? phone ?? (isAnon ? 'Guest' : 'User'));
    final initial = fullName?.isNotEmpty == true
        ? fullName![0].toUpperCase()
        : email?.isNotEmpty == true
            ? email![0].toUpperCase()
            : phone?.isNotEmpty == true
                ? phone![0]
                : '?';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Profile header ───────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.blurBackground],
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primaryContainer.withValues(alpha: 0.8),
                      cs.secondaryContainer.withValues(alpha: 0.5),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      // Avatar
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary,
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isAnon ? 'Guest user' : displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          if (!isAnon) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () =>
                                  _editName(context, ref, fullName ?? ''),
                              child: Icon(Icons.edit_outlined,
                                  size: 16,
                                  color: cs.onSurface.withValues(alpha: 0.5)),
                            ),
                          ],
                        ],
                      ),
                      if (isAnon)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.tertiaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Guest session',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onTertiaryContainer,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/'),
            ),
            title: Text(l.navProfile),
          ),

          // ── Settings sections ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Account info card
                  if (!isAnon && (email != null || phone != null)) ...[
                    _SectionLabel('Account'),
                    _Card(
                      children: [
                        if (email != null)
                          _InfoRow(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: email),
                        if (phone != null)
                          _InfoRow(
                              icon: Icons.phone_outlined,
                              label: 'Phone',
                              value: phone),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Rental stats (customers only)
                  if (!isAnon) ...[
                    statsAsync.maybeWhen(
                      data: (stats) {
                        if ((stats['total'] ?? 0) == 0) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel('Your stats'),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    cs.primaryContainer.withValues(alpha: 0.5),
                                    cs.secondaryContainer.withValues(alpha: 0.3),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _StatItem(
                                      value: '${stats['total']}',
                                      label: 'Total',
                                      cs: cs),
                                  _StatDivider(),
                                  _StatItem(
                                      value: '${stats['active']}',
                                      label: 'Active',
                                      cs: cs,
                                      highlight: (stats['active'] ?? 0) > 0),
                                  _StatDivider(),
                                  _StatItem(
                                      value: '${stats['completed']}',
                                      label: 'Completed',
                                      cs: cs),
                                  _StatDivider(),
                                  _StatItem(
                                      value: '${stats['pending']}',
                                      label: 'Pending',
                                      cs: cs),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],

                  // Preferences
                  _SectionLabel('Preferences'),
                  _Card(
                    children: [
                      // Dark mode toggle
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                themeMode == ThemeMode.dark
                                    ? Icons.dark_mode_outlined
                                    : themeMode == ThemeMode.light
                                        ? Icons.light_mode_outlined
                                        : Icons.brightness_auto_outlined,
                                size: 18,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('Appearance',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                            const Spacer(),
                            SegmentedButton<ThemeMode>(
                              style: SegmentedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                minimumSize: const Size(0, 36),
                              ),
                              segments: const [
                                ButtonSegment(
                                    value: ThemeMode.system,
                                    icon: Icon(Icons.brightness_auto, size: 16)),
                                ButtonSegment(
                                    value: ThemeMode.light,
                                    icon: Icon(Icons.light_mode, size: 16)),
                                ButtonSegment(
                                    value: ThemeMode.dark,
                                    icon: Icon(Icons.dark_mode, size: 16)),
                              ],
                              selected: {themeMode},
                              onSelectionChanged: (s) {
                                final mode = s.first;
                                // Defer to next frame to avoid widget-tree
                                // rebuild collision during SegmentedButton animation.
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  ref
                                      .read(themeModeProvider.notifier)
                                      .set(mode);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      Divider(
                          height: 1,
                          indent: 16,
                          color: cs.outlineVariant.withValues(alpha: 0.4)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.language_outlined,
                                  size: 18, color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(width: 12),
                            Text(l.language,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                            const Spacer(),
                            SegmentedButton<String>(
                              style: SegmentedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                minimumSize: const Size(0, 36),
                              ),
                              segments: [
                                ButtonSegment(
                                    value: 'ar', label: Text(l.arabic)),
                                ButtonSegment(
                                    value: 'en', label: Text(l.english)),
                              ],
                              selected: {
                                Localizations.localeOf(context)
                                    .languageCode,
                              },
                              onSelectionChanged: (s) {
                                final locale = Locale(s.first);
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  ref
                                      .read(localeProvider.notifier)
                                      .setLocale(locale);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Quick links
                  _SectionLabel('Activity'),
                  _Card(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.receipt_long_outlined,
                              size: 18, color: cs.primary),
                        ),
                        title: const Text('My Rentals',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        trailing: Icon(Icons.chevron_right,
                            color: cs.onSurfaceVariant),
                        onTap: () => context.push('/my-rentals'),
                      ),
                      Divider(
                          height: 1,
                          indent: 56,
                          color: cs.outlineVariant.withValues(alpha: 0.4)),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.dashboard_outlined,
                              size: 18, color: cs.onSecondaryContainer),
                        ),
                        title: const Text('Owner Dashboard',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text('Manage generators & requests',
                            style: TextStyle(fontSize: 12)),
                        trailing: ref
                            .watch(_pendingRequestsCountProvider)
                            .maybeWhen(
                              data: (n) => n == 0
                                  ? Icon(Icons.chevron_right,
                                      color: cs.onSurfaceVariant)
                                  : Badge(
                                      label: Text('$n'),
                                      child: Icon(Icons.chevron_right,
                                          color: cs.onSurfaceVariant),
                                    ),
                              orElse: () => Icon(Icons.chevron_right,
                                  color: cs.onSurfaceVariant),
                            ),
                        onTap: () => context.push('/owner-dashboard'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Admin panel (shown for all; access controlled inside)
                  _SectionLabel('Platform'),
                  _Card(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.admin_panel_settings_outlined,
                              size: 18, color: cs.error),
                        ),
                        title: const Text('Admin Panel',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text('Companies, stats, approvals',
                            style: TextStyle(fontSize: 12)),
                        trailing: Icon(Icons.chevron_right,
                            color: cs.onSurfaceVariant),
                        onTap: () => context.push('/admin'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Danger zone
                  _SectionLabel('Session'),
                  _Card(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.logout_rounded,
                              size: 18, color: cs.error),
                        ),
                        title: const Text(
                          'Sign out',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        trailing: Icon(Icons.chevron_right,
                            color: cs.onSurfaceVariant),
                        onTap: () async {
                          await supabase.auth.signOut();
                          if (context.mounted) context.go('/');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Your name',
            hintText: 'e.g. Ahmed Mostafa',
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty) return;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await supabase
        .from('profiles')
        .update({'full_name': newName}).eq('id', uid);
    ref.invalidate(_profileDataProvider);
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem(
      {required this.value,
      required this.label,
      required this.cs,
      this.highlight = false});
  final String value;
  final String label;
  final ColorScheme cs;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: highlight ? cs.primary : cs.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: VerticalDivider(
        color: Theme.of(context).colorScheme.outlineVariant,
        width: 1,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
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

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: cs.onSurfaceVariant),
      ),
      title: Text(label,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      subtitle: Text(value,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500, height: 1.3)),
    );
  }
}
