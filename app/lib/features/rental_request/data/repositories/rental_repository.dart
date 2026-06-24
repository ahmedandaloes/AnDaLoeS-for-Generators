import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase.dart';
import '../../domain/entities/rental_request.dart';
import '../../domain/repositories/i_rental_repository.dart';

final rentalRepositoryProvider =
    Provider<RentalRepository>((_) => RentalRepository());

/// Fetches timeline events for a single rental, ordered chronologically.
final rentalTimelineProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>((ref, rentalId) async {
  final data = await supabase
      .from('rental_timeline_events')
      .select('event, note, created_at')
      .eq('rental_id', rentalId)
      .order('created_at');
  return (data as List).cast<Map<String, dynamic>>();
});

/// Fetches delivery + return handover records for a rental (at most 2 rows).
final rentalHandoversProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>((ref, rentalId) async {
  final data = await supabase
      .from('rental_handovers')
      .select('type, fuel_level, meter_reading, note, created_at')
      .eq('rental_id', rentalId)
      .order('created_at');
  return (data as List).cast<Map<String, dynamic>>();
});

class RentalRepository implements IRentalRepository {
  static const _opsSelect =
      'id, status, start_date, end_date, created_at, price_total, '
      'generators(title), companies(name), profiles(full_name)';

  static String _today() =>
      DateTime.now().toIso8601String().substring(0, 10);

  @override
  Future<List<Map<String, dynamic>>> overdueActive() async {
    final data = await supabase
        .from('rental_requests')
        .select(_opsSelect)
        .eq('status', 'active')
        .lt('end_date', _today())
        .order('end_date');
    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
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

  @override
  Future<void> markOutForDelivery(String id) async {
    await supabase.from('rental_requests').update(
        {'delivered_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  @override
  Future<int> overlapCount(
      String generatorId, String start, String end) async {
    final data = await supabase
        .from('rental_requests')
        .select('id')
        .eq('generator_id', generatorId)
        .inFilter('status', ['accepted', 'active'])
        .lt('start_date', end)
        .gt('end_date', start);
    return (data as List).length;
  }

  @override
  Future<List<Map<String, dynamic>>> overdueAccepted() async {
    final data = await supabase
        .from('rental_requests')
        .select(_opsSelect)
        .eq('status', 'accepted')
        .lt('start_date', _today())
        .order('start_date');
    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<List<RentalRequestEntity>> fetchByCustomer(String uid) async {
    final data = await supabase
        .from('rental_requests')
        .select('id, generator_id, company_id, customer_id, start_date, '
            'end_date, total_days, price_total, status, note, created_at')
        .eq('customer_id', uid)
        .order('created_at', ascending: false);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(RentalRequestEntity.fromMap)
        .toList();
  }
}
