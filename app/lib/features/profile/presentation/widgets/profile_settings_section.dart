import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// A phone row that shows a phone number with an edit/add action.
class ProfileEditablePhoneRow extends StatelessWidget {
  const ProfileEditablePhoneRow({
    super.key,
    required this.phone,
    required this.isAnon,
    required this.onEdit,
    required this.cs,
  });

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
        child: Icon(Icons.phone_outlined, size: 18, color: cs.onSurfaceVariant),
      ),
      title: Text(
        l.phoneLabel,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      subtitle: Text(
        hasPhone ? phone! : 'Tap to add phone number',
        style: TextStyle(
          fontSize: hasPhone ? 15 : 13,
          fontWeight: hasPhone ? FontWeight.w500 : FontWeight.normal,
          color: hasPhone
              ? cs.onSurface
              : cs.onSurfaceVariant.withValues(alpha: 0.6),
          height: 1.3,
        ),
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

/// Upper-case section label used above card groups.
class ProfileSectionLabel extends StatelessWidget {
  const ProfileSectionLabel(this.text, {super.key});

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

/// Simple card wrapper for a list of child widgets.
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(children: children),
    );
  }
}

/// A read-only info row with an icon, label and value.
class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

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
      title: Text(
        label,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
      ),
    );
  }
}
