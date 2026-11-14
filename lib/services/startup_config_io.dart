import 'dart:io';

Future<String?> readStartupConfig({String? path}) async {
  final explicit = path ?? Platform.environment['MOOSHREVOLT_CONFIG'];
  if (explicit != null && explicit.trim().isEmpty) {
    throw const FormatException('MOOSHREVOLT_CONFIG must not be empty');
  }
  if (explicit == null && !Platform.isLinux) return null;
  final file = File(explicit ?? '/etc/moosh-revolt/config.json');
  try {
    return await file.readAsString();
  } on FileSystemException catch (error) {
    // Only an absent default is optional; permission and read errors fail closed.
    if (explicit == null && error.osError?.errorCode == 2) return null;
    rethrow;
  }
}
