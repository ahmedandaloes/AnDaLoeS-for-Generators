/// Canonical use-case segments a generator can serve. Drives the B2B
/// repositioning (see docs/BUSINESS_STRATEGY.md): owners tag listings, customers
/// filter by need. Shared by the owner add/edit forms and the browse filter so
/// the vocabulary stays consistent.
const List<String> kGeneratorUseCases = [
  'events',
  'construction',
  'industrial',
  'commercial',
  'telecom',
  'agriculture',
  'residential',
];

/// Title-cased display label for a use-case tag (e.g. 'events' → 'Events').
String useCaseLabel(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
