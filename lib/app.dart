import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/theme_provider.dart';
import 'core/localization/app_localizations.dart';
import 'presentation/router/app_router.dart';

class NMSApp extends ConsumerWidget {
  final AppRouter appRouter;

  const NMSApp({super.key, required this.appRouter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(resolvedThemeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Hospital NMS',
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter.router,
    );
  }
}
