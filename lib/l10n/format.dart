import 'package:intl/intl.dart';

import '../data/calc.dart';
import 'strings.dart';

/// Dates, times and numbers in the user's language. Times always use the 24-hour clock.
class Fmt {
  Fmt(this.t);

  final S t;

  String get _loc => t.intlLocale;

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// 21:40
  String time(int ms) => clockOfMs(ms);

  /// 29 October / 29. oktober
  String dayMonth(DateTime d) => DateFormat.MMMMd(_loc).format(d);

  /// Thursday 29 October / Torsdag 29. oktober
  String weekdayLong(DateTime d) => _cap(DateFormat.MMMMEEEEd(_loc).format(d));

  /// Thu 29 Oct / Tor. 29. okt.
  String weekdayShort(DateTime d) => _cap(DateFormat.MMMEd(_loc).format(d));

  /// 3 Nov / 3. nov.
  String dayMonthShort(DateTime d) => DateFormat.MMMd(_loc).format(d);

  /// 29 Oct 2026 / 29. okt. 2026
  String date(DateTime d) => DateFormat.yMMMd(_loc).format(d);

  /// 29 October 2026
  String dateLong(DateTime d) => DateFormat.yMMMMd(_loc).format(d);

  /// 72.9 / 72,9
  String kg(double v) => NumberFormat('0.0', _loc).format(v);

  /// 1.9 / 1,9
  String oneDecimal(double v) => NumberFormat('0.0', _loc).format(v);

  /// '+1,7' or '−0,4'
  String kgSigned(double v) => '${v >= 0 ? '+' : '−'}${kg(v.abs())}';

  /// Today / Yesterday / Tue 27 Oct
  String dayLabel(int ms, {int? now}) {
    final int today = startOfDay(now ?? DateTime.now().millisecondsSinceEpoch);
    final int day = startOfDay(ms);
    if (day == today) {
      return t('today');
    }
    if (day == startOfDay(today - 3600000)) {
      return t('yesterday');
    }
    return weekdayShort(DateTime.fromMillisecondsSinceEpoch(ms));
  }
}
