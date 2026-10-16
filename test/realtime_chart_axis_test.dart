import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/widgets/realtime_chart.dart';

void main() {
  test('fits data to a padded range on round grid steps', () {
    final range = ChartAxisRange.fit(11.8, 12.6);
    expect(range.min, lessThan(11.8));
    expect(range.max, greaterThan(12.6));
    expect(
      range.min / range.step,
      closeTo((range.min / range.step).round(), 1e-9),
    );
    expect(
      range.max / range.step,
      closeTo((range.max / range.step).round(), 1e-9),
    );
  });

  test('keeps the axis steady while noisy samples scroll through it', () {
    var range = ChartAxisRange.resolve(11.9, 12.5, null);
    final initial = range;
    // Successive windows of a noisy 12 V signal with slightly different
    // extremes must not rescale the plot.
    for (final (lo, hi) in [(11.95, 12.45), (11.9, 12.4), (12.0, 12.5)]) {
      range = ChartAxisRange.resolve(lo, hi, range);
      expect(identical(range, initial), isTrue);
    }
  });

  test('grows at once when data leaves the range', () {
    final range = ChartAxisRange.resolve(0, 1, null);
    final grown = ChartAxisRange.resolve(0, range.max * 3, range);
    expect(grown.max, greaterThanOrEqualTo(range.max * 3));
  });

  test('shrinks once the data uses a small part of the range', () {
    final wide = ChartAxisRange.resolve(-600, 600, null);
    final narrow = ChartAxisRange.resolve(0.9, 1.1, wide);
    expect(narrow.span, lessThan(wide.span * ChartAxisRange.shrinkThreshold));
    expect(narrow.min, lessThan(0.9));
    expect(narrow.max, greaterThan(1.1));
  });

  test('labels ticks with enough decimals to tell them apart', () {
    const range = ChartAxisRange(0, 0.002, 0.0005);
    expect(range.format(0.0015), '0.0015');
    expect(range.format(-1e-12), '0.0000');
    expect(const ChartAxisRange(0, 50, 10).format(30), '30');
  });

  test('thins long histories to a min/max envelope', () {
    final points = [
      for (var i = 0; i < 10000; i++) LinePoint(i / 10, i == 5000 ? 99 : 1),
    ];
    final thinned = decimateEnvelope(points, buckets: 100);
    expect(thinned.length, lessThanOrEqualTo(200));
    // The single spike survives thinning.
    expect(thinned.map((p) => p.y), contains(99));
    for (var i = 1; i < thinned.length; i++) {
      expect(thinned[i].x, greaterThanOrEqualTo(thinned[i - 1].x));
    }
  });

  test('keeps overload gaps when thinning', () {
    final points = [
      for (var i = 0; i < 1000; i++)
        LinePoint(i.toDouble(), i < 500 ? 1 : double.nan),
    ];
    final thinned = decimateEnvelope(points, buckets: 10);
    expect(thinned.where((p) => p.y.isNaN), isNotEmpty);
  });
}
