import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:workout_minds/repositories/providers.dart';

class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Access the background audio handler
    final handler = ref.watch(audioHandlerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout in Progress'),
        centerTitle: true,
        automaticallyImplyLeading:
            false, // Prevent accidental back swipes during workout
      ),
      // StreamBuilder listens directly to the audio_service background isolate
      body: StreamBuilder<MediaItem?>(
        stream: handler.mediaItem,
        builder: (context, snapshot) {
          final mediaItem = snapshot.data;

          // Fallbacks for the initial 3-second start delay
          final title = mediaItem?.title ?? 'Get Ready...';
          final subtitle = mediaItem?.artist ?? 'Starting soon';

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Exercise Name
                Text(
                  title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Set and Rep Information
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),

                const Spacer(), // Pushes buttons to the bottom half of the screen
                // Primary Action: Finish Set
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    elevation: 8,
                  ),
                  onPressed: () {
                    // Trigger the background state machine to advance
                    handler.completeSet();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Great job! 60s Rest Timer Started.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text(
                    'FINISH SET',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),

                // Secondary Action: End Workout Early
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    handler.stop();
                    Navigator.pop(context); // Safely exit the active screen
                  },
                  child: const Text(
                    'End Workout Early',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
