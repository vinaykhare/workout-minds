// lib/core/utils/ai_guard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/presentation/settings_screen.dart';

class AIGuard {
  /// Runs a pre-flight check before allowing any AI features to execute.
  /// 1. Checks if the user is signed in. If not, prompts them.
  /// 2. Checks if the user has credits. If not, offers to route to store.
  /// Returns `true` if the AI action is safe to proceed.
  static Future<bool> check(BuildContext context, WidgetRef ref) async {
    final authState = ref.read(authStateProvider);
    final user = authState.value;

    // 1. REQUIRE SIGN-IN
    if (user == null) {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sign In Required'),
          content: const Text(
            'You need to sign in with your Google account to use AI features and access cloud backups.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign In'),
            ),
          ],
        ),
      );

      if (result == true && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );
        final success = await ref.read(driveSyncProvider).signIn();

        if (context.mounted) {
          Navigator.pop(context); // close loader
          if (!success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sign in failed. Please try again.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          } else {
            // Wait briefly for the Auth stream to populate Firestore
            await Future.delayed(const Duration(milliseconds: 600));
            if (context.mounted) {
              // Recursively check again now that they are signed in to verify credits!
              return await check(context, ref);
            }
          }
        }
      }
      return false; // Stop execution
    }

    // 2. REQUIRE CREDITS (If not a Power User)
    final profile = ref.read(userProfileProvider);
    if (!profile.isPro) {
      final credits = await ref.read(firestoreCreditsProvider.future);

      if (credits <= 0) {
        if (!context.mounted) return false;
        final buyResult = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.star_outline, color: Colors.orange),
                SizedBox(width: 8),
                Text('Out of AI Credits'),
              ],
            ),
            content: const Text(
              'You have used all your AI credits. Would you like to get more to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Get Credits'),
              ),
            ],
          ),
        );

        if (buyResult == true && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        }
        return false; // Stop execution
      }
    }

    return true; // All checks passed!
  }
}
