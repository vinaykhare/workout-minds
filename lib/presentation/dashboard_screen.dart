import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/presentation/dashboard_controller.dart';
import 'package:workout_minds/presentation/workout_detail_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(dashboardControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: workoutsAsync.when(
        data: (workouts) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _VolumeChart()), // Summary Chart
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => ListTile(
                  title: Text(workouts[index].title),
                  subtitle: Text(workouts[index].difficultyLevel),
                  trailing: const Icon(Icons.play_arrow),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkoutDetailScreen(workout: workouts[index]),
                          ),
                        );
                      },
                ),
                childCount: workouts.length,
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(l10n.errorPrefix(e.toString()))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAiGenerator(context, ref),
        label: Text(l10n.aiGenerate),
        icon: const Icon(Icons.auto_awesome),
      ),
    );
  }

  void _showAiGenerator(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController promptController = TextEditingController();
    // Show a dialog to input the prompt
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aiGeneratorTitle),
        content: TextField(
          decoration: InputDecoration(
            hintText: l10n.aiGeneratorHint,
            helperText: l10n.aiGeneratorHelperText,
          ),
          controller: promptController,autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              final prompt = promptController.text.trim();
              ref.read(dashboardControllerProvider.notifier).generateWorkout(prompt);
              Navigator.pop(context);
            },
            child: Text(l10n.generate),
          ),
        ],
      ),
    );
  }
}

class _VolumeChart extends StatelessWidget {
  // For Sprint 1, we will default this to false.
  // In Sprint 2, we will wire this up to check the WorkoutLogs table.
  final bool hasData;

  const _VolumeChart({this.hasData = false});

  @override
  Widget build(BuildContext context) {
    if (!hasData) {
      return Container(
        height: 200,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  Icons.show_chart,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant
              ),
              const SizedBox(height: 8),
              Text(
                'No workout data yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Tap the button below to generate your first plan.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // The original chart code runs if hasData is true
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [const FlSpot(0, 1), const FlSpot(1, 3), const FlSpot(2, 2)],
              isCurved: true,
              color: Theme.of(context).primaryColor,
              barWidth: 4,
            ),
          ],
        ),
      ),
    );
  }
}
