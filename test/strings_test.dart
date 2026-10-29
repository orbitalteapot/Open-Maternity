import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_maternity/data/models.dart';
import 'package:open_maternity/l10n/strings.dart';

Set<String> _placeholders(String s) => RegExp(r'\{(\w+)\}').allMatches(s).map((Match m) => m.group(1)!).toSet();

void main() {
  final Map<String, String> en = stringTables['en']!;

  test('every language has exactly the English keys', () {
    for (final String lang in appLanguages) {
      final Map<String, String> table = stringTables[lang]!;
      expect(table.keys.toSet().difference(en.keys.toSet()), isEmpty, reason: '$lang has extra keys');
      expect(en.keys.toSet().difference(table.keys.toSet()), isEmpty, reason: '$lang is missing keys');
    }
  });

  test('placeholders match English in every language', () {
    for (final String lang in appLanguages) {
      final Map<String, String> table = stringTables[lang]!;
      for (final String key in en.keys) {
        expect(_placeholders(table[key]!), _placeholders(en[key]!), reason: '$lang:$key');
      }
    }
  });

  test('no empty translations', () {
    for (final String lang in appLanguages) {
      stringTables[lang]!.forEach((String key, String value) {
        expect(value.trim(), isNotEmpty, reason: '$lang:$key');
      });
    }
  });

  test('every literal key used in the code exists', () {
    final RegExp call = RegExp(r"""\bt(?:Read)?\('([a-z0-9_]+)'""");
    final RegExp sCall = RegExp(r"""\)\('([a-z0-9_]+)'""");
    final Set<String> used = <String>{};
    for (final FileSystemEntity f in Directory('lib').listSync(recursive: true)) {
      if (f is File && f.path.endsWith('.dart') && !f.path.contains('${Platform.pathSeparator}l10n${Platform.pathSeparator}strings_')) {
        final String src = f.readAsStringSync();
        used.addAll(call.allMatches(src).map((Match m) => m.group(1)!));
        used.addAll(sCall.allMatches(src).map((Match m) => m.group(1)!));
      }
    }
    expect(used, isNotEmpty);
    final Set<String> missing = used.where((String k) => !en.containsKey(k)).toSet();
    expect(missing, isEmpty);
  });

  test('keys built at runtime exist', () {
    final List<String> keys = <String>[
      for (final String r in numberRoles) 'role_$r',
      for (final String k in apptKinds) 'a_kind_$k',
      for (final DefaultBagItem b in defaultBag) 'b_i_${b.id}',
      for (final int i in <int>[1, 2, 3]) 'tri_$i',
      for (final String th in <String>['phone', 'light', 'dark', 'night']) 'th_$th',
      for (final String l in appLanguages) 'lang_$l',
      'grp_birth',
      'grp_care',
      'grp_emergency',
    ];
    for (final String k in keys) {
      expect(en.containsKey(k), isTrue, reason: k);
    }
  });

  test('placeholders are filled', () {
    final S t = S('nb');
    expect(t('week_n', <String, Object?>{'n': 36}), 'Uke 36');
    expect(t('packed_of', <String, Object?>{'a': 2, 'b': 10}), '2 av 10 pakket');
    expect(S('xx')('continue'), 'Continue');
    expect(S('en')('no_such_key'), 'no_such_key');
  });
}
