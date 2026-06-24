import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase.dart';
import '../../domain/entities/admin_stats.dart';
import '../../domain/repositories/i_admin_repository.dart';

final adminRepositoryProvider =
    Provider<AdminRepository>((_) => AdminRepository());

class AdminRepository implements IAdminRepository {
  @override
  Future<AdminStats> fetchStats() async {
    final results = await Future.wait([
      supabase.from('profiles').select('id').eq('role', 'customer'),
      supabase.from('profiles').select('id').eq('role', 'owner'),
      supabase.from('generators').select('id').eq('status', 'available'),
      supabase.from('companies').select('id').eq('status', 'pending'),
      supabase.from('rental_requests').select('id').eq('status', 'active'),
      supabase.from('rental_requests').select('id').eq('status', 'completed'),
      supabase.from('reports').select('id').eq('status', 'open'),
    ]);
    final revenue = await supabase
        .from('commissions')
        .select('commission_amount')
        .eq('status', 'collected');
    final total = (revenue as List).fold<double>(
        0, (sum, r) => sum + ((r['commission_amount'] as num?)?.toDouble() ?? 0));
    return AdminStats(
      totalUsers: (results[0] as List).length,
      totalOwners: (results[1] as List).length,
      totalGenerators: (results[2] as List).length,
      pendingCompanies: (results[3] as List).length,
      activeRentals: (results[4] as List).length,
      completedRentals: (results[5] as List).length,
      totalRevenue: total,
      openReports: (results[6] as List).length,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPendingCompanies() async {
    final data = await supabase
        .from('companies')
        .select('*, profiles(full_name, phone)')
        .eq('status', 'pending')
        .order('created_at');
    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> updateCompanyStatus(String companyId, String status) async {
    await supabase
        .from('companies')
        .update({'status': status}).eq('id', companyId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAllGenerators() async {
    final data = await supabase
        .from('generators')
        .select('id, title, status, capacity_kva, city, companies(name)')
        .order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> updateGeneratorStatus(
      String generatorId, String status) async {
    await supabase
        .from('generators')
        .update({'status': status}).eq('id', generatorId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOpenReports() async {
    final data = await supabase
        .from('reports')
        .select('*, profiles!reporter_id(full_name)')
        .eq('status', 'open')
        .order('created_at');
    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> resolveReport(
      String reportId, String note, String resolvedBy) async {
    await supabase.from('reports').update({
      'status': 'resolved',
      'resolution_note': note,
      'resolved_by': resolvedBy,
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', reportId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAllRentals(
      {String? search}) async {
    var query = supabase.from('rental_requests').select(
        'id, status, start_date, end_date, total_days, price_total, created_at, '
        'generators(title), companies(name), profiles!customer_id(full_name, phone)');
    if (search != null && search.isNotEmpty) {
      query = query.or(
          'profiles.full_name.ilike.%$search%,profiles.phone.ilike.%$search%');
    }
    final data = await query.order('created_at', ascending: false).limit(100);
    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    final data = await supabase
        .from('profiles')
        .select('id, full_name, phone, role, created_at')
        .order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }
}
