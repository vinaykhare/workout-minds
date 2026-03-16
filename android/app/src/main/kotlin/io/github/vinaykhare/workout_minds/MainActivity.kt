package io.github.vinaykhare.workout_minds

// 1. Remove the old io.flutter.embedding.android.FlutterActivity import
// 2. Add the audio_service import:
import com.ryanheise.audioservice.AudioServiceActivity

// 3. Change FlutterActivity to AudioServiceActivity
class MainActivity : AudioServiceActivity()
