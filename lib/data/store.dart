import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../l10n/strings.dart';
import '../services/reminders.dart';
import 'calc.dart';
import 'models.dart';
import 'storage.dart';

int _nowMs() => DateTime.now().millisecondsSinceEpoch;

/// Holds the app's data, saves every change to the phone, and offers undo
/// for anything that removes or replaces what the user logged.
class AppStore extends ChangeNotifier {
  AppStore({
    required this.storage,
    this.reminders = const NoReminders(),
    AppData? data,
    this.saveDelay = const Duration(milliseconds: 300),
  }) : data = data ?? AppData();

  /// Reads saved data, or starts fresh in [initialLang] the first time.
  static Future<AppStore> open({
    required StateStorage storage,
    Reminders reminders = const NoReminders(),
    String initialLang = 'en',
    Duration saveDelay = const Duration(milliseconds: 300),
  }) async {
    AppData data = AppData(lang: initialLang);
    try {
      final String? raw = await storage.read();
      if (raw != null && raw.trim().isNotEmpty) {
        data = AppData.fromJson(jsonDecode(raw));
      }
    } catch (_) {
      // Unreadable file: start fresh rather than crash.
    }
    if (!appLanguages.contains(data.lang)) {
      data.lang = initialLang;
    }
    return AppStore(storage: storage, reminders: reminders, data: data, saveDelay: saveDelay);
  }

  final StateStorage storage;
  final Reminders reminders;
  final Duration saveDelay;
  AppData data;

  /// One-tap theme switch on the timers, for this session only: '', 'night' or 'day'.
  String sessionTheme = '';

  Timer? _saveTimer;
  Future<void> _writing = Future<void>.value();

  S get t => S(data.lang);

  // ---------------------------------------------------------------- saving

  void _changed({bool meds = false}) {
    notifyListeners();
    _scheduleSave();
    if (meds) {
      unawaited(syncReminders());
    }
  }

  void _scheduleSave() {
    if (saveDelay == Duration.zero) {
      unawaited(flush());
      return;
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () {
      unawaited(flush());
    });
  }

