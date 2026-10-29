// Everything the app stores. All of it lives in one JSON file on the phone.
// Times are milliseconds since the epoch; dates are 'yyyy-mm-dd'; clock times 'hh:mm'.
import 'dart:convert';
import 'dart:math';

const int dataVersion = 1;

/// After this long without a contraction, starting the timer begins a new series.
const int autoSeriesGapMs = 2 * 60 * 60 * 1000;

/// The numbers a user can save. Nothing is ever pre-filled.
const List<String> numberRoles = <String>['ward', 'midwife', 'centre', 'doctor', 'emergency', 'support'];

const List<String> apptKinds = <String>['midwife', 'doctor', 'scan', 'other'];

class DefaultBagItem {
  const DefaultBagItem(this.id, this.group);
  final String id;
  final String group; // 'you' or 'baby'
}

const List<DefaultBagItem> defaultBag = <DefaultBagItem>[
  DefaultBagItem('id', 'you'),
  DefaultBagItem('record', 'you'),
  DefaultBagItem('charger', 'you'),
  DefaultBagItem('clothes', 'you'),
  DefaultBagItem('snacks', 'you'),
  DefaultBagItem('toiletries', 'you'),
  DefaultBagItem('babyclothes', 'baby'),
  DefaultBagItem('carseat', 'baby'),
  DefaultBagItem('nappies', 'baby'),
  DefaultBagItem('blanket', 'baby'),
];

final Random _random = Random();

/// A short unique id for new entries.
String newId() {
  final String time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final String noise = _random.nextInt(1 << 30).toRadixString(36);
  return '$time$noise';
}

// ---- JSON helpers that never throw on unexpected input ----

Map<String, Object?> _map(Object? v) {
  if (v is Map) {
    return v.map((Object? k, Object? value) => MapEntry<String, Object?>('$k', value));
  }
  return <String, Object?>{};
}

List<Object?> _list(Object? v) => v is List ? List<Object?>.from(v) : <Object?>[];

String _str(Object? v, [String fallback = '']) => v is String ? v : fallback;

int _int(Object? v, [int fallback = 0]) {
  if (v is int) {
    return v;
  }
  if (v is num && v.isFinite) {
    return v.round();
  }
  return fallback;
}

double _double(Object? v, [double fallback = 0]) => v is num && v.isFinite ? v.toDouble() : fallback;

bool _bool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

List<T> _items<T>(Object? v, T? Function(Map<String, Object?> m) read) {
  final List<T> out = <T>[];
  for (final Object? item in _list(v)) {
    if (item is Map) {
      final T? parsed = read(_map(item));
      if (parsed != null) {
        out.add(parsed);
      }
    }
  }
  return out;
}

final RegExp _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _clock = RegExp(r'^\d{2}:\d{2}$');

bool isIsoDate(String s) => _isoDate.hasMatch(s);
bool isClock(String s) => _clock.hasMatch(s);

// ---- Entries ----

class Contraction {
  const Contraction({required this.id, required this.start, required this.end});
  final String id;
  final int start;
  final int end;

  int get durationMs => end - start;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 's': start, 'e': end};

  static Contraction? fromJson(Map<String, Object?> m) {
    final int s = _int(m['s']);
    final int e = _int(m['e']);
    if (s <= 0 || e < s) {
      return null;
    }
    return Contraction(id: _str(m['id'], newId()), start: s, end: e);
  }
}

class MoveSession {
  const MoveSession({required this.id, required this.start, required this.end, required this.count});
  final String id;
  final int start;
  final int end;
  final int count;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 's': start, 'e': end, 'n': count};

  static MoveSession? fromJson(Map<String, Object?> m) {
    final int s = _int(m['s']);
    final int e = _int(m['e']);
    if (s <= 0 || e < s) {
      return null;
    }
    return MoveSession(id: _str(m['id'], newId()), start: s, end: e, count: max(0, _int(m['n'])));
  }
}

class RunningMoves {
  const RunningMoves({required this.start, required this.count});
  final int start;
  final int count;

  Map<String, Object?> toJson() => <String, Object?>{'s': start, 'n': count};

  static RunningMoves? fromJson(Object? v) {
    if (v is! Map) {
      return null;
    }
    final Map<String, Object?> m = _map(v);
    final int s = _int(m['s']);
    if (s <= 0) {
      return null;
    }
    return RunningMoves(start: s, count: max(0, _int(m['n'])));
  }
}

