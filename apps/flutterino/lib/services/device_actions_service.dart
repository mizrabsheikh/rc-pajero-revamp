// ============================================================
//  Device Actions Service
//  Handles actions that occur on the device (Android/iOS)
//  rather than on the Arduino. Examples: playing sounds,
//  showing notifications, haptic feedback, etc.
// ============================================================

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Service for handling device-side actions triggered by Arduino commands
class DeviceActionsService {
  // Audio player for playing sound effects
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Track the last state of the horn to avoid replaying on every command
  bool _hornWasPressed = false;

  /// Initialize the service
  Future<void> init() async {
    debugPrint('[DeviceActions] Initializing Device Actions Service...');

    // Pre-load the horn sound for faster playback
    await _audioPlayer.setSource(AssetSource('horn.mp3'));
    // Use loop mode so the sound repeats while button is held
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);

    debugPrint('[DeviceActions] Device Actions Service initialized');
  }

  /// Handle horn action - plays horn sound when horn button is pressed
  /// Loops continuously while pressed, stops immediately when released
  Future<void> handleHorn(bool isPressed) async {
    if (isPressed && !_hornWasPressed) {
      // Horn button was just pressed - start looping playback
      await _startHornSound();
    } else if (!isPressed && _hornWasPressed) {
      // Horn button was just released - stop playback immediately
      debugPrint('[DeviceActions] Horn released - stopping playback');
      await _stopHornSound();
    }
    _hornWasPressed = isPressed;
  }

  /// Start playing the horn sound in loop mode
  Future<void> _startHornSound() async {
    try {
      // Play the horn sound from assets (will loop due to ReleaseMode.loop)
      await _audioPlayer.play(AssetSource('horn.mp3'));
    } catch (e) {
      debugPrint('[DeviceActions] Error playing horn sound: $e');
    }
  }

  /// Stop the horn sound immediately
  Future<void> _stopHornSound() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('[DeviceActions] Error stopping horn sound: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    debugPrint('[DeviceActions] Disposing Device Actions Service');
    _audioPlayer.dispose();
  }
}
