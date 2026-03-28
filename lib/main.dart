import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/presentation/dashboard_screen.dart';
import 'package:workout_minds/presentation/onboarding_screen.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'package:workout_minds/services/workout_audio_handler.dart';

// Global Database Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

Future<void> main() async {
  // Ensure the engine is ready
  WidgetsFlutterBinding.ensureInitialized();
  // 1. Initialize SharedPreferences before the app starts
  final prefs = await SharedPreferences.getInstance();
  // // Just for Testing
  // await prefs.setBool('hasOnboarded', false);

  // Initialize the Background Audio Service
  final audioHandler = await AudioService.init(
    builder: () => WorkoutAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId:
          'io.github.vinaykhare.workout_minds.channel.audio',
      androidNotificationChannelName: 'Workout Execution',
      androidNotificationOngoing:
          true, // Prevents user from swiping away the active workout
      androidShowNotificationBadge: true,
    ),
  );

  await dotenv.load(fileName: ".env");
  runApp(
    ProviderScope(
      // Inject the initialized audioHandler into the Riverpod tree
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const WorkoutMindsApp(),
    ),
  );
}

class WorkoutMindsApp extends ConsumerWidget {
  const WorkoutMindsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      locale: Locale(userProfile.appLocale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueAccent,
        brightness: Brightness.dark,
      ),
      home: userProfile.hasOnboarded
          ? const DashboardScreen()
          : const OnboardingScreen(),
    );
  }
}
