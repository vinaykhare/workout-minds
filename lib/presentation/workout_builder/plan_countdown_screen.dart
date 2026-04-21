import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/presentation/active_workout_screen.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/repositories/providers.dart';

class PlanCountdownScreen extends ConsumerStatefulWidget {
  final int workoutId;
  final String workoutTitle;
  final int planId;
  final int planDayId;
  final int dayNumber;
  final DateTime endDate;

  const PlanCountdownScreen({
    super.key,
    required this.workoutId,
    required this.workoutTitle,
    required this.planId,
    required this.planDayId,
    required this.dayNumber,
    required this.endDate,
  });

  @override
  ConsumerState<PlanCountdownScreen> createState() =>
      _PlanCountdownScreenState();
}

class _PlanCountdownScreenState extends ConsumerState<PlanCountdownScreen> {
  int _secondsLeft = 10;
  Timer? _timer;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
        _launchWorkout();
      }
    });
  }

  Future<void> _launchWorkout() async {
    if (_isStarting) return;
    _isStarting = true;
    final l10n = AppLocalizations.of(context)!;

    final db = ref.read(databaseProvider);
    final rows = await db.getWorkoutDetails(widget.workoutId);

    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.countdownEmptyError)));
        Navigator.pop(context);
      }
      return;
    }

    final routine = rows.map((row) {
      final ex = row.readTable(db.exercises);
      final details = row.readTable(db.workoutExercises);
      return {
        'name': ex.name,
        'sets': details.targetSets,
        'reps': details.targetReps,
        'durationSeconds': details.targetDurationSeconds,
        'restSecondsSet': details.restSecondsAfterSet,
        'restSecondsExercise': details.restSecondsAfterExercise,
        'imageUrl': ex.imageUrl,
        'localImagePath': ex.localImagePath,
        'equipment': ex.equipment,
        'targetWeight': details.targetWeight,
        'instructions': ex.instructions,
      };
    }).toList();

    final appLocale = ref.read(userProfileProvider).appLocale;
    final handler = ref.read(audioHandlerProvider);

    handler.startWorkoutSequence(
      routine,
      widget.workoutTitle,
      widget.workoutId,
      appLocale,
      planId: widget.planId,
      planDayId: widget.planDayId,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ActiveWorkoutScreen()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateStr =
        '${months[widget.endDate.month - 1]} ${widget.endDate.day}, ${widget.endDate.year}';

    // FIX: Removed leading underscores
    Widget buildLeftPanel() {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_month, size: 64, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            l10n.countdownDay(widget.dayNumber),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey),
          ),
          Text(
            widget.workoutTitle,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withAlpha(100),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withAlpha(50),
              ),
            ),
            child: Column(
              children: [
                Text(
                  l10n.countdownProjectionTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.countdownProjectionText(dateStr),
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget buildRightPanel() {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$_secondsLeft',
            style: const TextStyle(
              fontSize: 84,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          Text(
            l10n.countdownSeconds,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 48),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            onPressed: () {
              _timer?.cancel();
              _launchWorkout();
            },
            icon: const Icon(Icons.bolt),
            label: Text(l10n.countdownSkip),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              _timer?.cancel();
              Navigator.pop(context);
            },
            child: Text(
              l10n.countdownCancel,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;

            if (isWide) {
              return Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: buildLeftPanel(),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: buildRightPanel(),
                    ),
                  ),
                ],
              );
            }

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    buildLeftPanel(),
                    const SizedBox(height: 64),
                    buildRightPanel(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
