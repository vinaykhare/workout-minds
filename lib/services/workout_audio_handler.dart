import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

class WorkoutAudioHandler extends BaseAudioHandler {
  int? currentPlanId;
  int? currentPlanDayId;
  int _workoutSessionId = 0; // NEW: Tracks the current async session
  bool _isRestarting = false; // NEW: Flag to suppress abort signals
  final StreamController<bool> _workoutAbortedController =
      StreamController<bool>.broadcast();
  Stream<bool> get workoutAbortedStream => _workoutAbortedController.stream;

  final FlutterTts flutterTts = FlutterTts();
  List<Map<String, dynamic>> _routine = [];

  int _currentIndex = 0;
  int _currentSet = 1;
  String _workoutTitle = "";

  // NEW: Tracks the current language for the audio engine
  String _currentLanguage = 'en';

  bool _isWorkoutActive = false;
  bool _isProcessingAction = false;
  int? currentWorkoutId;
  final StreamController<bool> _workoutCompleteController =
      StreamController<bool>.broadcast();
  Stream<bool> get workoutCompleteStream => _workoutCompleteController.stream;

  String _currentScreenState = 'intro';
  int _currentTimerSeconds = 0;
  Timer? _stateTimer;
  Timer? _introTimer;
  bool _isPaused = false;

  WorkoutAudioHandler() {
    flutterTts.setSpeechRate(0.5);
  }

  // --- NEW: EXECUTION FEEDBACK TRACKER ---
  final Map<String, String> executionFeedback = {};

  // --- 1. CORE STATE MANAGEMENT ---

  Future<void> startWorkoutSequence(
    List<Map<String, dynamic>> routine,
    String workoutTitle,
    int workoutId,
    String appLocale, {
    int? planId,
    int? planDayId,
  }) async {
    // 1. Increment the session ID immediately
    _workoutSessionId++;
    final int currentSession = _workoutSessionId;
    currentPlanId = planId;
    currentPlanDayId = planDayId;

    if (_isWorkoutActive) {
      // FIX 1: Set the flag before stopping so it doesn't trigger a UI pop!
      _isRestarting = true;
      await stop();
      _isRestarting = false;
    }

    currentWorkoutId = workoutId;
    _routine = routine;
    _workoutTitle = workoutTitle;
    _currentLanguage = appLocale;
    _currentIndex = 0;
    _currentSet = 1;
    _isWorkoutActive = true;
    _isProcessingAction = false;
    _isPaused = false;

    if (_currentLanguage == 'hi') {
      await flutterTts.setLanguage("en-IN");
      List<dynamic> voices = await flutterTts.getVoices;
      for (var voice in voices) {
        final name = voice["name"].toString().toLowerCase();
        final locale = voice["locale"].toString();
        if (locale.contains("en-in") ||
            locale.contains("en_in") ||
            name.contains("heera") ||
            name.contains("ravi")) {
          await flutterTts.setVoice({
            "name": voice["name"],
            "locale": voice["locale"],
          });
          break;
        }
      }
    } else {
      await flutterTts.setLanguage("en-US");
    }

    _currentScreenState = 'intro';
    _pushStateToUi();

    await flutterTts.stop();
    await flutterTts.awaitSpeakCompletion(true);

    // 2. CHECK: If the user hit restart during setup, kill this old thread
    if (currentSession != _workoutSessionId) return;

    final introSpeech = _currentLanguage == 'hi'
        ? "Workout shuru ho raha hai. Chalo shuru karein!"
        : "Workout Started. Let's crush it!";

    await flutterTts.speak(introSpeech);

    // 3. CHECK: If the user hit restart during the speech, kill this old thread
    if (currentSession != _workoutSessionId) return;

    await Future.delayed(const Duration(seconds: 1));

    // 4. CHECK: If the user hit restart during the pause, kill this old thread
    if (currentSession != _workoutSessionId) return;

    if (_isWorkoutActive && _currentScreenState == 'intro') {
      _startExercisePhase();
    }
  }

