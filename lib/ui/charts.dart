// A small line chart with a dashed trend line, drawn to the design tokens.
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/calc.dart';
import '../theme/tokens.dart';

class ChartPoint {
  const ChartPoint(this.x, this.y, this.label);

  /// Position along the time axis, e.g. hours or days since the first point.
  final double x;
  final double y;

  /// Shown above the chart when the point is selected, e.g. "13:42 · 5:12".
  final String label;
}

class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.formatAxis,
    required this.startLabel,
    required this.endLabel,
    required this.semanticsLabel,
    this.height = 200,
  });

  final List<ChartPoint> points;

  /// Labels for the value axis.
  final String Function(double value) formatAxis;
  final String startLabel;
  final String endLabel;

  /// What a screen reader says for the whole chart (values and trend).
  final String semanticsLabel;
  final double height;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _selected;

  @override
  void didUpdateWidget(TrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected != null && _selected! >= widget.points.length) {
      _selected = null;
    }
  }

  void _pick(Offset local, double width) {
    final _Layout layout = _Layout(widget.points, Size(width, widget.height));
    int? best;
    double bestDist = double.infinity;
    for (int i = 0; i < widget.points.length; i++) {
      final double d = (layout.px(widget.points[i].x) - local.dx).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    if (best != _selected) {
      setState(() => _selected = best);
    }
  }

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final double width = box.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (TapDownDetails d) => _pick(d.localPosition, width),
              onHorizontalDragDown: (DragDownDetails d) => _pick(d.localPosition, width),
              onHorizontalDragUpdate: (DragUpdateDetails d) => _pick(d.localPosition, width),
              child: CustomPaint(
                size: Size(width, widget.height),
                painter: _TrendPainter(
                  points: widget.points,
                  colors: c,
                  formatAxis: widget.formatAxis,
                  startLabel: widget.startLabel,
                  endLabel: widget.endLabel,
                  selected: _selected,
                  textScaler: MediaQuery.textScalerOf(context),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Where things go inside the chart.
class _Layout {
  _Layout(this.points, this.size) {
    final List<double> ys = points.map((ChartPoint p) => p.y).toList();
    double top = ys.isEmpty ? 1 : ys.reduce(max);
    final TrendLine? trend = trendLine(points.map((ChartPoint p) => p.x).toList(), ys);
    if (trend != null && points.isNotEmpty) {
      top = max(top, max(trend.at(points.first.x), trend.at(points.last.x)));
    }
    step = niceStep(top <= 0 ? 1 : top * 1.05);
    yTop = (top / step).ceil() * step;
    if (yTop <= 0) {
      yTop = step;
    }
    xMin = points.isEmpty ? 0 : points.first.x;
    xMax = points.isEmpty ? 1 : points.last.x;
  }

  static const double left = 44;
  static const double right = 12;
  static const double top = 36; // room for the selected value
  static const double bottom = 28; // room for the time labels

  final List<ChartPoint> points;
  final Size size;
  late final double step;
  late final double yTop;
  late final double xMin;
  late final double xMax;

  double get plotWidth => size.width - left - right;
  double get plotHeight => size.height - top - bottom;

  double px(double x) {
    if (xMax == xMin) {
      return left + plotWidth / 2;
    }
    return left + (x - xMin) / (xMax - xMin) * plotWidth;
  }

  double py(double y) => top + plotHeight - (y.clamp(0, yTop) / yTop) * plotHeight;
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.colors,
    required this.formatAxis,
    required this.startLabel,
    required this.endLabel,
    required this.selected,
    required this.textScaler,
  });

  final List<ChartPoint> points;
  final OmColors colors;
  final String Function(double) formatAxis;
  final String startLabel;
  final String endLabel;
  final int? selected;
  final TextScaler textScaler;

  TextPainter _text(String s, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler.clamp(maxScaleFactor: 1.3),
      maxLines: 1,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final _Layout l = _Layout(points, size);
    final TextStyle axis = OmText.caption.copyWith(color: colors.inkMuted, fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]);

    // Grid and value labels.
    final Paint grid = Paint()
      ..color = colors.line
      ..strokeWidth = 1;
    for (double v = 0; v <= l.yTop + l.step / 1000; v += l.step) {
      final double y = l.py(v);
      canvas.drawLine(Offset(_Layout.left, y), Offset(size.width - _Layout.right, y), grid);
      final TextPainter tp = _text(formatAxis(v), axis);
      tp.paint(canvas, Offset(_Layout.left - 8 - tp.width, y - tp.height / 2));
    }

    // Time labels.
    final double baseY = size.height - _Layout.bottom + 6;
    final TextPainter start = _text(startLabel, axis);
    start.paint(canvas, Offset(_Layout.left, baseY));
    final TextPainter end = _text(endLabel, axis);
    if (end.width + start.width + 16 < l.plotWidth) {
      end.paint(canvas, Offset(size.width - _Layout.right - end.width, baseY));
    }

    if (points.isEmpty) {
      return;
    }

    // Trend line (dashed).
    final TrendLine? trend = trendLine(points.map((ChartPoint p) => p.x).toList(), points.map((ChartPoint p) => p.y).toList());
    if (trend != null) {
      final Offset a = Offset(l.px(l.xMin), l.py(trend.at(l.xMin)));
      final Offset b = Offset(l.px(l.xMax), l.py(trend.at(l.xMax)));
      final Paint dash = Paint()
        ..color = colors.honey
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final double length = (b - a).distance;
      if (length > 0) {
        final Offset dir = (b - a) / length;
        for (double d = 0; d < length; d += 12) {
          canvas.drawLine(a + dir * d, a + dir * min(d + 6, length), dash);
        }
      }
    }

    // The values.
    final Path path = Path();
    for (int i = 0; i < points.length; i++) {
      final Offset o = Offset(l.px(points[i].x), l.py(points[i].y));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.clay
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    final Paint dot = Paint()..color = colors.clay;
    final Paint ring = Paint()..color = colors.surfaceRaised;
    final double r = points.length > 24 ? 3 : 4;
    for (final ChartPoint p in points) {
      final Offset o = Offset(l.px(p.x), l.py(p.y));
      canvas.drawCircle(o, r + 2, ring);
      canvas.drawCircle(o, r, dot);
    }

    // The selected point and its value.
    if (selected != null && selected! < points.length) {
      final ChartPoint p = points[selected!];
      final Offset o = Offset(l.px(p.x), l.py(p.y));
      canvas.drawLine(
        Offset(o.dx, _Layout.top),
        Offset(o.dx, size.height - _Layout.bottom),
        Paint()
          ..color = colors.lineStrong
          ..strokeWidth = 1,
      );
      canvas.drawCircle(o, 7, ring);
      canvas.drawCircle(o, 6, dot);
      final TextPainter label = _text(p.label, OmText.captionBold.copyWith(color: colors.surface));
      final double w = label.width + 16;
      final double h = label.height + 8;
      final double x = (o.dx - w / 2).clamp(0.0, max(0.0, size.width - w));
      final RRect box = RRect.fromRectAndRadius(Rect.fromLTWH(x, 2, w, h), const Radius.circular(8));
      canvas.drawRRect(box, Paint()..color = colors.ink);
      label.paint(canvas, Offset(x + 8, 6));
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points || old.selected != selected || old.colors != colors || old.startLabel != startLabel || old.endLabel != endLabel;
}
