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

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your AI-powered fitness journey,\nsynced securely with Google Drive.'**
  String get welcomeSubtitle;

  /// No description provided for @restoreGoogle.
  ///
  /// In en, this message translates to:
  /// **'Restore from Google Drive'**
  String get restoreGoogle;

  /// No description provided for @startFresh.
  ///
  /// In en, this message translates to:
  /// **'Start Fresh'**
  String get startFresh;

  /// No description provided for @chooseLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Language'**
  String get chooseLanguageTitle;

  /// No description provided for @chooseLanguageSub.
  ///
  /// In en, this message translates to:
  /// **'How would you like the app to talk to you?'**
  String get chooseLanguageSub;

  /// No description provided for @goalTitle.
  ///
  /// In en, this message translates to:
  /// **'What is your primary goal?'**
  String get goalTitle;

  /// No description provided for @goalSub.
  ///
  /// In en, this message translates to:
  /// **'We\'ll tailor your AI-generated workouts to focus on this.'**
  String get goalSub;

  /// No description provided for @goalWeight.
  ///
  /// In en, this message translates to:
  /// **'Lose Weight'**
  String get goalWeight;

  /// No description provided for @goalMuscle.
  ///
  /// In en, this message translates to:
  /// **'Build Muscle'**
  String get goalMuscle;

  /// No description provided for @goalFit.
  ///
  /// In en, this message translates to:
  /// **'Stay Fit & Active'**
  String get goalFit;

  /// No description provided for @assessTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s assess your strength'**
  String get assessTitle;

  /// No description provided for @assessSub.
  ///
  /// In en, this message translates to:
  /// **'Be honest! This helps the AI set your starting difficulty.'**
  String get assessSub;

  /// No description provided for @assessPushups.
  ///
  /// In en, this message translates to:
  /// **'Max Pushups in one go:'**
  String get assessPushups;

  /// No description provided for @assessPullups.
  ///
  /// In en, this message translates to:
  /// **'Max Pull-ups in one go:'**
  String get assessPullups;

  /// No description provided for @assessSquats.
  ///
  /// In en, this message translates to:
  /// **'Max Bodyweight Squats in one go:'**
  String get assessSquats;

  /// No description provided for @metricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s get your metrics'**
  String get metricsTitle;

  /// No description provided for @metricsSub.
  ///
  /// In en, this message translates to:
  /// **'Used to calculate your BMI and daily caloric burn.'**
  String get metricsSub;

  /// No description provided for @heightLabel.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightLabel;

  /// No description provided for @weightLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightLabel;

  /// No description provided for @finishSetup.
  ///
  /// In en, this message translates to:
  /// **'Finish Setup'**
  String get finishSetup;

  /// No description provided for @genderOther.
  ///
  /// In en, this message translates to:
  /// **'Other / Prefer not to say'**
  String get genderOther;

  /// No description provided for @generatingPlan.
  ///
  /// In en, this message translates to:
  /// **'Generating your first custom plan...'**
  String get generatingPlan;

  /// No description provided for @settingsStrengthBaseline.
  ///
  /// In en, this message translates to:
  /// **'Strength Baseline'**
  String get settingsStrengthBaseline;

  /// No description provided for @settingsMaxPushups.
  ///
  /// In en, this message translates to:
  /// **'Max Pushups'**
  String get settingsMaxPushups;

  /// No description provided for @settingsMaxPullups.
  ///
  /// In en, this message translates to:
  /// **'Max Pull-ups'**
  String get settingsMaxPullups;

  /// No description provided for @settingsMaxSquats.
  ///
  /// In en, this message translates to:
  /// **'Max Squats'**
  String get settingsMaxSquats;

  /// No description provided for @styleTitle.
  ///
  /// In en, this message translates to:
  /// **'Training Style'**
  String get styleTitle;

  /// No description provided for @styleGym.
  ///
  /// In en, this message translates to:
  /// **'Full Gym (All Equipment)'**
  String get styleGym;

  /// No description provided for @styleDumbbell.
  ///
  /// In en, this message translates to:
  /// **'Home (Dumbbells & Bands)'**
  String get styleDumbbell;

  /// No description provided for @styleBodyweight.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight Only (No Equipment)'**
  String get styleBodyweight;

  /// No description provided for @styleYoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga & Flexibility'**
  String get styleYoga;

  /// No description provided for @aiUsingProfile.
  ///
  /// In en, this message translates to:
  /// **'Using profile:'**
  String get aiUsingProfile;

  /// No description provided for @aiEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get aiEditProfile;

  /// No description provided for @warningWorkoutDeletion.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this workout and all its historical execution logs. This cannot be undone!'**
  String get warningWorkoutDeletion;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @generateAiPlan.
  ///
  /// In en, this message translates to:
  /// **'Generate AI Plan (1 Credit)'**
  String get generateAiPlan;

  /// No description provided for @skipAi.
  ///
  /// In en, this message translates to:
  /// **'Skip AI & Go to Dashboard'**
  String get skipAi;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'App Theme'**
  String get themeTitle;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get themeDark;

  /// No description provided for @builderNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Workout Name'**
  String get builderNameLabel;

  /// No description provided for @builderEmptyMsg.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first exercise'**
  String get builderEmptyMsg;

  /// No description provided for @builderAddBtn.
  ///
  /// In en, this message translates to:
  /// **'Add Exercise'**
  String get builderAddBtn;

  /// No description provided for @exSets.
  ///
  /// In en, this message translates to:
  /// **'Sets:'**
  String get exSets;

  /// No description provided for @exReps.
  ///
  /// In en, this message translates to:
  /// **'Reps:'**
  String get exReps;

  /// No description provided for @exDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration:'**
  String get exDuration;

  /// No description provided for @exRestSets.
  ///
  /// In en, this message translates to:
  /// **'Rest Between Sets:'**
  String get exRestSets;

  /// No description provided for @exRestNext.
  ///
  /// In en, this message translates to:
  /// **'Rest Before Next:'**
  String get exRestNext;

  /// No description provided for @exTimeBased.
  ///
  /// In en, this message translates to:
  /// **'Time-based Exercise'**
  String get exTimeBased;

  /// No description provided for @exEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment (Opt.)'**
  String get exEquipment;

  /// No description provided for @exTargetWeight.
  ///
  /// In en, this message translates to:
  /// **'Target Weight'**
  String get exTargetWeight;

  /// No description provided for @exInstructions.
  ///
  /// In en, this message translates to:
  /// **'Exercise Instructions & Tips'**
  String get exInstructions;

  /// No description provided for @detailOptimizeBtn.
  ///
  /// In en, this message translates to:
  /// **'Optimize Workout based on Feedback'**
  String get detailOptimizeBtn;

  /// No description provided for @detailOptimizingMsg.
  ///
  /// In en, this message translates to:
  /// **'Analyzing your feedback...\nOptimizing this workout...'**
  String get detailOptimizingMsg;

  /// No description provided for @detailOptimizeSuccess.
  ///
  /// In en, this message translates to:
  /// **'✨ Workout Optimized Successfully!'**
  String get detailOptimizeSuccess;

  /// No description provided for @detailNoExercises.
  ///
  /// In en, this message translates to:
  /// **'No exercises found in this workout.'**
  String get detailNoExercises;

  /// No description provided for @detailRestNext.
  ///
  /// In en, this message translates to:
  /// **'Rest {time} before next exercise'**
  String detailRestNext(String time);

  /// No description provided for @detailResume.
  ///
  /// In en, this message translates to:
  /// **'Resume Workout'**
  String get detailResume;

  /// No description provided for @detailStart.
  ///
  /// In en, this message translates to:
  /// **'Start Workout'**
  String get detailStart;

  /// No description provided for @detailRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart Workout'**
  String get detailRestart;

  /// No description provided for @detailRestartTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart Workout?'**
  String get detailRestartTitle;

  /// No description provided for @detailEndActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'End Active Workout?'**
  String get detailEndActiveTitle;

  /// No description provided for @detailRestartContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to restart \"{workout}\" from the beginning?'**
  String detailRestartContent(String workout);

  /// No description provided for @detailEndActiveContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to end your active workout \"{active}\" and start \"{target}\"?'**
  String detailEndActiveContent(String active, String target);

  /// No description provided for @detailEndAndStartBtn.
  ///
  /// In en, this message translates to:
  /// **'End & Start New'**
  String get detailEndAndStartBtn;

  /// No description provided for @detailStatExercises.
  ///
  /// In en, this message translates to:
  /// **'{count} Exercises'**
  String detailStatExercises(int count);

  /// No description provided for @detailStatSets.
  ///
  /// In en, this message translates to:
  /// **'{count} Total Sets'**
  String detailStatSets(int count);

  /// No description provided for @detailStatEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get detailStatEquipment;

  /// No description provided for @detailStatVolume.
  ///
  /// In en, this message translates to:
  /// **'Total Volume Lifted'**
  String get detailStatVolume;

  /// No description provided for @detailSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout Summary'**
  String get detailSummaryTitle;

  /// No description provided for @detailActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get detailActionEdit;

  /// No description provided for @detailActionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get detailActionShare;

  /// No description provided for @detailActionDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get detailActionDownload;

  /// No description provided for @detailActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get detailActionDelete;

  /// No description provided for @planProgress.
  ///
  /// In en, this message translates to:
  /// **'Plan Progress'**
  String get planProgress;

  /// No description provided for @planConquered.
  ///
  /// In en, this message translates to:
  /// **'Plan Conquered!'**
  String get planConquered;

  /// No description provided for @planCompletedOn.
  ///
  /// In en, this message translates to:
  /// **'Completed on {date}'**
  String planCompletedOn(String date);

  /// No description provided for @planClaimVictory.
  ///
  /// In en, this message translates to:
  /// **'Claim Victory & Reset Plan'**
  String get planClaimVictory;

  /// No description provided for @planStart.
  ///
  /// In en, this message translates to:
  /// **'Start Plan'**
  String get planStart;

  /// No description provided for @planResume.
  ///
  /// In en, this message translates to:
  /// **'Resume Plan'**
  String get planResume;

  /// No description provided for @planResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Progress?'**
  String get planResetTitle;

  /// No description provided for @planResetContent.
  ///
  /// In en, this message translates to:
  /// **'This will uncheck all days and stop tracking the calendar dates.'**
  String get planResetContent;

  /// No description provided for @planResetBtn.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get planResetBtn;

  /// No description provided for @planOptimizeBtn.
  ///
  /// In en, this message translates to:
  /// **'Optimize Schedule based on Feedback'**
  String get planOptimizeBtn;

  /// No description provided for @planSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get planSchedule;

  /// No description provided for @planRestDay.
  ///
  /// In en, this message translates to:
  /// **'Rest Day'**
  String get planRestDay;

  /// No description provided for @planRest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get planRest;

  /// No description provided for @planDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Day\n{num}'**
  String planDayLabel(int num);

  /// No description provided for @planActionShare.
  ///
  /// In en, this message translates to:
  /// **'Share Plan'**
  String get planActionShare;

  /// No description provided for @planActionDownload.
  ///
  /// In en, this message translates to:
  /// **'Save to Device'**
  String get planActionDownload;

  /// No description provided for @planActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Plan'**
  String get planActionEdit;

  /// No description provided for @planActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Plan'**
  String get planActionDelete;

  /// No description provided for @planDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Plan?'**
  String get planDeleteTitle;

  /// No description provided for @planDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this workout plan? Your individual workouts will NOT be deleted.'**
  String get planDeleteContent;

  /// No description provided for @builderPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan Builder'**
  String get builderPlanTitle;

  /// No description provided for @builderPlanName.
  ///
  /// In en, this message translates to:
  /// **'Plan Name'**
  String get builderPlanName;

  /// No description provided for @builderPlanNameHint.
  ///
  /// In en, this message translates to:
  /// **'E.g., 4-Week Shred'**
  String get builderPlanNameHint;

  /// No description provided for @builderPlanDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get builderPlanDuration;

  /// No description provided for @builderPlanWeeks.
  ///
  /// In en, this message translates to:
  /// **'{w} Weeks'**
  String builderPlanWeeks(int w);

  /// No description provided for @builderPlanTapDay.
  ///
  /// In en, this message translates to:
  /// **'Tap a day to assign a workout:'**
  String get builderPlanTapDay;

  /// No description provided for @builderAssignDay.
  ///
  /// In en, this message translates to:
  /// **'Assign Day {num}'**
  String builderAssignDay(int num);

  /// No description provided for @searchWorkoutsHint.
  ///
  /// In en, this message translates to:
  /// **'Search workouts...'**
  String get searchWorkoutsHint;

  /// No description provided for @countdownDay.
  ///
  /// In en, this message translates to:
  /// **'Day {num}'**
  String countdownDay(int num);

  /// No description provided for @countdownProjectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan Projection'**
  String get countdownProjectionTitle;

  /// No description provided for @countdownProjectionText.
  ///
  /// In en, this message translates to:
  /// **'Keep up this pace and you will conquer this plan on:\n{date}'**
  String countdownProjectionText(String date);

  /// No description provided for @countdownSeconds.
  ///
  /// In en, this message translates to:
  /// **'Seconds to start...'**
  String get countdownSeconds;

  /// No description provided for @countdownSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip Timer & Start Now'**
  String get countdownSkip;

  /// No description provided for @countdownCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel & Go Back'**
  String get countdownCancel;

  /// No description provided for @countdownEmptyError.
  ///
  /// In en, this message translates to:
  /// **'This workout has no exercises! Edit it first.'**
  String get countdownEmptyError;

  /// No description provided for @importReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Import'**
  String get importReviewTitle;

  /// No description provided for @importDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Imported Plan'**
  String get importDefaultTitle;

  /// No description provided for @importWeeksGoal.
  ///
  /// In en, this message translates to:
  /// **'{weeks} Weeks  •  {goal}'**
  String importWeeksGoal(int weeks, String goal);

  /// No description provided for @importEditBtn.
  ///
  /// In en, this message translates to:
  /// **'Edit Plan Details'**
  String get importEditBtn;

  /// No description provided for @importInstructions.
  ///
  /// In en, this message translates to:
  /// **'Tap any workout below to preview or edit it before saving this plan to your device.'**
  String get importInstructions;

  /// No description provided for @importIncluded.
  ///
  /// In en, this message translates to:
  /// **'Included Workouts'**
  String get importIncluded;

  /// No description provided for @importExercisesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Exercises'**
  String importExercisesCount(int count);

  /// No description provided for @importSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get importSaving;

  /// No description provided for @importSaveBtn.
  ///
  /// In en, this message translates to:
  /// **'Save Plan & Workouts'**
  String get importSaveBtn;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import: {error}'**
  String importFailed(String error);

  /// No description provided for @importEditDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Plan Details'**
  String get importEditDialogTitle;

  /// No description provided for @importEditNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan Title'**
  String get importEditNameLabel;

  /// No description provided for @importEditDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get importEditDescLabel;

  /// No description provided for @importEditGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal (e.g. Build Muscle)'**
  String get importEditGoalLabel;

  /// No description provided for @importEditSaveBtn.
  ///
  /// In en, this message translates to:
  /// **'Save Details'**
  String get importEditSaveBtn;

  /// No description provided for @summaryPlanHistory.
  ///
  /// In en, this message translates to:
  /// **'Plan History'**
  String get summaryPlanHistory;

  /// No description provided for @summaryWorkoutsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Workouts Completed'**
  String get summaryWorkoutsCompleted;

  /// No description provided for @summaryNoLogs.
  ///
  /// In en, this message translates to:
  /// **'No workout logs found for this run.'**
  String get summaryNoLogs;

  /// No description provided for @summaryWorkoutSession.
  ///
  /// In en, this message translates to:
  /// **'Workout Session (Volume: {vol})'**
  String summaryWorkoutSession(int vol);

  /// No description provided for @logDetailSummary.
  ///
  /// In en, this message translates to:
  /// **'Workout Summary'**
  String get logDetailSummary;

  /// No description provided for @logDetailExercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises Completed'**
  String get logDetailExercises;

  /// No description provided for @logDetailNoExercises.
  ///
  /// In en, this message translates to:
  /// **'No exercises found for this log.'**
  String get logDetailNoExercises;
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
