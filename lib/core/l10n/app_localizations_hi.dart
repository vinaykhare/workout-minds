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
  String errorPrefix(Object message) {
    return 'Arre error ho gaya: $message';
  }

  @override
  String get aiGenerate => 'AI se banao';

  @override
  String get aiGeneratorTitle => 'Aaj kya hit karna hai?';

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

  @override
  String get workoutStarted =>
      'Workout shuru ho gaya hai. Chalo shuru karte hain!';

  @override
  String get workoutPaused => 'Workout ruk gaya hai.';

  @override
  String get workoutStopped => 'Workout khatam. Aaj badhiya kaam kiya!';

  @override
  String get workoutComplete => 'Workout poora hua. Shabaash!';

  @override
  String nextUp(Object name, Object reps, Object setNum, Object total) {
    return 'Ab agli exercise: $name. Set $setNum of $total. Target hai $reps reps.';
  }

  @override
  String setCompleteRest(Object seconds) {
    return 'Set poora hua. Ab $seconds seconds rest karo.';
  }

  @override
  String exerciseCompleteRest(Object seconds) {
    return 'Exercise poori hui. Ab $seconds seconds rest karo.';
  }

  @override
  String restOver(Object setNum) {
    return 'Rest khatam. Chalo set $setNum shuru karein!';
  }

  @override
  String get finishSet => 'SET POORA HUA';

  @override
  String get endWorkout => 'Workout band karo';

  @override
  String get restTime => 'Aaraam ka samay';

  @override
  String get getReady => 'Taiyaar ho jao...';
}
