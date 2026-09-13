# Translations

MooshRevolt supports English and French. It follows the device language by
default, with English fallback for unsupported languages. Settings → Language
can override this choice; the preference is saved locally.

Edit messages in lib/l10n/app_en.arb and their translations in app_fr.arb.
Use named placeholders for dynamic values and ICU plural messages for counts.
Channel labels are translated in the UI, not in the BLE protocol package.
Measurements use localized decimal separators; SI symbols, CSV output,
protocol keys, and CLI commands remain machine-readable.

Run flutter gen-l10n after editing ARB files (Flutter builds also generate the
classes). Generated app_localizations*.dart files should not be edited by hand.
Run flutter analyze and flutter test to check messages and localized layouts.

To add a language, create app_<language>.arb with the same keys, translate its
messages, add the language to the Settings selector and preference validation,
then regenerate. Add layout tests for long translations and any different text
direction. French translations should be reviewed by native speakers.