  /// Writes the current data now. Writes never overlap.
  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final String json = jsonEncode(data.toJson());
    _writing = _writing.then((_) async {
      try {
        await storage.write(json);
      } catch (_) {
        // Keep running; the next change tries again.
      }
    });
    return _writing;
  }

  Future<void> syncReminders() async {
    try {
      await reminders.sync(data.meds, t);
    } catch (_) {
      // Reminders are a convenience; never let them break the app.
    }
  }

  /// Redraws everything, for example when the app returns to the foreground on a new day.
  void touch() => notifyListeners();

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- settings

  void setLang(String lang) {
    if (!appLanguages.contains(lang) || lang == data.lang) {
      return;
    }
    data.lang = lang;
    _changed(meds: true); // reminder text follows the language
  }

  void setThemePref(String pref) {
    data.themePref = pref;
    sessionTheme = '';
    _changed();
  }

  void setNightAuto(bool on) {
    data.nightAuto = on;
    _changed();
  }

  void setSessionTheme(String value) {
    sessionTheme = value;
    notifyListeners();
  }

  void completeOnboarding() {
    data.onboarded = true;
    _changed();
  }

  void restartOnboarding() {
    data.onboarded = false;
    _changed();
  }

  void setDue(String iso) {
    data.due = isIsoDate(iso) ? iso : '';
    _changed();
  }

  void setNumber(String role, String number, {String? name}) {
    data.numbers = Map<String, String>.from(data.numbers)..[role] = number.trim();
    if (role == 'support' && name != null) {
      data.supportName = name.trim();
    }
    _changed();
  }

  void removeNumber(String role) {
    data.numbers = Map<String, String>.from(data.numbers)..[role] = '';
    if (role == 'support') {
      data.supportName = '';
    }
    _changed();
  }

  int get savedNumberCount => numberRoles.where((String r) => data.number(r).isNotEmpty).length;

  // ---------------------------------------------------------------- contractions

  void startContraction({int? now}) {
    if (data.running != 0) {
      return;
    }
    data.running = now ?? _nowMs();
    _changed();
  }

  /// Stops the running contraction and returns an undo that restarts it.
  VoidCallback? stopContraction({int? now}) {
    if (data.running == 0) {
      return null;
    }
    final List<Contraction> before = data.contractions;
    final int startedAt = data.running;
    final int end = max(now ?? _nowMs(), startedAt);
    data.contractions = <Contraction>[...before, Contraction(id: newId(), start: startedAt, end: end)];
    data.running = 0;
    _changed();
    return () {
      data.contractions = before;
      data.running = startedAt;
      _changed();
    };
  }

  void updateContraction(String id, {required int start, required int end}) {
    data.contractions = data.contractions.map((Contraction c) {
      if (c.id != id) {
        return c;
      }
      final int safeEnd = end > start ? end : start + c.durationMs;
      return Contraction(id: c.id, start: start, end: safeEnd);
    }).toList();
    _changed();
  }

  VoidCallback deleteContraction(String id) {
    final List<Contraction> before = data.contractions;
    data.contractions = before.where((Contraction c) => c.id != id).toList();
    _changed();
    return () {
      data.contractions = before;
      _changed();
    };
  }

  // ---------------------------------------------------------------- movements

  void startMoves({int? now}) {
    if (data.move != null) {
      return;
    }
    data.move = RunningMoves(start: now ?? _nowMs(), count: 0);
    _changed();
  }

  void countMove() {
    final RunningMoves? m = data.move;
    if (m == null) {
      return;
    }
    data.move = RunningMoves(start: m.start, count: m.count + 1);
    _changed();
  }

  VoidCallback? endMoves({int? now}) {
    final RunningMoves? m = data.move;
    if (m == null) {
      return null;
    }
    final List<MoveSession> before = data.moves;
    final int end = max(now ?? _nowMs(), m.start);
    data.moves = <MoveSession>[...before, MoveSession(id: newId(), start: m.start, end: end, count: m.count)];
    data.move = null;
    _changed();
    return () {
      data.moves = before;
      data.move = m;
      _changed();
    };
  }

  // ---------------------------------------------------------------- hospital bag

  void toggleBag(String id) {
    final Set<String> next = Set<String>.from(data.bagDone);
    if (!next.remove(id)) {
      next.add(id);
    }
    data.bagDone = next;
    _changed();
  }

  void addBagItem(String group, String text) {
    final String clean = text.trim();
    if (clean.isEmpty) {
      return;
    }
    data.bagCustom = <BagItem>[...data.bagCustom, BagItem(id: 'x${newId()}', group: group == 'baby' ? 'baby' : 'you', text: clean)];
    _changed();
  }

  VoidCallback removeBagItem(String id) {
    final List<BagItem> before = data.bagCustom;
    final Set<String> doneBefore = data.bagDone;
    data.bagCustom = before.where((BagItem b) => b.id != id).toList();
    data.bagDone = Set<String>.from(doneBefore)..remove(id);
    _changed();
    return () {
      data.bagCustom = before;
      data.bagDone = doneBefore;
      _changed();
    };
  }

  // ---------------------------------------------------------------- appointments

  void saveAppt(Appointment a) {
    final bool exists = data.appts.any((Appointment x) => x.id == a.id);
    data.appts = exists
        ? data.appts.map((Appointment x) => x.id == a.id ? a : x).toList()
        : <Appointment>[...data.appts, a];
    _changed();
  }

  VoidCallback deleteAppt(String id) {
    final List<Appointment> before = data.appts;
    data.appts = before.where((Appointment a) => a.id != id).toList();
    _changed();
    return () {
      data.appts = before;
      _changed();
    };
  }

  // ---------------------------------------------------------------- medicines

  void saveMed(Medicine m) {
    final bool exists = data.meds.any((Medicine x) => x.id == m.id);
    data.meds = exists ? data.meds.map((Medicine x) => x.id == m.id ? m : x).toList() : <Medicine>[...data.meds, m];
    _changed(meds: true);
  }

  VoidCallback deleteMed(String id) {
    final List<Medicine> before = data.meds;
    data.meds = before.where((Medicine m) => m.id != id).toList();
    _changed(meds: true);
    return () {
      data.meds = before;
      _changed(meds: true);
    };
  }

  bool takenToday(String medId, {int? now}) {
    final int dayStart = startOfDay(now ?? _nowMs());
    return data.medLog.any((MedTaken l) => l.medId == medId && l.at >= dayStart);
  }

  VoidCallback markTaken(String medId, {int? now}) {
    final List<MedTaken> before = data.medLog;
    data.medLog = <MedTaken>[...before, MedTaken(medId: medId, at: now ?? _nowMs())];
    _changed();
    return () {
      data.medLog = before;
      _changed();
    };
  }

  // ---------------------------------------------------------------- weight

  void addWeight(double kg, {int? now}) {
    data.weights = <WeightEntry>[...data.weights, WeightEntry(id: newId(), at: now ?? _nowMs(), kg: kg)];
    _changed();
  }

  VoidCallback deleteWeight(String id) {
    final List<WeightEntry> before = data.weights;
    data.weights = before.where((WeightEntry w) => w.id != id).toList();
    _changed();
    return () {
      data.weights = before;
      _changed();
    };
  }

  // ---------------------------------------------------------------- everything

  /// Removes everything except the chosen language, and starts from the first screen.
  void deleteEverything() {
    data = AppData(lang: data.lang);
    sessionTheme = '';
    _changed(meds: true);
  }

  /// Replaces everything with a restored backup.
  void replaceAll(AppData restored) {
    final AppData next = restored.copy();
    next.onboarded = true;
    if (!appLanguages.contains(next.lang)) {
      next.lang = data.lang;
    }
    data = next;
    sessionTheme = '';
    _changed(meds: true);
  }

  /// Sample data for trying the app (debug builds only).
  void fillSample({int? now}) {
    final int n = now ?? _nowMs();
    final List<Contraction> list = <Contraction>[];
    for (int i = 0; i < 12; i++) {
      final int start = (n - (63 - i * 5.3) * 60000 + ((i % 3) - 1) * 15000).round();
      final int dur = 52000 + ((i * 7) % 14) * 1000;
      list.add(Contraction(id: 'c$i-$n', start: start, end: start + dur));
    }
    final DateTime y = DateTime.fromMillisecondsSinceEpoch(n - 86400000);
    final int yEvening = DateTime(y.year, y.month, y.day, 21, 40).millisecondsSinceEpoch;
    final DateTime appt = DateTime.fromMillisecondsSinceEpoch(n + 5 * 86400000);
    data.contractions = <Contraction>[...data.contractions, ...list];
    data.running = 0;
    data.moves = <MoveSession>[...data.moves, MoveSession(id: newId(), start: yEvening, end: yEvening + 22 * 60000, count: 14)];
    data.bagDone = <String>{...data.bagDone, 'id', 'record', 'charger', 'clothes', 'carseat'};
    data.appts = <Appointment>[
      ...data.appts,
      Appointment(id: newId(), kind: 'midwife', date: isoDate(appt), time: '10:30', note: ''),
    ];
    if (data.meds.isEmpty) {
      data.meds = <Medicine>[Medicine(id: newId(), name: t('sample_med'), time: '20:00')];
    }
    data.weights = <WeightEntry>[
      ...data.weights,
      WeightEntry(id: newId(), at: n - 42 * 86400000, kg: 71.2),
      WeightEntry(id: newId(), at: n - 21 * 86400000, kg: 72.0),
      WeightEntry(id: newId(), at: n - 2 * 86400000, kg: 72.9),
    ];
    if (data.due.isEmpty) {
      data.due = isoDate(DateTime.fromMillisecondsSinceEpoch(n + 28 * 86400000));
    }
    _changed(meds: true);
  }
}
