/// Environment configuration.
///
/// The Supabase URL and publishable key are **safe to ship in a client app** —
/// they are protected by Row Level Security on the database. NEVER put the
/// `service_role` key or the database password here.
///
/// Values can be overridden at build/run time with --dart-define, e.g.:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class Env {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vpfhxxpqkxkucywodpaa.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwZmh4eHBxa3hrdWN5d29kcGFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxNjE4NjQsImV4cCI6MjA5NzczNzg2NH0._NhJ2GNGQvgPRdAqdmNsH75wa843X1JUmqo2oM8w374',
  );
}
