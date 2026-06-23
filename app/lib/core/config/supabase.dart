import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

/// Initializes the Supabase client. Call once before runApp().
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );
}

/// Shorthand for the global Supabase client.
SupabaseClient get supabase => Supabase.instance.client;
