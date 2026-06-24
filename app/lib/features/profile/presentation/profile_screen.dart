import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FileOptions, UserAttributes;

import '../../../core/config/supabase.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../owner_dashboard/providers/owner_providers.dart' show myCompanyProvider;

// Fetches the user's profile row (full_name, phone, role).
final _profileDataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return null;
  final data = await supabase
      .from('profiles')
      .select('full_name, phone, role, avatar_url')
      .eq('id', uid)
      .maybeSingle();
  return data;
});

// Customer rental statistics (total, active, completed, spending).
final _rentalStatsProvider =
    FutureProvider.autoDispose<Map<String, num>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return {};
  final data = await supabase
      .from('rental_requests')
      .select('status, price_total, created_at')
      .eq('customer_id', uid);
  final list = (data as List).cast<Map<String, dynamic>>();

  final now = DateTime.now();
  final thisMonthStart = DateTime(now.year, now.month);
  final lastMonthStart = DateTime(now.year, now.month - 1);

  num totalSpent = 0;
  num thisMonthSpent = 0;
  num lastMonthSpent = 0;

  for (final r in list) {
    if (r['status'] == 'completed') {
      final price = (r['price_total'] as num?) ?? 0;
      totalSpent += price;
      try {
        final dt = DateTime.parse(r['created_at'].toString());
        if (!dt.isBefore(thisMonthStart)) {
          thisMonthSpent += price;
        } else if (!dt.isBefore(lastMonthStart)) {
          lastMonthSpent += price;
        }
      } catch (_) {}
    }
  }

  return {
    'total': list.length,
    'active':
        list.where((r) => r['status'] == 'active').length,
    'completed':
        list.where((r) => r['status'] == 'completed').length,
    'pending':
        list.where((r) => r['status'] == 'pending').length,
    'total_spent': totalSpent,
    'this_month_spent': thisMonthSpent,
    'last_month_spent': lastMonthSpent,
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
    final avatarUrl = profileAsync.valueOrNull?['avatar_url']?.toString();
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
                      // Avatar — tap to upload
                      GestureDetector(
                        onTap: isAnon
                            ? null
                            : () => _uploadAvatar(context, ref, cs),
                        child: Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
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
                                image: avatarUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(avatarUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: avatarUrl == null
                                  ? Center(
                                      child: Text(
                                        initial,
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                          color: cs.onPrimary,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            if (!isAnon)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: cs.surface, width: 2),
                                  ),
                                  child: Icon(Icons.camera_alt,
                                      size: 12, color: cs.onPrimary),
                                ),
                              ),
                          ],
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
                      // Role badge
                      if (!isAnon) Builder(builder: (_) {
                        final role = profileAsync.valueOrNull?['role']?.toString() ?? 'customer';
                        final roleConfig = switch (role) {
                          'admin' => (label: 'Admin', color: cs.error, icon: Icons.shield_outlined),
                          'owner' => (label: 'Owner', color: cs.secondary, icon: Icons.storefront_outlined),
                          _ => (label: 'Customer', color: cs.primary, icon: Icons.person_outline_rounded),
                        };
                        return Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: roleConfig.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: roleConfig.color.withValues(alpha: 0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(roleConfig.icon, size: 12, color: roleConfig.color),
                            const SizedBox(width: 5),
                            Text(roleConfig.label,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: roleConfig.color)),
                          ]),
                        );
                      }),
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
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
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
                  // Guest → registered upgrade CTA (keeps the same user + data)
                  if (isAnon) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.primary,
                            cs.primary.withValues(alpha: 0.82),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.workspace_premium_outlined,
                                color: cs.onPrimary, size: 20),
                            const SizedBox(width: 8),
                            Text(l.createYourAccount,
                                style: TextStyle(
                                    color: cs.onPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                          ]),
                          const SizedBox(height: 6),
                          Text(
                            "You're browsing as a guest. Create an account to keep your favorites, rentals and chats.",
                            style: TextStyle(
                                color: cs.onPrimary.withValues(alpha: 0.9),
                                fontSize: 13,
                                height: 1.35),
                          ),
                          const SizedBox(height: 14),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.onPrimary,
                              foregroundColor: cs.primary,
                              minimumSize: const Size.fromHeight(46),
                            ),
                            onPressed: () => _showGuestUpgrade(context, ref),
                            child: Text(l.createAccount),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // All-pages navigation hub (reach any screen for review/testing)
                  _Card(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.apps_rounded),
                        title: Text(l.allPages),
                        subtitle: Text(l.allPagesSubtitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.pageHub),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Account info card
                  if (!isAnon) ...[
                    _SectionLabel('Account'),
                    _Card(
                      children: [
                        if (email != null)
                          _InfoRow(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: email),
                        _EditablePhoneRow(
                          phone: phone,
                          isAnon: isAnon,
                          onEdit: () => _editPhone(context, ref, phone ?? ''),
                          cs: cs,
                        ),
                        Builder(builder: (_) {
                          final createdAt = user?.createdAt;
                          if (createdAt == null) return const SizedBox.shrink();
                          final dt = DateTime.tryParse(createdAt);
                          if (dt == null) return const SizedBox.shrink();
                          final label = '${dt.day}/${dt.month}/${dt.year}';
                          return _InfoRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Member since',
                              value: label);
                        }),
                        Builder(builder: (_) {
                          final lastSignIn = user?.lastSignInAt;
                          if (lastSignIn == null) return const SizedBox.shrink();
                          final dt = DateTime.tryParse(lastSignIn);
                          if (dt == null) return const SizedBox.shrink();
                          final diff = DateTime.now().difference(dt);
                          final ago = diff.inMinutes < 60
                              ? '${diff.inMinutes}m ago'
                              : diff.inHours < 24
                                  ? '${diff.inHours}h ago'
                                  : '${diff.inDays}d ago';
                          return _InfoRow(
                              icon: Icons.login_outlined,
                              label: 'Last sign in',
                              value: ago);
                        }),
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
                        final totalSpent =
                            (stats['total_spent'] ?? 0).toDouble();
                        final thisMonth =
                            (stats['this_month_spent'] ?? 0).toDouble();
                        final lastMonth =
                            (stats['last_month_spent'] ?? 0).toDouble();
                        final hasTrend =
                            totalSpent > 0 && lastMonth > 0;
                        final trendPct = hasTrend
                            ? ((thisMonth - lastMonth) /
                                    lastMonth *
                                    100)
                                .round()
                            : 0;
                        final trendUp = trendPct >= 0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel('Your stats'),
                            // Rental count row
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
                                      value: '${stats['total']?.toInt()}',
                                      label: 'Total',
                                      cs: cs),
                                  _StatDivider(),
                                  _StatItem(
                                      value: '${stats['active']?.toInt()}',
                                      label: 'Active',
                                      cs: cs,
                                      highlight:
                                          (stats['active'] ?? 0) > 0),
                                  _StatDivider(),
                                  _StatItem(
                                      value:
                                          '${stats['completed']?.toInt()}',
                                      label: 'Completed',
                                      cs: cs),
                                  _StatDivider(),
                                  _StatItem(
                                      value: '${stats['pending']?.toInt()}',
                                      label: 'Pending',
                                      cs: cs),
                                ],
                              ),
                            ),
                            // Spending card (only when there are completed rentals)
                            if (totalSpent > 0) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 14),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.payments_outlined,
                                        size: 18,
                                        color: Colors.green.shade700),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(l.totalSpent,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: cs.onSurfaceVariant)),
                                      Text(
                                        'EGP ${totalSpent.toStringAsFixed(0)}',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: cs.onSurface,
                                            letterSpacing: -0.5),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  if (hasTrend)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: trendUp
                                            ? Colors.red.withValues(alpha: 0.1)
                                            : Colors.green
                                                .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              trendUp
                                                  ? Icons.trending_up
                                                  : Icons.trending_down,
                                              size: 13,
                                              color: trendUp
                                                  ? Colors.red.shade600
                                                  : Colors.green.shade700,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${trendUp ? '+' : ''}$trendPct%',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: trendUp
                                                      ? Colors.red.shade600
                                                      : Colors.green.shade700),
                                            ),
                                          ]),
                                    ),
                                ]),
                              ),
                            ],
                            const SizedBox(height: 20),
                          ],
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],

                  // Customer tier badge
                  statsAsync.maybeWhen(
                    data: (stats) {
                      final spent =
                          (stats['total_spent'] ?? 0).toDouble();
                      if (spent <= 0) return const SizedBox.shrink();
                      final tier = spent >= 10000
                          ? (name: 'Gold', color: Colors.amber.shade700, icon: Icons.emoji_events_rounded)
                          : spent >= 3000
                              ? (name: 'Silver', color: Colors.blueGrey.shade500, icon: Icons.workspace_premium_rounded)
                              : (name: 'Bronze', color: Colors.brown.shade400, icon: Icons.military_tech_rounded);
                      final next = spent >= 10000
                          ? null
                          : spent >= 3000
                              ? 10000.0
                              : 3000.0;
                      final progress = next == null
                          ? 1.0
                          : spent >= 3000
                              ? (spent - 3000) / (10000 - 3000)
                              : spent / 3000;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel('Member tier'),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: tier.color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: tier.color.withValues(alpha: 0.3)),
                            ),
                            child: Row(children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: tier.color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(tier.icon,
                                    color: tier.color, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Text(tier.name,
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: tier.color)),
                                      const SizedBox(width: 6),
                                      Text(l.member,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: cs.onSurfaceVariant)),
                                    ]),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress.clamp(0.0, 1.0),
                                        minHeight: 6,
                                        backgroundColor: tier.color
                                            .withValues(alpha: 0.15),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                tier.color),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      next == null
                                          ? 'Maximum tier reached'
                                          : 'EGP ${(next - spent).toStringAsFixed(0)} to next tier',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),

                  // Referral code
                  if (!isAnon) ...[
                    _SectionLabel('Refer a friend'),
                    _ReferralCard(userId: user!.id, cs: cs),
                    const SizedBox(height: 20),
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
                            Text(l.appearance,
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
                        title: Text(l.myRentals,
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        trailing: Icon(Icons.chevron_right,
                            color: cs.onSurfaceVariant),
                        onTap: () => context.push(AppRoutes.myRentals),
                      ),
                      Divider(
                          height: 1,
                          indent: 56,
                          color: cs.outlineVariant.withValues(alpha: 0.4)),
                      Builder(builder: (_) {
                        final role = profileAsync.valueOrNull?['role']?.toString() ?? 'customer';
                        if (role == 'customer') {
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.storefront_outlined,
                                  size: 18, color: Colors.orange.shade700),
                            ),
                            title: Text(l.listYourGenerator,
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(l.listYourGeneratorSubtitle,
                                style: TextStyle(fontSize: 12)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade600,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(l.start,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ),
                            onTap: () => context.push(AppRoutes.ownerDashboard),
                          );
                        }
                        return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.dashboard_outlined,
                              size: 18, color: cs.onSecondaryContainer),
                        ),
                        title: Text(l.ownerDashboard,
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(l.ownerDashboardSubtitle,
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
                        onTap: () => context.push(AppRoutes.ownerDashboard),
                      );
                      }),
                      // View Company Profile — owners only
                      Builder(builder: (_) {
                        final role = profileAsync.valueOrNull?['role']?.toString() ?? 'customer';
                        if (role != 'owner' && role != 'admin') return const SizedBox.shrink();
                        return ref.watch(myCompanyProvider).maybeWhen(
                          data: (company) {
                            if (company == null) return const SizedBox.shrink();
                            final cid = company['id']?.toString() ?? '';
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Divider(height: 1, indent: 56,
                                    color: cs.outlineVariant.withValues(alpha: 0.4)),
                                ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: cs.tertiaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.storefront_outlined,
                                        size: 18, color: cs.onTertiaryContainer),
                                  ),
                                  title: Text(company['name']?.toString() ?? 'My Company',
                                      style: const TextStyle(fontWeight: FontWeight.w500)),
                                  subtitle: Text(l.publicCompanyPage,
                                      style: TextStyle(fontSize: 12)),
                                  trailing: Icon(Icons.open_in_new_rounded,
                                      size: 16, color: cs.onSurfaceVariant),
                                  onTap: () => context.push(AppRoutes.companyProfile(cid)),
                                ),
                              ],
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        );
                      }),
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
                        title: Text(l.adminPanel,
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(l.adminPanelSubtitle,
                            style: TextStyle(fontSize: 12)),
                        trailing: Icon(Icons.chevron_right,
                            color: cs.onSurfaceVariant),
                        onTap: () => context.push(AppRoutes.admin),
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
                        title: Text(
                          l.signOut,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        trailing: Icon(Icons.chevron_right,
                            color: cs.onSurfaceVariant),
                        onTap: () => _confirmSignOut(
                            context,
                            statsAsync.valueOrNull,
                            supabase.auth.currentUser?.createdAt),
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

  Future<void> _uploadAvatar(
      BuildContext context, WidgetRef ref, ColorScheme cs) async {
    final l = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    final ext = (file.extension ?? 'jpg').toLowerCase();
    final storagePath = '$uid/avatar.$ext';

    try {
      await supabase.storage.from('avatars').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$ext',
              upsert: true,
            ),
          );

      final publicUrl =
          supabase.storage.from('avatars').getPublicUrl(storagePath);

      await supabase
          .from('profiles')
          .update({'avatar_url': publicUrl}).eq('id', uid);

      ref.invalidate(_profileDataProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.profilePhotoUpdated),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.uploadFailed)),
        );
      }
    }
  }

  Future<void> _confirmSignOut(
      BuildContext context,
      Map<String, num>? stats,
      String? createdAt) async {
    final totalRentals = (stats?['total'] ?? 0).toInt();
    final totalSpent = stats?['total_spent'] ?? 0;

    String? joinedLabel;
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt);
        joinedLabel = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final l = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l.signOutQuestion),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (joinedLabel != null || totalRentals > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (joinedLabel != null)
                        _SessionRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Joined',
                            value: joinedLabel,
                            cs: cs),
                      if (totalRentals > 0) ...[
                        const SizedBox(height: 6),
                        _SessionRow(
                            icon: Icons.receipt_outlined,
                            label: 'Rentals',
                            value: '$totalRentals',
                            cs: cs),
                      ],
                      if (totalSpent > 0) ...[
                        const SizedBox(height: 6),
                        _SessionRow(
                            icon: Icons.payments_outlined,
                            label: 'Total spent',
                            value: 'EGP ${totalSpent.toStringAsFixed(0)}',
                            cs: cs),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(l.signOutBody),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.stay),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: cs.error),
              child: Text(l.signOut),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await supabase.auth.signOut();
      if (context.mounted) context.go(AppRoutes.home);
    }
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, String current) async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: current);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.displayName),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l.yourName,
            hintText: l.yourNameHint,
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: Text(l.save),
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

  Future<void> _editPhone(
      BuildContext context, WidgetRef ref, String current) async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: current);
    final newPhone = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.phoneLabel),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: l.phoneLabel,
            hintText: l.phoneHintNumber,
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: Text(l.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newPhone == null) return;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await supabase
        .from('profiles')
        .update({'phone': newPhone.isEmpty ? null : newPhone})
        .eq('id', uid);
    ref.invalidate(_profileDataProvider);
  }
}

