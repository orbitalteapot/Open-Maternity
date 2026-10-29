import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_maternity/data/calc.dart';
import 'package:open_maternity/data/models.dart';
import 'package:open_maternity/data/storage.dart';
import 'package:open_maternity/data/store.dart';
import 'package:open_maternity/services/backup.dart';
import 'package:open_maternity/version.dart';

Contraction c(int startMin, int durSec, {int base = 1800000000000}) {
  final int s = base + startMin * 60000;
  return Contraction(id: 'c$startMin', start: s, end: s + durSec * 1000);
}

void main() {
  group('pregnancy week', () {
    test('28 days before the due date is week 36 + 0', () {
      final DateTime now = DateTime(2026, 10, 29, 14);
      final PregnancyWeek w = pregnancyWeek('2026-11-26', now)!;
      expect(w.week, 36);
      expect(w.days, 0);
      expect(w.daysToDue, 28);
      expect(w.trimester, 3);
      expect(w.progress, closeTo(252 / 280, 0.0001));
    });

    test('works across daylight saving changes', () {
      final PregnancyWeek w = pregnancyWeek('2026-11-01', DateTime(2026, 10, 24, 23, 30))!;
      expect(w.daysToDue, 8);
    });

    test('trimester borders', () {
      final DateTime due = DateTime(2027, 6, 1);
      PregnancyWeek at(int week) => pregnancyWeek(isoDate(due), due.subtract(Duration(days: 280 - week * 7)))!;
      expect(at(12).trimester, 1);
      expect(at(13).trimester, 2);
      expect(at(27).trimester, 2);
      expect(at(28).trimester, 3);
    });

    test('past the due date and bad input', () {
      final PregnancyWeek w = pregnancyWeek('2026-10-20', DateTime(2026, 10, 29))!;
      expect(w.daysToDue, -9);
      expect(w.week, 41);
      expect(w.progress, 1.0);
      expect(pregnancyWeek('', DateTime.now()), isNull);
      expect(pregnancyWeek('2026-13', DateTime.now()), isNull);
    });
  });

  group('contraction stats', () {
    test('averages of the last six', () {
      final List<Contraction> list = <Contraction>[
        c(0, 30), c(10, 30), // older, outside the last six
        c(20, 60), c(25, 60), c(30, 60), c(35, 60), c(40, 60), c(45, 60),
      ];
      final ContractionStats s = contractionStats(list, list.last.end);
      expect(s.sample, 6);
      expect(s.avgDurationSec, 60);
      expect(s.avgIntervalSec, 300);
      expect(s.inLastHour, 8);
    });

    test('one contraction has no interval', () {
      final ContractionStats s = contractionStats(<Contraction>[c(0, 45)], 1800000000000);
      expect(s.sample, 1);
      expect(s.avgIntervalSec, 0);
    });

    test('order of input does not matter', () {
      final ContractionStats a = contractionStats(<Contraction>[c(0, 40), c(6, 50), c(12, 60)], 1800000000000 + 3600000);
      final ContractionStats b = contractionStats(<Contraction>[c(12, 60), c(0, 40), c(6, 50)], 1800000000000 + 3600000);
      expect(a.avgIntervalSec, b.avgIntervalSec);
      expect(a.avgIntervalSec, 360);
    });
  });

  group('formatting and parsing', () {
    test('durations', () {
      expect(formatDuration(75), '1:15');
      expect(formatDuration(0), '0:00');
      expect(formatDuration(-5), '0:00');
      expect(formatTimer(75), '01:15');
      expect(formatTimer(3600), '60:00');
    });

    test('weight accepts comma and dot, and checks the range', () {
      expect(parseKg('72,5'), 72.5);
      expect(parseKg(' 72.46 '), 72.5);
      expect(parseKg('12'), isNull);
      expect(parseKg('301'), isNull);
      expect(parseKg('abc'), isNull);
    });

    test('dialable numbers', () {
      expect(dialable('+47 22 33 44 55'), '+4722334455');
      expect(dialable('(0) 123-456'), '0123456');
      expect(dialable('ward'), '');
    });

    test('clock parsing', () {
      expect(parseClock('07:30'), (hour: 7, minute: 30));
      expect(parseClock('24:00'), isNull);
      expect(parseClock('7'), isNull);
    });
  });

  group('data', () {
    test('round trip through JSON', () {
      final AppData d = AppData(
        onboarded: true,
        lang: 'sv',
        due: '2026-11-26',
        numbers: <String, String>{'ward': '123', 'midwife': '', 'centre': '', 'doctor': '', 'emergency': '', 'support': '456'},
        supportName: 'Kim',
        contractions: <Contraction>[c(0, 60)],
        running: 1800000000000,
        move: const RunningMoves(start: 1800000000000, count: 3),
        moves: const <MoveSession>[MoveSession(id: 'm', start: 1, end: 60001, count: 10)],
        bagDone: <String>{'id', 'x1'},
        bagCustom: const <BagItem>[BagItem(id: 'x1', group: 'baby', text: 'Pillow')],
        appts: const <Appointment>[Appointment(id: 'a', kind: 'scan', date: '2026-11-03', time: '10:30', note: 'Ask')],
        meds: const <Medicine>[Medicine(id: 'md', name: 'Iron', time: '08:00')],
        medLog: const <MedTaken>[MedTaken(medId: 'md', at: 1800000000000)],
        weights: const <WeightEntry>[WeightEntry(id: 'w', at: 1800000000000, kg: 72.4)],
      );
      final AppData back = AppData.fromJson(jsonDecode(jsonEncode(d.toJson())));
      expect(jsonEncode(back.toJson()), jsonEncode(d.toJson()));
    });

    test('reads the prototype format and ignores junk', () {
      final AppData d = AppData.fromJson(<String, Object?>{
        'lang': 'nb',
        'bagDone': <String, Object?>{'id': true, 'record': false},
        'contractions': <Object?>[
          <String, Object?>{'id': 'a', 's': 100, 'e': 200},
          <String, Object?>{'id': 'b', 's': 300, 'e': 100},
          'nonsense',
        ],
        'weights': <Object?>[
          <String, Object?>{'t': 5, 'kg': 10},
        ],
        'themePref': 'purple',
        'due': 'soon',
      });
      expect(d.lang, 'nb');
      expect(d.bagDone, <String>{'id'});
      expect(d.contractions.length, 1);
      expect(d.weights, isEmpty);
      expect(d.themePref, 'phone');
      expect(d.due, '');
      expect(d.numbers.keys.toSet(), numberRoles.toSet());
    });

    test('backups decode and reject other files', () {
      final AppData d = AppData(lang: 'da', due: '2026-12-01');
      final String text = encodeBackup(d, DateTime.utc(2026, 10, 29, 12));
      final BackupFile? b = decodeBackup(text);
      expect(b, isNotNull);
      expect(b!.data.due, '2026-12-01');
      expect(b.exportedAt!.toUtc(), DateTime.utc(2026, 10, 29, 12));
      expect(decodeBackup('{"hello": 1}'), isNull);
      expect(decodeBackup('not json'), isNull);
      expect(decodeBackup('{"app":"open-maternity","format":99,"data":{}}'), isNull);
    });
  });

  group('store', () {
    Future<AppStore> fresh() => AppStore.open(storage: MemoryStateStorage(), saveDelay: Duration.zero);

    test('contraction start, stop and undo', () async {
      final AppStore s = await fresh();
      s.startContraction(now: 1000);
      expect(s.data.running, 1000);
      final void Function()? undo = s.stopContraction(now: 61000);
      expect(s.data.contractions.single.durationMs, 60000);
      expect(s.data.running, 0);
      undo!();
      expect(s.data.contractions, isEmpty);
      expect(s.data.running, 1000);
    });

    test('changes are saved and read back', () async {
      final MemoryStateStorage storage = MemoryStateStorage();
      final AppStore s = await AppStore.open(storage: storage, saveDelay: Duration.zero);
      s.setNumber('ward', ' 22 33 ');
      s.addWeight(70.5, now: 5000);
      s.completeOnboarding();
      await s.flush();
      final AppStore again = await AppStore.open(storage: storage, saveDelay: Duration.zero);
      expect(again.data.number('ward'), '22 33');
      expect(again.data.weights.single.kg, 70.5);
      expect(again.data.onboarded, isTrue);
    });

    test('unreadable saved data starts fresh', () async {
      final AppStore s = await AppStore.open(storage: MemoryStateStorage('{oops'), initialLang: 'da', saveDelay: Duration.zero);
      expect(s.data.lang, 'da');
      expect(s.data.onboarded, isFalse);
    });

    test('medicine taken today and undo', () async {
      final AppStore s = await fresh();
      s.saveMed(const Medicine(id: 'm1', name: 'Iron', time: '08:00'));
      final int now = DateTime(2026, 10, 29, 9).millisecondsSinceEpoch;
      expect(s.takenToday('m1', now: now), isFalse);
      final void Function() undo = s.markTaken('m1', now: now);
      expect(s.takenToday('m1', now: now), isTrue);
      expect(s.takenToday('m1', now: DateTime(2026, 10, 30, 9).millisecondsSinceEpoch), isFalse);
      undo();
      expect(s.takenToday('m1', now: now), isFalse);
    });

    test('bag items, removal and undo', () async {
      final AppStore s = await fresh();
      s.addBagItem('baby', '  Pillow ');
      final String id = s.data.bagCustom.single.id;
      s.toggleBag(id);
      expect(s.data.bagDone, contains(id));
      final void Function() undo = s.removeBagItem(id);
      expect(s.data.bagCustom, isEmpty);
      expect(s.data.bagDone, isNot(contains(id)));
      undo();
      expect(s.data.bagCustom.single.text, 'Pillow');
      expect(s.data.bagDone, contains(id));
    });

    test('delete everything keeps the language only', () async {
      final AppStore s = await fresh();
      s.setLang('sv');
      s.setNumber('ward', '1');
      s.completeOnboarding();
      s.deleteEverything();
      expect(s.data.lang, 'sv');
      expect(s.data.number('ward'), '');
      expect(s.data.onboarded, isFalse);
    });

    test('restoring a backup finishes setup', () async {
      final AppStore s = await fresh();
      s.replaceAll(AppData(lang: 'nb', due: '2026-11-26'));
      expect(s.data.onboarded, isTrue);
      expect(s.data.lang, 'nb');
    });
  });

  test('version in Settings matches pubspec.yaml', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final RegExpMatch m = RegExp(r'^version:\s*([0-9.]+)\+', multiLine: true).firstMatch(pubspec)!;
    expect(appVersion, m.group(1));
  });
}
