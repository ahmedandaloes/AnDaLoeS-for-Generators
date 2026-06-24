import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/db_error.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../data/repositories/ratings_repository.dart';

class RateRentalScreen extends ConsumerStatefulWidget {
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
  ConsumerState<RateRentalScreen> createState() => _RateRentalScreenState();
}

class _RateRentalScreenState extends ConsumerState<RateRentalScreen> {
  int _score = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;
  bool? _eligible; // null = checking
  bool _alreadyRated = false;

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  // Guard against deep-link/back-stack misuse: only rate a COMPLETED rental,
  // and only once. (RLS 0030 + the unique index are the hard guard; this is UX.)
  Future<void> _checkEligibility() async {
    try {
      final uid = ref.read(authRepositoryProvider).currentUserId;
      final result = await ref
          .read(ratingsRepositoryProvider)
          .checkEligibility(
            rentalRequestId: widget.rentalRequestId,
            raterId: uid,
          );
      if (mounted) {
        setState(() {
          _eligible = result.eligible;
          _alreadyRated = result.alreadyRated;
        });
      }
    } catch (_) {
      // Fail open to the form — RLS + unique index still enforce the rules.
      if (mounted) setState(() => _eligible = true);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    if (_score == 0) {
      _snack(l.selectStarRating);
      return;
    }
    setState(() => _submitting = true);
    try {
      final uid = ref.read(authRepositoryProvider).currentUserId;
      if (uid == null) {
        _snack(l.createAnAccountFirst);
        return;
      }
      await ref.read(ratingsRepositoryProvider).submitRating(
            rentalRequestId: widget.rentalRequestId,
            raterId: uid,
            rateeId: widget.rateeId,
            score: _score,
            comment: _commentController.text.trim().isNotEmpty
                ? _commentController.text.trim()
                : null,
          );
      if (mounted) {
        _snack(l.thankYouReview);
        context.pop();
        // The calling screen will invalidate its own providers via
        // Riverpod ref.invalidate — the rating badge updates on next build.
      }
    } catch (e) {
      _snack(friendlyDbError(e,
          fallback: l.couldNotSubmitRating));
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
    final l = AppLocalizations.of(context)!;

    if (_eligible == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_eligible == false) {
      return Scaffold(
        appBar: AppBar(title: Text(l.leaveAReview)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.reviews_outlined,
                    size: 48, color: cs.onSurfaceVariant),
                const SizedBox(height: 14),
                Text(_alreadyRated ? l.alreadyReviewed : l.reviewWhenCompleted,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: () => context.pop(),
                    child: Text(l.back)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.leaveAReview)),
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
                        ? l.rateTheCustomer
                        : l.rateYourExperience,
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
                _scoreLabel(_score, l),
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
              decoration: InputDecoration(
                labelText: l.commentOptional,
                hintText: l.commentHint,
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
                  : Text(l.submitReview),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(l.skip),
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

  String _scoreLabel(int score, AppLocalizations l) {
    return switch (score) {
      1 => l.scorePoor,
      2 => l.scoreFair,
      3 => l.scoreGood,
      4 => l.scoreVeryGood,
      5 => l.scoreExcellent,
      _ => l.tapToRate,
    };
  }
}