class BagItem {
  const BagItem({required this.id, required this.group, required this.text});
  final String id;
  final String group;
  final String text;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'g': group, 'text': text};

  static BagItem? fromJson(Map<String, Object?> m) {
    final String text = _str(m['text']).trim();
    if (text.isEmpty) {
      return null;
    }
    final String g = _str(m['g']) == 'baby' ? 'baby' : 'you';
    return BagItem(id: _str(m['id'], 'x${newId()}'), group: g, text: text);
  }
}

class Appointment {
  const Appointment({required this.id, required this.kind, required this.date, required this.time, required this.note});
  final String id;
  final String kind;
  final String date;
  final String time;
  final String note;

  DateTime get when {
    final List<String> d = date.split('-');
    final List<String> t = time.split(':');
    return DateTime(
      int.tryParse(d[0]) ?? 2000,
      d.length > 1 ? int.tryParse(d[1]) ?? 1 : 1,
      d.length > 2 ? int.tryParse(d[2]) ?? 1 : 1,
      int.tryParse(t[0]) ?? 0,
      t.length > 1 ? int.tryParse(t[1]) ?? 0 : 0,
    );
  }

  /// The saved number that belongs to this kind of appointment, if any.
  String? get role => kind == 'midwife' ? 'midwife' : (kind == 'doctor' ? 'doctor' : null);

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'kind': kind, 'date': date, 'time': time, 'note': note};

  static Appointment? fromJson(Map<String, Object?> m) {
    final String date = _str(m['date']);
    if (!isIsoDate(date)) {
      return null;
    }
    final String time = _str(m['time']);
    final String kind = _str(m['kind']);
    return Appointment(
      id: _str(m['id'], newId()),
      kind: apptKinds.contains(kind) ? kind : 'other',
      date: date,
      time: isClock(time) ? time : '09:00',
      note: _str(m['note']),
    );
  }
}

class Medicine {
  const Medicine({required this.id, required this.name, required this.time});
  final String id;
  final String name;
  final String time;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'name': name, 'time': time};

  static Medicine? fromJson(Map<String, Object?> m) {
    final String name = _str(m['name']).trim();
    if (name.isEmpty) {
      return null;
    }
    final String time = _str(m['time']);
    return Medicine(id: _str(m['id'], newId()), name: name, time: isClock(time) ? time : '20:00');
  }
}

class MedTaken {
  const MedTaken({required this.medId, required this.at});
  final String medId;
  final int at;

  Map<String, Object?> toJson() => <String, Object?>{'id': medId, 't': at};

  static MedTaken? fromJson(Map<String, Object?> m) {
    final int t = _int(m['t']);
    final String id = _str(m['id']);
    if (t <= 0 || id.isEmpty) {
      return null;
    }
    return MedTaken(medId: id, at: t);
  }
}

class WeightEntry {
  const WeightEntry({required this.id, required this.at, required this.kg});
  final String id;
  final int at;
  final double kg;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 't': at, 'kg': kg};

  static WeightEntry? fromJson(Map<String, Object?> m) {
    final int t = _int(m['t']);
    final double kg = _double(m['kg']);
    if (t <= 0 || kg < 30 || kg > 300) {
      return null;
    }
    return WeightEntry(id: _str(m['id'], newId()), at: t, kg: kg);
  }
}

// ---- Everything together ----

class AppData {
  AppData({
    this.onboarded = false,
    this.lang = 'en',
    this.themePref = 'phone',
    this.nightAuto = true,
    this.due = '',
    Map<String, String>? numbers,
    this.supportName = '',
    this.contractions = const <Contraction>[],
    this.seriesStarts = const <int>[],
    this.running = 0,
    this.move,
    this.moves = const <MoveSession>[],
    this.bagDone = const <String>{},
    this.bagCustom = const <BagItem>[],
    this.appts = const <Appointment>[],
    this.meds = const <Medicine>[],
    this.medLog = const <MedTaken>[],
    this.weights = const <WeightEntry>[],
  }) : numbers = numbers ?? <String, String>{for (final String r in numberRoles) r: ''};

  bool onboarded;
  String lang;
  String themePref; // phone, light, dark, night
  bool nightAuto;
  String due; // yyyy-mm-dd or ''
  Map<String, String> numbers;
  String supportName;
  List<Contraction> contractions;