  Future<void> _startExercisePhase() async {
    if (!_isWorkoutActive || _currentIndex >= _routine.length) return;
    final ex = _routine[_currentIndex];

    await flutterTts.stop();

    if (ex['durationSeconds'] != null && (ex['durationSeconds'] as int) > 0) {
      _currentScreenState = 'exercise_time';
      _currentTimerSeconds = ex['durationSeconds'] as int;
      _pushStateToUi();

      final speech = _currentLanguage == 'hi'
          ? "Agla hai: ${ex['name']}, $_currentTimerSeconds seconds ke liye."
          : "Next up: ${ex['name']}, for $_currentTimerSeconds seconds.";
      await flutterTts.speak(speech);

      _startCountdownTimer();
    } else {
      _currentScreenState = 'exercise_rep';
      _pushStateToUi();

      final speech = _currentLanguage == 'hi'
          ? "Agla hai: ${ex['name']}, ${ex['reps']} reps."
          : "Next up: ${ex['name']}, ${ex['reps']} reps.";
      await flutterTts.speak(speech);
    }
  }

  // --- 2. THE ADVANCE SEQUENCE ---

  Future<void> advanceSequence() async {
    if (_isProcessingAction || !_isWorkoutActive) return;
    _isProcessingAction = true;
    _isPaused = false;

    _stateTimer?.cancel();
    await flutterTts.stop();

    if (_currentScreenState == 'exercise_rep' ||
        _currentScreenState == 'exercise_time') {
      final ex = _routine[_currentIndex];
      final isLastSet = _currentSet >= (ex['sets'] as int);
      final isLastExercise = _currentIndex == _routine.length - 1;

      if (!isLastSet) {
        _currentSet++;
        _currentScreenState = 'rest';
        _currentTimerSeconds = ex['restSecondsSet'] as int;
        _pushStateToUi();

        final speech = _currentLanguage == 'hi'
            ? "$_currentTimerSeconds seconds aaram karein."
            : "Rest for $_currentTimerSeconds seconds.";
        await flutterTts.speak(speech);

        _startCountdownTimer();
      } else if (!isLastExercise) {
        _currentSet = 1;
        _currentIndex++;
        _currentScreenState = 'rest';
        _currentTimerSeconds = ex['restSecondsExercise'] as int;
        _pushStateToUi();

        final speech = _currentLanguage == 'hi'
            ? "Exercise khatam. $_currentTimerSeconds seconds aaram karein."
            : "Exercise complete. Rest for $_currentTimerSeconds seconds.";
        await flutterTts.speak(speech);

        _startCountdownTimer();
      } else {
        _currentScreenState = 'outro';
        _pushStateToUi();

        final speech = _currentLanguage == 'hi'
            ? "Workout poora hua! Bahut badhiya."
            : "Workout Complete! Great job.";
        await flutterTts.speak(speech);

        _workoutCompleteController.add(true);
      }
    } else if (_currentScreenState == 'rest') {
      await _startExercisePhase();
    }

    Future.delayed(
      const Duration(milliseconds: 500),
      () => _isProcessingAction = false,
    );
  }

  // --- 3. TIMERS & UI UPDATES ---

