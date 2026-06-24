import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/supabase.dart';
import 'core/localization/locale_provider.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/presentation/onboarding_screen.dart';
import 'features/generators/presentation/widgets/generator_filter.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();

  final container = ProviderContainer();
  final results = await Future.wait([
    container.read(themeModeProvider.notifier).load(),
    container.read(localeProvider.notifier).load(),
    hasSeenOnboarding(),
    loadSavedFilter(),
  ]);
  final seenOnboarding = results[2] as bool;
  // Restore the user's last home filters/sort.
  container.read(filterProvider.notifier).state =
      results[3] as GeneratorFilter;

  runApp(UncontrolledProviderScope(
    container: container,
    child: AndaloesApp(initialLocation: seenOnboarding ? '/' : '/onboarding'),
  ));
}

class AndaloesApp extends ConsumerStatefulWidget {
  const AndaloesApp({super.key, this.initialLocation = '/'});
  final String initialLocation;

  @override
  ConsumerState<AndaloesApp> createState() => _AndaloesAppState();
}

class _AndaloesAppState extends ConsumerState<AndaloesApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildAppRouter(widget.initialLocation);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: _router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
