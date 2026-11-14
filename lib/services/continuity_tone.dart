import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Plays the steady audible indication used by continuity mode.
///
/// Android and macOS play the tone natively and keep the audio path warm
/// between [prepare] and [release], so [start] is heard immediately and stays
/// in step with the reading that triggered it. Linux falls back to
/// PulseAudio's `paplay` with a generated WAV file.
class ContinuityTone {
  static const _channel = MethodChannel(
    'ca.richyoung.mooshrevolt/continuity_tone',
  );

  static bool get _native => Platform.isAndroid || Platform.isMacOS;

  Process? _linuxPlayer;
  bool _nativePlaying = false;

  /// Arms the audio output so a later [start] has no start-up delay.
  Future<void> prepare({required Future<String> Function() toneFile}) async {
    if (_native) {
      await _invoke('prepare');
    } else if (Platform.isLinux) {
      try {
        await toneFile();
      } catch (_) {
        // Generated on demand again by start().
      }
    }
  }

  Future<void> start({required Future<String> Function() toneFile}) async {
    if (_native) {
      if (_nativePlaying) return;
      _nativePlaying = true;
      await _invoke('start');
      return;
    }

    if (!Platform.isLinux || _linuxPlayer != null) return;
    try {
      final path = await toneFile();
      final player = await Process.start('paplay', [path]);
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
    if (_native) {
      if (!_nativePlaying) return;
      _nativePlaying = false;
      unawaited(_invoke('stop'));
    }
    final player = _linuxPlayer;
    _linuxPlayer = null;
    player?.kill();
  }

  /// Stops the tone and releases the audio output armed by [prepare].
  void release() {
    stop();
    if (_native) unawaited(_invoke('release'));
  }

  static Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (_) {
      // Audio output is non-essential; continuity measurements continue.
    } on MissingPluginException catch (_) {
      // Enables widget tests and unsupported embeddings.
    }
  }
}