  void _startCountdownTimer() {
    _stateTimer?.cancel();
    _stateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;

      if (!_isWorkoutActive) {
        timer.cancel();
        return;
      }
      if (_currentTimerSeconds > 0) {
        _currentTimerSeconds--;
        _pushStateToUi();
      } else {
        timer.cancel();
        advanceSequence();
      }
    });
  }

  void _updatePlaybackState(bool isPlaying) {
    if (_currentScreenState == 'outro') {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.idle,
          playing: false,
          controls: [],
        ),
      );
      return;
    }

    final forcePlaying = _currentScreenState == 'exercise_rep'
        ? true
        : isPlaying;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          forcePlaying ? MediaControl.pause : MediaControl.play, // Index 0
          MediaControl.skipToNext, // Index 1
          MediaControl.stop, // Index 2
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [],
        processingState: AudioProcessingState.ready,
        playing: forcePlaying,
      ),
    );
  }

  void _pushStateToUi() {
    if (_routine.isEmpty) return;

    final safeIndex = _currentIndex < _routine.length
        ? _currentIndex
        : _routine.length - 1;
    final ex = _routine[safeIndex];

    final exName = ex['name'] as String;
    final localPath = ex['localImagePath'] as String?;

    String displayTitle = exName;
    String displaySubtitle = 'Set $_currentSet of ${ex['sets']}';

    if (_currentScreenState == 'rest') {
      displayTitle = 'Resting';
      displaySubtitle = 'Next up: $exName';
    } else if (_currentScreenState == 'outro') {
      displayTitle = 'Workout Complete';
      displaySubtitle = 'Great Job!';
    }

    mediaItem.add(
      MediaItem(
        id: 'workout_${_currentIndex}_${DateTime.now().millisecondsSinceEpoch}',
        title: displayTitle,
        artist: displaySubtitle,
        album: _workoutTitle,
        artUri: localPath != null ? Uri.file(localPath) : null,
        extras: {
          'stateType': _currentScreenState,
          'exName': exName,
          'timerValue': _currentTimerSeconds,
          'reps': ex['reps']?.toString(),
          'imageUrl': ex['imageUrl'],
          'localImagePath': localPath,
          'totalExercises': _routine.length,
          'currentExerciseIndex': safeIndex + 1,
          'totalSets': ex['sets'],
          'currentSet': _currentSet,
          'equipment': ex['equipment'],
          'targetWeight': ex['targetWeight'],
          'instructions': ex['instructions'],
          'targetDuration': ex['durationSeconds'],
        },
      ),
    );

    _updatePlaybackState(!_isPaused);
  }

  // --- 4. MEDIA CONTROLS ---

  @override
  Future<void> pause() async {
    if (_currentScreenState == 'exercise_rep') {
      _updatePlaybackState(true);
      return;
    }
    _isPaused = true;
    _updatePlaybackState(false);
    await flutterTts.stop();
  }

  @override
  Future<void> play() async {
    if (_currentScreenState == 'exercise_rep') return;
    _isPaused = false;
    _updatePlaybackState(true);
  }

  @override
  Future<void> skipToNext() async {
    await advanceSequence();
  }

  @override
  Future<void> stop() async {
    _isWorkoutActive = false;
    _stateTimer?.cancel();
    _introTimer?.cancel();
    await flutterTts.stop();

    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
        controls: [],
      ),
    );

    // FIX 2: Only broadcast an abort if the user actually quit, NOT if they are just restarting!
    if (!_isRestarting) {
      _workoutAbortedController.add(true);
    }
    return super.stop();
  }

  Future<void> restartWorkout() async {
    if (currentWorkoutId == null) return;
    // Uses the saved _currentLanguage to restart!
    await startWorkoutSequence(
      _routine,
      _workoutTitle,
      currentWorkoutId!,
      _currentLanguage,
      planId: currentPlanId,
      planDayId: currentPlanDayId,
    );
  }

  void recordFeedback(String exerciseName, String note) {
    executionFeedback[exerciseName] = note;
  }

  // --- NEW: ON-DEMAND TTS INSTRUCTIONS ---
  Future<void> speakCurrentInstructions() async {
    if (_routine.isEmpty) return;
    final ex = _routine[_currentIndex];
    final instructions = ex['instructions'] as String?;

    if (instructions != null && instructions.isNotEmpty) {
      // Temporarily pause the timer if it's running
      final wasRunning = !_isPaused && _currentScreenState == 'exercise_time';
      if (wasRunning) _isPaused = true;

      await flutterTts.speak(instructions);
      await flutterTts.awaitSpeakCompletion(true);

      if (wasRunning) _isPaused = false;
    }
  }
}
