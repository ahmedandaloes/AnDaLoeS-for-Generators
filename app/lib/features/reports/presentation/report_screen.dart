import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase.dart';
import '../../../l10n/app_localizations.dart';

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
    final l = AppLocalizations.of(context)!;
    if (_reason == null) {
      _snack(l.selectReason);
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
        _snack(l.reportSubmitted);
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
    final l = AppLocalizations.of(context)!;
    final entityLabel = widget.entityName ?? _entityLabel(widget.entityType, l);

    return Scaffold(
      appBar: AppBar(title: Text(l.reportAnIssueTitle)),
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
                        Text(l.reportingEntity(entityLabel),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          l.reportConfidential,
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
            Text(l.whatsTheIssue,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            ..._reasons.map((r) {
              final key = r.$1;
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
                              Text(_reasonTitle(key, l),
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? cs.onErrorContainer
                                          : cs.onSurface)),
                              Text(_reasonDesc(key, l),
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
            Text(l.additionalDetails,
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
              decoration: InputDecoration(
                hintText: l.describeHint,
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
                  : Text(l.submitReport),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(l.cancel),
            ),
          ],
        ),
      ),
    );
  }

  String _entityLabel(String type, AppLocalizations l) => switch (type) {
        'generator' => l.generatorLabel,
        'company' => l.entityCompany,
        'user' => l.entityUser,
        _ => l.entityItem,
      };

  String _reasonTitle(String code, AppLocalizations l) => switch (code) {
        'misrepresentation' => l.reasonMisrep,
        'no_show' => l.reasonNoShow,
        'damage' => l.reasonDamage,
        'fraud' => l.reasonFraud,
        'harassment' => l.reasonHarassment,
        _ => l.reasonOther,
      };

  String _reasonDesc(String code, AppLocalizations l) => switch (code) {
        'misrepresentation' => l.reasonMisrepDesc,
        'no_show' => l.reasonNoShowDesc,
        'damage' => l.reasonDamageDesc,
        'fraud' => l.reasonFraudDesc,
        'harassment' => l.reasonHarassmentDesc,
        _ => l.reasonOtherDesc,
      };
}
