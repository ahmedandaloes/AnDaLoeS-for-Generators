class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.totalOwners,
    required this.totalGenerators,
    required this.pendingCompanies,
    required this.activeRentals,
    required this.completedRentals,
    required this.totalRevenue,
    required this.openReports,
  });

  final int totalUsers;
  final int totalOwners;
  final int totalGenerators;
  final int pendingCompanies;
  final int activeRentals;
  final int completedRentals;
  final double totalRevenue;
  final int openReports;

  factory AdminStats.empty() => const AdminStats(
        totalUsers: 0,
        totalOwners: 0,
        totalGenerators: 0,
        pendingCompanies: 0,
        activeRentals: 0,
        completedRentals: 0,
        totalRevenue: 0,
        openReports: 0,
      );
}
