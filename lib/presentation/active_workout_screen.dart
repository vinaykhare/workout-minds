import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../repositories/providers.dart';
import '../core/l10n/app_localizations.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return _ActiveWorkoutScreenState();
  }
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  @override
  void initState() {
    super.initState();
    final handler = ref.read(audioHandlerProvider);
    handler.workoutCompleteStream.listen((isComplete) {
      if (isComplete && mounted) {
        Navigator.pop(context); // Pops automatically!
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final handler = ref.watch(audioHandlerProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<int>(
        stream: handler.restStream,
        initialData: 0,
        builder: (context, restSnapshot) {
          final secondsLeft = restSnapshot.data ?? 0;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Only show exercise text if we are NOT resting
                if (secondsLeft == 0)
                  StreamBuilder<MediaItem?>(
                    stream: handler.mediaItem,
                    builder: (context, mediaSnapshot) {
                      final title = mediaSnapshot.data?.title ?? l10n.getReady;
                      final subtitle = mediaSnapshot.data?.artist ?? '';
                      final reps =
                          mediaSnapshot.data?.extras?['reps'] as String?;

                      final duration =
                          mediaSnapshot.data?.extras?['durationSeconds']
                              as int?;

                      // Extract image data
                      final imageUrl =
                          mediaSnapshot.data?.extras?['imageUrl'] as String?;
                      final localImagePath =
                          mediaSnapshot.data?.extras?['localImagePath']
                              as String?;

                      return Column(
                        children: [
                          // NEW: Beautiful Circular Thumbnail
                          if (localImagePath != null ||
                              (imageUrl != null && imageUrl.isNotEmpty))
                            Container(
                              width: 120,
                              height: 120,
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 4,
                                ),
                                image: DecorationImage(
                                  fit: BoxFit.cover,
                                  image: localImagePath != null
                                      ? FileImage(File(localImagePath))
                                            as ImageProvider
                                      : NetworkImage(imageUrl!),
                                ),
                              ),
                            ),

                          Text(
                            title,
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          if (reps != null && reps != 'null') ...[
                            _targetBadge('Target: $reps reps', context),
                          ] else if (duration != null) ...[
                            _targetBadge('Target: $duration seconds', context),
                          ],
                        ],
                      );
                    },
                  ),

                // Show Circular Timer if we ARE resting
                if (secondsLeft > 0)
                  Column(
                    children: [
                      Text(
                        l10n.restTime,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 32),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 250,
                            height: 250,
                            child: CircularProgressIndicator(
                              value: secondsLeft / 60,
                              strokeWidth: 16,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            "$secondsLeft",
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                const Spacer(),

                // Action Buttons
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: secondsLeft > 0
                      ? null
                      : () {
                          handler.completeSet();
                        },
                  child: Text(
                    l10n.finishSet,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  icon: const Icon(Icons.stop_circle, color: Colors.red),
                  label: Text(
                    l10n.endWorkout,
                    style: const TextStyle(fontSize: 18),
                  ),
                  onPressed: () async {
                    final handler = ref.read(audioHandlerProvider);
                    await handler
                        .stop(); // Kills the audio and timers immediately
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                // OutlinedButton(
                //   style: OutlinedButton.styleFrom(
                //     padding: const EdgeInsets.symmetric(vertical: 16),
                //   ),
                //   onPressed: () {
                //     handler.stop();
                //     Navigator.pop(context);
                //   },
                //   child: Text(
                //     l10n.endWorkout,
                //     style: const TextStyle(fontSize: 18),
                //   ),
                // ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper widget to display either Reps or Duration cleanly
  Widget _targetBadge(String text, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
