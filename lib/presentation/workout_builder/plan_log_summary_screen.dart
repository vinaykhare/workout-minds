import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/repositories/providers.dart';

class PlanLogSummaryScreen extends ConsumerWidget {
  final PlanLogData planLogData;

  const PlanLogSummaryScreen({super.key, required this.planLogData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final start = planLogData.log.startedAt;
    final end = planLogData.log.completedAt;
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
    final dateString =
        '${months[start.month - 1]} ${start.day} - ${months[end.month - 1]} ${end.day}, ${end.year}';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.summaryPlanHistory)),
      body: FutureBuilder<List<WorkoutLog>>(
        future: ref
            .read(databaseProvider)
            .getLogsForPlanInstance(planLogData.plan.id, start, end),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs = snapshot.data ?? [];

          // FIX: Removed leading underscores
          Widget buildLeftPanel() {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.emoji_events,
                  size: 100,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(height: 24),
                Text(
                  planLogData.plan.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  dateString,
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            );
          }

          Widget buildList() {
            if (logs.isEmpty) {
              return Center(child: Text(l10n.summaryNoLogs));
            }
            return ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                final logDate =
                    '${months[log.executedAt.month - 1]} ${log.executedAt.day}';
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.check, color: Colors.white),
                  ),
                  title: Text(
                    l10n.summaryWorkoutSession(log.totalVolume.toInt()),
                  ),
                  subtitle: Text(logDate),
                  trailing: log.executionFeedback != null
                      ? const Icon(Icons.feedback, color: Colors.orange)
                      : null,
                );
              },
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;

              if (isWide) {
                return Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: buildLeftPanel(),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              l10n.summaryWorkoutsCompleted,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(child: buildList()),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            size: 80,
                            color: Colors.orangeAccent,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            planLogData.plan.title,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            dateString,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              l10n.summaryWorkoutsCompleted,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (logs.isEmpty)
                    SliverToBoxAdapter(
                      child: Center(child: Text(l10n.summaryNoLogs)),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final log = logs[index];
                        final logDate =
                            '${months[log.executedAt.month - 1]} ${log.executedAt.day}';
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.check, color: Colors.white),
                          ),
                          title: Text(
                            l10n.summaryWorkoutSession(log.totalVolume.toInt()),
                          ),
                          subtitle: Text(logDate),
                          trailing: log.executionFeedback != null
                              ? const Icon(Icons.feedback, color: Colors.orange)
                              : null,
                        );
                      }, childCount: logs.length),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
