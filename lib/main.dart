import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/presentation/dashboard_screen.dart';

// 1. Global Database Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: WorkoutMindsApp(),
    ),
  );
}

class WorkoutMindsApp extends StatelessWidget {
  const WorkoutMindsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueAccent,
        brightness: Brightness.dark,
      ),
      home: const DashboardScreen(),
    );
  }
}
