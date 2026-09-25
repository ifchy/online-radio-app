import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'home_screen.dart';

/// Picks the UI language from the device locale (D-08): Bulgarian on a
/// device set to Bulgarian (any region), English for everything else.
///
/// Also used outside the widget tree (01-07's bootstrap builds the
/// notification strings with `lookupAppLocalizations(resolveAppLocale(...))`).
Locale resolveAppLocale(Locale? device) =>
    device?.languageCode == 'bg' ? const Locale('bg') : const Locale('en');

/// The app root, with the gen-l10n delegates (D-08).
class RadioApp extends StatelessWidget {
  const RadioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: ThemeData(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('bg'), Locale('en')],
      localeResolutionCallback: (device, _) => resolveAppLocale(device),
      home: const HomeScreen(),
    );
  }
}
