import 'package:flutter_test/flutter_test.dart';

import 'package:thabit_power/features/generators/domain/entities/generator.dart';
import 'package:thabit_power/features/generators/data/models/generator_model.dart';
import 'package:thabit_power/features/generators/presentation/widgets/generator_filter.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _fullMap({
  String id = 'gen-1',
  String title = 'Powerhouse 5KVA',
  double capacityKva = 5.0,
  double pricePerDay = 200.0,
  String city = 'Cairo',
  String governorate = 'القاهرة',
  List<String> photos = const ['https://example.com/photo.jpg'],
  double avgScore = 4.5,
  int ratingCount = 10,
  String fuelType = 'diesel',
  List<String> useCases = const ['events'],
  String hireType = 'wet_hire',
  String fuelPolicy = 'owner_provides',
  List<String> accessories = const ['cables'],
  String createdAt = '2025-01-01T00:00:00.000Z',
  Map<String, dynamic>? company,
}) =>
    {
      'id': id,
      'title': title,
      'capacity_kva': capacityKva,
      'price_per_day': pricePerDay,
      'city': city,
      'governorate': governorate,
      'photos': photos,
      'avg_score': avgScore,
      'rating_count': ratingCount,
      'fuel_type': fuelType,
      'use_cases': useCases,
      'hire_type': hireType,
      'fuel_policy': fuelPolicy,
      'accessories': accessories,
      'created_at': createdAt,
      if (company != null) 'companies': company,
    };

