import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../l10n/app_localizations.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(l.navProfile)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.phone),
            title: Text(user?.phone ?? '-'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.language),
            trailing: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'ar', label: Text(l.arabic)),
                ButtonSegment(value: 'en', label: Text(l.english)),
              ],
              selected: {
                Localizations.localeOf(context).languageCode,
              },
              onSelectionChanged: (s) => ref
                  .read(localeProvider.notifier)
                  .setLocale(Locale(s.first)),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => supabase.auth.signOut(),
          ),
        ],
      ),
    );
  }
}
