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

/// 13:58:07
String clockWithSeconds(DateTime d) => '${pad2(d.hour)}:${pad2(d.minute)}:${pad2(d.second)}';

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

/// Splits contractions (sorted by start) into series. A new series begins at
/// every time in [seriesStarts] that falls after one contraction and at or
/// before the next.
List<List<Contraction>> splitSeries(List<Contraction> sorted, List<int> seriesStarts) {
  final List<List<Contraction>> out = <List<Contraction>>[];
  if (sorted.isEmpty) {
    return out;
  }
  final List<int> marks = List<int>.of(seriesStarts)..sort();
  List<Contraction> current = <Contraction>[sorted.first];
  for (int i = 1; i < sorted.length; i++) {
    final int prev = sorted[i - 1].start;
    final int cur = sorted[i].start;
    if (marks.any((int t) => t > prev && t <= cur)) {
      out.add(current);
      current = <Contraction>[];
    }
    current.add(sorted[i]);
  }
  out.add(current);
  return out;
}

/// The series new contractions are added to. Empty when the user has just
/// started a new series and not timed anything in it yet.
List<Contraction> currentSeries(List<Contraction> sorted, List<int> seriesStarts) {
  if (sorted.isEmpty) {
    return const <Contraction>[];
  }
  final int lastMark = seriesStarts.isEmpty ? 0 : seriesStarts.reduce(max);
  if (lastMark > sorted.last.start) {
    return const <Contraction>[];
  }
  return splitSeries(sorted, seriesStarts).last;
}

ContractionStats contractionStats(List<Contraction> list, int nowMs, {List<int> seriesStarts = const <int>[]}) {
  final List<Contraction> sorted = sortedContractions(list);
  final List<Contraction> run = currentSeries(sorted, seriesStarts);
  return statsOf(run, inLastHour: sorted.where((Contraction c) => c.start >= nowMs - 3600000).length);
}

/// Averages over the last six contractions of [series] (sorted by start).
ContractionStats statsOf(List<Contraction> series, {int inLastHour = 0}) {
  final List<Contraction> last = series.length > 6 ? series.sublist(series.length - 6) : series;
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
  return ContractionStats(sample: last.length, avgDurationSec: avgDur, avgIntervalSec: avgGap, inLastHour: inLastHour);
}

/// Seconds since the previous contraction started, or null for the first one
/// of a series.
double? intervalBefore(List<Contraction> sorted, int index, {List<int> seriesStarts = const <int>[]}) {
  if (index <= 0 || index >= sorted.length) {
    return null;
  }
  final int prev = sorted[index - 1].start;
  final int cur = sorted[index].start;
  if (seriesStarts.any((int t) => t > prev && t <= cur)) {
    return null;
  }
  return (cur - prev) / 1000;
}

/// Straight line through points by least squares: y = intercept + slope * x.
class TrendLine {
  const TrendLine(this.slope, this.intercept);
  final double slope;
  final double intercept;

  double at(double x) => intercept + slope * x;
}

/// Needs at least three points with different x.
TrendLine? trendLine(List<double> xs, List<double> ys) {
  final int n = xs.length;
  if (n < 3 || ys.length != n) {
    return null;
  }
  final double mx = xs.reduce((double a, double b) => a + b) / n;
  final double my = ys.reduce((double a, double b) => a + b) / n;
  double sxx = 0;
  double sxy = 0;
  for (int i = 0; i < n; i++) {
    sxx += (xs[i] - mx) * (xs[i] - mx);
    sxy += (xs[i] - mx) * (ys[i] - my);
  }
  if (sxx == 0) {
    return null;
  }
  final double slope = sxy / sxx;
  return TrendLine(slope, my - slope * mx);
}

/// A "nice" step for about [ticks] axis lines between 0 and [maxValue].
double niceStep(double maxValue, {int ticks = 4}) {
  if (maxValue <= 0) {
    return 1;
  }
  final double raw = maxValue / ticks;
  final double mag = pow(10, (log(raw) / ln10).floor()).toDouble();
  final double norm = raw / mag;
  final double nice = norm <= 1 ? 1 : (norm <= 2 ? 2 : (norm <= 2.5 ? 2.5 : (norm <= 5 ? 5 : 10)));
  return nice * mag;
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
