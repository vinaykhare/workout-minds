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

  @override
  String get builderNameLabel => 'Workout ka Naam';

  @override
  String get builderEmptyMsg => '+ dabayein aur pehli exercise jodein';

  @override
  String get builderAddBtn => 'Exercise Jodein';

  @override
  String get exSets => 'Sets:';

  @override
  String get exReps => 'Reps:';

  @override
  String get exDuration => 'Samay (Duration):';

  @override
  String get exRestSets => 'Sets ke beech aaram:';

  @override
  String get exRestNext => 'Agli exercise se pehle aaram:';

  @override
  String get exTimeBased => 'Time-based Exercise';

  @override
  String get exEquipment => 'Equipment (Zaroori nahi)';

  @override
  String get exTargetWeight => 'Target Wazan';

  @override
  String get exInstructions => 'Instructions aur Tips';

  @override
  String get detailOptimizeBtn =>
      'Feedback ke hisaab se Workout behtar banayein';

  @override
  String get detailOptimizingMsg =>
      'Aapka feedback dekha ja raha hai...\nWorkout update ho raha hai...';

  @override
  String get detailOptimizeSuccess => '✨ Workout successfully update ho gaya!';

  @override
  String get detailNoExercises => 'Is workout mein koi exercise nahi mili.';

  @override
  String detailRestNext(String time) {
    return 'Agli exercise se pehle $time aaram karein';
  }

  @override
  String get detailResume => 'Workout Resume Karein';

  @override
  String get detailStart => 'Workout Shuru Karein';

  @override
  String get detailRestart => 'Workout Phir Se Shuru Karein';

  @override
  String get detailRestartTitle => 'Workout wapas shuru karein?';

  @override
  String get detailEndActiveTitle => 'Chalu workout band karein?';

  @override
  String detailRestartContent(String workout) {
    return 'Kya aap sach mein \"$workout\" ko shuruwat se karna chahte hain?';
  }

  @override
  String detailEndActiveContent(String active, String target) {
    return 'Kya aap apna chalu workout \"$active\" band karke \"$target\" shuru karna chahte hain?';
  }

  @override
  String get detailEndAndStartBtn => 'Band karein aur Naya Shuru karein';

  @override
  String detailStatExercises(int count) {
    return '$count Exercises';
  }

  @override
  String detailStatSets(int count) {
    return 'Kul $count Sets';
  }

  @override
  String get detailStatEquipment => 'Equipment';

  @override
  String get detailStatVolume => 'Kul Wazan Uthaya';

  @override
  String get detailSummaryTitle => 'Workout ka Summary';

  @override
  String get detailActionEdit => 'Badlein (Edit)';

  @override
  String get detailActionShare => 'Share';

  @override
  String get detailActionDownload => 'Download';

  @override
  String get detailActionDelete => 'Hatao (Delete)';

  @override
  String get planProgress => 'Plan ka Progress';

  @override
  String get planConquered => 'Plan Poora Hua!';

  @override
  String planCompletedOn(String date) {
    return '$date ko poora hua';
  }

  @override
  String get planClaimVictory => 'Jeet ka Jashn Manayein aur Reset Karein';

  @override
  String get planStart => 'Plan Shuru Karein';

  @override
  String get planResume => 'Plan Wapas Shuru Karein';

  @override
  String get planResetTitle => 'Progress Reset Karein?';

  @override
  String get planResetContent =>
      'Isse sabhi din uncheck ho jayenge aur calendar tracking ruk jayegi.';

  @override
  String get planResetBtn => 'Reset Karein';

  @override
  String get planOptimizeBtn =>
      'Feedback ke hisaab se Schedule behtar banayein';

  @override
  String get planSchedule => 'Schedule';

  @override
  String get planRestDay => 'Aaram ka Din';

  @override
  String get planRest => 'Aaram';

  @override
  String planDayLabel(int num) {
    return 'Din\n$num';
  }

  @override
  String get planActionShare => 'Plan Share Karein';

  @override
  String get planActionDownload => 'Device mein Save karein';

  @override
  String get planActionEdit => 'Plan Badlein';

  @override
  String get planActionDelete => 'Plan Hatao';

  @override
  String get planDeleteTitle => 'Plan Delete Karein?';

  @override
  String get planDeleteContent =>
      'Kya aap waqai is plan ko delete karna chahte hain? Aapke individual workouts delete NAHI honge.';

  @override
  String get builderPlanTitle => 'Plan Banayein';

  @override
  String get builderPlanName => 'Plan ka Naam';

  @override
  String get builderPlanNameHint => 'Jaise: 4-Week Shred';

  @override
  String get builderPlanDuration => 'Samay (Duration)';

  @override
  String builderPlanWeeks(int w) {
    return '$w Hafte (Weeks)';
  }

  @override
  String get builderPlanTapDay =>
      'Workout assign karne ke liye kisi bhi din par tap karein:';

  @override
  String builderAssignDay(int num) {
    return 'Din $num Assign Karein';
  }

  @override
  String get searchWorkoutsHint => 'Workouts dhoondein...';

  @override
  String countdownDay(int num) {
    return 'Din $num';
  }

  @override
  String get countdownProjectionTitle => 'Plan ka Anuman';

  @override
  String countdownProjectionText(String date) {
    return 'Agar aap aise hi chalte rahe, toh aapka plan is din poora hoga:\n$date';
  }

  @override
  String get countdownSeconds => 'Shuru hone mein seconds...';

  @override
  String get countdownSkip => 'Timer Chhodein aur Shuru Karein';

  @override
  String get countdownCancel => 'Cancel Karein aur Wapas Jayein';

  @override
  String get countdownEmptyError =>
      'Is workout mein koi exercise nahi hai! Pehle ise edit karein.';

  @override
  String get importReviewTitle => 'Import Review Karein';

  @override
  String get importDefaultTitle => 'Import kiya gaya Plan';

  @override
  String importWeeksGoal(int weeks, String goal) {
    return '$weeks Hafte  •  $goal';
  }

  @override
  String get importEditBtn => 'Plan Details Badlein';

  @override
  String get importInstructions =>
      'Device mein save karne se pehle kisi bhi workout par tap karke dekhein ya badlein.';

  @override
  String get importIncluded => 'Shamil Workouts';

  @override
  String importExercisesCount(int count) {
    return '$count Exercises';
  }

  @override
  String get importSaving => 'Save ho raha hai...';

  @override
  String get importSaveBtn => 'Plan aur Workouts Save Karein';

  @override
  String importFailed(String error) {
    return 'Import fail ho gaya: $error';
  }

  @override
  String get importEditDialogTitle => 'Plan Details Badlein';

  @override
  String get importEditNameLabel => 'Plan ka Naam';

  @override
  String get importEditDescLabel => 'Description';

  @override
  String get importEditGoalLabel => 'Goal (Jaise: Muscle Banana)';

  @override
  String get importEditSaveBtn => 'Details Save Karein';

  @override
  String get summaryPlanHistory => 'Plan ki History';

  @override
  String get summaryWorkoutsCompleted => 'Poore kiye gaye Workouts';

  @override
  String get summaryNoLogs => 'Is run ke liye koi workout log nahi mila.';

  @override
  String summaryWorkoutSession(int vol) {
    return 'Workout Session (Volume: $vol)';
  }

  @override
  String get logDetailSummary => 'Workout ka Summary';

  @override
  String get logDetailExercises => 'Poori ki gayi Exercises';

  @override
  String get logDetailNoExercises => 'Is log mein koi exercise nahi mili.';
}
