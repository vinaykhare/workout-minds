import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'dart:convert';

import 'package:workout_minds/services/workout_audio_handler.dart'; // Ensure dart:convert is imported at the top of the file!

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  bool _isButtonLocked = false;
  bool _isFullScreenImage = false;

  void _handleAdvance(WorkoutAudioHandler handler) async {
    if (_isButtonLocked) return;
    setState(() => _isButtonLocked = true);
    await handler.advanceSequence();
    if (mounted) setState(() => _isButtonLocked = false);
  }

  void _showStatusModal(Map<String, dynamic> extras) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final totalEx = extras['totalExercises'] ?? 1;
        final currEx = extras['currentExerciseIndex'] ?? 1;
        final totalSets = extras['totalSets'] ?? 1;
        final currSet = extras['currentSet'] ?? 1;
        final percent = (currEx / totalEx);

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Workout Status',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: percent,
                minHeight: 12,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 16),
              Text(
                'Exercise $currEx of $totalEx',
                style: const TextStyle(fontSize: 18),
              ),
              Text(
                'Working on Set $currSet of $totalSets',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // FIX 2: Added 'async' so we can await the modal and pause/resume the timer!
  void _showFeedbackModal(
    String exName,
    bool isTooEasy,
    Map<String, dynamic> extras,
  ) async {
    final targetReps = extras['reps'] != null
        ? int.tryParse(extras['reps'].toString())
        : null;
    final targetDuration = extras['targetDuration'] as int?;
    final targetWeight = extras['targetWeight'] as num?;

    // --- FIX 1: CALCULATE STRICT LOGICAL BOUNDARIES ---

    // Reps Logic
    int repMin = 0;
    int repMax = 10;
    int actualReps = 0;

    if (targetReps != null) {
      if (isTooEasy) {
        repMin = targetReps + 1;
        repMax = targetReps + 15; // Give them +15 reps headroom
        actualReps = repMin;
      } else {
        repMin = 0;
        repMax = targetReps - 1;
        if (repMax < 0) repMax = 0;
        actualReps = repMax;
      }
    }

    // Safety logic for Flutter Sliders (max must be > min)
    double sliderRepMax = repMax > repMin
        ? repMax.toDouble()
        : (repMin + 1).toDouble();
    int repDivs = (sliderRepMax - repMin).toInt();

    // Duration Logic
    int durMin = 0;
    int durMax = 30;
    int actualDuration = 0;

    if (targetDuration != null && targetDuration > 0) {
      if (isTooEasy) {
        durMin = targetDuration + 1;
        durMax = targetDuration + 60; // Give them +60s headroom
        actualDuration = durMin;
      } else {
        durMin = 0;
        durMax = targetDuration - 1;
        if (durMax < 0) durMax = 0;
        actualDuration = durMax;
      }
    }

    double sliderDurMax = durMax > durMin
        ? durMax.toDouble()
        : (durMin + 1).toDouble();
    int durDivs = (sliderDurMax - durMin).toInt();

    // Weight Logic
    String weightFeedback = isTooEasy ? 'Too Light' : 'Too Heavy';

    final handler = ref.read(audioHandlerProvider);

    // --- FIX 2: PAUSE THE TIMER ---
    final wasPlaying = handler.playbackState.value.playing;
    if (wasPlaying) {
      await handler.pause();
    }
    if (!mounted) return;

    // Await the modal so we know when the user closes it!
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(
              24.0,
            ).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isTooEasy ? 'Too Easy!' : 'Too Hard!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isTooEasy ? Colors.green : Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tell the AI your actual capacity for $exName so it can adapt your next plan.',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),

                // --- SLIDER 1: REPS (If it's a rep-based exercise) ---
                if (targetReps != null) ...[
                  Text(
                    'My Max Capacity is: $actualReps Reps',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: actualReps.toDouble().clamp(
                      repMin.toDouble(),
                      sliderRepMax,
                    ),
                    min: repMin.toDouble(),
                    max: sliderRepMax,
                    divisions: repDivs > 0 ? repDivs : 1,
                    activeColor: isTooEasy ? Colors.green : Colors.redAccent,
                    onChanged: (val) =>
                        setModalState(() => actualReps = val.toInt()),
                  ),
                  const SizedBox(height: 16),
                ],

                // --- SLIDER 2: TIME (If it's a time-based exercise) ---
                if (targetDuration != null && targetDuration > 0) ...[
                  Text(
                    'My Max Capacity is: $actualDuration Seconds',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: actualDuration.toDouble().clamp(
                      durMin.toDouble(),
                      sliderDurMax,
                    ),
                    min: durMin.toDouble(),
                    max: sliderDurMax,
                    divisions: durDivs > 0 ? durDivs : 1,
                    activeColor: isTooEasy ? Colors.green : Colors.redAccent,
                    onChanged: (val) =>
                        setModalState(() => actualDuration = val.toInt()),
                  ),
                  const SizedBox(height: 16),
                ],

                // --- TOGGLES: WEIGHT (If a weight was assigned) ---
                if (targetWeight != null && targetWeight > 0) ...[
                  Text(
                    'The weight ($targetWeight) felt:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'Too Light',
                        label: Text('Too Light'),
                      ),
                      ButtonSegment(
                        value: 'Just Right',
                        label: Text('Just Right'),
                      ),
                      ButtonSegment(
                        value: 'Too Heavy',
                        label: Text('Too Heavy'),
                      ),
                    ],
                    selected: {weightFeedback},
                    onSelectionChanged: (Set<String> newSelection) {
                      setModalState(() => weightFeedback = newSelection.first);
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                FilledButton(
                  onPressed: () {
                    // Build the AI Feedback String
                    String note =
                        "Rated: ${isTooEasy ? 'Too Easy' : 'Too Hard'}. ";

                    if (targetReps != null) {
                      note += "Actual Capacity: $actualReps reps. ";
                    } else if (targetDuration != null && targetDuration > 0) {
                      note += "Actual Capacity: $actualDuration seconds. ";
                    }

                    if (targetWeight != null && targetWeight > 0) {
                      note += "Weight ($targetWeight) was $weightFeedback.";
                    }

                    handler.recordFeedback(exName, note.trim());
                    Navigator.pop(context); // This unblocks the await!

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Feedback saved for AI review.'),
                        backgroundColor: isTooEasy
                            ? Colors.green
                            : Colors.orange,
                      ),
                    );
                  },
                  child: const Text('Save Feedback'),
                ),
              ],
            ),
          );
        },
      ),
    );

    // --- FIX 2: RESUME THE TIMER ---
    // Once the modal is closed, if the timer was running before, start it back up!
    if (wasPlaying && mounted) {
      await handler.play();
    }
  }

  @override
  void initState() {
    super.initState();
    final handler = ref.read(audioHandlerProvider);
    final db = ref.read(databaseProvider);

    handler.workoutCompleteStream.listen((isComplete) async {
      if (isComplete && mounted) {
        String? feedbackJson;
        if (handler.executionFeedback.isNotEmpty) {
          feedbackJson = jsonEncode(handler.executionFeedback);
        }
        await db.logWorkoutCompletion(
          handler.currentWorkoutId!,
          100,
          feedbackJson: feedbackJson,
        );
        ref.invalidate(weeklyStatsProvider);

        // --- NEW: EVENT-DRIVEN CLOUD SYNC ---
        final profile = ref.read(userProfileProvider);
        if (profile.isAutoSyncEnabled) {
          final profileJsonString = jsonEncode(profile.toJson());
          // Fire and forget! We don't await this, we just let it run silently in the background
          ref.read(driveSyncProvider).backupToCloud(profileJsonString).ignore();
        }
      }
    });

    handler.workoutAbortedStream.listen((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final handler = ref.read(audioHandlerProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: StreamBuilder<MediaItem?>(
          stream: handler.mediaItem,
          builder: (context, snapshot) {
            final workoutTitle = snapshot.data?.album ?? 'Active Workout';
            return Text(
              workoutTitle,
              style: const TextStyle(color: Colors.white),
            );
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart, color: Colors.white),
            onPressed: () async {
              final media = await handler.mediaItem.first;
              if (media?.extras != null) _showStatusModal(media!.extras!);
            },
          ),
        ],
      ),
      body: StreamBuilder<MediaItem?>(
        stream: handler.mediaItem,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final extras = snapshot.data!.extras ?? {};
          final stateType = extras['stateType'] as String? ?? 'intro';
          // final title = snapshot.data!.title;
          final exName = extras['exName'] as String? ?? '';
          final timerValue = extras['timerValue'] as int? ?? 0;
          final reps = extras['reps'] as String?;
          final imageUrl = extras['imageUrl'] as String?;
          final localImagePath = extras['localImagePath'] as String?;
          final equipment = extras['equipment'] as String?;
          final targetWeight = extras['targetWeight'] as num?;
          final instructions = extras['instructions'] as String?;

          final isExercise =
              stateType == 'exercise_rep' || stateType == 'exercise_time';

          return Stack(
            fit: StackFit.expand,
            children: [
              // --- LAYER 1: FULL SCREEN BACKGROUND (Double-Tap specific) ---
              if (isExercise && _isFullScreenImage) ...[
                GestureDetector(
                  onDoubleTap: () => setState(() => _isFullScreenImage = false),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (localImagePath != null && localImagePath.isNotEmpty)
                        Image.file(File(localImagePath), fit: BoxFit.cover)
                      else if (imageUrl != null && imageUrl.isNotEmpty)
                        Image.network(imageUrl, fit: BoxFit.cover)
                      else
                        Container(color: Colors.grey.shade900),

                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withAlpha(150),
                              Colors.transparent,
                              Colors.black.withAlpha(220),
                              Colors.black,
                            ],
                            stops: const [0.0, 0.4, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // --- LAYER 2: THE RESPONSIVE UI CONTENT ---
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isLandscape = constraints.maxWidth > 600;

                      // ==========================================
                      // LANDSCAPE MODE (2-Column Unified Layout)
                      // ==========================================
                      if (isLandscape && !_isFullScreenImage) {
                        return Row(
                          children: [
                            // LEFT COLUMN: Visuals & Context
                            Expanded(
                              flex: 1,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (stateType == 'intro') ...[
                                    const Icon(
                                      Icons.fitness_center,
                                      size: 80,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(height: 24),
                                    StreamBuilder<MediaItem?>(
                                      stream: handler.mediaItem,
                                      builder: (context, snapshot) {
                                        final workoutTitle =
                                            snapshot.data?.album ??
                                            'Active Workout';
                                        return Text(
                                          workoutTitle,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                    ),
                                  ] else if (isExercise) ...[
                                    // Replace your exName Text widget with this:
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            exName,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        if (instructions != null &&
                                            instructions.isNotEmpty)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.volume_up,
                                              color: Colors.blueAccent,
                                              size: 32,
                                            ),
                                            onPressed: () => handler
                                                .speakCurrentInstructions(),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      snapshot.data!.artist ?? '',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    // const SizedBox(height: 24),
                                    // Text(
                                    //   snapshot.data!.artist ?? '',
                                    //   textAlign: TextAlign.center,
                                    //   style: const TextStyle(
                                    //     fontSize: 20,
                                    //     color: Colors.white70,
                                    //   ),
                                    // ),

                                    // --- NEW: ACTIVE BADGE (LANDSCAPE) ---
                                    if ((equipment != null &&
                                            equipment.isNotEmpty) ||
                                        targetWeight != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 12.0,
                                        ),
                                        child: Text(
                                          [
                                            if (equipment != null &&
                                                equipment.isNotEmpty)
                                              equipment,
                                            if (targetWeight != null)
                                              '$targetWeight kg',
                                          ].join('  •  '),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amberAccent,
                                          ),
                                        ),
                                      ),
                                    // -------------------------------------
                                    const SizedBox(height: 24),
                                    Expanded(
                                      child: GestureDetector(
                                        onDoubleTap: () => setState(
                                          () => _isFullScreenImage = true,
                                        ),
                                        child: Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade900,
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            image: _getDecorationImage(
                                              localImagePath,
                                              imageUrl,
                                            ),
                                          ),
                                          child: null,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ] else if (stateType == 'rest') ...[
                                    const Icon(
                                      Icons.timer,
                                      size: 80,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      "Rest Time",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ] else if (stateType == 'outro') ...[
                                    const Icon(
                                      Icons.emoji_events,
                                      size: 100,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      "Workout Complete!",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 48),

                            // RIGHT COLUMN: Actions & Data
                            Expanded(
                              flex: 1,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (stateType == 'intro') ...[
                                    const Text(
                                      "Workout Started.\nLet's crush it!",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ] else if (isExercise) ...[
                                    if (stateType == 'exercise_rep')
                                      _targetBadge(
                                        'Target: $reps Reps',
                                        context,
                                      )
                                    else
                                      _targetBadge(
                                        'Time Left: $timerValue s',
                                        context,
                                      ),
                                    const SizedBox(height: 32),
                                    if (stateType == 'exercise_time')
                                      StreamBuilder<PlaybackState>(
                                        stream: handler.playbackState,
                                        builder: (context, pbSnapshot) {
                                          final isPlaying =
                                              pbSnapshot.data?.playing ?? true;
                                          return Row(
                                            children: [
                                              Expanded(
                                                child: FilledButton.tonalIcon(
                                                  onPressed: () => isPlaying
                                                      ? handler.pause()
                                                      : handler.play(),
                                                  icon: Icon(
                                                    isPlaying
                                                        ? Icons.pause
                                                        : Icons.play_arrow,
                                                  ),
                                                  label: Text(
                                                    isPlaying
                                                        ? 'Pause'
                                                        : 'Resume',
                                                  ),
                                                  style: FilledButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: FilledButton.icon(
                                                  onPressed: _isButtonLocked
                                                      ? null
                                                      : () => _handleAdvance(
                                                          handler,
                                                        ),
                                                  icon: const Icon(
                                                    Icons.skip_next,
                                                  ),
                                                  label: const Text(
                                                    'Skip Time',
                                                  ),
                                                  style: FilledButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      )
                                    else
                                      FilledButton.icon(
                                        onPressed: _isButtonLocked
                                            ? null
                                            : () => _handleAdvance(handler),
                                        icon: const Icon(Icons.check_circle),
                                        label: const Text('Finish Set'),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.all(16),
                                        ),
                                      ),
                                    // --- NEW: EASY/HARD FEEDBACK ROW ---
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            icon: const Icon(
                                              Icons.thumb_down_alt_outlined,
                                              color: Colors.redAccent,
                                            ),
                                            label: const Text(
                                              'Too Hard',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                            onPressed: () => _showFeedbackModal(
                                              exName,
                                              false,
                                              extras,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            icon: const Icon(
                                              Icons.thumb_up_alt_outlined,
                                              color: Colors.green,
                                            ),
                                            label: const Text(
                                              'Too Easy',
                                              style: TextStyle(
                                                color: Colors.green,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                color: Colors.green,
                                              ),
                                            ),
                                            onPressed: () => _showFeedbackModal(
                                              exName,
                                              true,
                                              extras,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // -----------------------------------
                                  ] else if (stateType == 'rest') ...[
                                    Text(
                                      '$timerValue',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 100,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    StreamBuilder<PlaybackState>(
                                      stream: handler.playbackState,
                                      builder: (context, pbSnapshot) {
                                        final isPlaying =
                                            pbSnapshot.data?.playing ?? true;
                                        return Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () => isPlaying
                                                    ? handler.pause()
                                                    : handler.play(),
                                                icon: Icon(
                                                  isPlaying
                                                      ? Icons.pause
                                                      : Icons.play_arrow,
                                                  color: Colors.white,
                                                ),
                                                label: Text(
                                                  isPlaying
                                                      ? 'Pause'
                                                      : 'Resume',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(
                                                    color: Colors.white,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: FilledButton.icon(
                                                onPressed: _isButtonLocked
                                                    ? null
                                                    : () => _handleAdvance(
                                                        handler,
                                                      ),
                                                icon: const Icon(
                                                  Icons.fast_forward,
                                                ),
                                                label: const Text('Skip Rest'),
                                                style: FilledButton.styleFrom(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ] else if (stateType == 'outro') ...[
                                    FilledButton.icon(
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Restart Workout'),
                                      onPressed: () => handler.restartWorkout(),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.all(16),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.home,
                                        color: Colors.white,
                                      ),
                                      label: const Text(
                                        'Go Home / Dashboard',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      onPressed: () async =>
                                          await handler.stop(),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Colors.white,
                                        ),
                                        padding: const EdgeInsets.all(16),
                                      ),
                                    ),
                                  ],

                                  // Global End Early button for Landscape Right-Column
                                  if (stateType != 'outro') ...[
                                    const SizedBox(height: 16),
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.stop_circle,
                                        color: Colors.redAccent,
                                      ),
                                      label: const Text(
                                        'End Workout Early',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 16,
                                        ),
                                      ),
                                      onPressed: () async =>
                                          await handler.stop(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      // ==========================================
                      // PORTRAIT MODE (or Fullscreen Landscape)
                      // ==========================================
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (stateType == 'intro') ...[
                            const Icon(
                              Icons.fitness_center,
                              size: 80,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 24),
                            StreamBuilder<MediaItem?>(
                              stream: handler.mediaItem,
                              builder: (context, snapshot) {
                                final workoutTitle =
                                    snapshot.data?.album ?? 'Active Workout';
                                return Text(
                                  workoutTitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                            // Text(
                            //   title,
                            //   textAlign: TextAlign.center,
                            //   style: const TextStyle(
                            //     fontSize: 32,
                            //     fontWeight: FontWeight.bold,
                            //     color: Colors.white,
                            //   ),
                            // ),
                            const SizedBox(height: 16),
                            const Text(
                              "Workout Started.\nLet's crush it!",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white70,
                              ),
                            ),
                          ],

                          if (isExercise) ...[
                            if (!_isFullScreenImage)
                              Expanded(
                                child: GestureDetector(
                                  onDoubleTap: () =>
                                      setState(() => _isFullScreenImage = true),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 24),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade900,
                                      borderRadius: BorderRadius.circular(24),
                                      image: _getDecorationImage(
                                        localImagePath,
                                        imageUrl,
                                      ),
                                    ),
                                    child: null,
                                  ),
                                ),
                              )
                            else
                              const Spacer(),

                            // Replace your exName Text widget with this:
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    exName,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (instructions != null &&
                                    instructions.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.volume_up,
                                      color: Colors.blueAccent,
                                      size: 32,
                                    ),
                                    onPressed: () =>
                                        handler.speakCurrentInstructions(),
                                  ),
                              ],
                            ),
                            // const SizedBox(height: 8),
                            // Text(
                            //   snapshot.data!.artist ?? '',
                            //   textAlign: TextAlign.center,
                            //   style: const TextStyle(
                            //     fontSize: 20,
                            //     color: Colors.white70,
                            //   ),
                            // ),
                            Text(
                              snapshot.data!.artist ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.white70,
                              ),
                            ),
                            // --- NEW: ACTIVE BADGE (PORTRAIT) ---
                            if ((equipment != null && equipment.isNotEmpty) ||
                                targetWeight != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: Text(
                                  [
                                    if (equipment != null &&
                                        equipment.isNotEmpty)
                                      equipment,
                                    if (targetWeight != null)
                                      '$targetWeight kg',
                                  ].join('  •  '),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amberAccent,
                                  ),
                                ),
                              ),
                            // -------------------------------------
                            const SizedBox(height: 32),

                            if (stateType == 'exercise_rep')
                              _targetBadge('Target: $reps Reps', context)
                            else
                              _targetBadge('Time Left: $timerValue s', context),

                            const SizedBox(height: 32),
                            if (stateType == 'exercise_time')
                              StreamBuilder<PlaybackState>(
                                stream: handler.playbackState,
                                builder: (context, pbSnapshot) {
                                  final isPlaying =
                                      pbSnapshot.data?.playing ?? true;
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.tonalIcon(
                                          onPressed: () => isPlaying
                                              ? handler.pause()
                                              : handler.play(),
                                          icon: Icon(
                                            isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                          ),
                                          label: Text(
                                            isPlaying ? 'Pause' : 'Resume',
                                          ),
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.all(16),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: _isButtonLocked
                                              ? null
                                              : () => _handleAdvance(handler),
                                          icon: const Icon(Icons.skip_next),
                                          label: const Text('Skip Time'),
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.all(16),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              )
                            else
                              FilledButton.icon(
                                onPressed: _isButtonLocked
                                    ? null
                                    : () => _handleAdvance(handler),
                                icon: const Icon(Icons.check_circle),
                                label: const Text('Finish Set'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                            // Your existing Finish Set button here...
                            // --- NEW: EASY/HARD FEEDBACK ROW ---
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.thumb_down_alt_outlined,
                                      color: Colors.redAccent,
                                    ),
                                    label: const Text(
                                      'Too Hard',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                    onPressed: () => _showFeedbackModal(
                                      exName,
                                      false,
                                      extras,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.thumb_up_alt_outlined,
                                      color: Colors.green,
                                    ),
                                    label: const Text(
                                      'Too Easy',
                                      style: TextStyle(color: Colors.green),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Colors.green,
                                      ),
                                    ),
                                    onPressed: () => _showFeedbackModal(
                                      exName,
                                      true,
                                      extras,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // -----------------------------------
                          ],

                          if (stateType == 'rest') ...[
                            const Icon(
                              Icons.timer,
                              size: 80,
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "Rest Time",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '$timerValue',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 100,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const Spacer(),
                            StreamBuilder<PlaybackState>(
                              stream: handler.playbackState,
                              builder: (context, pbSnapshot) {
                                final isPlaying =
                                    pbSnapshot.data?.playing ?? true;
                                return Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => isPlaying
                                            ? handler.pause()
                                            : handler.play(),
                                        icon: Icon(
                                          isPlaying
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          color: Colors.white,
                                        ),
                                        label: Text(
                                          isPlaying ? 'Pause' : 'Resume',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: Colors.white,
                                          ),
                                          padding: const EdgeInsets.all(16),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: _isButtonLocked
                                            ? null
                                            : () => _handleAdvance(handler),
                                        icon: const Icon(Icons.fast_forward),
                                        label: const Text('Skip Rest'),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.all(16),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],

                          if (stateType == 'outro') ...[
                            const Icon(
                              Icons.emoji_events,
                              size: 100,
                              color: Colors.amber,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "Workout Complete!",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Restart Workout'),
                                  onPressed: () => handler.restartWorkout(),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.home,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Go Home / Dashboard',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  onPressed: () async => await handler.stop(),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white),
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Global End Early button for Portrait
                          if (stateType != 'outro') ...[
                            const SizedBox(height: 16),
                            TextButton.icon(
                              icon: const Icon(
                                Icons.stop_circle,
                                color: Colors.redAccent,
                              ),
                              label: const Text(
                                'End Workout Early',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 16,
                                ),
                              ),
                              onPressed: () async => await handler.stop(),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  DecorationImage _getDecorationImage(String? local, String? network) {
    if (local != null && local.isNotEmpty) {
      return DecorationImage(image: FileImage(File(local)), fit: BoxFit.cover);
    }
    if (network != null && network.isNotEmpty) {
      return DecorationImage(image: NetworkImage(network), fit: BoxFit.cover);
    }
    // FIX: Always return a high-quality default image if nothing else exists!
    return const DecorationImage(
      image: AssetImage('assets/images/default_workout.jpg'),
      fit: BoxFit.cover,
    );
  }

  Widget _targetBadge(String text, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withAlpha(200),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 24,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
