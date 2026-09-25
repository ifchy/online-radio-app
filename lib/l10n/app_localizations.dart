import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bg.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bg'),
    Locale('en'),
  ];

  /// App name shown in the launcher task switcher and window title. The same word in every language.
  ///
  /// In en, this message translates to:
  /// **'eRadioto'**
  String get appTitle;

  /// AppBar title of the home screen's station list.
  ///
  /// In en, this message translates to:
  /// **'Stations'**
  String get stationListTitle;

  /// Tooltip and TalkBack label of the mini-player button that starts or resumes playback.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get actionPlay;

  /// Tooltip and TalkBack label of the mini-player button that pauses playback.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get actionPause;

  /// Tooltip and TalkBack label of the mini-player button that stops playback and hides the player.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get actionStop;

  /// TalkBack hint on a station tile in the list: what tapping the tile does.
  ///
  /// In en, this message translates to:
  /// **'Play {station}'**
  String playStationHint(String station);

  /// Mini-player and notification state label while the stream is being opened.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get stateConnecting;

  /// Mini-player and notification state label while playback waits for more data.
  ///
  /// In en, this message translates to:
  /// **'Buffering…'**
  String get stateBuffering;

  /// Mini-player and notification state label while the app retries a dropped stream.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get stateReconnecting;

  /// Mini-player and notification state label while another app (e.g. a phone call) has taken audio focus.
  ///
  /// In en, this message translates to:
  /// **'Interrupted'**
  String get stateInterrupted;

  /// Mini-player and notification state label while playback is paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get statePaused;

  /// Mini-player and notification state label after playback failed. The friendly error text comes in Phase 4.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get stateError;

  /// Name of the Android notification channel for the media notification, shown in the system notification settings.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get notificationChannelName;

  /// TalkBack label of the mini-player region at the bottom of the screen.
  ///
  /// In en, this message translates to:
  /// **'Now playing: {station}'**
  String miniPlayerRegionLabel(String station);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bg', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bg':
      return AppLocalizationsBg();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
