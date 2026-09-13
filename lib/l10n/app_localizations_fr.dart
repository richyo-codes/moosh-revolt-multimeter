// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get settings => 'Paramètres';

  @override
  String get connection => 'Connexion';

  @override
  String get autoConnect => 'Connexion automatique au démarrage';

  @override
  String get autoConnectHelp =>
      'Se reconnecter automatiquement au dernier appareil enregistré';

  @override
  String get skipFirmware => 'Ignorer la vérification du micrologiciel';

  @override
  String get skipFirmwareHelp => 'Ignorer la demande de mise à jour OAD';

  @override
  String get appearance => 'Apparence';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get darkModeHelp =>
      'Utiliser des couleurs sombres dans toute l’application';

  @override
  String get showFloating => 'Afficher les valeurs des sondes flottantes';

  @override
  String get showFloatingHelp =>
      'Afficher les mesures proches de zéro même si une sonde semble déconnectée';

  @override
  String get rememberedDevices => 'Appareils enregistrés';

  @override
  String get noRemembered =>
      'Aucun appareil enregistré. Connectez un appareil et appuyez sur « Enregistrer ».';

  @override
  String get forgetQuestion => 'Oublier cet appareil ?';

  @override
  String get cancel => 'Annuler';

  @override
  String get forget => 'Oublier';

  @override
  String get unknownDevice => 'Appareil inconnu';

  @override
  String get dataCollection => 'Acquisition';

  @override
  String get defaultSampleRate => 'Fréquence d’échantillonnage par défaut';

  @override
  String get maxGraphPoints => 'Nombre maximal de points';

  @override
  String get about => 'À propos';

  @override
  String get serviceUuids => 'UUID des services BLE';

  @override
  String get connectYourMeter => 'Connectez votre multimètre';

  @override
  String get wakeMeter =>
      'Réveillez votre Mooshimeter et gardez-le à proximité.';

  @override
  String get stopScanning => 'Arrêter la recherche';

  @override
  String get findMeters => 'Rechercher';

  @override
  String get savedMeters => 'Multimètres enregistrés';

  @override
  String get autoConnectEnabled => 'Connexion automatique activée';

  @override
  String get savedConnect => 'Enregistré · appuyez pour connecter';

  @override
  String get knownDevices => 'Appareils connus';

  @override
  String get establishConnection => 'Ouvrir pour connecter le multimètre';

  @override
  String get nearbyMeters => 'Multimètres à proximité';

  @override
  String get searchingMeters => 'Recherche de Mooshimeters à proximité…';

  @override
  String get savedHint =>
      'Connectez un multimètre enregistré ou recherchez-en un autre.';

  @override
  String get noMeters =>
      'Aucun multimètre trouvé. Vérifiez le Bluetooth et relancez la recherche.';

  @override
  String get scan => 'Rechercher';

  @override
  String get stopScan => 'Arrêter la recherche';

  @override
  String get meterSettings => 'Paramètres du multimètre';

  @override
  String get graphView => 'Graphique';

  @override
  String get clearGraph => 'Effacer le graphique';

  @override
  String get copyCsv => 'Copier la commande CSV';

  @override
  String get saveSnapshot => 'Enregistrer les données';

  @override
  String get saveScreenshot => 'Enregistrer une capture d’écran';

  @override
  String get disconnect => 'Déconnecter';

  @override
  String get connectingMeter => 'Connexion au multimètre…';

  @override
  String get meterDisconnected => 'Multimètre déconnecté';

  @override
  String get disconnectedHelp =>
      'Les mesures actuelles ont été effacées. Reconnectez-vous pour reprendre l’acquisition.';

  @override
  String get reconnect => 'Reconnecter';

  @override
  String get connecting => 'Connexion…';

  @override
  String get connected => 'Connecté';

  @override
  String get disconnecting => 'Déconnexion…';

  @override
  String get disconnected => 'Déconnecté';

  @override
  String get enableChannel => 'Activez un canal pour afficher sa mesure';

  @override
  String get unitsHelp => 'Unités : Auto choisit le préfixe SI';

  @override
  String get unitsAuto => 'Unités : Auto';

  @override
  String get stopMinMax => 'Arrêter le suivi min/max';

  @override
  String get trackMinMax => 'Suivre les valeurs minimale et maximale';

  @override
  String get outOfRange => 'HORS PLAGE';

  @override
  String get waitingSample => 'En attente d’une nouvelle mesure';

  @override
  String get possiblyFloating => 'Proche de zéro · sonde peut-être flottante';

  @override
  String get rememberDevice => 'Enregistrer l’appareil';

  @override
  String get forgetDevice => 'Oublier l’appareil';

  @override
  String get autoConnectNext => 'Connexion automatique la prochaine fois';

  @override
  String get rememberedTap => 'Enregistré — appuyez pour connecter';

  @override
  String get connect => 'Connecter';

  @override
  String get live => 'Direct';

  @override
  String get exportCsv => 'Exporter en CSV';

  @override
  String get clearData => 'Effacer les données';

  @override
  String get all => 'Tout';

  @override
  String get noSamples => 'Aucune mesure à enregistrer';

  @override
  String get sampleRate => 'Fréquence d’échantillonnage';

  @override
  String get sdLogging => 'Enregistrement sur carte SD';

  @override
  String get sdRefreshHint =>
      'Actualisez pour vérifier la carte microSD du multimètre.';

  @override
  String get sdDetected =>
      'Carte détectée. L’enregistrement peut continuer après déconnexion.';

  @override
  String get sdInsert => 'Insérez une carte microSD FAT/FAT32 et actualisez.';

  @override
  String get refreshSd => 'Actualiser l’état de la carte SD';

  @override
  String get logToSd => 'Enregistrer les mesures sur carte SD';

  @override
  String get loggingContinues => 'L’enregistrement continue après déconnexion.';

  @override
  String get loggingInterval => 'Intervalle d’enregistrement';

  @override
  String get split => 'Séparé';

  @override
  String get dualAxis => 'Deux axes';

  @override
  String get shared => 'Partagé';

  @override
  String get auto => 'Auto';

  @override
  String get voltageDc => 'Tension CC';

  @override
  String get voltageAc => 'Tension CA';

  @override
  String get currentDc => 'Courant CC';

  @override
  String get currentAc => 'Courant CA';

  @override
  String get internalTemperature => 'Température interne';

  @override
  String get resistance => 'Résistance';

  @override
  String get diode => 'Chute de tension diode';

  @override
  String get frequency => 'Fréquence';

  @override
  String get period => 'Période';

  @override
  String get auxDc => 'Tension auxiliaire CC';

  @override
  String get auxAc => 'Tension auxiliaire CA';

  @override
  String get inputRange => 'Plage d’entrée';

  @override
  String get autoRecommended => 'Auto (recommandé)';

  @override
  String get input60 => 'Entrée 60 V';

  @override
  String get input600 => 'Entrée 600 V';

  @override
  String get continuityTone => 'Signal sonore de continuité';

  @override
  String get defaultRange => 'Plage d’entrée par défaut';

  @override
  String get currentRangeHelp =>
      'Le courant CH1 utilise la plage d’entrée 10 A.';

  @override
  String get resistanceRangeHelp =>
      'La résistance et la continuité utilisent la plage 1 kΩ.';

  @override
  String get defaultRangeHelp =>
      'Cette mesure utilise la plage par défaut du multimètre.';

  @override
  String get aboutApp => 'À propos de MooshRevolt';

  @override
  String get modernClient => 'Un client Mooshimeter moderne';

  @override
  String get whyExists => 'Pourquoi ce projet';

  @override
  String get license => 'Licence';

  @override
  String sampleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesures',
      one: '1 mesure',
    );
    return '$_temp0';
  }

  @override
  String foundDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count appareils trouvés',
      one: '1 appareil trouvé',
    );
    return '$_temp0';
  }

  @override
  String batteryPercent(int value) {
    return 'Batterie $value %';
  }

  @override
  String savedPath(String path) {
    return 'Enregistré : $path';
  }

  @override
  String configureChannel(String channel) {
    return 'Configurer $channel';
  }

  @override
  String unitsValue(String unit) {
    return 'Unités : $unit';
  }

  @override
  String graphStyle(String style) {
    return 'Style du graphique : $style';
  }

  @override
  String sampleRateValue(int rate) {
    return 'Échantillonnage : $rate Hz';
  }

  @override
  String removeDevice(String name) {
    return 'Supprimer « $name » des appareils enregistrés ?';
  }

  @override
  String deviceForgotten(String name) {
    return '$name oublié';
  }

  @override
  String rememberedDate(String date) {
    return 'Enregistré le $date';
  }

  @override
  String seconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count secondes',
      one: '1 seconde',
    );
    return '$_temp0';
  }

  @override
  String points(int count) {
    return 'Points : $count';
  }

  @override
  String lookingFor(String name) {
    return 'Recherche de $name…';
  }

  @override
  String connectingTo(String name) {
    return 'Connexion à $name…';
  }

  @override
  String errorMessage(String error) {
    return 'Erreur : $error';
  }

  @override
  String get tapScan => 'Appuyez pour rechercher';

  @override
  String get scanning => 'Recherche…';

  @override
  String get noneFound => 'Aucun appareil trouvé';

  @override
  String get connectFailed => 'Connexion impossible — réessayez';

  @override
  String get deviceRemembered => 'Appareil enregistré';

  @override
  String get forgotten => 'Appareil oublié';

  @override
  String get showChannel => 'Afficher le canal';

  @override
  String get showChannelHelp =>
      'Inclure ce canal dans les mesures et le graphique';

  @override
  String get continuityHelp => 'Émettre un son continu en dessous de 50 Ω';

  @override
  String get voltageAux => 'Mesures de tension et auxiliaires';

  @override
  String get autoRangeHelp =>
      'Auto conserve l’entrée 60 V pour les mesures normales et change si nécessaire.';

  @override
  String get tempRangeHelp =>
      'Le mode température n’utilise pas de plage de tension.';

  @override
  String get loggingRangeHelp =>
      'Choisissez une plage fixe adaptée avant d’enregistrer ; le multimètre ne change pas automatiquement de plage pendant l’enregistrement.';

  @override
  String get notRemembered => 'Non enregistré';

  @override
  String get remember => 'Enregistrer';

  @override
  String get deviceSettings => 'Paramètres de l’appareil';

  @override
  String get graphStyleTitle => 'Style du graphique';

  @override
  String get sampleRateTitle => 'Fréquence d’échantillonnage';

  @override
  String get splitChannels => 'Canaux séparés';

  @override
  String get sharedAxis => 'Axe partagé';

  @override
  String get enableForCsv =>
      'Activez au moins un canal avant de copier une commande';

  @override
  String get appDescription =>
      'MooshRevolt est une application Android et Linux pour le multimètre Bluetooth LE Mooshimeter. Elle offre des mesures en direct, des graphiques et l’enregistrement des données.';

  @override
  String get appBackground =>
      'Ce projet est né de l’utilisation d’un Mooshimeter acheté vers 2016. Il n’existait pas d’application Linux dédiée, la prise en charge par libsigrok pouvait être peu fiable et l’application Android d’origine était vieillissante. MooshRevolt propose une base Flutter commune pour Linux et Android.';

  @override
  String get licenseNotice =>
      'Copyright © Rich Young. Sous licence GNU GPL v3.0 ou ultérieure. Le code source et les versions modifiées doivent rester disponibles sous la même licence.';

  @override
  String meterNotFound(String name) {
    return '« $name » introuvable — est-il à proximité ?';
  }

  @override
  String get language => 'Langue';

  @override
  String get systemLanguage => 'Langue du système';

  @override
  String get measurement => 'Mesure';

  @override
  String get currentAux => 'Courant, résistance et mesures auxiliaires';

  @override
  String get device => 'Appareil';

  @override
  String get statusUnchecked => 'État non vérifié';

  @override
  String get ready => 'Prête';

  @override
  String get excellent => 'Excellent';

  @override
  String get good => 'Bon';

  @override
  String get fair => 'Moyen';

  @override
  String get weak => 'Faible';

  @override
  String cardUnavailable(int status) {
    return 'Carte indisponible (état $status)';
  }

  @override
  String batteryVoltage(String voltage) {
    return '$voltage V mesurés aux bornes de deux piles AA';
  }

  @override
  String get waitingSamples => 'En attente de mesures…';

  @override
  String get currentAxis => 'Courant (A)';

  @override
  String get voltageAxis => 'Tension (V)';

  @override
  String rememberedMeter(String name, String address) {
    return 'Enregistré : $name ($address)';
  }
}
