import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase.dart';

final reportsRepositoryProvider =
    Provider<ReportsRepository>((_) => ReportsRepository());

class ReportsRepository {
  Future<void> submitReport({
    required String reporterId,
    required String entityType,
    required String entityId,
    String? rentalRequestId,
    required String reason,
    String? description,
  }) async {
    await supabase.from('reports').insert({
      'reporter_id': reporterId,
      'reported_entity_type': entityType,
      'reported_entity_id': entityId,
      if (rentalRequestId != null) 'rental_request_id': rentalRequestId,
      'reason': reason,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
  }
}
