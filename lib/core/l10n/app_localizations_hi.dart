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

  @override
  String get genderTitle => 'Aapka gender kya hai?';

  @override
  String get genderSubtitle => 'Isse hamari AI aapke metrics calculate karegi.';

  @override
  String get genderMale => 'Purush (Male)';

  @override
  String get genderFemale => 'Mahila (Female)';

  @override
  String get welcomeSubtitle =>
      'Aapka AI fitness journey,\nGoogle Drive ke saath securely synced.';

  @override
  String get restoreGoogle => 'Google Drive se Restore karein';

  @override
  String get startFresh => 'Nayi Shuruvaat';

  @override
  String get chooseLanguageTitle => 'Bhasha Chunein';

  @override
  String get chooseLanguageSub =>
      'Aap app ko kis bhasha mein use karna chahenge?';

  @override
  String get goalTitle => 'Aapka primary goal kya hai?';

  @override
  String get goalSub => 'AI aapke workouts isi goal par focus karegi.';

  @override
  String get goalWeight => 'Wazan Kam Karna (Lose Weight)';

  @override
  String get goalMuscle => 'Muscle Banana (Build Muscle)';

  @override
  String get goalFit => 'Fit Rehna (Stay Fit)';

  @override
  String get assessTitle => 'Aapki strength test karein';

  @override
  String get assessSub =>
      'Sahi batana! Isse AI aapka starting level decide karegi.';

  @override
  String get assessPushups => 'Ek baar mein max Pushups:';

  @override
  String get assessPullups => 'Ek baar mein max Pull-ups:';

  @override
  String get assessSquats => 'Ek baar mein max Squats:';

  @override
  String get metricsTitle => 'Aapke metrics kya hain?';

  @override
  String get metricsSub => 'Aapka BMI calculate karne ke liye.';

  @override
  String get heightLabel => 'Height (Kadd) - cm';

  @override
  String get weightLabel => 'Weight (Wazan) - kg';

  @override
  String get finishSetup => 'Setup Poora Karein';

  @override
  String get genderOther => 'Anya / Batana nahi chahte';

  @override
  String get generatingPlan => 'Aapka custom plan ban raha hai...';

  @override
  String get settingsStrengthBaseline => 'Strength Baseline (Taakat)';

  @override
  String get settingsMaxPushups => 'Max Pushups';

  @override
  String get settingsMaxPullups => 'Max Pull-ups';

  @override
  String get settingsMaxSquats => 'Max Squats';

  @override
  String get styleTitle => 'Training Style';

  @override
  String get styleGym => 'Full Gym (Saari Machines)';

  @override
  String get styleDumbbell => 'Home (Sirf Dumbbells/Bands)';

  @override
  String get styleBodyweight => 'Bodyweight (Bina Equipment)';

  @override
  String get styleYoga => 'Yoga aur Stretching';

  @override
  String get aiUsingProfile => 'Aapki profile ke mutaabiq:';

  @override
  String get aiEditProfile => 'Badlein';

  @override
  String get warningWorkoutDeletion =>
      'Yah workout aur iske sabhi purane Execution Logs humesha k liye delete ho jayenge. Ise wapas nahi kiya ja sakta!';

  @override
  String get skip => 'Chhodein (Skip)';

  @override
  String get generateAiPlan => 'AI Plan Banao (1 Credit)';

  @override
  String get skipAi => 'Skip karein aur Dashboard par jayein';

  @override
  String get themeTitle => 'App Theme (Rang)';

  @override
  String get themeSystem => 'System Default';

  @override
  String get themeLight => 'Light Mode';

  @override
  String get themeDark => 'Dark Mode';
}
