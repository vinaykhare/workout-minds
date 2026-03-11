// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Workout Minds';

  @override
  String errorPrefix(String message) {
    return 'Error: $message';
  }

  @override
  String get aiGenerate => 'AI Generate';

  @override
  String get aiGeneratorTitle => 'What are we hitting today?';

  @override
  String get aiGeneratorHint => 'e.g. Heavy Chest Day';

  @override
  String get aiGeneratorHelperText =>
      'Gemini will build a custom plan based on this.';

  @override
  String get cancel => 'Cancel';

  @override
  String get generate => 'Generate';

  @override
  String get heavyChestDay => 'Heavy Chest Day';
}
