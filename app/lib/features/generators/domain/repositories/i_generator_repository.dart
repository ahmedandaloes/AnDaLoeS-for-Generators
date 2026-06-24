import '../entities/generator.dart';

/// Abstract contract for generator data access.
/// Concrete implementations live in data/repositories/.
abstract class IGeneratorRepository {
  Future<List<Generator>> fetchAll();
  Future<List<Generator>> fetchFeatured();
  Future<List<Generator>> fetchNewArrivals();
  Future<Map<String, dynamic>> fetchById(String id);
  Future<List<Map<String, dynamic>>> fetchBooked(String generatorId);
  Future<List<Map<String, dynamic>>> fetchReviews(String generatorId);
  Future<List<Map<String, dynamic>>> fetchSimilar(Map<String, dynamic> gen);
  Future<Set<String>> fetchFavorites(String uid);
  Future<bool> fetchIsFav(String uid, String generatorId);
  Future<void> toggleFavorite(String uid, String generatorId, bool isFav);
  Future<List<String>> searchAutocomplete(String query);
  Future<int?> fetchAvgResponseTime(String companyId);
  Future<Map<String, int>> countAvailableByGovernorate();
}
