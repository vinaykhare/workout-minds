import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
// import '../core/l10n/app_localizations.dart';

class WorkoutAudioHandler extends BaseAudioHandler {
  final FlutterTts flutterTts = FlutterTts();
  List<Map<String, dynamic>> _routine = [];
  // AppLocalizations? _l10n;

  int _currentIndex = 0;
  int _currentSet = 1;
  String _workoutTitle = "";
  // int _currentWorkoutId;

  bool _isWorkoutActive = false;
  bool _isProcessingAction = false; // The Double-Tap Lock
  // --- ADD THESE MISSING VARIABLES ---
  int? currentWorkoutId;
  final StreamController<bool> _workoutCompleteController =
      StreamController<bool>.broadcast();
  Stream<bool> get workoutCompleteStream => _workoutCompleteController.stream;

  String _currentScreenState =
      'intro'; // 'intro', 'exercise_rep', 'exercise_time', 'rest', 'outro'
  int _currentTimerSeconds = 0;
  Timer? _stateTimer;
  Timer? _introTimer; // Dedicated timer for the intro

  WorkoutAudioHandler() {
    flutterTts.setLanguage("en-US");
    flutterTts.setSpeechRate(0.5);
  }

  // --- 1. CORE STATE MANAGEMENT ---

  Future<void> startWorkoutSequence(
    List<Map<String, dynamic>> routine,
    // AppLocalizations l10n,
    String workoutTitle,
    int workoutId,
  ) async {
    currentWorkoutId = workoutId;
    _routine = routine;
    // _l10n = l10n;
    _workoutTitle = workoutTitle;
    _currentIndex = 0;
    _currentSet = 1;
    _isWorkoutActive = true;
    _isProcessingAction = false;

    // Phase 1: INTRO
    _currentScreenState = 'intro';
    _pushStateToUi();

    await flutterTts.stop();
    await flutterTts.speak("Workout Started. Let's crush it!");

    // Wait for the intro speech to finish (approx 3 seconds), then auto-advance if not interrupted
    _introTimer?.cancel();
    _introTimer = Timer(const Duration(seconds: 3), () {
      if (_isWorkoutActive && _currentScreenState == 'intro') {
        _startExercisePhase();
      }
    });
  }

  Future<void> _startExercisePhase() async {
    if (!_isWorkoutActive || _currentIndex >= _routine.length) return;
    final ex = _routine[_currentIndex];

    await flutterTts.stop();

    if (ex['durationSeconds'] != null) {
      _currentScreenState = 'exercise_time';
      _currentTimerSeconds = ex['durationSeconds'] as int;
      _pushStateToUi();
      await flutterTts.speak(
        "Next up: ${ex['name']}, for $_currentTimerSeconds seconds.",
      );
      _startCountdownTimer();
    } else {
      _currentScreenState = 'exercise_rep';
      _pushStateToUi();
      await flutterTts.speak("Next up: ${ex['name']}, ${ex['reps']} reps.");
    }
  }

  // --- 2. THE ADVANCE SEQUENCE (Replaces completeSet) ---

  // This is called when the user hits "Finish Set", "Skip Rest", or a timer hits 0.
  Future<void> advanceSequence() async {
    if (_isProcessingAction || !_isWorkoutActive) {
      return; // Prevent Double-Taps!
    }
    _isProcessingAction = true;

    _stateTimer?.cancel();
    await flutterTts.stop(); // Instantly kill current speech

    if (_currentScreenState == 'exercise_rep' ||
        _currentScreenState == 'exercise_time') {
      final ex = _routine[_currentIndex];
      final isLastSet = _currentSet >= (ex['sets'] as int);
      final isLastExercise = _currentIndex == _routine.length - 1;

      if (!isLastSet) {
        // Go to Rest (Between Sets)
        _currentSet++;
        _currentScreenState = 'rest';
        _currentTimerSeconds = ex['restSecondsSet'] as int;
        _pushStateToUi();
        await flutterTts.speak("Rest for $_currentTimerSeconds seconds.");
        _startCountdownTimer();
      } else if (!isLastExercise) {
        // Go to Rest (Between Exercises)
        _currentSet = 1;
        _currentIndex++;
        _currentScreenState = 'rest';
        _currentTimerSeconds = ex['restSecondsExercise'] as int;
        _pushStateToUi();
        await flutterTts.speak(
          "Exercise complete. Rest for $_currentTimerSeconds seconds.",
        );
        _startCountdownTimer();
      } else {
        // Go to Outro
        _currentScreenState = 'outro';
        _pushStateToUi();
        await flutterTts.speak("Workout Complete! Great job.");
        // NEW: Tell a listener to log this! We'll use your existing stream.
        _workoutCompleteController.add(true);
      }
    } else if (_currentScreenState == 'rest') {
      // Rest is over, start the next exercise phase
      await _startExercisePhase();
    }

    // Unlock the button
    Future.delayed(
      const Duration(milliseconds: 500),
      () => _isProcessingAction = false,
    );
  }

  // --- 3. TIMERS & UI UPDATES ---

  void _startCountdownTimer() {
    _stateTimer?.cancel();
    _stateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isWorkoutActive) {
        timer.cancel();
        return;
      }
      if (_currentTimerSeconds > 0) {
        _currentTimerSeconds--;
        _pushStateToUi(); // Update the clock on screen
      } else {
        timer.cancel();
        advanceSequence(); // Auto-advance when time is up
      }
    });
  }

  void _pushStateToUi() {
    if (!_isWorkoutActive) return;

    final ex = _currentIndex < _routine.length ? _routine[_currentIndex] : null;

    mediaItem.add(
      MediaItem(
        id: 'active_workout',
        title: _workoutTitle,
        artist: ex != null ? 'Set $_currentSet of ${ex['sets']}' : '',
        extras: {
          'stateType':
              _currentScreenState, // 'intro', 'exercise_rep', 'exercise_time', 'rest', 'outro'
          'exName': ex?['name'],
          'reps': ex?['reps']?.toString(),
          'timerValue': _currentTimerSeconds,
          'imageUrl': ex?['imageUrl'],
          'localImagePath': ex?['localImagePath'],
          // Data for the Status Modal
          'totalExercises': _routine.length,
          'currentExerciseIndex': _currentIndex + 1,
          'totalSets': ex?['sets'],
          'currentSet': _currentSet,
        },
      ),
    );
  }

  @override
  Future<void> stop() async {
    _isWorkoutActive = false;
    _stateTimer?.cancel();
    _introTimer?.cancel(); // FIX: Kill the intro timer!
    await flutterTts.stop();
    return super.stop();
  }

  // NEW: Safely restarts the current routine from the beginning
  Future<void> restartWorkout() async {
    if (currentWorkoutId == null) return;
    await startWorkoutSequence(_routine, _workoutTitle, currentWorkoutId!);
  }
}
