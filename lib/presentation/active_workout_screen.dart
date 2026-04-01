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

  @override
  void initState() {
    super.initState();
    final handler = ref.read(audioHandlerProvider);
    final db = ref.read(databaseProvider);

    handler.workoutCompleteStream.listen((isComplete) async {
      if (isComplete && mounted) {
        await db.logWorkoutCompletion(handler.currentWorkoutId!, 100);
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
                                    Text(
                                      exName,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
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

                            Text(
                              exName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