void main() {
  // ── Generator.fromMap ──────────────────────────────────────────────────────

  group('Generator.fromMap – required fields', () {
    test('id maps from "id"', () {
      expect(Generator.fromMap(_fullMap()).id, 'gen-1');
    });

    test('title maps from "title"', () {
      expect(Generator.fromMap(_fullMap()).title, 'Powerhouse 5KVA');
    });

    test('capacityKva maps from "capacity_kva"', () {
      expect(Generator.fromMap(_fullMap()).capacityKva, 5.0);
    });

    test('pricePerDay maps from "price_per_day"', () {
      expect(Generator.fromMap(_fullMap()).pricePerDay, 200.0);
    });

    test('city maps correctly', () {
      expect(Generator.fromMap(_fullMap()).city, 'Cairo');
    });

    test('governorate maps correctly', () {
      expect(Generator.fromMap(_fullMap()).governorate, 'القاهرة');
    });

    test('photos list maps correctly', () {
      final g = Generator.fromMap(_fullMap());
      expect(g.photos, hasLength(1));
      expect(g.photos.first, 'https://example.com/photo.jpg');
    });

    test('avgScore maps from "avg_score"', () {
      expect(Generator.fromMap(_fullMap()).avgScore, 4.5);
    });

    test('ratingCount maps from "rating_count"', () {
      expect(Generator.fromMap(_fullMap()).ratingCount, 10);
    });

    test('fuelType maps from "fuel_type"', () {
      expect(Generator.fromMap(_fullMap()).fuelType, 'diesel');
    });

    test('useCases maps from "use_cases"', () {
      expect(Generator.fromMap(_fullMap()).useCases, ['events']);
    });

    test('hireType maps from "hire_type"', () {
      expect(Generator.fromMap(_fullMap()).hireType, 'wet_hire');
    });

    test('fuelPolicy maps from "fuel_policy"', () {
      expect(Generator.fromMap(_fullMap()).fuelPolicy, 'owner_provides');
    });

    test('accessories list maps correctly', () {
      expect(Generator.fromMap(_fullMap()).accessories, ['cables']);
    });

    test('createdAt parsed from ISO string', () {
      final g = Generator.fromMap(_fullMap());
      expect(g.createdAt, DateTime.utc(2025, 1, 1));
    });
  });

  group('Generator.fromMap – company nested object', () {
    test('companyName extracted from companies.name', () {
      final g = Generator.fromMap(
        _fullMap(company: {'name': 'Delta Power', 'verification_status': 'pending'}),
      );
      expect(g.companyName, 'Delta Power');
    });

    test('isVerified true when verification_status == approved', () {
      final g = Generator.fromMap(
        _fullMap(company: {'name': 'Delta Power', 'verification_status': 'approved'}),
      );
      expect(g.isVerified, true);
    });

    test('isVerified false when verification_status != approved', () {
      final g = Generator.fromMap(
        _fullMap(company: {'name': 'Delta Power', 'verification_status': 'pending'}),
      );
      expect(g.isVerified, false);
    });

    test('companyName empty string when companies key absent', () {
      expect(Generator.fromMap(_fullMap()).companyName, '');
    });

    test('isVerified false when companies key absent', () {
      expect(Generator.fromMap(_fullMap()).isVerified, false);
    });
  });

  group('Generator.fromMap – null / missing field defaults', () {
    test('null id defaults to empty string', () {
      final m = _fullMap();
      m['id'] = null;
      expect(Generator.fromMap(m).id, '');
    });

    test('null capacity_kva defaults to 0', () {
      final m = _fullMap();
      m['capacity_kva'] = null;
      expect(Generator.fromMap(m).capacityKva, 0.0);
    });

    test('null photos defaults to empty list', () {
      final m = _fullMap();
      m['photos'] = null;
      expect(Generator.fromMap(m).photos, isEmpty);
    });

    test('empty photos list maps to empty list', () {
      final m = _fullMap(photos: []);
      expect(Generator.fromMap(m).photos, isEmpty);
    });

    test('null use_cases defaults to empty list', () {
      final m = _fullMap();
      m['use_cases'] = null;
      expect(Generator.fromMap(m).useCases, isEmpty);
    });

    test('missing hire_type defaults to dry_hire', () {
      final m = _fullMap();
      m.remove('hire_type');
      expect(Generator.fromMap(m).hireType, 'dry_hire');
    });

    test('missing fuel_policy defaults to customer_provides', () {
      final m = _fullMap();
      m.remove('fuel_policy');
      expect(Generator.fromMap(m).fuelPolicy, 'customer_provides');
    });

    test('null created_at defaults to DateTime(2000)', () {
      final m = _fullMap();
      m['created_at'] = null;
      expect(Generator.fromMap(m).createdAt, DateTime(2000));
    });

    test('invalid created_at string defaults to DateTime(2000)', () {
      final m = _fullMap();
      m['created_at'] = 'not-a-date';
      expect(Generator.fromMap(m).createdAt, DateTime(2000));
    });
  });

  // ── Generator.toMap round-trip ────────────────────────────────────────────

  group('Generator.toMap round-trip', () {
    test('toMap includes all serialised fields', () {
      final g = Generator.fromMap(_fullMap());
      final map = g.toMap();
      expect(map['id'], 'gen-1');
      expect(map['title'], 'Powerhouse 5KVA');
      expect(map['capacity_kva'], 5.0);
      expect(map['price_per_day'], 200.0);
      expect(map['city'], 'Cairo');
      expect(map['governorate'], 'القاهرة');
      expect(map['photos'], hasLength(1));
      expect(map['avg_score'], 4.5);
      expect(map['rating_count'], 10);
      expect(map['fuel_type'], 'diesel');
      expect(map['hire_type'], 'wet_hire');
      expect(map['fuel_policy'], 'owner_provides');
      expect(map['accessories'], ['cables']);
      expect(map['created_at'], isA<String>());
    });

    test('fromMap → toMap → fromMap identity', () {
      final original = Generator.fromMap(_fullMap());
      final roundTrip = Generator.fromMap(original.toMap());
      expect(roundTrip.id, original.id);
      expect(roundTrip.title, original.title);
      expect(roundTrip.capacityKva, original.capacityKva);
      expect(roundTrip.pricePerDay, original.pricePerDay);
      expect(roundTrip.avgScore, original.avgScore);
      expect(roundTrip.ratingCount, original.ratingCount);
    });
  });

  // ── GeneratorModel.fromMap ────────────────────────────────────────────────

  group('GeneratorModel.fromMap', () {
    test('returns a GeneratorModel instance (is-a Generator)', () {
      final model = GeneratorModel.fromMap(_fullMap());
      expect(model, isA<Generator>());
    });

    test('fields match underlying Generator.fromMap', () {
      final model = GeneratorModel.fromMap(_fullMap());
      expect(model.id, 'gen-1');
      expect(model.pricePerDay, 200.0);
    });
  });

  // ── GeneratorFilter ───────────────────────────────────────────────────────

  group('GeneratorFilter', () {
    test('default filter has no active filters', () {
      expect(const GeneratorFilter().hasActiveFilters, false);
    });

    test('governorate set → hasActiveFilters true', () {
      expect(
        const GeneratorFilter(governorate: 'Cairo').hasActiveFilters,
        true,
      );
    });

    test('maxKva set → hasActiveFilters true', () {
      expect(const GeneratorFilter(maxKva: 100).hasActiveFilters, true);
    });

    test('maxPrice set → hasActiveFilters true', () {
      expect(const GeneratorFilter(maxPrice: 500).hasActiveFilters, true);
    });

    test('fuelType set → hasActiveFilters true', () {
      expect(
        const GeneratorFilter(fuelType: 'diesel').hasActiveFilters,
        true,
      );
    });

    test('useCases non-empty → hasActiveFilters true', () {
      expect(
        const GeneratorFilter(useCases: {'events'}).hasActiveFilters,
        true,
      );
    });

    test('withQuery creates new filter with updated query', () {
      const f = GeneratorFilter();
      final updated = f.withQuery('solar');
      expect(updated.query, 'solar');
      expect(f.query, ''); // original unchanged
    });

    test('withGovernorate creates new filter', () {
      const f = GeneratorFilter();
      final updated = f.withGovernorate('Giza');
      expect(updated.governorate, 'Giza');
    });

    test('withGovernorate(null) clears governorate', () {
      const f = GeneratorFilter(governorate: 'Cairo');
      expect(f.withGovernorate(null).governorate, isNull);
    });

    test('withMaxKva creates new filter', () {
      const f = GeneratorFilter();
      expect(f.withMaxKva(250).maxKva, 250.0);
    });

    test('withFuelType creates new filter', () {
      const f = GeneratorFilter();
      expect(f.withFuelType('petrol').fuelType, 'petrol');
    });

    test('withSort creates new filter with given sort', () {
      const f = GeneratorFilter();
      expect(f.withSort(GeneratorSortBy.priceLow).sort, GeneratorSortBy.priceLow);
    });

    test('default sort is newest', () {
      expect(const GeneratorFilter().sort, GeneratorSortBy.newest);
    });
  });

  group('GeneratorFilter JSON round-trip', () {
    test('full filter persists and restores', () {
      const f = GeneratorFilter(
        query: 'transient',
        governorate: 'Alexandria',
        maxKva: 500,
        maxPrice: 1500,
        fuelType: 'diesel',
        useCases: {'events', 'construction'},
        sort: GeneratorSortBy.ratingTop,
      );
      final back = GeneratorFilter.fromJson(f.toJson());
      expect(back.governorate, 'Alexandria');
      expect(back.maxKva, 500.0);
      expect(back.maxPrice, 1500.0);
      expect(back.fuelType, 'diesel');
      expect(back.useCases, containsAll(['events', 'construction']));
      expect(back.sort, GeneratorSortBy.ratingTop);
      // query is transient, not persisted
      expect(back.query, '');
    });

    test('empty filter round-trips to defaults', () {
      final back = GeneratorFilter.fromJson(const GeneratorFilter().toJson());
      expect(back.hasActiveFilters, false);
      expect(back.sort, GeneratorSortBy.newest);
    });

    test('fromJson with out-of-range sort index defaults to newest', () {
      final back = GeneratorFilter.fromJson({'sort': 999});
      expect(back.sort, GeneratorSortBy.newest);
    });

    test('fromJson with empty map gives default filter', () {
      final back = GeneratorFilter.fromJson({});
      expect(back.hasActiveFilters, false);
    });
  });
}
