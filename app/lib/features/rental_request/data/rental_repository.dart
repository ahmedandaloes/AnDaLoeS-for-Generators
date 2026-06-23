import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';

final rentalRepositoryProvider =
    Provider<RentalRepository>((_) => RentalRepository());

/// Central data access for rental_requests (REST/repository layer — keeps
/// queries out of widgets and non-duplicated).
class RentalRepository {
  static const _opsSelect =
      'id, status, start_date, end_date, created_at, price_total, '
      'generators(title), companies(name), profiles(full_name)';

  static String _today() =>
      DateTime.now().toIso8601String().substring(0, 10);

  /// Active rentals past their end date (not yet returned/completed).
  Future<List<Map<String, dynamic>>> overdueActive() async {
    final data = await supabase
        .from('rental_requests')
        .select(_opsSelect)
        .eq('status', 'active')
        .lt('end_date', _today())
        .order('end_date');
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Pending requests older than [hours] — owner hasn't responded.
  Future<List<Map<String, dynamic>>> stalePending({int hours = 24}) async {
    final cutoff =
        DateTime.now().subtract(Duration(hours: hours)).toIso8601String();
    final data = await supabase
        .from('rental_requests')
        .select(_opsSelect)
        .eq('status', 'pending')
        .lt('created_at', cutoff)
        .order('created_at');
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Accepted rentals whose start date has passed but never went active.
  Future<List<Map<String, dynamic>>> overdueAccepted() async {
    final data = await supabase
        .from('rental_requests')
        .select(_opsSelect)
        .eq('status', 'accepted')
        .lt('start_date', _today())
        .order('start_date');
    return (data as List).cast<Map<String, dynamic>>();
  }
}
