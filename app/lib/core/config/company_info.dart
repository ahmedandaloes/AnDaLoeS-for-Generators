/// Legal / tax identity of the platform operator, shown on invoices and
/// receipts so they're tax-ready (Egypt). FILL THESE IN with the real
/// registered values before issuing invoices in production — and confirm VAT
/// treatment with an accountant.
class CompanyInfo {
  static const String legalName = 'Thabit Power';
  static const String taxRegistrationNumber = '___-___-___'; // set real ETA tax #
  static const String commercialRegister = '________'; // set real CR number

  /// Egypt standard VAT rate. Displayed totals are treated as VAT-inclusive
  /// (common Egyptian convention); the VAT component is total − total / 1.14.
  static const double vatRate = 0.14;

  /// VAT component of a VAT-inclusive amount.
  static double vatComponentOf(num inclusiveTotal) =>
      inclusiveTotal - inclusiveTotal / (1 + vatRate);

  /// Whether tax identifiers have been configured (controls showing them).
  static bool get hasTaxIds =>
      !taxRegistrationNumber.contains('_') &&
      taxRegistrationNumber.trim().isNotEmpty;
}
