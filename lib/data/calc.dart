// Pure calculations, kept apart from the UI so they are easy to test.
import 'dart:math';

import 'models.dart';

String pad2(int n) => n.toString().padLeft(2, '0');

/// 75 seconds -> '1:15'.
String formatDuration(num seconds) {
  final int s = max(0, seconds.round());
  return '${s ~/ 60}:${pad2(s % 60)}';
}

/// 75 seconds -> '01:15' (the running timer).
String formatTimer(int seconds) {
  final int s = max(0, seconds);
  return '${pad2(s ~/ 60)}:${pad2(s % 60)}';
}

String clockOf(DateTime d) => '${pad2(d.hour)}:${pad2(d.minute)}';

String clockOfMs(int ms) => clockOf(DateTime.fromMillisecondsSinceEpoch(ms));

String isoDate(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';

DateTime? parseIsoDate(String s) {
  if (!isIsoDate(s)) {
    return null;
  }
  final List<String> p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Parses '07:30' into hours and minutes.
({int hour, int minute})? parseClock(String s) {
  final List<String> p = s.split(':');
  if (p.length != 2) {
    return null;
  }
  final int? h = int.tryParse(p[0]);
  final int? m = int.tryParse(p[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return null;
  }
  return (hour: h, minute: m);
}

int startOfDay(int ms) {
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
  return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
}

/// Whole calendar days from [a] to [b], ignoring the clock and daylight saving.
int calendarDaysBetween(DateTime a, DateTime b) {
  final DateTime ua = DateTime.utc(a.year, a.month, a.day);
  final DateTime ub = DateTime.utc(b.year, b.month, b.day);
  return (ub.difference(ua).inHours / 24).round();
}

class PregnancyWeek {
  const PregnancyWeek({
    required this.week,
    required this.days,
    required this.daysToDue,
    required this.trimester,
    required this.progress,
  });

  final int week;
  final int days;
  final int daysToDue;
  final int trimester;
  final double progress; // 0..1
}

/// Week of pregnancy from a due date, counting 280 days from the last period.
PregnancyWeek? pregnancyWeek(String due, DateTime now) {
  final DateTime? dueDate = parseIsoDate(due);
  if (dueDate == null) {
    return null;
  }
  final int daysToDue = calendarDaysBetween(now, dueDate);
  final int ga = 280 - daysToDue;
  final int week = max(0, (ga / 7).floor());
  final int days = max(0, ga - week * 7);
  final int trimester = week <= 12 ? 1 : (week <= 27 ? 2 : 3);
  final double progress = (ga / 280).clamp(0.0, 1.0).toDouble();
  return PregnancyWeek(week: week, days: days, daysToDue: daysToDue, trimester: trimester, progress: progress);
}

class ContractionStats {
  const ContractionStats({
    required this.sample,
    required this.avgDurationSec,
    required this.avgIntervalSec,
    required this.inLastHour,
  });

  /// How many recent contractions the averages are based on (at most 6).
  final int sample;
  final double avgDurationSec;

  /// Average time from the start of one contraction to the start of the next; 0 if unknown.
  final double avgIntervalSec;
  final int inLastHour;

  /// How many contractions come per 10 minutes at the average interval; 0 if unknown.
  double get per10Min => avgIntervalSec > 0 ? 600 / avgIntervalSec : 0;
}

List<Contraction> sortedContractions(List<Contraction> list) {
  return List<Contraction>.of(list)..sort((Contraction a, Contraction b) => a.start.compareTo(b.start));
}

/// Contractions more than an hour apart belong to different runs (another day,
/// false labour). Intervals across that gap are not shown or averaged.
const int runGapMs = 60 * 60 * 1000;

/// The latest run: the newest contractions with less than an hour between starts.
List<Contraction> currentRun(List<Contraction> sorted) {
  if (sorted.isEmpty) {
    return const <Contraction>[];
  }
  int first = sorted.length - 1;
  while (first > 0 && sorted[first].start - sorted[first - 1].start <= runGapMs) {
    first--;
  }
  return sorted.sublist(first);
}

ContractionStats contractionStats(List<Contraction> list, int nowMs) {
  final List<Contraction> sorted = sortedContractions(list);
  final List<Contraction> run = currentRun(sorted);
  final List<Contraction> last = run.length > 6 ? run.sublist(run.length - 6) : run;
  double avgDur = 0;
  if (last.isNotEmpty) {
    avgDur = last.fold<int>(0, (int sum, Contraction c) => sum + c.durationMs) / last.length / 1000;
  }
  double avgGap = 0;
  if (last.length >= 2) {
    int total = 0;
    for (int i = 1; i < last.length; i++) {
      total += last[i].start - last[i - 1].start;
    }
    avgGap = total / (last.length - 1) / 1000;
  }
  final int inHour = sorted.where((Contraction c) => c.start >= nowMs - 3600000).length;
  return ContractionStats(sample: last.length, avgDurationSec: avgDur, avgIntervalSec: avgGap, inLastHour: inHour);
}

/// Seconds since the previous contraction started, or null for the first one
/// of a run (none before it, or more than an hour since the previous one).
double? intervalBefore(List<Contraction> sorted, int index) {
  if (index <= 0 || index >= sorted.length) {
    return null;
  }
  final int gap = sorted[index].start - sorted[index - 1].start;
  if (gap > runGapMs) {
    return null;
  }
  return gap / 1000;
}

/// Puts a clock time picked by the user on the day (yesterday, same day or
/// tomorrow, seen from [original]) that is closest to [original]. Keeps times
/// near midnight on the right side of it.
DateTime nearestClockTime(DateTime original, int hour, int minute, {int second = 0}) {
  DateTime best = original;
  int bestDiff = -1;
  for (final int dayOffset in <int>[-1, 0, 1]) {
    final DateTime candidate = DateTime(original.year, original.month, original.day + dayOffset, hour, minute, second);
    final int diff = (candidate.millisecondsSinceEpoch - original.millisecondsSinceEpoch).abs();
    if (bestDiff < 0 || diff < bestDiff) {
      best = candidate;
      bestDiff = diff;
    }
  }
  return best;
}

/// Accepts '72,5' or '72.5'. Returns null when outside 30–300 kg.
double? parseKg(String input) {
  final double? v = double.tryParse(input.trim().replaceAll(',', '.'));
  if (v == null || !v.isFinite || v < 30 || v > 300) {
    return null;
  }
  return (v * 10).round() / 10;
}

/// Keeps only what a phone dialler understands.
String dialable(String number) => number.replaceAll(RegExp(r'[^0-9+*#]'), '');
