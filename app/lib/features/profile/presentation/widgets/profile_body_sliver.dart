import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/locale_provider.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../owner_dashboard/providers/owner_providers.dart' show myCompanyProvider;
import '../providers/profile_screen_providers.dart';
import 'profile_referral_card.dart';
import 'profile_settings_section.dart';
import 'profile_stats_section.dart';

/// The scrollable settings body of the profile screen.
/// Owns all sections: account info, stats, tier, referral, preferences, activity, session.
class ProfileBodySliver extends ConsumerWidget {
  const ProfileBodySliver({
    super.key,
    required this.onEditPhone,
    required this.onGuestUpgrade,
    required this.onConfirmSignOut,
  });

  final VoidCallback onEditPhone;
  final VoidCallback onGuestUpgrade;
  final void Function(Map<String, num>? stats, String? createdAt) onConfirmSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final authRepo = ref.read(authRepositoryProvider);
    final cs = Theme.of(context).colorScheme;
    final profileAsync = ref.watch(profileDataProvider);
    final statsAsync = ref.watch(rentalStatsProvider);
    final themeMode = ref.watch(themeModeProvider);

    final isAnon = authRepo.isCurrentUserAnonymous;
    final email = profileAsync.valueOrNull?['email']?.toString();
    final phone = profileAsync.valueOrNull?['phone']?.toString();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Guest → registered upgrade CTA
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
                      onPressed: onGuestUpgrade,
                      child: Text(l.createAccount),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            // All-pages navigation hub
            ProfileCard(
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
              ProfileSectionLabel(l.accountSection),
              ProfileCard(
                children: [
                  if (email != null)
                    ProfileInfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: email),
                  ProfileEditablePhoneRow(
                    phone: phone,
                    isAnon: isAnon,
                    onEdit: onEditPhone,
                    cs: cs,
                  ),
                  Builder(builder: (_) {
                    final createdAt = authRepo.currentUserCreatedAt;
                    if (createdAt == null) return const SizedBox.shrink();
                    final dt = DateTime.tryParse(createdAt);
                    if (dt == null) return const SizedBox.shrink();
                    final label = '${dt.day}/${dt.month}/${dt.year}';
                    return ProfileInfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Member since',
                        value: label);
                  }),
                  Builder(builder: (_) {
                    final lastSignIn = authRepo.currentUserLastSignInAt;
                    if (lastSignIn == null) return const SizedBox.shrink();
                    final dt = DateTime.tryParse(lastSignIn);
                    if (dt == null) return const SizedBox.shrink();
                    final diff = DateTime.now().difference(dt);
                    final ago = diff.inMinutes < 60
                        ? '${diff.inMinutes}m ago'
                        : diff.inHours < 24
                            ? '${diff.inHours}h ago'
                            : '${diff.inDays}d ago';
                    return ProfileInfoRow(
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
                  if ((stats['total'] ?? 0) == 0) return const SizedBox.shrink();
                  final totalSpent = (stats['total_spent'] ?? 0).toDouble();
                  final thisMonth = (stats['this_month_spent'] ?? 0).toDouble();
                  final lastMonth = (stats['last_month_spent'] ?? 0).toDouble();
                  final hasTrend = totalSpent > 0 && lastMonth > 0;
                  final trendPct = hasTrend
                      ? ((thisMonth - lastMonth) / lastMonth * 100).round()
                      : 0;
                  final trendUp = trendPct >= 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProfileSectionLabel('Your stats'),
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
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            ProfileStatItem(
                                value: '${stats['total']?.toInt()}',
                                label: 'Total',
                                cs: cs),
                            ProfileStatDivider(),
                            ProfileStatItem(
                                value: '${stats['active']?.toInt()}',
                                label: 'Active',
                                cs: cs,
                                highlight: (stats['active'] ?? 0) > 0),
                            ProfileStatDivider(),
                            ProfileStatItem(
                                value: '${stats['completed']?.toInt()}',
                                label: 'Completed',
                                cs: cs),
                            ProfileStatDivider(),
                            ProfileStatItem(
                                value: '${stats['pending']?.toInt()}',
                                label: 'Pending',
                                cs: cs),
                          ],
                        ),
                      ),
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
                                  size: 18, color: Colors.green.shade700),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                      : Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
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
                final spent = (stats['total_spent'] ?? 0).toDouble();
                if (spent <= 0) return const SizedBox.shrink();
                final tier = spent >= 10000
                    ? (
                        name: 'Gold',
                        color: Colors.amber.shade700,
                        icon: Icons.emoji_events_rounded,
                      )
                    : spent >= 3000
                        ? (
                            name: 'Silver',
                            color: Colors.blueGrey.shade500,
                            icon: Icons.workspace_premium_rounded,
                          )
                        : (
                            name: 'Bronze',
                            color: Colors.brown.shade400,
                            icon: Icons.military_tech_rounded,
                          );
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
                    ProfileSectionLabel('Member tier'),
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
                          child: Icon(tier.icon, color: tier.color, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  minHeight: 6,
                                  backgroundColor:
                                      tier.color.withValues(alpha: 0.15),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(tier.color),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                next == null
                                    ? 'Maximum tier reached'
                                    : 'EGP ${(next - spent).toStringAsFixed(0)} to next tier',
                                style: TextStyle(
                                    fontSize: 10, color: cs.onSurfaceVariant),
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
              ProfileSectionLabel('Refer a friend'),
              ProfileReferralCard(userId: authRepo.currentUserId!, cs: cs),
              const SizedBox(height: 20),
            ],

