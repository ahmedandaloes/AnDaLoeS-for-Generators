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
    defaultValue: 'https://xugierxfccleozfidard.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_8wcCikvVyVHgau82jyBtEw_hxH5dqVy',
  );
}
