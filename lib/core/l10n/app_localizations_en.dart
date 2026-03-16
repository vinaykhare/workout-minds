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

  @override
  String get workoutStarted => 'Workout started. Let\'s crush it!';

  @override
  String get workoutPaused => 'Workout paused.';

  @override
  String get workoutStopped => 'Workout stopped. Great job today!';

  @override
  String get workoutComplete => 'Workout complete. Fantastic job today!';

  @override
  String nextUp(Object name, Object reps, Object set, Object total) {
    return 'Next up: $name. Set $set of $total. Target is $reps reps.';
  }

  @override
  String get setCompleteRest => 'Set complete. Rest for 60 seconds.';

  @override
  String restOver(Object set) {
    return 'Rest is over. Get ready for set $set.';
  }

  @override
  String get finishSet => 'FINISH SET';

  @override
  String get endWorkout => 'End Workout Early';

  @override
  String get restTime => 'Rest Time';

  @override
  String get getReady => 'Get Ready...';
}
