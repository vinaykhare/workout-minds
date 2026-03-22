import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. Synchronous SharedPreferences Provider (Initialized in main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main.dart',
  );
});

// 2. The User Profile Model
class UserProfile {
  final bool hasOnboarded;
  final String gender;
  final String goal;
  final String experienceLevel;
  final double heightCm;
  final double weightKg;
  final String appLanguage;

  UserProfile({
    required this.hasOnboarded,
    required this.gender,
    required this.goal,
    required this.experienceLevel,
    required this.heightCm,
    required this.weightKg,
    required this.appLanguage,
  });

  // Automatically calculates BMI on the fly!
  double get bmi {
    if (heightCm <= 0 || weightKg <= 0) return 0.0;
    final heightMeters = heightCm / 100;
    return weightKg / (heightMeters * heightMeters);
  }

  UserProfile copyWith({
    bool? hasOnboarded,
    String? gender,
    String? goal,
    String? experienceLevel,
    double? heightCm,
    double? weightKg,
  }) {
    return UserProfile(
      hasOnboarded: hasOnboarded ?? this.hasOnboarded,
      gender: gender ?? this.gender,
      goal: goal ?? this.goal,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      appLanguage: appLanguage,
    );
  }
}

// 3. The State Notifier to manage saving/loading
class UserProfileNotifier extends StateNotifier<UserProfile> {
  final SharedPreferences prefs;

  UserProfileNotifier(this.prefs) : super(_loadFromPrefs(prefs));

  // Loads saved data, or defaults to a fresh profile
  static UserProfile _loadFromPrefs(SharedPreferences prefs) {
    return UserProfile(
      hasOnboarded: prefs.getBool('hasOnboarded') ?? false,
      gender: prefs.getString('gender') ?? '',
      goal: prefs.getString('goal') ?? '',
      experienceLevel: prefs.getString('experienceLevel') ?? '',
      heightCm: prefs.getDouble('heightCm') ?? 0.0,
      weightKg: prefs.getDouble('weightKg') ?? 0.0,
      appLanguage: prefs.getString('appLanguage') ?? 'English',
    );
  }

  // Save full profile and mark onboarding as complete
  Future<void> saveProfile(UserProfile newProfile) async {
    await prefs.setBool('hasOnboarded', true);
    await prefs.setString('gender', newProfile.gender);
    await prefs.setString('goal', newProfile.goal);
    await prefs.setString('experienceLevel', newProfile.experienceLevel);
    await prefs.setDouble('heightCm', newProfile.heightCm);
    await prefs.setDouble('weightKg', newProfile.weightKg);
    await prefs.setString('appLanguage', newProfile.appLanguage);

    // Update the state so the UI reacts instantly
    state = newProfile.copyWith(hasOnboarded: true);
  }

  // Just updates a specific field (for the Settings screen later)
  Future<void> updateField(String key, dynamic value) async {
    if (value is String) await prefs.setString(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is bool) await prefs.setBool(key, value);
    state = _loadFromPrefs(prefs); // Reload state
  }
}

// 4. The main provider you will watch in your UI
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return UserProfileNotifier(prefs);
    });
