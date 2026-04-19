import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'dart:convert';
import 'package:workout_minds/services/workout_audio_handler.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  bool _isButtonLocked = false;

  void _handleAdvance(WorkoutAudioHandler handler) {
    if (_isButtonLocked) return;
    setState(() => _isButtonLocked = true);
    handler.advanceSequence();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _isButtonLocked = false);
    });
  }

  void _showFullScreenImage(
    String? local,
    String? network,
    String title,
    String? instructions,
  ) {
    if ((local == null || local.isEmpty) &&
        (network == null || network.isEmpty)) {
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              child: local != null && local.isNotEmpty
                  ? Image.file(File(local), fit: BoxFit.contain)
                  : Image.network(network!, fit: BoxFit.contain),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24).copyWith(top: 64),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87, Colors.black],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (instructions != null && instructions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        instructions,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 36),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
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

    int repMin = 0;
    int repMax = 10;
    int actualReps = 0;

    if (targetReps != null) {
      if (isTooEasy) {
        repMin = targetReps + 1;
        repMax = targetReps + 15;
        actualReps = repMin;
      } else {
        repMin = 0;
        repMax = targetReps - 1;
        if (repMax < 0) repMax = 0;
        actualReps = repMax;
      }
    }

    double sliderRepMax = repMax > repMin
        ? repMax.toDouble()
        : (repMin + 1).toDouble();
    int repDivs = (sliderRepMax - repMin).toInt();

    int durMin = 0;
    int durMax = 30;
    int actualDuration = 0;

    if (targetDuration != null && targetDuration > 0) {
      if (isTooEasy) {
        durMin = targetDuration + 1;
        durMax = targetDuration + 60;
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

    String weightFeedback = isTooEasy ? 'Too Light' : 'Too Heavy';
    final handler = ref.read(audioHandlerProvider);

    final wasPlaying = handler.playbackState.value.playing;
    if (wasPlaying) {
      await handler.pause();
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            // FIX: Added safe bottom padding for keyboard without stretching the content
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            // FIX: Wrapped in SingleChildScrollView so tall contents never crash on small screens!
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
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
                        setModalState(
                          () => weightFeedback = newSelection.first,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  FilledButton(
                    onPressed: () {
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
                      Navigator.pop(context);

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
            ),
          );
        },
      ),
    );

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
          planId: handler.currentPlanId,
        );
        if (handler.currentPlanDayId != null) {
          await db.togglePlanDayCompletion(handler.currentPlanDayId!, true);
          ref.invalidate(planScheduleProvider);
        }
        ref.invalidate(weeklyStatsProvider);

        final profile = ref.read(userProfileProvider);
        if (profile.isAutoSyncEnabled) {
          final profileJsonString = jsonEncode(profile.toJson());
          ref.read(driveSyncProvider).backupToCloud(profileJsonString).ignore();
        }
      }
    });

    handler.workoutAbortedStream.listen((_) {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  Widget _flexButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? color,
    bool isOutlined = false,
  }) {
    final content = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );

    final activeColor = color ?? Colors.blue;

    if (isOutlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: activeColor,
          disabledForegroundColor: Colors.grey, // Visible disabled text
          side: BorderSide(
            color: onPressed == null ? Colors.grey.withAlpha(100) : activeColor,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        ),
        child: content,
      );
    } else {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: activeColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.withAlpha(50),
          disabledForegroundColor: Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        ),
        child: content,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final handler = ref.read(audioHandlerProvider);
    final isPlanWorkout = handler.currentPlanId != null;
    final l10n = AppLocalizations.of(context)!;

    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final textMutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: bgColor,
      appBar: AppBar(
        title: StreamBuilder<MediaItem?>(
          stream: handler.mediaItem,
          builder: (context, snapshot) {
            final workoutTitle = snapshot.data?.album ?? 'Active Workout';
            return Text(workoutTitle, style: TextStyle(color: textColor));
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.pie_chart, color: textColor),
            onPressed: () async {
              final media = await handler.mediaItem.first;
              if (media?.extras != null) {
                _showStatusModal(media!.extras!);
              }
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

          // ==========================================================
          // ISOLATED OUTRO STATE
          // ==========================================================
          if (stateType == 'outro') {
            return Container(
              color: bgColor,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          size: 120,
                          color: Colors.amber,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l10n.workoutComplete,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 64),
                        if (!isPlanWorkout) ...[
                          _flexButton(
                            icon: Icons.refresh,
                            label: 'Restart Workout',
                            onPressed: () => handler.restartWorkout(),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _flexButton(
                          icon: isPlanWorkout ? Icons.fact_check : Icons.home,
                          label: isPlanWorkout
                              ? 'Go to Plan & Check Progress'
                              : 'Go Home / Dashboard',
                          onPressed: () async => await handler.stop(),
                          isOutlined: true,
                          color: textColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          // ==========================================================
          // MAIN LAYOUT ROUTER
          // ==========================================================
          return LayoutBuilder(
            builder: (context, constraints) {
              // FIX: Bumped to 800 so large portrait phones don't crash the UI!
              final isLandscape = constraints.maxWidth > 800;

              if (isLandscape) {
                // LANDSCAPE MODE
                return SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    height: constraints.maxHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // LEFT COLUMN: Visuals
                        Expanded(
                          flex: 4,
                          // FIX: Made the landscape columns scrollable so they never overflow!
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (stateType == 'intro') ...[
                                  const Icon(
                                    Icons.fitness_center,
                                    size: 80,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    snapshot.data?.album ?? 'Active Workout',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ] else if (isExercise) ...[
                                  // FIX: Swapped Expanded for AspectRatio so it scrolls safely
                                  GestureDetector(
                                    onTap: () => _showFullScreenImage(
                                      localImagePath,
                                      imageUrl,
                                      exName,
                                      instructions,
                                    ),
                                    child: Container(
                                      height: constraints.maxHeight * 0.60,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(24),
                                        image: _getDecorationImage(
                                          localImagePath,
                                          imageUrl,
                                        ),
                                      ),

                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (instructions != null &&
                                              instructions.isNotEmpty)
                                            Positioned(
                                              bottom: 12,
                                              right: 12,
                                              child: FloatingActionButton.small(
                                                backgroundColor: Colors
                                                    .blueAccent
                                                    .withAlpha(200),
                                                elevation: 0,
                                                onPressed: () => handler
                                                    .speakCurrentInstructions(),
                                                child: const Icon(
                                                  Icons.volume_up,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    exName,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    snapshot.data!.artist ?? '',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: textMutedColor,
                                    ),
                                  ),
                                  if (instructions != null &&
                                      instructions.isNotEmpty)
                                    Text(
                                      instructions,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: textMutedColor,
                                      ),
                                    ),
                                  if ((equipment != null &&
                                          equipment.isNotEmpty) ||
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
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 24),
                                ] else if (stateType == 'rest') ...[
                                  Container(
                                    height: constraints.maxHeight * 0.8,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(24),
                                      image: _getDecorationImage(null, null),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),

                        // RIGHT COLUMN: Controls
                        Expanded(
                          flex: 1,
                          // FIX: Added scroll view so Landscape controls never overflow on small heights
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (stateType == 'intro') ...[
                                  Text(
                                    l10n.workoutStarted,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: textMutedColor,
                                    ),
                                  ),
                                ] else if (isExercise) ...[
                                  if (stateType == 'exercise_rep')
                                    _targetBadge('Target: $reps Reps', context)
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
                                              child: _flexButton(
                                                icon: isPlaying
                                                    ? Icons.pause
                                                    : Icons.play_arrow,
                                                label: isPlaying
                                                    ? 'Pause'
                                                    : 'Resume',
                                                onPressed: () => isPlaying
                                                    ? handler.pause()
                                                    : handler.play(),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: _flexButton(
                                                icon: Icons.skip_next,
                                                label: 'Skip Time',
                                                onPressed: _isButtonLocked
                                                    ? null
                                                    : () => _handleAdvance(
                                                        handler,
                                                      ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    )
                                  else
                                    _flexButton(
                                      icon: Icons.check_circle,
                                      label: l10n.finishSet,
                                      onPressed: _isButtonLocked
                                          ? null
                                          : () => _handleAdvance(handler),
                                    ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: _flexButton(
                                          icon: Icons.thumb_down_alt_outlined,
                                          label: 'Too Hard',
                                          color: Colors.redAccent,
                                          isOutlined: true,
                                          onPressed: () => _showFeedbackModal(
                                            exName,
                                            false,
                                            extras,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _flexButton(
                                          icon: Icons.thumb_up_alt_outlined,
                                          label: 'Too Easy',
                                          color: Colors.green,
                                          isOutlined: true,
                                          onPressed: () => _showFeedbackModal(
                                            exName,
                                            true,
                                            extras,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else if (stateType == 'rest') ...[
                                  const Icon(
                                    Icons.timer,
                                    size: 80,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    l10n.restTime,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
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
                                            child: _flexButton(
                                              icon: isPlaying
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              label: isPlaying
                                                  ? 'Pause'
                                                  : 'Resume',
                                              isOutlined: true,
                                              color: textColor,
                                              onPressed: () => isPlaying
                                                  ? handler.pause()
                                                  : handler.play(),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _flexButton(
                                              icon: Icons.fast_forward,
                                              label: 'Skip Rest',
                                              onPressed: _isButtonLocked
                                                  ? null
                                                  : () =>
                                                        _handleAdvance(handler),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.stop_circle,
                                    color: Colors.redAccent,
                                  ),
                                  label: Text(
                                    l10n.endWorkout,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 16,
                                    ),
                                  ),
                                  onPressed: () async => await handler.stop(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // PORTRAIT MODE
              return SafeArea(
                child: Column(
                  children: [
                    // TOP HALF: Image
                    if (isExercise)
                      Container(
                        height: constraints.maxHeight * 0.42,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          image: _getDecorationImage(localImagePath, imageUrl),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            GestureDetector(
                              onTap: () => _showFullScreenImage(
                                localImagePath,
                                imageUrl,
                                exName,
                                instructions,
                              ),
                              child: Container(color: Colors.transparent),
                            ),
                            if (instructions != null && instructions.isNotEmpty)
                              Positioned(
                                bottom: 16,
                                right: 16,
                                child: FloatingActionButton.small(
                                  backgroundColor: Colors.blueAccent.withAlpha(
                                    200,
                                  ),
                                  elevation: 0,
                                  onPressed: () =>
                                      handler.speakCurrentInstructions(),
                                  child: const Icon(
                                    Icons.volume_up,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    // BOTTOM HALF: Controls
                    Expanded(
                      child: SafeArea(
                        top: !isExercise,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (stateType == 'intro') ...[
                                const Icon(
                                  Icons.fitness_center,
                                  size: 80,
                                  color: Colors.blue,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  snapshot.data?.album ?? 'Active Workout',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.workoutStarted,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: textMutedColor,
                                  ),
                                ),
                              ],
                              if (isExercise) ...[
                                Text(
                                  exName,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  snapshot.data!.artist ?? '',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textMutedColor,
                                  ),
                                ),
                                if ((equipment != null &&
                                        equipment.isNotEmpty) ||
                                    targetWeight != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
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
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                if (stateType == 'exercise_rep')
                                  _targetBadge('Target: $reps Reps', context)
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
                                            child: _flexButton(
                                              icon: isPlaying
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              label: isPlaying
                                                  ? 'Pause'
                                                  : 'Resume',
                                              onPressed: () => isPlaying
                                                  ? handler.pause()
                                                  : handler.play(),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _flexButton(
                                              icon: Icons.skip_next,
                                              label: 'Skip Time',
                                              onPressed: _isButtonLocked
                                                  ? null
                                                  : () =>
                                                        _handleAdvance(handler),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  )
                                else
                                  _flexButton(
                                    icon: Icons.check_circle,
                                    label: l10n.finishSet,
                                    onPressed: _isButtonLocked
                                        ? null
                                        : () => _handleAdvance(handler),
                                  ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: _flexButton(
                                        icon: Icons.thumb_down_alt_outlined,
                                        label: 'Too Hard',
                                        color: Colors.redAccent,
                                        isOutlined: true,
                                        onPressed: () => _showFeedbackModal(
                                          exName,
                                          false,
                                          extras,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _flexButton(
                                        icon: Icons.thumb_up_alt_outlined,
                                        label: 'Too Easy',
                                        color: Colors.green,
                                        isOutlined: true,
                                        onPressed: () => _showFeedbackModal(
                                          exName,
                                          true,
                                          extras,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (stateType == 'rest') ...[
                                const Icon(
                                  Icons.timer,
                                  size: 80,
                                  color: Colors.orange,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  l10n.restTime,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
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
                                const SizedBox(height: 32),
                                StreamBuilder<PlaybackState>(
                                  stream: handler.playbackState,
                                  builder: (context, pbSnapshot) {
                                    final isPlaying =
                                        pbSnapshot.data?.playing ?? true;
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: _flexButton(
                                            icon: isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            label: isPlaying
                                                ? 'Pause'
                                                : 'Resume',
                                            isOutlined: true,
                                            color: textColor,
                                            onPressed: () => isPlaying
                                                ? handler.pause()
                                                : handler.play(),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _flexButton(
                                            icon: Icons.fast_forward,
                                            label: 'Skip Rest',
                                            onPressed: _isButtonLocked
                                                ? null
                                                : () => _handleAdvance(handler),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                              if (stateType != 'outro') ...[
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.stop_circle,
                                    color: Colors.redAccent,
                                  ),
                                  label: Text(
                                    l10n.endWorkout,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 16,
                                    ),
                                  ),
                                  onPressed: () async => await handler.stop(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  DecorationImage _getDecorationImage(String? local, String? network) {
    if (local != null && local.isNotEmpty) {
      return DecorationImage(
        image: FileImage(File(local)),
        fit: BoxFit.contain,
      );
    }
    if (network != null && network.isNotEmpty) {
      return DecorationImage(image: NetworkImage(network), fit: BoxFit.contain);
    }
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
