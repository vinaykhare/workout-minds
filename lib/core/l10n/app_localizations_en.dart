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
  String errorPrefix(Object message) {
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
  String nextUp(Object name, Object reps, Object setNum, Object total) {
    return 'Next up: $name. Set $setNum of $total. Target is $reps reps.';
  }

  @override
  String setCompleteRest(Object seconds) {
    return 'Set complete. Rest for $seconds seconds.';
  }

  @override
  String exerciseCompleteRest(Object seconds) {
    return 'Exercise complete. Rest for $seconds seconds.';
  }

  @override
  String restOver(Object setNum) {
    return 'Rest is over. Let\'s start set $setNum!';
  }

  @override
  String get finishSet => 'FINISH SET';

  @override
  String get endWorkout => 'End Workout Early';

  @override
  String get restTime => 'Rest Time';

  @override
  String get getReady => 'Get Ready...';

  @override
  String get genderTitle => 'How do you identify?';

  @override
  String get genderSubtitle =>
      'This helps our AI calculate your baseline metrics.';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get welcomeSubtitle =>
      'Your AI-powered fitness journey,\nsynced securely with Google Drive.';

  @override
  String get restoreGoogle => 'Restore from Google Drive';

  @override
  String get startFresh => 'Start Fresh';

  @override
  String get chooseLanguageTitle => 'Choose Language';

  @override
  String get chooseLanguageSub => 'How would you like the app to talk to you?';

  @override
  String get goalTitle => 'What is your primary goal?';

  @override
  String get goalSub =>
      'We\'ll tailor your AI-generated workouts to focus on this.';

  @override
  String get goalWeight => 'Lose Weight';

  @override
  String get goalMuscle => 'Build Muscle';

  @override
  String get goalFit => 'Stay Fit & Active';

  @override
  String get assessTitle => 'Let\'s assess your strength';

  @override
  String get assessSub =>
      'Be honest! This helps the AI set your starting difficulty.';

  @override
  String get assessPushups => 'Max Pushups in one go:';

  @override
  String get assessPullups => 'Max Pull-ups in one go:';

  @override
  String get assessSquats => 'Max Bodyweight Squats in one go:';

  @override
  String get metricsTitle => 'Let\'s get your metrics';

  @override
  String get metricsSub => 'Used to calculate your BMI and daily caloric burn.';

  @override
  String get heightLabel => 'Height (cm)';

  @override
  String get weightLabel => 'Weight (kg)';

  @override
  String get finishSetup => 'Finish Setup';

  @override
  String get genderOther => 'Other / Prefer not to say';

  @override
  String get generatingPlan => 'Generating your first custom plan...';

  @override
  String get settingsStrengthBaseline => 'Strength Baseline';

  @override
  String get settingsMaxPushups => 'Max Pushups';

  @override
  String get settingsMaxPullups => 'Max Pull-ups';

  @override
  String get settingsMaxSquats => 'Max Squats';

  @override
  String get styleTitle => 'Training Style';

  @override
  String get styleGym => 'Full Gym (All Equipment)';

  @override
  String get styleDumbbell => 'Home (Dumbbells & Bands)';

  @override
  String get styleBodyweight => 'Bodyweight Only (No Equipment)';

  @override
  String get styleYoga => 'Yoga & Flexibility';

  @override
  String get aiUsingProfile => 'Using profile:';

  @override
  String get aiEditProfile => 'Edit';

  @override
  String get warningWorkoutDeletion =>
      'This will permanently delete this workout and all its historical execution logs. This cannot be undone!';

  @override
  String get skip => 'Skip';

  @override
  String get generateAiPlan => 'Generate AI Plan (1 Credit)';

  @override
  String get skipAi => 'Skip AI & Go to Dashboard';

  @override
  String get themeTitle => 'App Theme';

  @override
  String get themeSystem => 'System Default';

  @override
  String get themeLight => 'Light Mode';

  @override
  String get themeDark => 'Dark Mode';

  @override
  String get builderNameLabel => 'Workout Name';

  @override
  String get builderEmptyMsg => 'Tap + to add your first exercise';

  @override
  String get builderAddBtn => 'Add Exercise';

  @override
  String get exSets => 'Sets:';

  @override
  String get exReps => 'Reps:';

  @override
  String get exDuration => 'Duration:';

  @override
  String get exRestSets => 'Rest Between Sets:';

  @override
  String get exRestNext => 'Rest Before Next:';

  @override
  String get exTimeBased => 'Time-based Exercise';

  @override
  String get exEquipment => 'Equipment (Opt.)';

  @override
  String get exTargetWeight => 'Target Weight';

  @override
  String get exInstructions => 'Exercise Instructions & Tips';

  @override
  String get detailOptimizeBtn => 'Optimize Workout based on Feedback';

  @override
  String get detailOptimizingMsg =>
      'Analyzing your feedback...\nOptimizing this workout...';

  @override
  String get detailOptimizeSuccess => '✨ Workout Optimized Successfully!';

  @override
  String get detailNoExercises => 'No exercises found in this workout.';

  @override
  String detailRestNext(String time) {
    return 'Rest $time before next exercise';
  }

  @override
  String get detailStart => 'Start Workout';

  @override
  String get detailRestart => 'Restart Workout';

  @override
  String get detailRestartTitle => 'Restart Workout?';

  @override
  String get detailEndActiveTitle => 'End Active Workout?';

  @override
  String detailRestartContent(String workout) {
    return 'Are you sure you want to restart \"$workout\" from the beginning?';
  }

  @override
  String detailEndActiveContent(String active, String target) {
    return 'Are you sure you want to end your active workout \"$active\" and start \"$target\"?';
  }

  @override
  String get detailEndAndStartBtn => 'End & Start New';

  @override
  String detailStatExercises(int count) {
    return '$count Exercises';
  }

  @override
  String detailStatSets(int count) {
    return '$count Total Sets';
  }

  @override
  String get detailStatEquipment => 'Equipment';

  @override
  String get detailStatVolume => 'Total Volume Lifted';

  @override
  String get detailSummaryTitle => 'Workout Summary';

  @override
  String get detailActionEdit => 'Edit';

  @override
  String get detailActionShare => 'Share';

  @override
  String get detailActionDownload => 'Download';

  @override
  String get detailActionDelete => 'Delete';
}
