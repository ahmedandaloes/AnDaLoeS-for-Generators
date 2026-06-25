/// Maps known database errors to friendly, user-facing messages.
///
/// Keeps raw Postgres/PostgREST errors out of the UI. Currently recognizes the
/// `rental_requests_no_overlap` exclusion constraint (migration 0021), which
/// fires when an owner tries to accept/activate a rental that overlaps an
/// already-committed one for the same generator.
String friendlyDbError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final lower = error.toString().toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('clientexception') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('errno = 7')) {
    return 'No internet connection. Check your connection and try again.';
  }
  if (lower.contains('rental_requests_no_overlap') ||
      lower.contains('exclusion constraint') ||
      lower.contains('23p01')) {
    return 'Those dates are already booked for this generator. '
        'Pick different dates or reject the overlapping request first.';
  }
  return fallback;
}