  /// Times where the user (or the 2-hour rule) started a new series of contractions.
  List<int> seriesStarts;
  int running; // start time of a running contraction, or 0
  RunningMoves? move;
  List<MoveSession> moves;
  Set<String> bagDone;
  List<BagItem> bagCustom;
  List<Appointment> appts;
  List<Medicine> meds;
  List<MedTaken> medLog;
  List<WeightEntry> weights;

  String number(String role) => numbers[role] ?? '';

  Map<String, Object?> toJson() => <String, Object?>{
        'v': dataVersion,
        'onboarded': onboarded,
        'lang': lang,
        'themePref': themePref,
        'nightAuto': nightAuto,
        'due': due,
        'numbers': Map<String, String>.from(numbers),
        'supportName': supportName,
        'contractions': contractions.map((Contraction c) => c.toJson()).toList(),
        'seriesStarts': (List<int>.of(seriesStarts)..sort()),
        'running': running,
        'move': move?.toJson(),
        'moves': moves.map((MoveSession m) => m.toJson()).toList(),
        'bagDone': (bagDone.toList()..sort()),
        'bagCustom': bagCustom.map((BagItem b) => b.toJson()).toList(),
        'appts': appts.map((Appointment a) => a.toJson()).toList(),
        'meds': meds.map((Medicine m) => m.toJson()).toList(),
        'medLog': medLog.map((MedTaken l) => l.toJson()).toList(),
        'weights': weights.map((WeightEntry w) => w.toJson()).toList(),
      };

  static AppData fromJson(Object? json) {
    final Map<String, Object?> m = _map(json);
    final Map<String, Object?> rawNumbers = _map(m['numbers']);
    final Map<String, String> numbers = <String, String>{
      for (final String r in numberRoles) r: _str(rawNumbers[r]).trim(),
    };
    // The prototype stored bagDone as {id: true}; the app stores a list of ids.
    final Object? rawBag = m['bagDone'];
    final Set<String> bagDone = <String>{};
    if (rawBag is List) {
      for (final Object? id in rawBag) {
        if (id is String) {
          bagDone.add(id);
        }
      }
    } else if (rawBag is Map) {
      rawBag.forEach((Object? k, Object? v) {
        if (v == true) {
          bagDone.add('$k');
        }
      });
    }
    final String lang = _str(m['lang'], 'en');
    final String theme = _str(m['themePref'], 'phone');
    final String due = _str(m['due']);
    final List<Contraction> contractions = _items(m['contractions'], Contraction.fromJson);
    final List<int> seriesStarts = <int>[];
    if (m.containsKey('seriesStarts')) {
      for (final Object? v in _list(m['seriesStarts'])) {
        final int t = _int(v);
        if (t > 0) {
          seriesStarts.add(t);
        }
      }
    } else {
      // Data from before series existed: split where two hours or more passed.
      final List<Contraction> sorted = List<Contraction>.of(contractions)
        ..sort((Contraction a, Contraction b) => a.start.compareTo(b.start));
      for (int i = 1; i < sorted.length; i++) {
        if (sorted[i].start - sorted[i - 1].end >= autoSeriesGapMs) {
          seriesStarts.add(sorted[i].start);
        }
      }
    }
    seriesStarts.sort();
    return AppData(
      onboarded: _bool(m['onboarded']),
      lang: lang,
      themePref: const <String>['phone', 'light', 'dark', 'night'].contains(theme) ? theme : 'phone',
      nightAuto: _bool(m['nightAuto'], true),
      due: isIsoDate(due) ? due : '',
      numbers: numbers,
      supportName: _str(m['supportName']).trim(),
      contractions: contractions,
      seriesStarts: seriesStarts,
      running: max(0, _int(m['running'])),
      move: RunningMoves.fromJson(m['move']),
      moves: _items(m['moves'], MoveSession.fromJson),
      bagDone: bagDone,
      bagCustom: _items(m['bagCustom'], BagItem.fromJson),
      appts: _items(m['appts'], Appointment.fromJson),
      meds: _items(m['meds'], Medicine.fromJson),
      medLog: _items(m['medLog'], MedTaken.fromJson),
      weights: _items(m['weights'], WeightEntry.fromJson),
    );
  }

  /// A deep, independent copy.
  AppData copy() => AppData.fromJson(jsonDecode(jsonEncode(toJson())));
}
