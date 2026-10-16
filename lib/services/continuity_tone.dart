import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Plays the steady audible indication used by continuity mode.
///
/// Linux uses PulseAudio's `paplay` and macOS uses the built-in `afplay`, both
/// with a generated WAV file. Android owns the playback natively so it can
/// keep a low-latency loop alive without a notification sound or a Dart-side
/// timer.
class ContinuityTone {
  static const _androidChannel = MethodChannel(
    'ca.richyoung.mooshrevolt/continuity_tone',
  );

  Process? _desktopPlayer;
  bool _androidPlaying = false;

  Future<void> start({required Future<String> Function() toneFile}) async {
    if (Platform.isAndroid) {
      if (_androidPlaying) return;
      try {
        await _androidChannel.invokeMethod<void>('start');
        _androidPlaying = true;
      } on PlatformException catch (_) {
        // Audio output is non-essential; continuity measurements continue.
      } on MissingPluginException catch (_) {
        // Enables widget tests and unsupported Android embeddings.
      }
      return;
    }

    final playerCommand = _desktopPlayerCommand();
    if (playerCommand == null || _desktopPlayer != null) return;
    try {
      final path = await toneFile();
      final player = await Process.start(playerCommand, [path]);
      _desktopPlayer = player;
      unawaited(
        player.exitCode.whenComplete(() {
          if (identical(_desktopPlayer, player)) _desktopPlayer = null;
        }),
      );
    } catch (_) {
      // The player may not be installed. Measurements are still usable.
    }
  }

  void stop() {
    if (Platform.isAndroid) {
      _androidPlaying = false;
      unawaited(_androidChannel.invokeMethod<void>('stop').catchError((_) {}));
    }
    final player = _desktopPlayer;
    _desktopPlayer = null;
    player?.kill();
  }

  static String? _desktopPlayerCommand() {
    if (Platform.isLinux) return 'paplay';
    if (Platform.isMacOS) return '/usr/bin/afplay';
    return null;
  }
}
