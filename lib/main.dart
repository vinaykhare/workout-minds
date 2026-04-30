import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/presentation/dashboard_screen.dart';
import 'package:workout_minds/presentation/welcome_screen.dart';
import 'package:workout_minds/presentation/active_workout_screen.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'package:workout_minds/services/workout_audio_handler.dart';

// Global Database Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Ensure the engine is ready
  WidgetsFlutterBinding.ensureInitialized();
  // 1. Initialize SharedPreferences before the app starts
  final prefs = await SharedPreferences.getInstance();

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
      // FIX: Explicitly tell Android to open the app UI when the notification is tapped
      androidNotificationClickStartsActivity: true,
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

class WorkoutMindsApp extends ConsumerStatefulWidget {
  const WorkoutMindsApp({super.key});

  @override
  ConsumerState<WorkoutMindsApp> createState() => _WorkoutMindsAppState();
}

class _WorkoutMindsAppState extends ConsumerState<WorkoutMindsApp>
    with WidgetsBindingObserver {
  late StreamSubscription _intentDataStreamSubscription;
  // FIX 2: Global key to show SnackBars safely from background processes!
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _intentDataStreamSubscription = ReceiveSharingIntent.instance
          .getMediaStream()
          .listen(
            (List<SharedMediaFile> value) {
              _handleSharedFile(value);
            },
            onError: (err) {
              debugPrint("getIntentDataStream error: $err");
            },
          );

      ReceiveSharingIntent.instance.getInitialMedia().then((
        List<SharedMediaFile> value,
      ) {
        _handleSharedFile(value);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndNavigateToActiveWorkout();
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndNavigateToActiveWorkout();
    }
  }

  void _checkAndNavigateToActiveWorkout() {
    final handler = ref.read(audioHandlerProvider);
    final pbState = handler.playbackState.value;
    final isPlayingSomething =
        pbState.processingState != AudioProcessingState.idle;
    if (isPlayingSomething && handler.currentWorkoutId != null) {
      if (!isActiveWorkoutScreenOpen) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (context) => const ActiveWorkoutScreen()),
        );
      }
    }
  }

  void _handleSharedFile(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    final path = files.first.path;
    final shareService = ref.read(workoutShareProvider);
    final workoutData = await shareService.parseWorkoutFile(path);

    if (workoutData != null) {
      ReceiveSharingIntent.instance.reset(); // Clean up OS intent

      if (workoutData['type'] == 'plan' || workoutData.containsKey('plan')) {
        ref.read(pendingPlanImportProvider.notifier).state = workoutData;
      } else {
        ref.read(pendingImportProvider.notifier).state = workoutData;
      }
    } else {
      ReceiveSharingIntent.instance.reset();
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Workout Minds cannot read this file.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey:
          _scaffoldMessengerKey, // FIX 3: Attach the key to MaterialApp!
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      locale: Locale(userProfile.appLocale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      // --- NEW THEME ENGINE ---
      themeMode: userProfile.themeMode == 'light'
          ? ThemeMode.light
          : userProfile.themeMode == 'dark'
          ? ThemeMode.dark
          : ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueAccent,
        brightness: Brightness.light, // Light Mode
        scaffoldBackgroundColor: Colors.grey.shade50,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueAccent,
        brightness: Brightness.dark, // Dark Mode
      ),
      // ------------------------
      home: userProfile.hasOnboarded
          ? const DashboardScreen()
          : const WelcomeScreen(),
    );
  }
}
