import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase.dart';

class RateRentalScreen extends StatefulWidget {
  const RateRentalScreen({
    super.key,
    required this.rentalRequestId,
    required this.rateeId,
    required this.rateeName,
    this.isOwnerRating = false,
  });

  final String rentalRequestId;
  final String rateeId;
  final String rateeName;
  final bool isOwnerRating;

  @override
  State<RateRentalScreen> createState() => _RateRentalScreenState();
}

class _RateRentalScreenState extends State<RateRentalScreen> {
  int _score = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_score == 0) {
      _snack('Select a star rating');
      return;
    }
    setState(() => _submitting = true);
    try {
      await supabase.from('ratings').insert({
        'rental_request_id': widget.rentalRequestId,
        'rater_id': supabase.auth.currentUser!.id,
        'ratee_id': widget.rateeId,
        'score': _score,
        if (_commentController.text.trim().isNotEmpty)
          'comment': _commentController.text.trim(),
      });
      if (mounted) {
        _snack('Thank you for your review!');
        context.pop();
        // The calling screen will invalidate its own providers via
        // Riverpod ref.invalidate — the rating badge updates on next build.
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Leave a Review')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Who are you rating
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.rateeName.isNotEmpty
                            ? widget.rateeName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimaryContainer),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.isOwnerRating
                        ? 'Rate the customer'
                        : 'Rate your experience',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.rateeName,
                    style: TextStyle(
                        fontSize: 14, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Star selector
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _score = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        _score >= star ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 44,
                        color: _score >= star
                            ? Colors.amber.shade600
                            : cs.outlineVariant,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _scoreLabel(_score),
                style: TextStyle(
                  fontSize: 14,
                  color: _score > 0 ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Quick-tag chips — score-sensitive suggestions
            if (_score > 0) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions(_score)
                    .map((tag) => ActionChip(
                          label: Text(tag,
                              style: const TextStyle(fontSize: 12)),
                          onPressed: () {
                            final cur = _commentController.text.trim();
                            if (!cur.contains(tag)) {
                              _commentController.text =
                                  cur.isEmpty ? tag : '$cur. $tag';
                              _commentController.selection =
                                  TextSelection.collapsed(
                                      offset:
                                          _commentController.text.length);
                            }
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Comment
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                hintText:
                    'Share details about your experience…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.onPrimary),
                    )
                  : const Text('Submit review'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Skip'),
            ),
          ],
        ),
      ),
    );
  }

  static List<String> _suggestions(int score) => switch (score) {
        5 => [
            'Generator arrived on time',
            'Very clean and well-maintained',
            'Owner was very helpful',
            'Ran smoothly throughout',
            'Would rent again',
          ],
        4 => [
            'Good condition overall',
            'On time delivery',
            'Owner was responsive',
            'Slight noise but manageable',
          ],
        3 => [
            'Decent but could improve',
            'Minor delays in delivery',
            'Performance was average',
          ],
        _ => [
            'Late delivery',
            'Generator had issues',
            'Owner was unresponsive',
            'Not as described',
          ],
      };

  String _scoreLabel(int score) {
    return switch (score) {
      1 => 'Poor',
      2 => 'Fair',
      3 => 'Good',
      4 => 'Very good',
      5 => 'Excellent!',
      _ => 'Tap to rate',
    };
  }
}
