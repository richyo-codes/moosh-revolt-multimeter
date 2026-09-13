import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'app_localizations.dart';
import 'app_localizations_en.dart';
import '../models/meter_reading.dart';

/// English fallback also supports standalone widget previews.
extension LocalizedContext on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? AppLocalizationsEn();

  String formatReading(double value, int decimals) => NumberFormat(
    decimals == 0 ? '0' : '0.${'0' * decimals}',
    l10n.localeName,
  ).format(value);
}

extension LocalizedChannelMode on ChannelMode {
  String localizedLabel(BuildContext context) => switch (this) {
    ChannelMode.auto => context.l10n.auto,
    ChannelMode.voltage => context.l10n.voltageDc,
    ChannelMode.voltageAc => context.l10n.voltageAc,
    ChannelMode.current => context.l10n.currentDc,
    ChannelMode.currentAc => context.l10n.currentAc,
    ChannelMode.internalTemperature => context.l10n.internalTemperature,
    ChannelMode.resistance => context.l10n.resistance,
    ChannelMode.diode => context.l10n.diode,
    ChannelMode.frequency => context.l10n.frequency,
    ChannelMode.period => context.l10n.period,
    ChannelMode.auxiliaryVoltageDc => context.l10n.auxDc,
    ChannelMode.auxiliaryVoltageAc => context.l10n.auxAc,
    ChannelMode.temperatureC => '°C',
    ChannelMode.temperatureF => '°F',
  };
}
