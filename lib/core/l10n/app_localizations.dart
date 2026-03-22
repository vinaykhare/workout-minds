import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout Minds'**
  String get appTitle;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorPrefix(Object message);

  /// No description provided for @aiGenerate.
  ///
  /// In en, this message translates to:
  /// **'AI Generate'**
  String get aiGenerate;

  /// No description provided for @aiGeneratorTitle.
  ///
  /// In en, this message translates to:
  /// **'What are we hitting today?'**
  String get aiGeneratorTitle;

  /// No description provided for @aiGeneratorHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Heavy Chest Day'**
  String get aiGeneratorHint;

  /// No description provided for @aiGeneratorHelperText.
  ///
  /// In en, this message translates to:
  /// **'Gemini will build a custom plan based on this.'**
  String get aiGeneratorHelperText;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// No description provided for @heavyChestDay.
  ///
  /// In en, this message translates to:
  /// **'Heavy Chest Day'**
  String get heavyChestDay;

  /// No description provided for @workoutStarted.
  ///
  /// In en, this message translates to:
  /// **'Workout started. Let\'s crush it!'**
  String get workoutStarted;

  /// No description provided for @workoutPaused.
  ///
  /// In en, this message translates to:
  /// **'Workout paused.'**
  String get workoutPaused;

  /// No description provided for @workoutStopped.
  ///
  /// In en, this message translates to:
  /// **'Workout stopped. Great job today!'**
  String get workoutStopped;

  /// No description provided for @workoutComplete.
  ///
  /// In en, this message translates to:
  /// **'Workout complete. Fantastic job today!'**
  String get workoutComplete;

  /// No description provided for @nextUp.
  ///
  /// In en, this message translates to:
  /// **'Next up: {name}. Set {setNum} of {total}. Target is {reps} reps.'**
  String nextUp(Object name, Object reps, Object setNum, Object total);

  /// No description provided for @setCompleteRest.
  ///
  /// In en, this message translates to:
  /// **'Set complete. Rest for {seconds} seconds.'**
  String setCompleteRest(Object seconds);

  /// No description provided for @exerciseCompleteRest.
  ///
  /// In en, this message translates to:
  /// **'Exercise complete. Rest for {seconds} seconds.'**
  String exerciseCompleteRest(Object seconds);

  /// No description provided for @restOver.
  ///
  /// In en, this message translates to:
  /// **'Rest is over. Let\'s start set {setNum}!'**
  String restOver(Object setNum);

  /// No description provided for @finishSet.
  ///
  /// In en, this message translates to:
  /// **'FINISH SET'**
  String get finishSet;

  /// No description provided for @endWorkout.
  ///
  /// In en, this message translates to:
  /// **'End Workout Early'**
  String get endWorkout;

  /// No description provided for @restTime.
  ///
  /// In en, this message translates to:
  /// **'Rest Time'**
  String get restTime;

  /// No description provided for @getReady.
  ///
  /// In en, this message translates to:
  /// **'Get Ready...'**
  String get getReady;

  /// No description provided for @genderTitle.
  ///
  /// In en, this message translates to:
  /// **'How do you identify?'**
  String get genderTitle;

  /// No description provided for @genderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This helps our AI calculate your baseline metrics.'**
  String get genderSubtitle;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;
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
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
