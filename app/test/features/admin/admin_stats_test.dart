import 'package:flutter_test/flutter_test.dart';

import 'package:andaloes/features/admin/domain/entities/admin_stats.dart';

void main() {
  group('AdminStats.empty()', () {
    test('returns instance with all zeros', () {
      const s = AdminStats(
        totalUsers: 0,
        totalOwners: 0,
        totalGenerators: 0,
        pendingCompanies: 0,
        activeRentals: 0,
        completedRentals: 0,
        totalRevenue: 0,
        openReports: 0,
      );
      expect(s.totalUsers, 0);
      expect(s.totalOwners, 0);
      expect(s.totalGenerators, 0);
      expect(s.pendingCompanies, 0);
      expect(s.activeRentals, 0);
      expect(s.completedRentals, 0);
      expect(s.totalRevenue, 0.0);
      expect(s.openReports, 0);
    });

    test('AdminStats.empty() factory produces all-zero fields', () {
      final s = AdminStats.empty();
      expect(s.totalUsers, 0);
      expect(s.totalOwners, 0);
      expect(s.totalGenerators, 0);
      expect(s.pendingCompanies, 0);
      expect(s.activeRentals, 0);
      expect(s.completedRentals, 0);
      expect(s.totalRevenue, 0.0);
      expect(s.openReports, 0);
    });
  });

  group('AdminStats constructor', () {
    const stats = AdminStats(
      totalUsers: 120,
      totalOwners: 15,
      totalGenerators: 42,
      pendingCompanies: 3,
      activeRentals: 8,
      completedRentals: 97,
      totalRevenue: 48500.75,
      openReports: 2,
    );

    test('totalUsers maps correctly', () {
      expect(stats.totalUsers, 120);
    });

    test('totalOwners maps correctly', () {
      expect(stats.totalOwners, 15);
    });

    test('totalGenerators maps correctly', () {
      expect(stats.totalGenerators, 42);
    });

    test('pendingCompanies maps correctly', () {
      expect(stats.pendingCompanies, 3);
    });

    test('activeRentals maps correctly', () {
      expect(stats.activeRentals, 8);
    });

    test('completedRentals maps correctly', () {
      expect(stats.completedRentals, 97);
    });

    test('totalRevenue maps as double', () {
      expect(stats.totalRevenue, 48500.75);
    });

    test('openReports maps correctly', () {
      expect(stats.openReports, 2);
    });
  });

  group('AdminStats edge cases', () {
    test('large totalRevenue value preserved', () {
      const s = AdminStats(
        totalUsers: 0,
        totalOwners: 0,
        totalGenerators: 0,
        pendingCompanies: 0,
        activeRentals: 0,
        completedRentals: 0,
        totalRevenue: 9999999.99,
        openReports: 0,
      );
      expect(s.totalRevenue, closeTo(9999999.99, 0.001));
    });

    test('activeRentals can be zero without issue', () {
      const s = AdminStats(
        totalUsers: 10,
        totalOwners: 2,
        totalGenerators: 5,
        pendingCompanies: 0,
        activeRentals: 0,
        completedRentals: 50,
        totalRevenue: 25000,
        openReports: 0,
      );
      expect(s.activeRentals, 0);
    });
  });
}