/// Converts the current anonymous (guest) session into a permanent email +
/// password account. Supabase keeps the SAME user id, so the guest's favorites,
/// rentals and chats carry over. Email confirmation applies if the project
/// requires it (the user simply confirms via the emailed link, then signs in).
Future<void> _showGuestUpgrade(BuildContext context, WidgetRef ref) async {
  final emailC = TextEditingController();
  final passC = TextEditingController();
  var loading = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) => StatefulBuilder(builder: (sheetCtx, setSheet) {
      final cs = Theme.of(sheetCtx).colorScheme;
      final l = AppLocalizations.of(sheetCtx)!;
      Future<void> submit() async {
        final email = emailC.text.trim();
        final pass = passC.text;
        if (!email.contains('@') || pass.length < 6) {
          ScaffoldMessenger.of(sheetCtx).showSnackBar(const SnackBar(
              content: Text(
                  'Enter a valid email and a password of at least 6 characters.')));
          return;
        }
        setSheet(() => loading = true);
        try {
          await supabase.auth.updateUser(
              UserAttributes(email: email, password: pass));
          ref.invalidate(_profileDataProvider);
          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Account created — check your email to confirm. Your data is saved.')));
          }
        } catch (e) {
          setSheet(() => loading = false);
          if (sheetCtx.mounted) {
            ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(
                content: Text(l.couldNotCreateAccount)));
          }
        }
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.createYourAccount,
                style: Theme.of(sheetCtx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l.createAccountKeep,
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            TextField(
              controller: emailC,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passC,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: loading ? null : submit,
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l.createAccount),
            ),
          ],
        ),
      );
    }),
  );
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

