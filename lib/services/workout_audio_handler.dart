import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';

class WorkoutAudioHandler extends BaseAudioHandler {
  bool _isWorkoutActive = false;
  final FlutterTts _tts = FlutterTts();
  final StreamController<bool> _workoutCompleteController =
      StreamController<bool>.broadcast();
  Stream<bool> get workoutCompleteStream => _workoutCompleteController.stream;

  List<Map<String, dynamic>> _routine = [];
  int _currentIndex = 0;
  int _currentSet = 1;

  AppLocalizations? _l10n;

  // Timer state for the UI
  Timer? _restTimer;
  int _currentRestSeconds = 0;
  final _restStreamController = StreamController<int>.broadcast();
  Stream<int> get restStream => _restStreamController.stream;

  WorkoutAudioHandler() {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [MediaControl.play, MediaControl.stop],
        processingState: AudioProcessingState.ready,
        playing: false,
      ),
    );
    mediaItem.add(
      const MediaItem(
        id: 'workout_idle',
        title: 'Workout Minds',
        artist: 'Ready to train',
      ),
    );
  }

  Future<void> _configureTts(String localeName) async {
    final ttsLanguage = localeName == 'hi' ? "hi-IN" : "en-IN";
    await _tts.setLanguage(ttsLanguage);
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // CRITICAL FIX: Forces the engine to finish the current sentence
    // before allowing the code to proceed to the next await announce()
    await _tts.awaitSpeakCompletion(true);
  }

  // NEW: A smart announce method that interrupts old speech
  Future<void> announce(String text) async {
    if (!_isWorkoutActive) return;
    await _tts.stop(); // Instantly kills whatever is currently talking
    await _tts.speak(text);
  }

  Future<void> startWorkoutSequence(
    List<Map<String, dynamic>> routine,
    AppLocalizations l10n,
  ) async {
    _routine = routine;
    _l10n = l10n;
    _currentIndex = 0;
    _currentSet = 1;
    _isWorkoutActive = true; // Mark as active!

    // Instantly push the first exercise to the UI so the screen isn't waiting
    if (_routine.isNotEmpty) {
      _updateUiStream(_routine.first);
    }

    // Speech 1
    await announce("Workout started. Let's crush it!");

    // CRITICAL CHECK: Did the user hit "Stop" or "Finish Set" while I was talking?
    // If they quit, OR if they advanced the set/index, ABORT Speech 2!
    if (!_isWorkoutActive || _currentIndex > 0 || _currentSet > 1) return;

    // Speech 2
    await _announceCurrentExercise();
  }

  Future<void> _announceCurrentExercise() async {
    if (_l10n == null) return;

    if (_currentIndex >= _routine.length) {
      await announce(_l10n!.workoutComplete);
      await stop();
      return;
    }

    final ex = _routine[_currentIndex];

    // FIX 1: Update the UI stream BEFORE the TTS speaks so the screen is instantly correct
    mediaItem.add(
      MediaItem(
        id: 'active_ex',
        title: ex['name'].toString(),
        artist: 'Set $_currentSet of ${ex['sets']}',
        extras: {
          'reps': ex['reps'].toString(),
          'durationSeconds': ex['durationSeconds'], // NEW
          'imageUrl': ex['imageUrl'], // NEW
          'localImagePath': ex['localImagePath'], // NEW
        },
      ),
    );

    final msg = _l10n!.nextUp(
      ex['name'].toString(),
      ex['reps'].toString(),
      _currentSet.toString(),
      ex['sets'].toString(),
    );

    // FIX 2: Now the code waits for the speech, but the UI is already updated!
    await announce(msg);
  }

  Future<void> completeSet() async {
    if (!_isWorkoutActive || _currentIndex >= _routine.length || _l10n == null)
      return;

    await flutterTts
        .stop(); // Instantly kill Speech 1 or 2 if it's currently rambling

    final ex = _routine[_currentIndex];
    final isLastSet = _currentSet >= (ex['sets'] as int);
    final isLastExercise = _currentIndex == _routine.length - 1;

    if (!isLastSet) {
      _currentSet++;
      _currentRestSeconds = ex['restSecondsSet'] as int;
      await announce(_l10n!.setCompleteRest(_currentRestSeconds.toString()));
      if (!_isWorkoutActive) return; // Ghost check
      _startCountdown(ex);
    } else if (!isLastExercise) {
      _currentIndex++;
      _currentSet = 1;
      final nextEx = _routine[_currentIndex];
      _currentRestSeconds = ex['restSecondsExercise'] as int;

      await announce(
        _l10n!.exerciseCompleteRest(_currentRestSeconds.toString()),
      );
      if (!_isWorkoutActive) return; // Ghost check
      _startCountdown(nextEx);
    } else {
      _currentIndex++;
      // Assuming you have a translation string for Workout Complete
      await announce("Workout complete! Great job.");
      _workoutCompleteController.add(true);
      await stop();
    }
  }

  // Extracted the timer logic to keep things clean
  void _startCountdown(Map<String, dynamic> upcomingEx) {
    if (_currentRestSeconds <= 0) {
      announce(_l10n!.restOver(_currentSet.toString()));
      _updateUiStream(upcomingEx);
      return;
    }

    _restStreamController.add(_currentRestSeconds);
    _restTimer?.cancel();

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Ghost check inside the timer loop
      if (!_isWorkoutActive) {
        timer.cancel();
        return;
      }

      if (_currentRestSeconds > 0) {
        _currentRestSeconds--;
        _restStreamController.add(_currentRestSeconds);
      } else {
        timer.cancel();
        announce(_l10n!.restOver(_currentSet.toString()));
        _updateUiStream(upcomingEx);
      }
    });
  }

  void _updateUiStream(Map<String, dynamic> ex) {
    mediaItem.add(
      MediaItem(
        id: 'active_ex',
        title: ex['name'].toString(),
        artist: 'Set $_currentSet of ${ex['sets']}',
        extras: {
          'reps': ex['reps'].toString(),
          'durationSeconds': ex['durationSeconds'], // NEW
          'imageUrl': ex['imageUrl'],
          'localImagePath': ex['localImagePath'],
        },
      ),
    );
  }

  @override
  Future<void> play() async {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [MediaControl.pause, MediaControl.stop],
        playing: true,
      ),
    );
    if (_l10n != null) await announce(_l10n!.workoutStarted);
  }

  @override
  Future<void> pause() async {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [MediaControl.play, MediaControl.stop],
        playing: false,
      ),
    );
    if (_l10n != null) await announce(_l10n!.workoutPaused);
  }

  @override
  Future<void> stop() async {
    _isWorkoutActive = false; // 1. Flag the workout as dead
    _restTimer?.cancel(); // 2. Kill the timers
    await _tts.stop(); // 3. Kill the voice instantly
    return super.stop();
  }
}
