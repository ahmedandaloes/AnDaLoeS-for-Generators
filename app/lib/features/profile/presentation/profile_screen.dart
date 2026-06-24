import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../profile/data/repositories/profile_repository.dart';
import 'providers/profile_screen_providers.dart';
import 'widgets/profile_body_sliver.dart';
import 'widgets/profile_header_sliver.dart';
import 'widgets/profile_stats_section.dart' show ProfileSessionRow;


class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepo = ref.read(authRepositoryProvider);
    final cs = Theme.of(context).colorScheme;
    final profileAsync = ref.watch(profileDataProvider);

    // Auth state for display purposes only (no DB access)
    final currentUserAsync = ref.watch(currentUserProvider);
    final appUser = currentUserAsync.valueOrNull;
    final email = appUser?.email;
    final phone = profileAsync.valueOrNull?['phone']?.toString();
    final isAnon = authRepo.isCurrentUserAnonymous;
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
          ProfileHeaderSliver(
            isAnon: isAnon,
            displayName: displayName,
            initial: initial,
            avatarUrl: avatarUrl,
            role: profileAsync.valueOrNull?['role']?.toString() ?? 'customer',
            onUploadAvatar: () => _uploadAvatar(context, ref, cs),
            onEditName: () => _editName(context, ref, fullName ?? ''),
            cs: cs,
          ),

          // ── Settings body ────────────────────────────────────────
          ProfileBodySliver(
            onEditPhone: () => _editPhone(context, ref, phone ?? ''),
            onGuestUpgrade: () => _showGuestUpgrade(context, ref),
            onConfirmSignOut: (stats, createdAt) =>
                _confirmSignOut(context, ref, stats, createdAt),
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

    final uid = ref.read(authRepositoryProvider).currentUserId;
    if (uid == null) return;

    final ext = (file.extension ?? 'jpg').toLowerCase();

    try {
      await ref.read(profileRepositoryProvider).uploadAvatar(uid, bytes, ext);
      ref.invalidate(profileDataProvider);

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
      WidgetRef ref,
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
                        ProfileSessionRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Joined',
                            value: joinedLabel,
                            cs: cs),
                      if (totalRentals > 0) ...[
                        const SizedBox(height: 6),
                        ProfileSessionRow(
                            icon: Icons.receipt_outlined,
                            label: 'Rentals',
                            value: '$totalRentals',
                            cs: cs),
                      ],
                      if (totalSpent > 0) ...[
                        const SizedBox(height: 6),
                        ProfileSessionRow(
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
      await ref.read(profileRepositoryProvider).signOut();
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
    final uid = ref.read(authRepositoryProvider).currentUserId;
    if (uid == null) return;
    await ref.read(profileRepositoryProvider).updateProfile(
        uid, {'full_name': newName});
    ref.invalidate(profileDataProvider);
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
    final uid = ref.read(authRepositoryProvider).currentUserId;
    if (uid == null) return;
    await ref.read(profileRepositoryProvider).updateProfile(
        uid, {'phone': newPhone.isEmpty ? null : newPhone});
    ref.invalidate(profileDataProvider);
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
          await ref.read(profileRepositoryProvider).upgradeAnonymousAccount(
              email, pass);
          ref.invalidate(profileDataProvider);
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

