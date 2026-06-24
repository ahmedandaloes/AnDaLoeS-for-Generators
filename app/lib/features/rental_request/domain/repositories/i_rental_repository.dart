import '../entities/rental_request.dart';

abstract interface class IRentalRepository {
  Future<List<Map<String, dynamic>>> overdueActive();
  Future<List<Map<String, dynamic>>> stalePending({int hours = 24});
  Future<void> markOutForDelivery(String id);
  Future<int> overlapCount(String generatorId, String start, String end);
  Future<List<Map<String, dynamic>>> overdueAccepted();
  Future<List<RentalRequestEntity>> fetchByCustomer(String uid);
}
