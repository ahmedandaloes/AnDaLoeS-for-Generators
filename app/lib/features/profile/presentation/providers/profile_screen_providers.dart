import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase.dart';

/// Fetches the user's profile row (full_name, phone, role, avatar_url).
final profileDataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return null;
  final data = await supabase
      .from('profiles')
      .select('full_name, phone, role, avatar_url')
      .eq('id', uid)
      .maybeSingle();
  return data;
});

/// Customer rental statistics (total, active, completed, spending).
final rentalStatsProvider =
    FutureProvider.autoDispose<Map<String, num>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return {};
  final data = await supabase
      .from('rental_requests')
      .select('status, price_total, created_at')
      .eq('customer_id', uid);
  final list = (data as List).cast<Map<String, dynamic>>();

  final now = DateTime.now();
  final thisMonthStart = DateTime(now.year, now.month);
  final lastMonthStart = DateTime(now.year, now.month - 1);

  num totalSpent = 0;
  num thisMonthSpent = 0;
  num lastMonthSpent = 0;

  for (final r in list) {
    if (r['status'] == 'completed') {
      final price = (r['price_total'] as num?) ?? 0;
      totalSpent += price;
      try {
        final dt = DateTime.parse(r['created_at'].toString());
        if (!dt.isBefore(thisMonthStart)) {
          thisMonthSpent += price;
        } else if (!dt.isBefore(lastMonthStart)) {
          lastMonthSpent += price;
        }
      } catch (_) {}
    }
  }

  return {
    'total': list.length,
    'active': list.where((r) => r['status'] == 'active').length,
    'completed': list.where((r) => r['status'] == 'completed').length,
    'pending': list.where((r) => r['status'] == 'pending').length,
    'total_spent': totalSpent,
    'this_month_spent': thisMonthSpent,
    'last_month_spent': lastMonthSpent,
  };
});

/// Counts pending rental requests for generators the current user owns.
final pendingRequestsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return 0;
  final data = await supabase
      .from('rental_requests')
      .select('id, generators!inner(company_id, companies!inner(owner_user_id))')
      .eq('status', 'pending')
      .eq('generators.companies.owner_user_id', uid);
  return (data as List).length;
});
