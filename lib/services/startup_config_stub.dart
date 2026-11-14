// Browser builds have no access to the device's /etc configuration.
Future<String?> readStartupConfig({String? path}) async => null;
