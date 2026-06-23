import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase.dart';

const _reasons = [
  ('misrepresentation', 'Misrepresentation', 'Generator specs don\'t match reality'),
  ('no_show', 'No-show', 'Owner / customer didn\'t show up'),
  ('damage', 'Property damage', 'Equipment was damaged'),
  ('fraud', 'Fraud / scam', 'Suspicious activity or payment fraud'),
  ('harassment', 'Harassment', 'Abusive or threatening behaviour'),
  ('other', 'Other', 'Something else'),
];

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.entityType,
    required this.entityId,
    this.rentalRequestId,
    this.entityName,
    this.initialReason,
  });

  final String entityType;
  final String entityId;
  final String? rentalRequestId;
  final String? entityName;
  final String? initialReason;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late String? _reason = widget.initialReason;
  final _descController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      _snack('Please select a reason');
      return;
    }
    setState(() => _submitting = true);
    try {
      await supabase.from('reports').insert({
        'reporter_id': supabase.auth.currentUser!.id,
        'reported_entity_type': widget.entityType,
        'reported_entity_id': widget.entityId,
        if (widget.rentalRequestId != null)
          'rental_request_id': widget.rentalRequestId,
        'reason': _reason,
        if (_descController.text.trim().isNotEmpty)
          'description': _descController.text.trim(),
      });
      if (mounted) {
        _snack('Report submitted — we\'ll review it shortly.');
        context.pop();
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entityLabel = widget.entityName ?? _entityLabel(widget.entityType);

    return Scaffold(
      appBar: AppBar(title: const Text('Report an Issue')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, color: cs.error, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reporting: $entityLabel',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          'Your report is confidential and reviewed by our team.',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Reason selector
            Text('What\'s the issue?',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            ..._reasons.map((r) {
              final (key, label, sub) = r;
              final selected = _reason == key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _reason = key),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected
                          ? cs.errorContainer.withValues(alpha: 0.5)
                          : cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? cs.error : cs.outlineVariant,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          size: 20,
                          color: selected ? cs.error : cs.outlineVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? cs.onErrorContainer
                                          : cs.onSurface)),
                              Text(sub,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),

            // Description
            Text('Additional details (optional)',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Describe what happened…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.onError),
                    )
                  : const Text('Submit report'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  String _entityLabel(String type) => switch (type) {
        'generator' => 'Generator',
        'company' => 'Company',
        'user' => 'User',
        _ => 'Item',
      };
}
