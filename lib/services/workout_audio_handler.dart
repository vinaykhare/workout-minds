import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

class WorkoutAudioHandler extends BaseAudioHandler {
  final StreamController<bool> _workoutAbortedController =
      StreamController<bool>.broadcast();
  Stream<bool> get workoutAbortedStream => _workoutAbortedController.stream;

  final FlutterTts flutterTts = FlutterTts();
  List<Map<String, dynamic>> _routine = [];

  int _currentIndex = 0;
  int _currentSet = 1;
  String _workoutTitle = "";

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

  WorkoutAudioHandler() {
    flutterTts.setLanguage("en-US");
    flutterTts.setSpeechRate(0.5);
  }

  // --- 1. CORE STATE MANAGEMENT ---

  Future<void> startWorkoutSequence(
    List<Map<String, dynamic>> routine,
    String workoutTitle,
    int workoutId,
  ) async {
    // Prevent parallel workouts! Kill any active workout before starting a new one.
    if (_isWorkoutActive) {
      await stop();
    }
    currentWorkoutId = workoutId;
    _routine = routine;
    _workoutTitle = workoutTitle;
    _currentIndex = 0;
    _currentSet = 1;
    _isWorkoutActive = true;
    _isProcessingAction = false;
    _isPaused = false; // Reset pause state

    // Phase 1: INTRO
    _currentScreenState = 'intro';
    _pushStateToUi();

    await flutterTts.stop();
    await flutterTts.speak("Workout Started. Let's crush it!");

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

    if (ex['durationSeconds'] != null && (ex['durationSeconds'] as int) > 0) {
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

  // --- 2. THE ADVANCE SEQUENCE ---

  Future<void> advanceSequence() async {
    if (_isProcessingAction || !_isWorkoutActive) return;
    _isProcessingAction = true;
    _isPaused = false;

    _stateTimer?.cancel();
    await flutterTts.stop();

    // Find out if we are at the end of the workout BEFORE we increment indexes
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
        await flutterTts.speak("Rest for $_currentTimerSeconds seconds.");
        _startCountdownTimer();
      } else if (!isLastExercise) {
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
        _currentScreenState = 'outro';
        _pushStateToUi();
        await flutterTts.speak("Workout Complete! Great job.");
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
      // FIX: This must be inside the loop to freeze the clock when paused!
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

  bool _isPaused = false;

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

    // FIX: Android 13 forces a center button. For Rep exercises, we force it
    // to look like it's "playing" so it doesn't look stalled.
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

    // FIX 1: Change what the notification says based on the screen!
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
        },
      ),
    );

    _updatePlaybackState(!_isPaused);
  }

  // --- 4. MEDIA CONTROLS ---

  @override
  Future<void> pause() async {
    // FIX: Completely ignore Pause commands if it's a Rep-based exercise!
    if (_currentScreenState == 'exercise_rep') {
      _updatePlaybackState(
        true,
      ); // Bounce the Android UI back to its proper state
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

  // FIX: Wire up the Notification's "Next Track" arrow to advance the workout!
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

    // FIX 1: Explicitly tell Android to destroy the media notification!
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
        controls: [],
      ),
    );

    _workoutAbortedController.add(true);
    return super.stop();
  }

  Future<void> restartWorkout() async {
    if (currentWorkoutId == null) return;
    await startWorkoutSequence(_routine, _workoutTitle, currentWorkoutId!);
  }
}
