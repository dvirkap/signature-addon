import '../lib/translations.dart';

void main() {
  print('appSupportedLanguages count: ${appSupportedLanguages.length}');
  print('localizedValues count: ${localizedValues.length}');
  
  // Verify that all keys in appSupportedLanguages exist in localizedValues
  var missingInLocalized = <String>[];
  for (var key in appSupportedLanguages.keys) {
    if (!localizedValues.containsKey(key)) {
      missingInLocalized.add(key);
    }
  }
  print('Keys in appSupportedLanguages missing in localizedValues: $missingInLocalized');
  
  var missingInSupported = <String>[];
  for (var key in localizedValues.keys) {
    if (!appSupportedLanguages.containsKey(key)) {
      missingInSupported.add(key);
    }
  }
  print('Keys in localizedValues missing in appSupportedLanguages: $missingInSupported');
}
