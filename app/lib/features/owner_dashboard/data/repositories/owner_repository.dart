import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;

import '../../../../core/config/supabase.dart';
import '../../domain/entities/company.dart';
import '../../domain/repositories/i_owner_repository.dart';

final ownerRepositoryProvider =
    Provider<OwnerRepository>((_) => OwnerRepository());

class OwnerRepository implements IOwnerRepository {
  String? get currentUserId => supabase.auth.currentUser?.id;

  @override
  Future<CompanyEntity?> fetchMyCompany(String uid) async {
    final data = await supabase
        .from('companies')
        .select()
        .eq('owner_user_id', uid)
        .maybeSingle();
    if (data == null) return null;
    return CompanyEntity.fromMap(data);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRequests(String companyId,
      {List<String>? statuses}) async {
    var query = supabase
        .from('rental_requests')
        .select('*, generators(title, capacity_kva), profiles(full_name, phone)')
        .eq('company_id', companyId);
    if (statuses != null && statuses.isNotEmpty) {
      query = query.inFilter('status', statuses);
    }
    final data = await query.order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchGenerators(String companyId) async {
    final data = await supabase
        .from('generators')
        .select(
            'id, title, capacity_kva, description, price_per_day, price_per_week, '
            'price_per_month, deposit_amount, city, governorate, status, photos, '
            'fuel_type, hire_type, fuel_policy, accessories, use_cases')
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<int> pendingRequestCount(String companyId) async {
    final data = await supabase
        .from('rental_requests')
        .select('id')
        .eq('company_id', companyId)
        .eq('status', 'pending');
    return (data as List).length;
  }

  @override
  Future<Map<String, int>> activeRentalCounts(String companyId) async {
    final data = await supabase
        .from('rental_requests')
        .select('generator_id')
        .eq('company_id', companyId)
        .inFilter('status', ['accepted', 'active']);
    final counts = <String, int>{};
    for (final row in (data as List)) {
      final gid = row['generator_id']?.toString() ?? '';
      counts[gid] = (counts[gid] ?? 0) + 1;
    }
    return counts;
  }

  Future<List<Map<String, dynamic>>> fetchCommissionConfig() async {
    final data = await supabase
        .from('commission_config')
        .select('type, value, company_id')
        .eq('active', true);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> fetchMyCompanyByUid(String uid) async {
    return await supabase
        .from('companies')
        .select()
        .eq('owner_user_id', uid)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> fetchHistory(String companyId) async {
    return await supabase
        .from('rental_requests')
        .select('*, generators(title, capacity_kva), profiles(full_name, phone)')
        .eq('company_id', companyId)
        .inFilter('status', ['completed', 'rejected', 'cancelled'])
        .order('updated_at', ascending: false)
        .limit(50);
  }

  Future<Set<String>> fetchRatedRentalIds(String uid) async {
    final data = await supabase
        .from('ratings')
        .select('rental_request_id')
        .eq('rater_id', uid);
    return {for (final r in (data as List)) r['rental_request_id'].toString()};
  }

  Future<List<Map<String, dynamic>>> fetchAvailableGeneratorsGovernorates() async {
    final data = await supabase
        .from('generators')
        .select('governorate')
        .eq('status', 'available');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchEarnings(String companyId) async {
    final rentals = await supabase
        .from('rental_requests')
        .select('id, price_total, start_date, end_date, generators(title)')
        .eq('company_id', companyId)
        .eq('status', 'completed')
        .order('created_at', ascending: false);

    final rentalList = (rentals as List).cast<Map<String, dynamic>>();

    final commissions = await supabase
        .from('commissions')
        .select('rental_request_id, commission_amount, type, value, status')
        .inFilter('rental_request_id', rentalList.map((r) => r['id']).toList());

    final commissionList = (commissions as List).cast<Map<String, dynamic>>();
    final commissionMap = {
      for (final c in commissionList) c['rental_request_id'].toString(): c
    };

    final totalRevenue = rentalList.fold<double>(
        0, (s, r) => s + (double.tryParse(r['price_total']?.toString() ?? '0') ?? 0));
    final totalCommissions = commissionList.fold<double>(
        0, (s, c) => s + (double.tryParse(c['commission_amount']?.toString() ?? '0') ?? 0));
    final commissionOwed = commissionList
        .where((c) => c['status'] != 'settled')
        .fold<double>(0,
            (s, c) => s + (double.tryParse(c['commission_amount']?.toString() ?? '0') ?? 0));
    final commissionSettled = totalCommissions - commissionOwed;

    final monthlyMap = <String, double>{};
    for (final r in rentalList) {
      final raw = r['start_date']?.toString() ?? '';
      if (raw.length >= 7) {
        final month = raw.substring(0, 7);
        final gross = double.tryParse(r['price_total']?.toString() ?? '0') ?? 0;
        final fee = commissionMap[r['id'].toString()] != null
            ? double.tryParse(commissionMap[r['id'].toString()]?['commission_amount']?.toString() ?? '0') ?? 0
            : 0.0;
        monthlyMap[month] = (monthlyMap[month] ?? 0) + (gross - fee);
      }
    }
    final sortedMonths = monthlyMap.keys.toList()..sort();

    return {
      'rentals': rentalList,
      'commission_map': commissionMap,
      'total_revenue': totalRevenue,
      'total_commissions': totalCommissions,
      'commission_owed': commissionOwed,
      'commission_settled': commissionSettled,
      'net_payout': totalRevenue - totalCommissions,
      'monthly_net': {for (final m in sortedMonths) m: monthlyMap[m]!},
    };
  }

  Future<void> toggleGeneratorStatus(
      String generatorId, bool available) async {
    await supabase
        .from('generators')
        .update({'status': available ? 'available' : 'unavailable'}).eq(
            'id', generatorId);
  }

  Future<Map<String, dynamic>> insertGenerator(
      Map<String, dynamic> data) async {
    final result = await supabase
        .from('generators')
        .insert(data)
        .select('id')
        .single();
    return result;
  }

  Future<void> updateGeneratorPhotos(
      String generatorId, List<String> urls) async {
    await supabase
        .from('generators')
        .update({'photos': urls}).eq('id', generatorId);
  }

  Future<void> updateGenerator(
      String generatorId, Map<String, dynamic> data) async {
    await supabase.from('generators').update(data).eq('id', generatorId);
  }

  Future<String> uploadGeneratorPhoto(
      String remotePath, dynamic file, dynamic fileOptions) async {
    await supabase.storage.from('generator-photos').upload(
          remotePath,
          file,
          fileOptions: fileOptions,
        );
    return supabase.storage.from('generator-photos').getPublicUrl(remotePath);
  }

  Future<void> recordHandover({
    required String rentalId,
    required String type,
    required String recordedBy,
    String? fuelLevel,
    double? meterReading,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'rental_id': rentalId,
      'type': type,
      'recorded_by': recordedBy,
    };
    if (fuelLevel != null) payload['fuel_level'] = fuelLevel;
    if (meterReading != null) payload['meter_reading'] = meterReading;
    if (note != null) payload['note'] = note;
    await supabase.from('rental_handovers').insert(payload);
  }

  Future<void> updateRequestStatus(
      String requestId, String newStatus, {String? ownerNote}) async {
    final update = <String, dynamic>{'status': newStatus};
    if (ownerNote != null) update['owner_note'] = ownerNote;
    await supabase.from('rental_requests').update(update).eq('id', requestId);
  }

  Future<Map<String, dynamic>> fetchGeneratorById(String id) async {
    return await supabase.from('generators').select('*').eq('id', id).single();
  }

  Future<void> deleteGenerator(String generatorId) async {
    await supabase.from('generators').delete().eq('id', generatorId);
  }

  RealtimeChannel ownerRequestsChannel(
      String companyId, void Function() onInsert) {
    return supabase
        .channel('owner-requests-$companyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'rental_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: companyId,
          ),
          callback: (_) => onInsert(),
        );
  }
}
