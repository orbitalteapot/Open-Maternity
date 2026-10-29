import 'package:flutter/material.dart';

import '../data/store.dart';
import '../l10n/strings.dart';
import '../services/backup.dart';
import '../services/phone.dart';
import '../services/summary_pdf.dart';
import 'scope.dart';
import 'sheets/sheets.dart';
import 'widgets.dart';

/// Opens the dialler, or explains if the phone can't.
Future<void> callNumber(BuildContext context, String number) async {
  final S t = context.tRead;
  final bool ok = await openDialler(number);
  if (!ok) {
    toastText(t('call_failed'));
  }
}

DateTime _clampDate(DateTime d, DateTime first, DateTime last) {
  if (d.isBefore(first)) {
    return first;
  }
  if (d.isAfter(last)) {
    return last;
  }
  return d;
}

Future<DateTime?> pickDate(BuildContext context, {DateTime? initial, required DateTime first, required DateTime last}) {
  return showDatePicker(
    context: context,
    initialDate: _clampDate(initial ?? DateTime.now(), first, last),
    firstDate: first,
    lastDate: last,
  );
}

/// Time picker that always uses the 24-hour clock.
Future<TimeOfDay?> pickTime(BuildContext context, TimeOfDay initial) {
  return showTimePicker(
    context: context,
    initialTime: initial,
    builder: (BuildContext ctx, Widget? child) {
      return MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}

Rect? _originOf(BuildContext context) {
  final RenderObject? box = context.findRenderObject();
  if (box is RenderBox && box.hasSize) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  return null;
}

/// Makes the PDF summary and opens the share menu.
Future<void> shareSummaryFlow(BuildContext context) async {
  final AppStore store = context.storeRead;
  final S t = store.t;
  final Rect? origin = _originOf(context);
  try {
    await shareSummary(store.data, t, origin: origin);
  } catch (_) {
    toastText(t('pdf_fail'));
  }
}

Future<void> exportBackupFlow(BuildContext context) async {
  final AppStore store = context.storeRead;
  final S t = store.t;
  await store.flush();
  try {
    final bool saved = await saveBackup(store.data, DateTime.now());
    if (saved) {
      toastText(t('s_export_done'));
    }
  } catch (_) {
    toastText(t('s_export_fail'));
  }
}

Future<void> restoreBackupFlow(BuildContext context) async {
  final AppStore store = context.storeRead;
  final S t = store.t;
  String? text;
  try {
    text = await pickBackupText();
  } catch (_) {
    text = null;
  }
  if (text == null) {
    return;
  }
  final BackupFile? backup = decodeBackup(text);
  if (backup == null) {
    toastText(t('s_restore_bad'));
    return;
  }
  if (!context.mounted) {
    return;
  }
  await showRestoreSheet(context, backup);
}
