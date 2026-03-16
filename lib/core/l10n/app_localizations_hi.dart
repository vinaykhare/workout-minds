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
  String nextUp(Object name, Object reps, Object set, Object total) {
    return 'Ab agli exercise: $name. Set $set of $total. Target hai $reps reps.';
  }

  @override
  String get setCompleteRest => 'Set poora hua. Ab 60 seconds rest karo.';

  @override
  String restOver(Object set) {
    return 'Rest khatam. Set $set ke liye taiyaar ho jao.';
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
