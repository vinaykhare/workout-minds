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
  final String appLocale; // NEW: 'en' or 'hi'
  final String themeMode;
  final String gender;
  final String goal;
  final String preferredStyle;
  final int pushupCapacity;
  final int pullupCapacity; // Optional, but great for back strength
  final int squatCapacity;
  final double heightCm;
  final double weightKg;
  final int aiCredits;
  final bool isPro;
  final String customApiKey;
  final String customModelName;
  final bool isAutoSyncEnabled;

  UserProfile({
    required this.hasOnboarded,
    required this.appLocale,
    required this.themeMode,
    required this.gender,
    required this.goal,
    required this.preferredStyle,
    required this.pushupCapacity,
    required this.pullupCapacity,
    required this.squatCapacity,
    required this.heightCm,
    required this.weightKg,
    required this.aiCredits,
    required this.isPro,
    required this.customApiKey,
    required this.customModelName,
    required this.isAutoSyncEnabled,
  });

  // Automatically calculates BMI on the fly!
  double get bmi {
    if (heightCm <= 0 || weightKg <= 0) return 0.0;
    final heightMeters = heightCm / 100;
    return weightKg / (heightMeters * heightMeters);
  }

  UserProfile copyWith({
    bool? hasOnboarded,
    String? appLocale,
    String? themeMode,
    String? gender,
    String? goal,
    String? preferredStyle,
    int? pushupCapacity,
    int? pullupCapacity,
    int? squatCapacity,
    double? heightCm,
    double? weightKg,
    int? aiCredits,
    bool? isPro,
    String? customApiKey,
    String? customModelName,
    bool? isAutoSyncEnabled,
  }) {
    return UserProfile(
      hasOnboarded: hasOnboarded ?? this.hasOnboarded,
      appLocale: appLocale ?? this.appLocale,
      themeMode: themeMode ?? this.themeMode,
      gender: gender ?? this.gender,
      goal: goal ?? this.goal,
      preferredStyle: preferredStyle ?? this.preferredStyle,
      pushupCapacity: pushupCapacity ?? this.pushupCapacity,
      pullupCapacity: pullupCapacity ?? this.pullupCapacity,
      squatCapacity: squatCapacity ?? this.squatCapacity,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      aiCredits: aiCredits ?? this.aiCredits,
      isPro: isPro ?? this.isPro,
      customApiKey: this.customApiKey,
      customModelName: customModelName ?? this.customModelName,
      isAutoSyncEnabled: isAutoSyncEnabled ?? this.isAutoSyncEnabled,
    );
  }

  // 1. Convert the object to a JSON Map
  Map<String, dynamic> toJson() {
    return {
      'appLocale': appLocale,
      'themeMode': themeMode,
      'gender': gender,
      'goal': goal,
      'preferredStyle': preferredStyle,
      'pushupCapacity': pushupCapacity,
      'pullupCapacity': pullupCapacity,
      'squatCapacity': squatCapacity,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'aiCredits': aiCredits,
      'isPro': isPro,
      'customApiKey': customApiKey,
      'customModelName': customModelName,
      'isAutoSyncEnabled': isAutoSyncEnabled,
    };
  }

  // 2. Rebuild the object from a JSON Map
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      hasOnboarded: true, // If restoring, they bypass onboarding!
      appLocale: json['appLocale'] as String? ?? 'en',
      themeMode: json['themeMode'] as String? ?? 'system',
      gender: json['gender'] as String? ?? '',
      goal: json['goal'] as String? ?? '',
      preferredStyle: json['preferredStyle'] as String? ?? 'Full Gym',
      pushupCapacity: json['pushupCapacity'] as int? ?? 0,
      pullupCapacity: json['pullupCapacity'] as int? ?? 0,
      squatCapacity: json['squatCapacity'] as int? ?? 0,
      heightCm: (json['heightCm'] as num?)?.toDouble() ?? 0.0,
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0.0,
      aiCredits: json['aiCredits'] as int? ?? 3,
      isPro: json['isPro'] as bool? ?? false,
      customApiKey: json['customApiKey'] as String? ?? '',
      customModelName: json['customModelName'] as String? ?? '',
      isAutoSyncEnabled: json['isAutoSyncEnabled'] as bool? ?? false,
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
      appLocale: prefs.getString('appLocale') ?? 'en', // Default to English
      themeMode: prefs.getString('themeMode') ?? 'system',
      gender: prefs.getString('gender') ?? '',
      goal: prefs.getString('goal') ?? '',
      preferredStyle: prefs.getString('preferredStyle') ?? 'Full Gym',
      pushupCapacity: prefs.getInt('pushupCapacity') ?? 0,
      pullupCapacity: prefs.getInt('pullupCapacity') ?? 0,
      squatCapacity: prefs.getInt('squatCapacity') ?? 0,
      heightCm: prefs.getDouble('heightCm') ?? 0.0,
      weightKg: prefs.getDouble('weightKg') ?? 0.0,
      aiCredits: prefs.getInt('aiCredits') ?? 3,
      isPro: prefs.getBool('isPro') ?? false,
      customApiKey: prefs.getString('customApiKey') ?? '',
      customModelName: prefs.getString('customModelName') ?? '',
      isAutoSyncEnabled: prefs.getBool('isAutoSyncEnabled') ?? false,
    );
  }

  // Save full profile and mark onboarding as complete
  Future<void> saveProfile(UserProfile newProfile) async {
    await prefs.setBool('hasOnboarded', true);
    await prefs.setString('appLocale', newProfile.appLocale);
    await prefs.setString('themeMode', newProfile.themeMode);
    await prefs.setString('gender', newProfile.gender);
    await prefs.setString('goal', newProfile.goal);
    await prefs.setString('preferredStyle', newProfile.preferredStyle);
    await prefs.setInt('pushupCapacity', newProfile.pushupCapacity);
    await prefs.setInt('pullupCapacity', newProfile.pullupCapacity);
    await prefs.setInt('squatCapacity', newProfile.squatCapacity);
    await prefs.setDouble('heightCm', newProfile.heightCm);
    await prefs.setDouble('weightKg', newProfile.weightKg);
    await prefs.setInt('aiCredits', newProfile.aiCredits);
    await prefs.setBool('isPro', newProfile.isPro);
    await prefs.setString('customApiKey', newProfile.customApiKey);
    await prefs.setString('customModelName', newProfile.customModelName);
    await prefs.setBool('isAutoSyncEnabled', newProfile.isAutoSyncEnabled);
    // Update the state so the UI reacts instantly
    state = newProfile.copyWith(hasOnboarded: true);
  }

  // A dedicated method to burn a credit
  Future<void> useAiCredit() async {
    if (state.isPro) return; // Pro users have "unlimited" usage
    final currentCredits = state.aiCredits;
    if (currentCredits > 0) {
      final newTotal = currentCredits - 1;
      await prefs.setInt('aiCredits', newTotal);
      state = state.copyWith(aiCredits: newTotal);
    }
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
