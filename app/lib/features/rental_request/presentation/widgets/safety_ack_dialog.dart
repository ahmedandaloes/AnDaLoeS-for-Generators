import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SafetyAckDialog extends StatelessWidget {
  const SafetyAckDialog({super.key});

  /// Shows the dialog once per install. Returns true if user agreed.
  static Future<bool> checkAndShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('safety_ack_shown') == true) return true;
    if (!context.mounted) return false;
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SafetyAckDialog(),
    );
    if (agreed == true) {
      await prefs.setBool('safety_ack_shown', true);
    }
    return agreed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: cs.error, size: 40),
      title: const Text('Safety Notice'),
      content: const Text(
        'Generators must ALWAYS be operated outdoors in well-ventilated areas.\n\n'
        'Never run a generator indoors or in a garage — '
        'it produces carbon monoxide (CO) which is odourless and deadly.',
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('I understand'),
        ),
      ],
    );
  }
}
