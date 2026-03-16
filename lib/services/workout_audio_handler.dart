import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

class WorkoutAudioHandler extends BaseAudioHandler {
  final FlutterTts _tts = FlutterTts();

  // State tracking for the active workout
  List<Map<String, dynamic>> _routine = [];
  int _currentIndex = 0;
  int _currentSet = 1;
  Timer? _restTimer;

  WorkoutAudioHandler() {
    _initTts();
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

  Future<void> _initTts() async {
    await _tts.setLanguage("en-IN");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> announce(String message) async {
    await _tts.speak(message);
  }

  // --- NEW: WORKOUT STATE MACHINE ---

  /// Receives the specific exercises from the UI and starts the sequence
  Future<void> startWorkoutSequence(List<Map<String, dynamic>> routine) async {
    _routine = routine;
    _currentIndex = 0;
    _currentSet = 1;
    _restTimer?.cancel();

    await play(); // Triggers the "Workout started" announcement

    // Wait 3 seconds for the intro to finish, then announce the first exercise
    Future.delayed(const Duration(seconds: 3), () {
      _announceCurrentExercise();
    });
  }

  Future<void> _announceCurrentExercise() async {
    if (_currentIndex >= _routine.length) {
      await announce("Workout complete. Fantastic job today!");
      await stop();
      return;
    }

    final ex = _routine[_currentIndex];
    await announce(
      "Next up: ${ex['name']}. Set $_currentSet of ${ex['sets']}. Target is ${ex['reps']} reps.",
    );

    // Update lock screen metadata
    mediaItem.add(
      MediaItem(
        id: 'active_ex',
        title: ex['name'],
        artist: 'Set $_currentSet of ${ex['sets']}',
      ),
    );
  }

  /// Called when the user clicks "Finish Set" on the UI
  Future<void> completeSet() async {
    if (_currentIndex >= _routine.length) return;

    final ex = _routine[_currentIndex];

    if (_currentSet < (ex['sets'] as int)) {
      _currentSet++;
      await announce("Set complete. Rest for 60 seconds.");

      // Start a 60-second rest timer in the background
      _restTimer?.cancel();
      _restTimer = Timer(const Duration(seconds: 60), () {
        announce("Rest is over. Get ready for set $_currentSet.");
      });
    } else {
      // Move to the next exercise
      _currentIndex++;
      _currentSet = 1;
      await announce("Exercise complete.");
      Future.delayed(
        const Duration(seconds: 2),
        () => _announceCurrentExercise(),
      );
    }
  }

  // --- STANDARD CONTROLS ---

  @override
  Future<void> play() async {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [MediaControl.pause, MediaControl.stop],
        playing: true,
      ),
    );
    await announce("Workout started. Let's crush it!");
  }

  @override
  Future<void> pause() async {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [MediaControl.play, MediaControl.stop],
        playing: false,
      ),
    );
    _restTimer?.cancel(); // Pause the rest timer
    await announce("Workout paused.");
  }

  @override
  Future<void> stop() async {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    _restTimer?.cancel();
    await super.stop();
  }
}
