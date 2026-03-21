import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../repositories/providers.dart';
import '../services/workout_audio_handler.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  bool _isButtonLocked = false;
  bool _isFullScreenImage = false; // FIX: Controls the double-tap state!

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
      }
    });

    // FIX 2: Listen for the notification "Stop" button!
    handler.workoutAbortedStream.listen((_) {
      if (mounted) {
        Navigator.pop(context); // Closes the active workout screen
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final handler = ref.read(audioHandlerProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Active Workout',
          style: TextStyle(color: Colors.white),
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
          final title = snapshot.data!.title;
          final exName = extras['exName'] as String? ?? '';
          final timerValue = extras['timerValue'] as int? ?? 0;
          final reps = extras['reps'] as String?;
          final imageUrl = extras['imageUrl'] as String?;
          final localImagePath = extras['localImagePath'] as String?;

          // Helper boolean to check if we are in an exercise state
          final isExercise =
              stateType == 'exercise_rep' || stateType == 'exercise_time';

          return Stack(
            fit: StackFit.expand,
            children: [
              // --- LAYER 1: FULL SCREEN BACKGROUND (Only if enabled and is an exercise) ---
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

                      // Gradient Overlay so text is readable
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

              // --- LAYER 2: THE UI CONTENT ---
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- 1. INTRO SCREEN ---
                      if (stateType == 'intro') ...[
                        const Icon(
                          Icons.fitness_center,
                          size: 80,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Workout Started.\nLet's crush it!",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, color: Colors.white70),
                        ),
                      ],

                      // --- 2. EXERCISE SCREEN ---
                      if (isExercise) ...[
                        // FIX: Show the inline rounded image ONLY if full screen is disabled
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
                                child:
                                    _getDecorationImage(
                                          localImagePath,
                                          imageUrl,
                                        ) ==
                                        null
                                    ? const Icon(
                                        Icons.fitness_center,
                                        size: 64,
                                        color: Colors.grey,
                                      )
                                    : null,
                              ),
                            ),
                          )
                        else
                          const Spacer(), // Pushes content down if image is full screen

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

                        // FIX 5: Dynamic UI Play/Pause button syncing with the notification
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

                      // --- 3. REST SCREEN ---
                      if (stateType == 'rest') ...[
                        const Icon(Icons.timer, size: 80, color: Colors.orange),
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
                            final isPlaying = pbSnapshot.data?.playing ?? true;
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

                      // --- 4. OUTRO SCREEN ---
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
                            // FIX: Removed the Scheduled Notification Button entirely!
                            OutlinedButton.icon(
                              icon: const Icon(Icons.home, color: Colors.white),
                              label: const Text(
                                'Go Home / Dashboard',
                                style: TextStyle(color: Colors.white),
                              ),
                              onPressed: () async {
                                // FIX: Removed Navigator.pop(context)!
                                // Calling stop() fires the stream, which safely pops the screen exactly once.
                                await handler.stop();
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white),
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // GLOBAL ABORT BUTTON
                      // GLOBAL ABORT BUTTON (Hidden on Outro)
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
                          onPressed: () async {
                            // FIX: Removed the duplicate Navigator.pop(context)!
                            // The stream listener at the top of the file handles closing the screen securely.
                            await handler.stop();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Helper to safely extract image provider for the Box Decoration
  DecorationImage? _getDecorationImage(String? local, String? network) {
    if (local != null && local.isNotEmpty) {
      return DecorationImage(image: FileImage(File(local)), fit: BoxFit.cover);
    }
    if (network != null && network.isNotEmpty) {
      return DecorationImage(image: NetworkImage(network), fit: BoxFit.cover);
    }
    return null;
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
