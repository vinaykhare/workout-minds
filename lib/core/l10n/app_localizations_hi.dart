// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'Workout Minds';

  @override
  String errorPrefix(String message) {
    return 'Arre error ho gaya: $message';
  }

  @override
  String get aiGenerate => 'AI se banao';

  @override
  String get aiGeneratorTitle => 'Aaj kya Exercise karna hai?';

  @override
  String get aiGeneratorHint => 'Jaise: Heavy Chest Day';

  @override
  String get aiGeneratorHelperText =>
      'Gemini is hisaab se Ek Custom Plan banayega.';

  @override
  String get cancel => 'Rehne do';

  @override
  String get generate => 'Banao';

  @override
  String get heavyChestDay => 'Zabardast Chest Day';
}