            // Preferences
            ProfileSectionLabel('Preferences'),
            ProfileCard(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      Expanded(
                        child: Text(l.appearance,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<ThemeMode>(
                        style: SegmentedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
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
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            ref.read(themeModeProvider.notifier).set(mode);
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              fontSize: 15, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      SegmentedButton<String>(
                        style: SegmentedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 36),
                        ),
                        segments: [
                          ButtonSegment(
                              value: 'ar', label: Text(l.arabic)),
                          ButtonSegment(
                              value: 'en', label: Text(l.english)),
                        ],
                        selected: {
                          Localizations.localeOf(context).languageCode,
                        },
                        onSelectionChanged: (s) {
                          final locale = Locale(s.first);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
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
            ProfileSectionLabel('Activity'),
            ProfileCard(
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
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: Icon(Icons.chevron_right,
                      color: cs.onSurfaceVariant),
                  onTap: () => context.push(AppRoutes.myRentals),
                ),
                Divider(
                    height: 1,
                    indent: 56,
                    color: cs.outlineVariant.withValues(alpha: 0.4)),
                Builder(builder: (_) {
                  final role = profileAsync.valueOrNull?['role']?.toString() ??
                      'customer';
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
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(l.listYourGeneratorSubtitle,
                          style: const TextStyle(fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(l.start,
                            style: const TextStyle(
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
                        style:
                            const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(l.ownerDashboardSubtitle,
                        style: const TextStyle(fontSize: 12)),
                    trailing: ref
                        .watch(pendingRequestsCountProvider)
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
                Builder(builder: (_) {
                  final role = profileAsync.valueOrNull?['role']?.toString() ??
                      'customer';
                  if (role != 'owner' && role != 'admin') {
                    return const SizedBox.shrink();
                  }
                  return ref.watch(myCompanyProvider).maybeWhen(
                    data: (company) {
                      if (company == null) return const SizedBox.shrink();
                      final cid = company['id']?.toString() ?? '';
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Divider(
                              height: 1,
                              indent: 56,
                              color: cs.outlineVariant.withValues(alpha: 0.4)),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cs.tertiaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.storefront_outlined,
                                  size: 18,
                                  color: cs.onTertiaryContainer),
                            ),
                            title: Text(
                                company['name']?.toString() ?? 'My Company',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                            subtitle: Text(l.publicCompanyPage,
                                style: const TextStyle(fontSize: 12)),
                            trailing: Icon(Icons.open_in_new_rounded,
                                size: 16, color: cs.onSurfaceVariant),
                            onTap: () =>
                                context.push(AppRoutes.companyProfile(cid)),
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

            // Admin panel
            ProfileSectionLabel('Platform'),
            ProfileCard(
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
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(l.adminPanelSubtitle,
                      style: const TextStyle(fontSize: 12)),
                  trailing: Icon(Icons.chevron_right,
                      color: cs.onSurfaceVariant),
                  onTap: () => context.push(AppRoutes.admin),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Session / sign-out
            ProfileSectionLabel('Session'),
            ProfileCard(
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
                  onTap: () => onConfirmSignOut(
                    statsAsync.valueOrNull,
                    authRepo.currentUserCreatedAt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
