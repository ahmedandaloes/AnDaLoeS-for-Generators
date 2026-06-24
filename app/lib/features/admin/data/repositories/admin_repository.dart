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

  Future<bool> isAdmin(String uid) async {
    final data = await supabase
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .single();
    return data['role'] == 'admin';
  }

  Future<Map<String, dynamic>> fetchPlatformStats() async {
    final results = await Future.wait([
      supabase.from('profiles').select('id'),
      supabase.from('generators').select('id'),
      supabase.from('rental_requests').select('id, status'),
      supabase.from('commissions').select('commission_amount, status'),
    ]);
    final rentalList =
        (results[2] as List).cast<Map<String, dynamic>>();
    final commissionList =
        (results[3] as List).cast<Map<String, dynamic>>();
    final completed =
        rentalList.where((r) => r['status'] == 'completed').length;
    final pending =
        rentalList.where((r) => r['status'] == 'pending').length;
    final accepted =
        rentalList.where((r) => r['status'] == 'accepted').length;
    final active =
        rentalList.where((r) => r['status'] == 'active').length;
    final totalCommissions = commissionList.fold<double>(
        0,
        (s, c) =>
            s +
            (double.tryParse(
                    c['commission_amount']?.toString() ?? '0') ??
                0));
    return {
      'users': (results[0] as List).length,
      'generators': (results[1] as List).length,
      'total_rentals': rentalList.length,
      'pending_rentals': pending,
      'accepted_rentals': accepted,
      'active_rentals': active,
      'completed_rentals': completed,
      'total_commission_earned': totalCommissions,
    };
  }

  Future<List<Map<String, dynamic>>> fetchActiveCommissions() async {
    final rows = await supabase
        .from('commissions')
        .select(
            'id, commission_amount, status, created_at, rental_requests(companies(name), generators(title))')
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<({String type, double value})?> fetchActiveCommissionRate() async {
    final rows = await supabase
        .from('commission_config')
        .select('type, value')
        .eq('active', true)
        .isFilter('company_id', null)
        .limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    return (
      type: list.first['type']?.toString() ?? 'percentage',
      value: (list.first['value'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<void> updateCommissionRate(double pct) async {
    await supabase
        .from('commission_config')
        .update({'active': false})
        .eq('active', true)
        .isFilter('company_id', null);
    await supabase.from('commission_config').insert({
      'company_id': null,
      'type': 'percentage',
      'value': pct / 100.0,
      'active': true,
    });
  }

  Future<void> updateTaxConfig({
    required double rate,
    required String label,
    required String appliesWhen,
  }) async {
    await supabase
        .from('tax_config')
        .update({'active': false}).eq('active', true);
    await supabase.from('tax_config').insert({
      'rate': rate,
      'label': label,
      'applies_when': appliesWhen,
      'active': true,
    });
  }

  Future<void> settleCommission(String commissionId) async {
    await supabase
        .from('commissions')
        .update({'status': 'settled'}).eq('id', commissionId);
  }

  Future<List<Map<String, dynamic>>> fetchPendingCompaniesAdmin() async {
    final data = await supabase
        .from('companies')
        .select('*, profiles!owner_user_id(full_name, phone)')
        .inFilter(
            'verification_status', ['pending', 'under_review']).order(
        'created_at');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> approveCompany(
      String companyId, String reviewedBy) async {
    await supabase.from('companies').update({
      'verification_status': 'approved',
      'reviewed_by': reviewedBy,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', companyId);
  }

  Future<void> rejectCompany(
      String companyId, String reviewedBy, String reason) async {
    await supabase.from('companies').update({
      'verification_status': 'rejected',
      'rejection_reason': reason,
      'reviewed_by': reviewedBy,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', companyId);
  }

  Future<String> getCompanyDocSignedUrl(String path) async {
    return supabase.storage
        .from('company-docs')
        .createSignedUrl(path, 300);
  }

  Future<List<Map<String, dynamic>>> fetchAllGeneratorsAdmin() async {
    final data = await supabase
        .from('generators')
        .select(
            'id, title, capacity_kva, price_per_day, city, governorate, photos, status, created_at, companies(name)')
        .inFilter(
            'status', ['pending', 'available', 'unavailable', 'rejected'])
        .order('created_at', ascending: false)
        .limit(80);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> setGeneratorStatus(String genId, String status) async {
    await supabase
        .from('generators')
        .update({'status': status}).eq('id', genId);
  }

  Future<List<Map<String, dynamic>>> fetchAllUsersAdmin() async {
    final data = await supabase
        .from('profiles')
        .select('id, full_name, phone, role')
        .order('role', ascending: true)
        .limit(200);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> setUserRole(String uid, String role) async {
    await supabase.from('profiles').update({'role': role}).eq('id', uid);
  }

  Future<List<Map<String, dynamic>>> fetchAllRentalsAdmin() async {
    final data = await supabase.from('rental_requests').select(
        'id, status, start_date, end_date, total_days, price_total, created_at, '
        'profiles(full_name, phone), '
        'generators(title, capacity_kva), '
        'companies(name)').order('created_at', ascending: false).limit(100);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchOpenReportsAdmin() async {
    final data = await supabase
        .from('reports')
        .select('*')
        .inFilter('status', ['open', 'under_review']).order('created_at');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> resolveReportAdmin(
      String id, Map<String, dynamic> update) async {
    await supabase.from('reports').update(update).eq('id', id);
  }

  Future<void> setReportStatus(String id, String status) async {
    await supabase.from('reports').update({'status': status}).eq('id', id);
  }

  Future<int> expireStaleRequests() async {
    final result = await supabase.rpc('expire_stale_pending_requests');
    return (result as int?) ?? 0;
  }
}
