import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/providers.dart'; // Ensure this path is correct!

class WeeklyProgressCard extends ConsumerWidget {
  const WeeklyProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Listen to your actual database provider
    final weeklyStatsAsync = ref.watch(weeklyStatsProvider);

    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Card(
      elevation: 0,
      color: surfaceColor.withAlpha(100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),

        // 2. Handle the Future states (Loading, Error, Data)
        child: weeklyStatsAsync.when(
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, stack) =>
              SizedBox(height: 200, child: Center(child: Text('Error: $err'))),
          data: (spots) {
            // Extract the Y values (Volume) from your FlSpots
            List<double> weeklyData = List.filled(7, 0.0);
            for (var spot in spots) {
              weeklyData[spot.x.toInt()] = spot.y;
            }

            // Calculate dynamic text and chart bounds
            double totalWorkouts = weeklyData.fold(
              0,
              (sum, item) => sum + item,
            );
            double maxVolume = weeklyData.isEmpty ? 0 : weeklyData.reduce(max);

            // Add a 20% headroom above the tallest bar so it looks clean, default to 100 if empty
            double chartMaxY = maxVolume > 0 ? (maxVolume * 1.2) : 100;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weekly Consistency',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                // Dynamic motivational subtitle
                Text(
                  totalWorkouts > 0
                      ? 'You completed ${totalWorkouts.toInt()} workouts this week! 💪'
                      : 'Ready to crush some goals this week?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: chartMaxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${rod.toY.toInt()} workouts',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              // Dynamically calculate the days (e.g., if today is Wed, the last bar is W)
                              final daysAgo = 6 - value.toInt();
                              final date = DateTime.now().subtract(
                                Duration(days: daysAgo),
                              );
                              const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                              final dayStr =
                                  days[date.weekday - 1]; // weekday is 1-7

                              final isToday = daysAgo == 0;

                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  dayStr,
                                  style: TextStyle(
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 12,
                                    color: isToday
                                        ? primaryColor
                                        : Colors.grey, // Highlight today!
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(7, (index) {
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: weeklyData[index],
                              // Darken the past days, highlight Today (index 6)
                              color: index == 6
                                  ? primaryColor
                                  : primaryColor.withAlpha(150),
                              width: 16,
                              borderRadius: BorderRadius.circular(8),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: chartMaxY,
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainer,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
