import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../l10n/app_localizations.dart';

/// The expandable SliverAppBar shown at the top of the profile screen.
/// Displays the user's avatar, name, role badge, and edit affordances.
class ProfileHeaderSliver extends StatelessWidget {
  const ProfileHeaderSliver({
    super.key,
    required this.isAnon,
    required this.displayName,
    required this.initial,
    required this.avatarUrl,
    required this.role,
    required this.onUploadAvatar,
    required this.onEditName,
    required this.cs,
  });

  final bool isAnon;
  final String displayName;
  final String initial;
  final String? avatarUrl;
  final String role;
  final VoidCallback? onUploadAvatar;
  final VoidCallback? onEditName;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SliverAppBar(
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
                GestureDetector(
                  onTap: isAnon ? null : onUploadAvatar,
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
                                  image: CachedNetworkImageProvider(avatarUrl!),
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
                              border: Border.all(color: cs.surface, width: 2),
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
                        onTap: onEditName,
                        child: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!isAnon) _RoleBadge(role: role, cs: cs),
                if (isAnon)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Guest session',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onTertiaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: l.back,
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.home),
      ),
      title: Text(l.navProfile),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.cs});

  final String role;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final roleConfig = switch (role) {
      'admin' => (
          label: 'Admin',
          color: cs.error,
          icon: Icons.shield_outlined,
        ),
      'owner' => (
          label: 'Owner',
          color: cs.secondary,
          icon: Icons.storefront_outlined,
        ),
      _ => (
          label: 'Customer',
          color: cs.primary,
          icon: Icons.person_outline_rounded,
        ),
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
        Text(
          roleConfig.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: roleConfig.color,
          ),
        ),
      ]),
    );
  }
}
