import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Plays the steady audible indication used by continuity mode.
///
/// Linux uses PulseAudio's `paplay` with a generated WAV file. Android owns
/// the playback natively so it can keep a low-latency loop alive without a
/// notification sound or a Dart-side timer.
class ContinuityTone {
  static const _androidChannel = MethodChannel(
    'ca.richyoung.mooshrevolt/continuity_tone',
  );

  Process? _linuxPlayer;
  bool _androidPlaying = false;

  Future<void> start({required Future<String> Function() linuxToneFile}) async {
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

    if (!Platform.isLinux || _linuxPlayer != null) return;
    try {
      final toneFile = await linuxToneFile();
      final player = await Process.start('paplay', [toneFile]);
      _linuxPlayer = player;
      unawaited(
        player.exitCode.whenComplete(() {
          if (identical(_linuxPlayer, player)) _linuxPlayer = null;
        }),
      );
    } catch (_) {
      // `paplay` may not be installed. Measurements are still usable.
    }
  }

  void stop() {
    if (Platform.isAndroid) {
      _androidPlaying = false;
      unawaited(_androidChannel.invokeMethod<void>('stop').catchError((_) {}));
    }
    final player = _linuxPlayer;
    _linuxPlayer = null;
    player?.kill();
  }
}
