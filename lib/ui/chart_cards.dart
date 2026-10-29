// Chart cards for contractions (per series) and movement sessions.
import 'package:flutter/material.dart';

import '../data/calc.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../theme/tokens.dart';
import 'charts.dart';
import 'scope.dart';
import 'widgets.dart';

/// "2 h 10 min", "45 min", "3 days".
String sinceText(S t, int ms) {
  final int minutes = (ms / 60000).floor();
  if (minutes < 60) {
    return t('dur_min', <String, Object?>{'m': minutes});
  }
  if (minutes < 24 * 60) {
    return t('dur_hm', <String, Object?>{'h': minutes ~/ 60, 'm': minutes % 60});
  }
  final int days = minutes ~/ (24 * 60);
  return days == 1 ? t('dur_day') : t('dur_days', <String, Object?>{'d': days});
}

/// The trend line's change in words, e.g. "−0,8 min per hour", or "About the same".
class _Trend {
  const _Trend(this.icon, this.text);
  final IconData icon;
  final String text;
}

_Trend? _describeTrend(S t, List<ChartPoint> points, String Function(double) formatChange, String perKey) {
  final TrendLine? line = trendLine(points.map((ChartPoint p) => p.x).toList(), points.map((ChartPoint p) => p.y).toList());
  if (line == null) {
    return null;
  }
  final double span = points.last.x - points.first.x;
  final double mean = points.fold<double>(0, (double a, ChartPoint p) => a + p.y) / points.length;
  final double change = line.slope * span;
  if (span <= 0 || mean == 0 || (change / mean).abs() < 0.05) {
    return _Trend(Icons.trending_flat_rounded, t('ch_flat'));
  }
  final String value = formatChange(line.slope);
  return _Trend(
    line.slope > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
    t(perKey, <String, Object?>{'v': value}),
  );
}

String _signed(String magnitude, double v) => '${v >= 0 ? '+' : '−'}$magnitude';

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.trend});
  final _Trend trend;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    final S t = context.t;
    return Row(
      children: <Widget>[
        Container(width: 18, height: 3, decoration: BoxDecoration(color: c.honey, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Icon(trend.icon, size: 20, color: c.ink),
        const SizedBox(width: 6),
        Expanded(
          child: Text('${t('ch_trend')}: ${trend.text}', style: OmText.label.copyWith(color: c.ink)),
        ),
      ],
    );
  }
}

Widget _cardFrame(BuildContext context, List<Widget> children) {
  final OmColors c = context.om;
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: c.surfaceRaised,
      borderRadius: BorderRadius.circular(OmSize.radiusLg),
      border: Border.all(color: c.line),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: children),
  );
}

// ------------------------------------------------------------------ contractions

class ContractionChartCard extends StatefulWidget {
  const ContractionChartCard({super.key});

  /// True when there is a series with at least two contractions to draw.
  static bool hasData(AppData d) {
    return splitSeries(sortedContractions(d.contractions), d.seriesStarts).any((List<Contraction> s) => s.length >= 2);
  }

  @override
  State<ContractionChartCard> createState() => _ContractionChartCardState();
}

class _ContractionChartCardState extends State<ContractionChartCard> {
  String _metric = 'apart';

  /// Index into the series that have at least two contractions; null = the latest.
  int? _index;

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.store;
    final S t = context.t;
    final Fmt f = Fmt(t);
    final OmColors c = context.om;
    final List<List<Contraction>> all = splitSeries(sortedContractions(store.data.contractions), store.data.seriesStarts)
        .where((List<Contraction> s) => s.length >= 2)
        .toList();
    if (all.isEmpty) {
      return const SizedBox.shrink();
    }
    final int index = (_index ?? all.length - 1).clamp(0, all.length - 1);
    final List<Contraction> series = all[index];
    final DateTime first = DateTime.fromMillisecondsSinceEpoch(series.first.start);
    const double hour = 3600000.0;

    final List<ChartPoint> points = <ChartPoint>[];
    for (int i = 0; i < series.length; i++) {
      final Contraction x = series[i];
      final double at = (x.start - series.first.start) / hour;
      final String when = clockOfMs(x.start);
      switch (_metric) {
        case 'length':
          final double sec = x.durationMs / 1000;
          points.add(ChartPoint(at, sec, '$when · ${formatDuration(sec)}'));
        case 'per10':
          if (i > 0) {
            final double gap = (x.start - series[i - 1].start) / 1000;
            if (gap > 0) {
              final double per10 = 600 / gap;
              points.add(ChartPoint(at, per10, '$when · ${f.oneDecimal(per10)}'));
            }
          }
        default:
          if (i > 0) {
            final double gap = (x.start - series[i - 1].start) / 1000;
            points.add(ChartPoint(at, gap / 60, '$when · ${formatDuration(gap)}'));
          }
      }
    }

