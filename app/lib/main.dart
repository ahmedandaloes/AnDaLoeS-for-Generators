import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/supabase.dart';
import 'core/localization/locale_provider.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/presentation/onboarding_screen.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();

  final container = ProviderContainer();
  final results = await Future.wait([
    container.read(themeModeProvider.notifier).load(),
    container.read(localeProvider.notifier).load(),
    hasSeenOnboarding(),
  ]);
  final seenOnboarding = results[2] as bool;

  runApp(UncontrolledProviderScope(
    container: container,
    child: AndaloesApp(initialLocation: seenOnboarding ? '/' : '/onboarding'),
  ));
}

class AndaloesApp extends ConsumerWidget {
  const AndaloesApp({super.key, this.initialLocation = '/'});
  final String initialLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: buildAppRouter(initialLocation),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
