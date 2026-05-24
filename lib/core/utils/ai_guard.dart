// lib/core/utils/ai_guard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/presentation/settings_screen.dart';

class AIGuard {
  /// Runs a pre-flight check before allowing any AI features to execute.
  /// Checks if the user has provided their own Gemini API key.
  static Future<bool> check(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(userProfileProvider);

    // REQUIRE BYOK (Bring Your Own Key)
    if (profile.customApiKey.trim().isEmpty) {
      if (!context.mounted) return false;

      final configureKey = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.key, color: Colors.deepPurpleAccent),
              SizedBox(width: 8),
              Text('Gemini Key Required'),
            ],
          ),
          content: const Text(
            'Workout Minds is completely free and runs local-first!\n\nTo build and optimize routines, please provide your personal free Google Gemini API key in the settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Set Up Key'),
            ),
          ],
        ),
      );

      if (configureKey == true && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SettingsScreen(scrollToBYOK: true),
          ),
        );
      }
      return false; // Stop execution until they provide a key
    }

    return true; // Key present, proceed!
  }
}
