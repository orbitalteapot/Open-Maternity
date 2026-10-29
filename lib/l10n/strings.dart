import 'dart:ui' show Locale, PlatformDispatcher;

import 'strings_da.dart';
import 'strings_en.dart';
import 'strings_nb.dart';
import 'strings_sv.dart';

/// The four languages the app ships with, in the order shown on the language screen.
const List<String> appLanguages = <String>['en', 'nb', 'sv', 'da'];

const Map<String, Map<String, String>> stringTables = <String, Map<String, String>>{
  'en': stringsEn,
  'nb': stringsNb,
  'sv': stringsSv,
  'da': stringsDa,
};

final RegExp _placeholder = RegExp(r'\{(\w+)\}');

/// Looks up user-facing text. Call it like a function: `t('w_title')`,
/// or with values for placeholders: `t('week_n', {'n': 36})`.
class S {
  S(String lang)
      : lang = stringTables.containsKey(lang) ? lang : 'en',
        _table = stringTables[lang] ?? stringsEn;

  final String lang;
  final Map<String, String> _table;

  String call(String key, [Map<String, Object?> values = const <String, Object?>{}]) {
    final String text = _table[key] ?? stringsEn[key] ?? key;
    if (values.isEmpty) {
      return text;
    }
    return text.replaceAllMapped(_placeholder, (Match m) {
      final Object? value = values[m.group(1)];
      return value == null ? m.group(0)! : '$value';
    });
  }

  /// The locale used for Material widgets and the date pickers.
  /// English uses British conventions (24-hour clock, day before month).
  Locale get locale => localeFor(lang);

  /// The locale name used by package:intl for dates and numbers.
  String get intlLocale => lang == 'en' ? 'en_GB' : lang;

  static Locale localeFor(String lang) => lang == 'en' ? const Locale('en', 'GB') : Locale(lang);

  /// Picks the best starting language from the phone's own languages.
  static String guessFromDevice() {
    for (final Locale l in PlatformDispatcher.instance.locales) {
      switch (l.languageCode) {
        case 'nb':
        case 'nn':
        case 'no':
          return 'nb';
        case 'sv':
          return 'sv';
        case 'da':
          return 'da';
        case 'en':
          return 'en';
      }
    }
    return 'en';
  }
}
