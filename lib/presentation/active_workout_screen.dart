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
  bool _isButtonLocked = false; // Local UI lock to prevent button mashing

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

        // Rough percentage based on exercises completed
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
  Widget build(BuildContext context) {
    final handler = ref.read(audioHandlerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Workout'),
        automaticallyImplyLeading:
            false, // Hide back button to prevent accidental quits
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart),
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

          return Padding(
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Workout Started.\nLet's crush it!",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                ],

                // --- 2. EXERCISE (REP OR TIME) SCREEN ---
                if (stateType == 'exercise_rep' ||
                    stateType == 'exercise_time') ...[
                  _buildThumbnail(localImagePath, imageUrl, context),
                  Text(
                    exName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.data!.artist ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  if (stateType == 'exercise_rep')
                    _targetBadge('Target: $reps Reps', context)
                  else
                    _targetBadge('Time Left: $timerValue s', context),

                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _isButtonLocked
                        ? null
                        : () => _handleAdvance(handler),
                    icon: Icon(
                      stateType == 'exercise_rep'
                          ? Icons.check_circle
                          : Icons.skip_next,
                    ),
                    label: Text(
                      stateType == 'exercise_rep'
                          ? 'Finish Set'
                          : 'Skip Remaining Time',
                    ),
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
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$timerValue',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _isButtonLocked
                        ? null
                        : () => _handleAdvance(handler),
                    icon: const Icon(Icons.fast_forward),
                    label: const Text('Skip Rest'),
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
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      handler.stop();
                      Navigator.pop(context);
                    },
                    child: const Text('Go Home / Dashboard'),
                  ),
                ],

                // GLOBAL ABORT BUTTON (Hidden on Outro)
                if (stateType != 'outro') ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    icon: const Icon(Icons.stop_circle, color: Colors.red),
                    label: const Text(
                      'End Workout Early',
                      style: TextStyle(color: Colors.red),
                    ),
                    onPressed: () async {
                      await handler.stop();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper Widget for Image
  Widget _buildThumbnail(String? local, String? network, BuildContext context) {
    if (local == null && (network == null || network.isEmpty)) {
      return const SizedBox(height: 120);
    }
    return Container(
      width: 120,
      height: 120,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 4,
        ),
        image: DecorationImage(
          fit: BoxFit.cover,
          image: local != null
              ? FileImage(File(local)) as ImageProvider
              : NetworkImage(network!),
        ),
      ),
    );
  }

  // Helper Widget for Target Badge
  Widget _targetBadge(String text, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
