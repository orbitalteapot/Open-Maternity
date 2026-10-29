import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../data/calc.dart';
import '../data/models.dart';
import '../l10n/format.dart';
import '../l10n/strings.dart';

const PdfColor _clay = PdfColor.fromInt(0xFFA8502F);
const PdfColor _ink = PdfColor.fromInt(0xFF2E241F);
const PdfColor _muted = PdfColor.fromInt(0xFF685850);
const PdfColor _line = PdfColor.fromInt(0xFFE8DCCD);
const PdfColor _soft = PdfColor.fromInt(0xFFF7E0D4);

/// Builds a one- or two-page PDF of what was logged, for the user to share herself.
Future<Uint8List> buildSummaryPdf(AppData data, S t, DateTime now) async {
  final pw.Font regular = pw.Font.ttf(await rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-Regular.ttf'));
  final pw.Font bold = pw.Font.ttf(await rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-Bold.ttf'));
  final Fmt f = Fmt(t);
  final int nowMs = now.millisecondsSinceEpoch;

  final pw.TextStyle body = pw.TextStyle(font: regular, fontSize: 11, color: _ink, lineSpacing: 2);
  final pw.TextStyle muted = body.copyWith(color: _muted, fontSize: 10);
  final pw.TextStyle h1 = pw.TextStyle(font: bold, fontSize: 20, color: _ink);
  final pw.TextStyle h2 = pw.TextStyle(font: bold, fontSize: 13, color: _clay);
  final pw.TextStyle cellHead = pw.TextStyle(font: bold, fontSize: 10, color: _ink);

  pw.Widget heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
        child: pw.Text(text, style: h2),
      );

  pw.Widget table(List<String> headers, List<List<String>> rows) {
    if (rows.isEmpty) {
      return pw.Text(t('pdf_none'), style: muted);
    }
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: cellHead,
      cellStyle: body,
      headerDecoration: const pw.BoxDecoration(color: _soft),
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
        bottom: pw.BorderSide(color: _line, width: 0.5),
      ),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    );
  }

  // Pregnancy week
  final List<pw.Widget> intro = <pw.Widget>[];
  final PregnancyWeek? week = pregnancyWeek(data.due, now);
  final DateTime? due = parseIsoDate(data.due);
  if (week != null && due != null) {
    intro.add(pw.Text('${t('due_label')}: ${f.dateLong(due)}', style: body));
    intro.add(pw.Text(weeksAndDays(t, week), style: body));
  }

  // Contractions, last 24 hours
  final List<Contraction> sorted = sortedContractions(data.contractions);
  final List<List<String>> cRows = <List<String>>[];
  for (int i = 0; i < sorted.length; i++) {
    final Contraction c = sorted[i];
    if (c.start < nowMs - 86400000) {
      continue;
    }
    final double? gap = intervalBefore(sorted, i);
    cRows.add(<String>[
      '${f.dayLabel(c.start, now: nowMs)} ${f.time(c.start)}',
      formatDuration(c.durationMs / 1000),
      gap == null ? '–' : formatDuration(gap),
    ]);
  }

  // Movement sessions, last 7 days
  final List<MoveSession> moves = List<MoveSession>.of(data.moves)
    ..sort((MoveSession a, MoveSession b) => b.start.compareTo(a.start));
  final List<List<String>> mRows = moves
      .where((MoveSession m) => m.start >= nowMs - 7 * 86400000)
      .map((MoveSession m) => <String>[
            '${f.dayLabel(m.start, now: nowMs)} ${f.time(m.start)}',
            t('m_line', <String, Object?>{'n': m.count, 'm': ((m.end - m.start) / 60000).round().clamp(1, 1 << 20)}),
          ])
      .toList();

  // Weight
  final List<WeightEntry> weights = List<WeightEntry>.of(data.weights)
    ..sort((WeightEntry a, WeightEntry b) => b.at.compareTo(a.at));
  final List<List<String>> wRows = weights
      .take(12)
      .map((WeightEntry w) => <String>[f.date(DateTime.fromMillisecondsSinceEpoch(w.at)), '${f.kg(w.kg)} kg'])
      .toList();

  // Medicines
  final List<Medicine> meds = List<Medicine>.of(data.meds)..sort((Medicine a, Medicine b) => a.time.compareTo(b.time));
  final List<List<String>> medRows = meds
      .map((Medicine m) => <String>[m.name, t('md_daily', <String, Object?>{'t': m.time})])
      .toList();

  // Upcoming appointments
  final List<Appointment> appts = data.appts.where((Appointment a) => a.when.millisecondsSinceEpoch >= nowMs - 3600000).toList()
    ..sort((Appointment a, Appointment b) => a.when.compareTo(b.when));
  final List<List<String>> aRows = appts
      .map((Appointment a) => <String>[
            '${f.weekdayShort(a.when)} ${a.time}',
            t('a_kind_${a.kind}'),
            a.note,
          ])
      .toList();

  final pw.Document doc = pw.Document(title: t('pdf_subject'), author: 'Open Maternity', creator: 'Open Maternity');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 56),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (pw.Context ctx) => pw.Container(
        alignment: pw.Alignment.centerLeft,
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Text(t('w_disclaimer'), style: muted),
      ),
      build: (pw.Context ctx) => <pw.Widget>[
        pw.Text(t('s_summary'), style: h1),
        pw.SizedBox(height: 4),
        pw.Text(t('pdf_made', <String, Object?>{'date': '${f.dateLong(now)} ${f.time(nowMs)}'}), style: muted),
        pw.SizedBox(height: 8),
        ...intro,
        heading(t('pdf_c_title')),
        table(<String>[t('pdf_col_start'), t('pdf_col_len'), t('pdf_col_gap')], cRows),
        heading(t('pdf_m_title')),
        table(<String>[t('a_date'), t('t_movements')], mRows),
        heading(t('t_weight')),
        table(<String>[t('a_date'), t('wt_label')], wRows),
        heading(t('t_meds')),
        table(<String>[t('md_name'), t('md_time')], medRows),
        heading(t('t_appts')),
        table(<String>[t('a_date'), t('a_kind'), t('a_note')], aRows),
      ],
    ),
  );
  return doc.save();
}

/// '36 weeks and 2 days', with the singular forms.
String weeksAndDays(S t, PregnancyWeek w) {
  if (w.days == 0) {
    return t('weeks_0', <String, Object?>{'w': w.week});
  }
  if (w.days == 1) {
    return t('weeks_1day', <String, Object?>{'w': w.week});
  }
  return t('weeks_days', <String, Object?>{'w': w.week, 'd': w.days});
}

/// Writes the PDF to a temporary file and opens the phone's share menu.
Future<void> shareSummary(AppData data, S t, {Rect? origin}) async {
  final DateTime now = DateTime.now();
  final Uint8List bytes = await buildSummaryPdf(data, t, now);
  final Directory dir = await getTemporaryDirectory();
  final File file = File('${dir.path}${Platform.pathSeparator}open-maternity-summary-${isoDate(now)}.pdf');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'application/pdf')],
      subject: t('pdf_subject'),
      sharePositionOrigin: origin,
    ),
  );
}