class _SessionRow extends StatelessWidget {
  const _SessionRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.cs});
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: cs.onSurfaceVariant),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _EditablePhoneRow extends StatelessWidget {
  const _EditablePhoneRow(
      {required this.phone,
      required this.isAnon,
      required this.onEdit,
      required this.cs});
  final String? phone;
  final bool isAnon;
  final VoidCallback onEdit;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final hasPhone = phone != null && phone!.isNotEmpty;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.phone_outlined,
            size: 18, color: cs.onSurfaceVariant),
      ),
      title: Text(l.phoneLabel,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      subtitle: Text(
        hasPhone ? phone! : 'Tap to add phone number',
        style: TextStyle(
            fontSize: hasPhone ? 15 : 13,
            fontWeight:
                hasPhone ? FontWeight.w500 : FontWeight.normal,
            color: hasPhone
                ? cs.onSurface
                : cs.onSurfaceVariant.withValues(alpha: 0.6),
            height: 1.3),
      ),
      trailing: !isAnon
          ? IconButton(
              icon: Icon(
                hasPhone ? Icons.edit_outlined : Icons.add_rounded,
                size: 18,
                color: cs.primary,
              ),
              onPressed: onEdit,
              tooltip: hasPhone ? 'Edit phone' : 'Add phone',
            )
          : null,
      onTap: isAnon ? null : onEdit,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
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

// ── Referral card ─────────────────────────────────────────────────────────────
class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.userId, required this.cs});
  final String userId;
  final ColorScheme cs;

  String get _code =>
      'AL-${userId.replaceAll('-', '').substring(0, 6).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final code = _code;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withValues(alpha: 0.8),
            cs.secondaryContainer.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.card_giftcard_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(l.yourReferralCode,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.primary)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: cs.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(l.referralCodeCopied),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 2),
                ));
              },
              icon: const Icon(Icons.copy_outlined, size: 18),
              tooltip: 'Copy code',
            ),
            IconButton.filled(
              onPressed: () => Share.share(
                'Join AnDaLoeS for Generators — Egypt\'s generator rental marketplace.'
                '\n\nUse my referral code $code when you sign up!',
                subject: 'AnDaLoeS Referral',
              ),
              style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white),
              icon: const Icon(Icons.share_outlined, size: 18),
              tooltip: 'Share',
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            'Share with friends and get rewarded when they complete their first rental.',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }
}
