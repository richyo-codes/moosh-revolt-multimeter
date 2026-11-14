import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moosh_revolt/models/math_channel.dart';
import 'package:moosh_revolt/models/meter_reading.dart';
import 'package:moosh_revolt/widgets/meter_jacks.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Channel modes and math function a recipe sets up on the meter.
typedef GuideSetup = ({ChannelMode? ch1, ChannelMode? ch2, MathFunction? math});

const _ch1Color = Colors.red;
const _ch2Color = Colors.blue;
const _auxColor = Colors.purple;

const cheatSheetUrl =
    'https://cdn.sparkfun.com/datasheets/Tools/MooshimeterCheatSheet-V0.pdf';
const manualUrl =
    'https://cdn.sparkfun.com/datasheets/Tools/MooshimeterManualRev1.pdf';

/// How to connect the Mooshimeter: its four jacks and what each measures,
/// step-by-step recipes for common measurements, and safety notes.
///
/// Ranges are read from the connected meter when there is one. With
/// [onSetUp], each recipe can configure the meter for that measurement.
class MeterGuideScreen extends StatelessWidget {
  const MeterGuideScreen({super.key, this.onSetUp});

  final Future<void> Function(GuideSetup setup)? onSetUp;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BleProvider?>();
    return Scaffold(
      appBar: AppBar(title: const Text('Meter guide')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _JackOverview(provider: provider),
                  const SizedBox(height: 28),
                  _heading(context, 'Quick recipes'),
                  const SizedBox(height: 4),
                  Text(
                    'The red probe goes into the jack of what you measure; '
                    'the black probe always goes into C.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final recipe in _recipes)
                        _RecipeCard(
                          recipe: recipe,
                          onSetUp: onSetUp == null || recipe.setup == null
                              ? null
                              : () async {
                                  await onSetUp!(recipe.setup!);
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _heading(context, 'Safety'),
                  const SizedBox(height: 8),
                  ..._safety.map((note) => _Bullet(note)),
                  const SizedBox(height: 28),
                  _heading(context, 'Official documents'),
                  const SizedBox(height: 4),
                  Text(
                    'Published by Mooshim Engineering for the Mooshimeter '
                    'V.1. They describe early firmware, so some ranges differ '
                    'from what your meter reports above.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  const _LinkTile(
                    title: 'Mooshimeter cheat sheet',
                    url: cheatSheetUrl,
                  ),
                  const _LinkTile(
                    title: 'Mooshimeter user manual',
                    url: manualUrl,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _heading(BuildContext context, String text) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge);
}

class _JackOverview extends StatelessWidget {
  const _JackOverview({required this.provider});

  final BleProvider? provider;

  /// "60 V, 600 V" from the meter, or typical V.1 values when unknown.
  String _ranges(int channel, ChannelMode mode, List<double> typical) {
    final values = provider?.rangesFor(channel, mode.input) ?? typical;
    return values.map((v) => _label(mode.toDisplay(v), mode.units)).join(', ');
  }

  static String _label(double value, String units) {
    final scale = SiScale.forValue(value);
    final scaled = value * scale.multiplier;
    final text = scaled == scaled.roundToDouble()
        ? scaled.round().toString()
        : scaled.toString();
    return '$text ${scale.prefix}$units';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final live = provider?.rangesFor(1, ChannelMode.voltage.input) != null;
    final jacks = [
      (
        jack: 'V',
        color: _ch2Color,
        title: 'Voltage · always CH2',
        body:
            'DC and AC voltage. Ranges ${_ranges(1, ChannelMode.voltage, const [60, 600])}.',
      ),
      (
        jack: 'A',
        color: _ch1Color,
        title: 'Current · always CH1',
        body:
            'DC and AC current through a fused shunt to C. Range '
            '${_ranges(0, ChannelMode.current, const [10])}.',
      ),
      (
        jack: 'Ω',
        color: _auxColor,
        title: 'Aux input · CH1 or CH2, one at a time',
        body:
            'Low voltage (${_ranges(0, ChannelMode.auxiliaryVoltageDc, const [0.1, 0.3, 1.2])}), '
            'resistance (${_ranges(0, ChannelMode.resistance, const [1e3, 1e4, 1e5, 1e6, 1e7])}) '
            'and diode drop (${_ranges(0, ChannelMode.diode, const [1.2])}). '
            'Not the V jack.',
      ),
      (
        jack: 'C',
        color: theme.colorScheme.onSurface,
        title: 'Common · the black probe',
        body: 'Every measurement is taken against C.',
      ),
    ];

    final diagram = MeterJacks(
      key: const ValueKey('guide-jacks'),
      size: 190,
      fills: {for (final j in jacks) j.jack: j.color},
    );
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('The four jacks', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'As laid out on the case. '
          '${live ? 'Ranges are read from your meter.' : 'Typical Mooshimeter V.1 ranges; connect a meter to read its own.'}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final j in jacks)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: j.color,
                  child: Text(
                    j.jack,
                    style: TextStyle(
                      color: theme.colorScheme.surface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        j.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: j.jack == 'C' ? null : j.color,
                        ),
                      ),
                      Text(j.body, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 560
          ? Column(
              children: [
                const SizedBox(height: 8),
                diagram,
                const SizedBox(height: 16),
                legend,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 24, 32, 0),
                  child: diagram,
                ),
                Expanded(child: legend),
              ],
            ),
    );
  }
}

class _Recipe {
  const _Recipe({
    required this.title,
    required this.jacks,
    required this.steps,
    this.warning,
    this.setup,
  });

  final String title;

  /// The jacks the probes go into, with the channel colour each reads on.
  final Map<String, Color> jacks;
  final List<String> steps;
  final String? warning;
  final GuideSetup? setup;
}

const _recipes = [
  _Recipe(
    title: 'Battery or DC voltage',
    jacks: {'V': _ch2Color},
    steps: [
      'Red probe into V, black probe into C.',
      'Touch red to + and black to −.',
      'Read CH2 (Voltage DC). A negative value means the probes are '
          'reversed.',
    ],
    setup: (ch1: null, ch2: ChannelMode.voltage, math: null),
  ),
  _Recipe(
    title: 'AC or mains voltage',
    jacks: {'V': _ch2Color},
    steps: [
      'Red probe into V, black probe into C.',
      'Read CH2 (Voltage AC). This is the RMS value; the sample rate '
          'switches to 4 kHz on its own.',
    ],
    warning:
        'Stay within the 600 V rating printed on the case, and keep your '
        'fingers behind the probe guards.',
    setup: (ch1: null, ch2: ChannelMode.voltageAc, math: null),
  ),
  _Recipe(
    title: 'Current',
    jacks: {'A': _ch1Color},
    steps: [
      'Switch the circuit off and open it where you want to measure.',
      'Red probe into A, black probe into C, and connect the meter in '
          'series so the current flows through it.',
      'Switch on and read CH1 (Current DC or AC). Up to 10 A.',
    ],
    warning:
        'Never connect A and C across a voltage source: the A input is a '
        'near short circuit.',
    setup: (ch1: ChannelMode.current, ch2: null, math: null),
  ),
  _Recipe(
    title: 'Resistance and continuity',
    jacks: {'Ω': _ch1Color},
    steps: [
      'Switch the circuit off and discharge any capacitors.',
      'Red probe into Ω, black probe into C.',
      'Read CH1 (Resistance). For a beep below 50 Ω, turn on the '
          'continuity tone in CH1\'s settings.',
    ],
    setup: (ch1: ChannelMode.resistance, ch2: null, math: null),
  ),
  _Recipe(
    title: 'Diode',
    jacks: {'Ω': _ch1Color},
    steps: [
      'Switch the circuit off.',
      'Red probe into Ω on the anode, black probe into C on the cathode '
          '(the banded end).',
      'Read CH1 (Diode drop): about 0.6–0.7 V for silicon, OL in reverse.',
    ],
    setup: (ch1: ChannelMode.diode, ch2: null, math: null),
  ),
  _Recipe(
    title: 'Power',
    jacks: {'A': _ch1Color, 'V': _ch2Color},
    steps: [
      'Run the load current through A and C (in series), and measure the '
          'load voltage between V and C.',
      'Both share C, so C must sit where the current path and the voltage '
          'measurement meet.',
      'Read the Math card: real power, or switch it to apparent power or '
          'power factor.',
    ],
    setup: (
      ch1: ChannelMode.current,
      ch2: ChannelMode.voltage,
      math: MathFunction.realPower,
    ),
  ),
  _Recipe(
    title: 'Type-K thermocouple',
    jacks: {'Ω': _ch1Color},
    steps: [
      'Plug the thermocouple into Ω (+) and C (−).',
      'Read the Math card. The meter\'s own temperature is the cold '
          'junction, so keep the connection close to the meter.',
    ],
    setup: (
      ch1: ChannelMode.auxiliaryVoltageDc,
      ch2: ChannelMode.internalTemperature,
      math: MathFunction.thermocoupleK,
    ),
  ),
];

const _safety = [
  'Stay within 600 V and 10 A, and within the category rating printed on '
      'the case.',
  'Measure resistance, continuity and diodes only on circuits that are '
      'switched off. A voltage on the probes makes the reading invalid; '
      'MooshRevolt shows it as OL.',
  'The A jack is a low-resistance shunt. Never connect A and C across a '
      'voltage.',
  'The A input is fused. Replace a blown fuse only with the same type and '
      'rating.',
  'MooshRevolt is community software. Check readings against a known '
      'source before relying on them for safety-critical work.',
];

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, this.onSetUp});

  final _Recipe recipe;
  final VoidCallback? onSetUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      width: 418,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MeterJacks(
                    size: 58,
                    fills: {...recipe.jacks, 'C': colors.onSurface},
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      recipe.title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < recipe.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '${i + 1}.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(child: Text(recipe.steps[i])),
                    ],
                  ),
                ),
              if (recipe.warning case final warning?)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 18,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(warning, style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
              if (onSetUp != null) ...[
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  key: ValueKey('guide-set-up-${recipe.title}'),
                  onPressed: onSetUp,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Set up the meter'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.picture_as_pdf_outlined),
      title: Text(title),
      subtitle: Text(url, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.copy, size: 18),
        tooltip: 'Copy link',
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: url));
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Link copied')));
          }
        },
      ),
      onTap: () => launchUrl(Uri.parse(url)),
    );
  }
}