    final String title = switch (_metric) {
      'length' => '${t('ch_length')} (s)',
      'per10' => t('ch_per10'),
      _ => '${t('ch_apart')} (min)',
    };
    final _Trend? trend = switch (_metric) {
      'length' => _describeTrend(t, points, (double v) => _signed('${v.abs().round()} s', v), 'ch_per_hour'),
      'per10' => _describeTrend(t, points, (double v) => _signed(f.oneDecimal(v.abs()), v), 'ch_per_hour'),
      _ => _describeTrend(t, points, (double v) => _signed('${f.oneDecimal(v.abs())} min', v), 'ch_per_hour'),
    };
    final ContractionStats stats = statsOf(series);
    final String summary = t('h_summary', <String, Object?>{
      'a': formatDuration(stats.avgIntervalSec),
      'd': formatDuration(stats.avgDurationSec),
    });
    final String seriesLabel =
        '${t('c_series_from', <String, Object?>{'t': '${f.dayLabel(series.first.start)} ${clockOf(first)}'})} · '
        '${t('c_series_count', <String, Object?>{'n': series.length})}';

    return _cardFrame(context, <Widget>[
      Row(
        children: <Widget>[
          if (all.length > 1)
            OmIconButton(
              icon: Icons.chevron_left_rounded,
              label: t('c_series_prev'),
              onPressed: index > 0 ? () => setState(() => _index = index - 1) : null,
            ),
          Expanded(
            child: Text(
              seriesLabel,
              textAlign: all.length > 1 ? TextAlign.center : TextAlign.start,
              style: OmText.captionBold.copyWith(color: c.inkMuted),
            ),
          ),
          if (all.length > 1)
            OmIconButton(
              icon: Icons.chevron_right_rounded,
              label: t('c_series_next'),
              onPressed: index < all.length - 1 ? () => setState(() => _index = index + 1 == all.length - 1 ? null : index + 1) : null,
            ),
        ],
      ),
      Segmented<String>(
        items: <ChoiceItem<String>>[
          ChoiceItem<String>('apart', t('ch_tab_apart')),
          ChoiceItem<String>('length', t('ch_tab_length')),
          ChoiceItem<String>('per10', t('ch_tab_per10')),
        ],
        value: _metric,
        onChanged: (String m) => setState(() => _metric = m),
      ),
      Text(title, style: OmText.title.copyWith(color: c.ink)),
      if (points.length >= 2)
        TrendChart(
          points: points,
          formatAxis: (double v) => _metric == 'per10' ? f.oneDecimal(v) : (v == v.roundToDouble() ? '${v.round()}' : f.oneDecimal(v)),
          startLabel: clockOfMs(series.first.start),
          endLabel: clockOfMs(series.last.start),
          semanticsLabel: '$title. $seriesLabel. ${trend == null ? '' : '${t('ch_trend')}: ${trend.text}.'}',
        ),
      if (trend != null) _TrendRow(trend: trend),
      Text(summary, style: OmText.body.copyWith(color: c.ink)),
      Text(t('ch_hint'), style: OmText.caption.copyWith(color: c.inkMuted)),
    ]);
  }
}

// ------------------------------------------------------------------ movements

class MovementChartCard extends StatelessWidget {
  const MovementChartCard({super.key});

  static bool hasData(AppData d) => d.moves.length >= 2;

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.store;
    final S t = context.t;
    final Fmt f = Fmt(t);
    final OmColors c = context.om;
    final List<MoveSession> sessions = List<MoveSession>.of(store.data.moves)
      ..sort((MoveSession a, MoveSession b) => a.start.compareTo(b.start));
    if (sessions.length < 2) {
      return const SizedBox.shrink();
    }
    final List<MoveSession> shown = sessions.length > 20 ? sessions.sublist(sessions.length - 20) : sessions;
    const double day = 86400000.0;
    final List<ChartPoint> points = <ChartPoint>[
      for (final MoveSession m in shown)
        ChartPoint(
          (m.start - shown.first.start) / day,
          m.count.toDouble(),
          '${f.weekdayShort(DateTime.fromMillisecondsSinceEpoch(m.start))} ${clockOfMs(m.start)} · ${m.count}',
        ),
    ];
    final _Trend? trend = _describeTrend(t, points, (double v) => _signed(f.oneDecimal(v.abs()), v), 'ch_per_day');
    final String title = t('ch_moves');
    return _cardFrame(context, <Widget>[
      Text(title, style: OmText.title.copyWith(color: c.ink)),
      TrendChart(
        points: points,
        formatAxis: (double v) => '${v.round()}',
        startLabel: f.dayMonthShort(DateTime.fromMillisecondsSinceEpoch(shown.first.start)),
        endLabel: f.dayMonthShort(DateTime.fromMillisecondsSinceEpoch(shown.last.start)),
        semanticsLabel: '$title. ${trend == null ? '' : '${t('ch_trend')}: ${trend.text}.'}',
      ),
      if (trend != null) _TrendRow(trend: trend),
      Text(t('ch_hint'), style: OmText.caption.copyWith(color: c.inkMuted)),
    ]);
  }
}
