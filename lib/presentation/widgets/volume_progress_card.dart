import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/providers.dart';

class VolumeProgressCard extends ConsumerWidget {
  const VolumeProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(weeklyStatsProvider);
    final primaryColor = Colors.deepPurpleAccent;
    final surfaceColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return logsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (spots) {
        // Find out if they actually lifted anything!
        double totalWeeklyVolume = 0;
        List<double> dailyVolume = List.filled(7, 0.0);

        // Note: We need the raw logs to get volume, not the FlSpots from the consistency chart.
        // For now, let's assume we can fetch the raw logs. (You can also update weeklyStatsProvider to return a complex object).
        // To keep it simple, we will watch the raw Stream directly here:
        return StreamBuilder(
          stream: ref.read(databaseProvider).watchWeeklyVolumeStats(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final logs = snapshot.data!;
            final today = DateTime.now();
            final cleanToday = DateTime(today.year, today.month, today.day);

            for (var log in logs) {
              final logDate = log.executedAt;
              final cleanLogDate = DateTime(
                logDate.year,
                logDate.month,
                logDate.day,
              );
              final difference = cleanToday.difference(cleanLogDate).inDays;

              if (difference >= 0 && difference <= 6) {
                final xIndex = 6 - difference;
                dailyVolume[xIndex] += log.totalVolume;
                totalWeeklyVolume += log.totalVolume;
              }
            }

            // HIDE CHART IF NO WEIGHT WAS LIFTED (e.g. Bodyweight only)
            if (totalWeeklyVolume <= 0) return const SizedBox.shrink();

            double maxVolume = dailyVolume.reduce(max);
            double chartMaxY = maxVolume > 0 ? (maxVolume * 1.2) : 100;

            return Card(
              elevation: 0,
              color: surfaceColor.withAlpha(100),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              margin: const EdgeInsets.only(top: 16),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Volume Lifted (kg)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You moved ${totalWeeklyVolume.toInt()} kg this week!',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 150,
                      child: LineChart(
                        LineChartData(
                          maxY: chartMaxY,
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            show: true,
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final daysAgo = 6 - value.toInt();
                                  final date = DateTime.now().subtract(
                                    Duration(days: daysAgo),
                                  );
                                  const days = [
                                    'M',
                                    'T',
                                    'W',
                                    'T',
                                    'F',
                                    'S',
                                    'S',
                                  ];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      days[date.weekday - 1],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: daysAgo == 0
                                            ? primaryColor
                                            : Colors.grey,
                                        fontWeight: daysAgo == 0
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                7,
                                (index) => FlSpot(
                                  index.toDouble(),
                                  dailyVolume[index],
                                ),
                              ),
                              isCurved: true,
                              color: primaryColor,
                              barWidth: 4,
                              isStrokeCapRound: true,
                              belowBarData: BarAreaData(
                                show: true,
                                color: primaryColor.withAlpha(50),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
