# Measurements

This guide explains what each channel can measure and how MooshRevolt sets up
the meter. To configure a channel, tap its range chip or the tune icon on its
reading card.

## Inputs and modes

The Mooshimeter has two channels. Each channel has a dedicated input and can
also use one shared auxiliary input.

| Mode | CH1 | CH2 | Unit | Ranges |
| --- | --- | --- | --- | --- |
| Current DC / AC | ✓ (A jack) | | A | 10 A |
| Voltage DC / AC | | ✓ (V jack) | V | 60 V, 600 V |
| Internal Temperature | ✓ | ✓ | °C | — |
| Auxiliary Voltage DC / AC | ✓ | ✓ | V | 100 mV, 300 mV, 1.2 V |
| Resistance | ✓ | ✓ | Ω | 1 kΩ, 10 kΩ, 100 kΩ, 1 MΩ, 10 MΩ |
| Diode Drop | ✓ | ✓ | V | 1.2 V |

Auxiliary voltage, resistance and diode drop use the shared input, so only one
channel can use them at a time. The configuration sheet disables these modes
on one channel while the other channel uses the shared input.

MooshRevolt reads the available options and ranges from the meter's
configuration tree when it connects. It then selects each option by name, so
every mode configures the hardware that it names.

## Ranges and auto-ranging

Each card shows the active range, for example **Auto · 60 V**. Auto-ranging
works like a bench meter:

1. It starts on the highest range.
2. When a reading goes above 110% of the range, it moves up one range.
3. When a reading uses less than 90% of a smaller range, it moves straight
   down to that range.

Select a fixed range in the configuration sheet to stop auto-ranging, for
example before you log to the SD card.

## Overload

When a reading is above 120% of the active range, the input is saturated and
the value is not a measurement. The display then shows **OL**. The chart
leaves a gap, and CSV exports write `OL`.

A resistance far below zero also shows **OL**. This occurs when an external
voltage drives the probes. Do not measure resistance on a powered circuit.

## Digits and units

The decimal point and the prefix are set by the range, so the digits do not
move while the value changes. The number of digits follows the resolution of
the analog-to-digital converter (ADC) at the current sample rate. At 125 Hz
the meter resolves about 6 digits. At 8 kHz it resolves about 4.

The units menu on each card selects a fixed prefix, for example mA or kΩ.
**Auto** follows the range.

Internal temperature is reported by the meter in kelvin. MooshRevolt shows it
in degrees Celsius.

## Sample rate

**Auto** is the default. It uses these settings:

- 125 Hz with 64-sample averaging for DC measurements, for the most digits.
- 4 kHz with 256-sample averaging when a channel measures AC (RMS), so each
  reading covers several complete mains cycles.

You can select a fixed rate from the menu or in Meter settings.

## Zero (relative reading)

**Zero** stores the present reading as an offset, and the meter subtracts it
from later readings. In resistance mode, short the probes and zero to remove
the lead resistance. Select **Clear** to remove the offset. The offset is
stored in the meter.

## Continuity

In resistance mode, the configuration sheet has two options:

- **Continuity tone** plays a continuous tone while the resistance is below
  50 Ω. Shorted probes often read slightly below zero, for example −1 Ω,
  because of the zero offset, so the test uses the magnitude of the
  resistance. While the tone is on, the 1 kΩ range is held, so the tone does
  not wait for auto-ranging.
- **Continuity graph** plots the channel as open or continuous instead of
  ohms.

## Diode drop

Diode drop measures the forward voltage of a diode. The meter sends a small,
constant test current through the part and shows the voltage across it.

| Part | Typical forward voltage |
| --- | --- |
| Silicon diode | 0.6–0.7 V |
| Schottky diode | 0.2–0.4 V |
| LED | 1.8–3 V (may light faintly) |

In diode mode, the configuration has a **Short tone** that beeps below
0.1 V, which means the diode is shorted.

A diode conducts in one direction only. If the reading shows **OL**, reverse
the probes. A good diode shows a forward voltage in one direction and **OL**
in the other. An open diode shows **OL** in both directions, because the
open-circuit voltage is more than the 1.2 V range. A shorted diode reads near
0 V in both directions.
