import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/services/continuity_tone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stopping a tone is safe before playback starts', () {
    expect(() => ContinuityTone().stop(), returnsNormally);
  });
}
