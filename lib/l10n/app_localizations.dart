import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// No description provided for @autoConnect.
  ///
  /// In en, this message translates to:
  /// **'Auto-connect on launch'**
  String get autoConnect;

  /// No description provided for @autoConnectHelp.
  ///
  /// In en, this message translates to:
  /// **'Automatically reconnect to last remembered device'**
  String get autoConnectHelp;

  /// No description provided for @skipFirmware.
  ///
  /// In en, this message translates to:
  /// **'Skip firmware check'**
  String get skipFirmware;

  /// No description provided for @skipFirmwareHelp.
  ///
  /// In en, this message translates to:
  /// **'Skip OAD firmware update prompt'**
  String get skipFirmwareHelp;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @darkModeHelp.
  ///
  /// In en, this message translates to:
  /// **'Use a dark color scheme throughout the app'**
  String get darkModeHelp;

  /// No description provided for @showFloating.
  ///
  /// In en, this message translates to:
  /// **'Show values for floating probes'**
  String get showFloating;

  /// No description provided for @showFloatingHelp.
  ///
  /// In en, this message translates to:
  /// **'Keep displaying near-zero readings when a probe may be unconnected'**
  String get showFloatingHelp;

  /// No description provided for @rememberedDevices.
  ///
  /// In en, this message translates to:
  /// **'Remembered Devices'**
  String get rememberedDevices;

  /// No description provided for @noRemembered.
  ///
  /// In en, this message translates to:
  /// **'No devices remembered yet. Connect to a device and tap \"Remember\" to save it.'**
  String get noRemembered;

  /// No description provided for @forgetQuestion.
  ///
  /// In en, this message translates to:
  /// **'Forget device?'**
  String get forgetQuestion;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @forget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get forget;

  /// No description provided for @unknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get unknownDevice;

  /// No description provided for @dataCollection.
  ///
  /// In en, this message translates to:
  /// **'Data Collection'**
  String get dataCollection;

  /// No description provided for @defaultSampleRate.
  ///
  /// In en, this message translates to:
  /// **'Default sample rate'**
  String get defaultSampleRate;

  /// No description provided for @maxGraphPoints.
  ///
  /// In en, this message translates to:
  /// **'Max graph points'**
  String get maxGraphPoints;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @serviceUuids.
  ///
  /// In en, this message translates to:
  /// **'BLE Service UUIDs'**
  String get serviceUuids;

  /// No description provided for @connectYourMeter.
  ///
  /// In en, this message translates to:
  /// **'Connect your meter'**
  String get connectYourMeter;

  /// No description provided for @wakeMeter.
  ///
  /// In en, this message translates to:
  /// **'Wake your Mooshimeter and keep it nearby.'**
  String get wakeMeter;

  /// No description provided for @stopScanning.
  ///
  /// In en, this message translates to:
  /// **'Stop scanning'**
  String get stopScanning;

  /// No description provided for @findMeters.
  ///
  /// In en, this message translates to:
  /// **'Find meters'**
  String get findMeters;

  /// No description provided for @savedMeters.
  ///
  /// In en, this message translates to:
  /// **'Saved meters'**
  String get savedMeters;

  /// No description provided for @autoConnectEnabled.
  ///
  /// In en, this message translates to:
  /// **'Auto-connect enabled'**
  String get autoConnectEnabled;

  /// No description provided for @savedConnect.
  ///
  /// In en, this message translates to:
  /// **'Saved · tap to connect'**
  String get savedConnect;

  /// No description provided for @knownDevices.
  ///
  /// In en, this message translates to:
  /// **'Known to this computer'**
  String get knownDevices;

  /// No description provided for @establishConnection.
  ///
  /// In en, this message translates to:
  /// **'Open to establish a meter connection'**
  String get establishConnection;

  /// No description provided for @nearbyMeters.
  ///
  /// In en, this message translates to:
  /// **'Nearby meters'**
  String get nearbyMeters;

  /// No description provided for @searchingMeters.
  ///
  /// In en, this message translates to:
  /// **'Searching for nearby Mooshimeters…'**
  String get searchingMeters;

  /// No description provided for @savedHint.
  ///
  /// In en, this message translates to:
  /// **'Connect a saved meter above, or search for another.'**
  String get savedHint;

  /// No description provided for @noMeters.
  ///
  /// In en, this message translates to:
  /// **'No meters found yet. Check Bluetooth and try Find meters.'**
  String get noMeters;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @stopScan.
  ///
  /// In en, this message translates to:
  /// **'Stop Scan'**
  String get stopScan;

  /// No description provided for @meterSettings.
  ///
  /// In en, this message translates to:
  /// **'Meter settings'**
  String get meterSettings;

  /// No description provided for @graphView.
  ///
  /// In en, this message translates to:
  /// **'Graph View'**
  String get graphView;

  /// No description provided for @clearGraph.
  ///
  /// In en, this message translates to:
  /// **'Clear graph'**
  String get clearGraph;

  /// No description provided for @copyCsv.
  ///
  /// In en, this message translates to:
  /// **'Copy CSV logger command'**
  String get copyCsv;

  /// No description provided for @saveSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Save data snapshot'**
  String get saveSnapshot;

  /// No description provided for @saveScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Save screenshot'**
  String get saveScreenshot;

  /// No description provided for @bluetoothUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth unavailable. Connect or enable a Bluetooth adapter, then tap Scan.'**
  String get bluetoothUnavailable;

  /// No description provided for @exitApp.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exitApp;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @connectingMeter.
  ///
  /// In en, this message translates to:
  /// **'Connecting to meter…'**
  String get connectingMeter;

  /// No description provided for @meterDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Meter disconnected'**
  String get meterDisconnected;

  /// No description provided for @disconnectedHelp.
  ///
  /// In en, this message translates to:
  /// **'The live readings have been cleared. Reconnect to resume sampling.'**
  String get disconnectedHelp;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting...'**
  String get disconnecting;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @enableChannel.
  ///
  /// In en, this message translates to:
  /// **'Enable a channel to show its reading'**
  String get enableChannel;

  /// No description provided for @unitsHelp.
  ///
  /// In en, this message translates to:
  /// **'Display units: Auto chooses an SI prefix'**
  String get unitsHelp;

  /// No description provided for @unitsAuto.
  ///
  /// In en, this message translates to:
  /// **'Units: Auto'**
  String get unitsAuto;

  /// No description provided for @stopMinMax.
  ///
  /// In en, this message translates to:
  /// **'Stop min/max tracking'**
  String get stopMinMax;

  /// No description provided for @trackMinMax.
  ///
  /// In en, this message translates to:
  /// **'Track minimum and maximum values'**
  String get trackMinMax;

  /// No description provided for @outOfRange.
  ///
  /// In en, this message translates to:
  /// **'OUT OF RANGE'**
  String get outOfRange;

  /// No description provided for @waitingSample.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a fresh sample'**
  String get waitingSample;

  /// No description provided for @possiblyFloating.
  ///
  /// In en, this message translates to:
  /// **'Near zero · possibly floating'**
  String get possiblyFloating;

  /// No description provided for @rememberDevice.
  ///
  /// In en, this message translates to:
  /// **'Remember device'**
  String get rememberDevice;

  /// No description provided for @forgetDevice.
  ///
  /// In en, this message translates to:
  /// **'Forget device'**
  String get forgetDevice;

  /// No description provided for @autoConnectNext.
  ///
  /// In en, this message translates to:
  /// **'Auto-connect next time'**
  String get autoConnectNext;

  /// No description provided for @rememberedTap.
  ///
  /// In en, this message translates to:
  /// **'Remembered — tap to auto-connect'**
  String get rememberedTap;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @clearData.
  ///
  /// In en, this message translates to:
  /// **'Clear Data'**
  String get clearData;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @noSamples.
  ///
  /// In en, this message translates to:
  /// **'No samples to save'**
  String get noSamples;

  /// No description provided for @sampleRate.
  ///
  /// In en, this message translates to:
  /// **'Sample Rate'**
  String get sampleRate;

  /// No description provided for @sdLogging.
  ///
  /// In en, this message translates to:
  /// **'SD Card Logging'**
  String get sdLogging;

  /// No description provided for @sdRefreshHint.
  ///
  /// In en, this message translates to:
  /// **'Tap refresh to check the meter’s microSD card.'**
  String get sdRefreshHint;

  /// No description provided for @sdDetected.
  ///
  /// In en, this message translates to:
  /// **'Card detected. The meter can log while disconnected.'**
  String get sdDetected;

  /// No description provided for @sdInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert a FAT/FAT32 microSD card and refresh.'**
  String get sdInsert;

  /// No description provided for @refreshSd.
  ///
  /// In en, this message translates to:
  /// **'Refresh SD-card status'**
  String get refreshSd;

  /// No description provided for @logToSd.
  ///
  /// In en, this message translates to:
  /// **'Log measurements to SD card'**
  String get logToSd;

  /// No description provided for @loggingContinues.
  ///
  /// In en, this message translates to:
  /// **'Logging continues after disconnecting.'**
  String get loggingContinues;

  /// No description provided for @loggingInterval.
  ///
  /// In en, this message translates to:
  /// **'Logging interval'**
  String get loggingInterval;

  /// No description provided for @split.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get split;

  /// No description provided for @dualAxis.
  ///
  /// In en, this message translates to:
  /// **'Dual axis'**
  String get dualAxis;

  /// No description provided for @shared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get shared;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @voltageDc.
  ///
  /// In en, this message translates to:
  /// **'Voltage DC'**
  String get voltageDc;

  /// No description provided for @voltageAc.
  ///
  /// In en, this message translates to:
  /// **'Voltage AC'**
  String get voltageAc;

  /// No description provided for @currentDc.
  ///
  /// In en, this message translates to:
  /// **'Current DC'**
  String get currentDc;

  /// No description provided for @currentAc.
  ///
  /// In en, this message translates to:
  /// **'Current AC'**
  String get currentAc;

  /// No description provided for @internalTemperature.
  ///
  /// In en, this message translates to:
  /// **'Internal Temperature'**
  String get internalTemperature;

  /// No description provided for @resistance.
  ///
  /// In en, this message translates to:
  /// **'Resistance'**
  String get resistance;

  /// No description provided for @diode.
  ///
  /// In en, this message translates to:
  /// **'Diode Drop'**
  String get diode;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @period.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// No description provided for @auxDc.
  ///
  /// In en, this message translates to:
  /// **'Auxiliary Voltage DC'**
  String get auxDc;

  /// No description provided for @auxAc.
  ///
  /// In en, this message translates to:
  /// **'Auxiliary Voltage AC'**
  String get auxAc;

  /// No description provided for @inputRange.
  ///
  /// In en, this message translates to:
  /// **'Input range'**
  String get inputRange;

  /// No description provided for @autoRecommended.
  ///
  /// In en, this message translates to:
  /// **'Auto (recommended)'**
  String get autoRecommended;

  /// No description provided for @input60.
  ///
  /// In en, this message translates to:
  /// **'60 V input'**
  String get input60;

  /// No description provided for @input600.
  ///
  /// In en, this message translates to:
  /// **'600 V input'**
  String get input600;

  /// No description provided for @continuityTone.
  ///
  /// In en, this message translates to:
  /// **'Continuity tone'**
  String get continuityTone;

  /// No description provided for @defaultRange.
  ///
  /// In en, this message translates to:
  /// **'Default input range'**
  String get defaultRange;

  /// No description provided for @currentRangeHelp.
  ///
  /// In en, this message translates to:
  /// **'CH1 current uses the 10 A input range.'**
  String get currentRangeHelp;

  /// No description provided for @resistanceRangeHelp.
  ///
  /// In en, this message translates to:
  /// **'Resistance and continuity use the 1 kΩ input range.'**
  String get resistanceRangeHelp;

  /// No description provided for @defaultRangeHelp.
  ///
  /// In en, this message translates to:
  /// **'This measurement uses the meter default range.'**
  String get defaultRangeHelp;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About MooshRevolt'**
  String get aboutApp;

  /// No description provided for @modernClient.
  ///
  /// In en, this message translates to:
  /// **'A modern Mooshimeter client'**
  String get modernClient;

  /// No description provided for @whyExists.
  ///
  /// In en, this message translates to:
  /// **'Why it exists'**
  String get whyExists;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @sampleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 sample} other{{count} samples}}'**
  String sampleCount(int count);

  /// No description provided for @foundDevices.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Found 1 device} other{Found {count} devices}}'**
  String foundDevices(int count);

  /// No description provided for @batteryPercent.
  ///
  /// In en, this message translates to:
  /// **'Battery {value}%'**
  String batteryPercent(int value);

  /// No description provided for @savedPath.
  ///
  /// In en, this message translates to:
  /// **'Saved {path}'**
  String savedPath(String path);

  /// No description provided for @configureChannel.
  ///
  /// In en, this message translates to:
  /// **'Configure {channel}'**
  String configureChannel(String channel);

  /// No description provided for @unitsValue.
  ///
  /// In en, this message translates to:
  /// **'Units: {unit}'**
  String unitsValue(String unit);

  /// No description provided for @graphStyle.
  ///
  /// In en, this message translates to:
  /// **'Graph style: {style}'**
  String graphStyle(String style);

  /// No description provided for @sampleRateValue.
  ///
  /// In en, this message translates to:
  /// **'Sample rate: {rate} Hz'**
  String sampleRateValue(int rate);

  /// No description provided for @removeDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from remembered devices?'**
  String removeDevice(String name);

  /// No description provided for @deviceForgotten.
  ///
  /// In en, this message translates to:
  /// **'{name} forgotten'**
  String deviceForgotten(String name);

  /// No description provided for @rememberedDate.
  ///
  /// In en, this message translates to:
  /// **'Remembered: {date}'**
  String rememberedDate(String date);

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 second} other{{count} seconds}}'**
  String seconds(int count);

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points: {count}'**
  String points(int count);

  /// No description provided for @lookingFor.
  ///
  /// In en, this message translates to:
  /// **'Looking for {name}…'**
  String lookingFor(String name);

  /// No description provided for @connectingTo.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {name}…'**
  String connectingTo(String name);

  /// No description provided for @errorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorMessage(String error);

  /// No description provided for @tapScan.
  ///
  /// In en, this message translates to:
  /// **'Tap to scan'**
  String get tapScan;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get scanning;

  /// No description provided for @noneFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get noneFound;

  /// No description provided for @connectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect — try again'**
  String get connectFailed;

  /// No description provided for @deviceRemembered.
  ///
  /// In en, this message translates to:
  /// **'Device remembered'**
  String get deviceRemembered;

  /// No description provided for @forgotten.
  ///
  /// In en, this message translates to:
  /// **'Device forgotten'**
  String get forgotten;

  /// No description provided for @showChannel.
  ///
  /// In en, this message translates to:
  /// **'Show channel'**
  String get showChannel;

  /// No description provided for @showChannelHelp.
  ///
  /// In en, this message translates to:
  /// **'Include this channel in readings and graph'**
  String get showChannelHelp;

  /// No description provided for @continuityHelp.
  ///
  /// In en, this message translates to:
  /// **'Play a continuous tone below 50 Ω'**
  String get continuityHelp;

  /// No description provided for @voltageAux.
  ///
  /// In en, this message translates to:
  /// **'Voltage and auxiliary measurements'**
  String get voltageAux;

  /// No description provided for @autoRangeHelp.
  ///
  /// In en, this message translates to:
  /// **'Auto keeps normal measurements on the 60 V input and changes only when needed.'**
  String get autoRangeHelp;

  /// No description provided for @tempRangeHelp.
  ///
  /// In en, this message translates to:
  /// **'Temperature mode does not use a voltage range.'**
  String get tempRangeHelp;

  /// No description provided for @loggingRangeHelp.
  ///
  /// In en, this message translates to:
  /// **'Set a safe fixed input range before logging; the meter does not autorange while logging.'**
  String get loggingRangeHelp;

  /// No description provided for @notRemembered.
  ///
  /// In en, this message translates to:
  /// **'Not remembered'**
  String get notRemembered;

  /// No description provided for @remember.
  ///
  /// In en, this message translates to:
  /// **'Remember'**
  String get remember;

  /// No description provided for @deviceSettings.
  ///
  /// In en, this message translates to:
  /// **'Device settings'**
  String get deviceSettings;

  /// No description provided for @graphStyleTitle.
  ///
  /// In en, this message translates to:
  /// **'Graph style'**
  String get graphStyleTitle;

  /// No description provided for @sampleRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Sample rate'**
  String get sampleRateTitle;

  /// No description provided for @splitChannels.
  ///
  /// In en, this message translates to:
  /// **'Split channels'**
  String get splitChannels;

  /// No description provided for @sharedAxis.
  ///
  /// In en, this message translates to:
  /// **'Shared axis'**
  String get sharedAxis;

  /// No description provided for @enableForCsv.
  ///
  /// In en, this message translates to:
  /// **'Enable at least one channel before copying a logger command'**
  String get enableForCsv;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'MooshRevolt is an Android and Linux desktop app for the Mooshimeter BLE multimeter. It provides live readings, graphing, logging, and a practical interface for modern devices.'**
  String get appDescription;

  /// No description provided for @appBackground.
  ///
  /// In en, this message translates to:
  /// **'The project grew from using a Mooshimeter bought around 2016. There was no dedicated Linux desktop app, existing libsigrok support could be unreliable, and the original Android experience was not designed for current devices. MooshRevolt brings the meter to a shared Flutter codebase for Linux and Android.'**
  String get appBackground;

  /// No description provided for @licenseNotice.
  ///
  /// In en, this message translates to:
  /// **'Copyright © Rich Young. Licensed under GNU GPL v3.0 or later. Source code and modified versions must remain available under the same license.'**
  String get licenseNotice;

  /// No description provided for @meterNotFound.
  ///
  /// In en, this message translates to:
  /// **'Could not find \"{name}\" — is it nearby ?'**
  String meterNotFound(String name);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemLanguage;

  /// No description provided for @measurement.
  ///
  /// In en, this message translates to:
  /// **'Measurement'**
  String get measurement;

  /// No description provided for @currentAux.
  ///
  /// In en, this message translates to:
  /// **'Current, resistance, and auxiliary measurements'**
  String get currentAux;

  /// No description provided for @device.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get device;

  /// No description provided for @statusUnchecked.
  ///
  /// In en, this message translates to:
  /// **'Status not checked'**
  String get statusUnchecked;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @excellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get excellent;

  /// No description provided for @good.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get good;

  /// No description provided for @fair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get fair;

  /// No description provided for @weak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get weak;

  /// No description provided for @cardUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Card unavailable (status {status})'**
  String cardUnavailable(int status);

  /// No description provided for @batteryVoltage.
  ///
  /// In en, this message translates to:
  /// **'{voltage} V measured across two AA cells'**
  String batteryVoltage(String voltage);

  /// No description provided for @waitingSamples.
  ///
  /// In en, this message translates to:
  /// **'Waiting for samples…'**
  String get waitingSamples;

  /// No description provided for @currentAxis.
  ///
  /// In en, this message translates to:
  /// **'Current (A)'**
  String get currentAxis;

  /// No description provided for @voltageAxis.
  ///
  /// In en, this message translates to:
  /// **'Voltage (V)'**
  String get voltageAxis;

  /// No description provided for @rememberedMeter.
  ///
  /// In en, this message translates to:
  /// **'Remembered: {name} ({address})'**
  String rememberedMeter(String name, String address);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
