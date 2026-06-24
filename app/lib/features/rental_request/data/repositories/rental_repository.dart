import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;

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
  String? get currentUserId => supabase.auth.currentUser?.id;
  bool get isCurrentUserAnonymous =>
      supabase.auth.currentUser?.isAnonymous ?? true;

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

  Future<List<Map<String, dynamic>>> fetchMyRentals(String uid) async {
    final data = await supabase
        .from('rental_requests')
        .select(
            '*, generators(title, capacity_kva, city, photos), companies(name)')
        .eq('customer_id', uid)
        .order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchReceiptById(String rentalId) async {
    return await supabase
        .from('rental_requests')
        .select(
            '*, generators(title, capacity_kva, city, governorate), '
            'profiles!customer_id(full_name, phone)')
        .eq('id', rentalId)
        .single();
  }

  Future<Map<String, dynamic>> fetchOfferById(String rentalId) async {
    return await supabase
        .from('rental_requests')
        .select('''
          id, start_date, end_date, total_days, price_total, note, owner_note,
          status, created_at,
          generators(title, capacity_kva, city, governorate, fuel_type),
          companies(name, phone),
          profiles!rental_requests_customer_id_fkey(full_name, phone)
        ''')
        .eq('id', rentalId)
        .single();
  }

  Future<Map<String, dynamic>> fetchInvoiceById(String rentalId) async {
    return await supabase
        .from('rental_requests')
        .select('''
          id, start_date, end_date, total_days, price_total, note,
          owner_note, status, created_at, invoice_no,
          generators(title, capacity_kva, city, governorate, fuel_type,
                     price_per_day),
          companies(name, phone),
          profiles!rental_requests_customer_id_fkey(full_name, phone)
        ''')
        .eq('id', rentalId)
        .single();
  }

  Future<void> insertRentalRequest(Map<String, dynamic> data) async {
    await supabase.from('rental_requests').insert(data);
  }

  Future<void> cancelRentalRequest(String id, {String? note}) async {
    final update = <String, dynamic>{'status': 'cancelled'};
    if (note != null) update['note'] = note;
    await supabase.from('rental_requests').update(update).eq('id', id);
  }

  Future<void> confirmRentalReceipt(String id) async {
    await supabase
        .from('rental_requests')
        .update({'status': 'active'})
        .eq('id', id)
        .eq('status', 'accepted');
  }

  Future<Set<String>> fetchRatedRentalIds(String uid) async {
    final data = await supabase
        .from('ratings')
        .select('rental_request_id')
        .eq('rater_id', uid);
    return {for (final r in (data as List)) r['rental_request_id'].toString()};
  }

  Future<List<Map<String, dynamic>>> fetchTimeline(String rentalId) async {
    final data = await supabase
        .from('rental_timeline_events')
        .select('event, note, created_at')
        .eq('rental_id', rentalId)
        .order('created_at');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchHandovers(String rentalId) async {
    final data = await supabase
        .from('rental_handovers')
        .select('type, fuel_level, meter_reading, note, created_at')
        .eq('rental_id', rentalId)
        .order('created_at');
    return (data as List).cast<Map<String, dynamic>>();
  }

  RealtimeChannel myRentalsChannel(
      String uid, void Function(Map<String, dynamic>) onUpdate) {
    return supabase
        .channel('my-rentals-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rental_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: uid,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        );
  }

  Stream<List<Map<String, dynamic>>> chatMessagesStream(String rentalRequestId) {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('rental_request_id', rentalRequestId)
        .order('created_at')
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }
}
