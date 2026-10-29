// Bottom sheets for adding and editing entries.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/calc.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../l10n/format.dart';
import '../../l10n/strings.dart';
import '../../services/backup.dart';
import '../../services/summary_pdf.dart';
import '../../theme/tokens.dart';
import '../actions.dart';
import '../scope.dart';
import '../widgets.dart';

final List<TextInputFormatter> _phoneFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9+*#()\- ]')),
  LengthLimitingTextInputFormatter(32),
];

// ------------------------------------------------------------------ phone numbers

Future<void> showNumberSheet(BuildContext context, String role) {
  final S t = context.tRead;
  return showOmSheet<void>(context, title: t('role_$role'), builder: (_) => _NumberSheet(role: role));
}

class _NumberSheet extends StatefulWidget {
  const _NumberSheet({required this.role});
  final String role;

  @override
  State<_NumberSheet> createState() => _NumberSheetState();
}

class _NumberSheetState extends State<_NumberSheet> {
  late final TextEditingController _number;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    final AppStore store = context.storeRead;
    _number = TextEditingController(text: store.data.number(widget.role));
    _name = TextEditingController(text: widget.role == 'support' ? store.data.supportName : '');
  }

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final AppStore store = context.storeRead;
    final S t = store.t;
    store.setNumber(widget.role, _number.text, name: widget.role == 'support' ? _name.text : null);
    Navigator.of(context).pop();
    toastText(t('number_saved'));
  }

  void _remove() {
    context.storeRead.removeNumber(widget.role);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final S t = context.t;
    final bool hasExisting = context.store.data.number(widget.role).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: <Widget>[
        OmTextField(
          label: t('phone_ph'),
          controller: _number,
          icon: Icons.call_rounded,
          keyboardType: TextInputType.phone,
          inputFormatters: _phoneFormatters,
          autofocus: !hasExisting,
          textInputAction: widget.role == 'support' ? TextInputAction.next : TextInputAction.done,
        ),
        if (widget.role == 'support')
          OmTextField(
            label: t('name_opt'),
            controller: _name,
            icon: Icons.person_rounded,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
          ),
        OmButton(label: t('save'), onPressed: _save, expand: true),
        if (hasExisting)
          OmButton(
            label: t('remove_number'),
            icon: Icons.delete_rounded,
            kind: BtnKind.outlined,
            onPressed: _remove,
            expand: true,
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ appointments

Future<void> showApptSheet(BuildContext context, {Appointment? existing}) {
  final S t = context.tRead;
  return showOmSheet<void>(
    context,
    title: existing == null ? t('a_add') : t('a_edit'),
    builder: (_) => _ApptSheet(existing: existing),
  );
}

class _ApptSheet extends StatefulWidget {
  const _ApptSheet({this.existing});
  final Appointment? existing;

  @override
  State<_ApptSheet> createState() => _ApptSheetState();
}

class _ApptSheetState extends State<_ApptSheet> {
  late String _kind;
  late DateTime _date;
  late TimeOfDay _time;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final Appointment? a = widget.existing;
    final DateTime inAWeek = DateTime.now().add(const Duration(days: 7));
    _kind = a?.kind ?? 'midwife';
    _date = a != null ? (parseIsoDate(a.date) ?? inAWeek) : DateTime(inAWeek.year, inAWeek.month, inAWeek.day);
    final ({int hour, int minute})? clock = a == null ? null : parseClock(a.time);
    _time = clock == null ? const TimeOfDay(hour: 10, minute: 0) : TimeOfDay(hour: clock.hour, minute: clock.minute);
    _note = TextEditingController(text: a?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final DateTime now = DateTime.now();
    final DateTime? d = await pickDate(
      context,
      initial: _date,
      first: DateTime(now.year - 1, now.month, now.day),
      last: DateTime(now.year + 2, now.month, now.day),
    );
    if (d != null && mounted) {
      setState(() => _date = d);
    }
  }

  Future<void> _chooseTime() async {
    final TimeOfDay? tod = await pickTime(context, _time);
    if (tod != null && mounted) {
      setState(() => _time = tod);
    }
  }

  void _save() {
    final AppStore store = context.storeRead;
    final S t = store.t;
    store.saveAppt(Appointment(
      id: widget.existing?.id ?? newId(),
      kind: _kind,
      date: isoDate(_date),
      time: '${pad2(_time.hour)}:${pad2(_time.minute)}',
      note: _note.text.trim(),
    ));
    Navigator.of(context).pop();
    toastText(t('a_saved'));
  }

  void _delete() {
    final AppStore store = context.storeRead;
    final S t = store.t;
    final VoidCallback undo = store.deleteAppt(widget.existing!.id);
    Navigator.of(context).pop();
    toastText(t('a_deleted'), undoLabel: t('undo'), undo: undo);
  }

  @override
  Widget build(BuildContext context) {
    final S t = context.t;
    final Fmt f = Fmt(t);
    final OmColors c = context.om;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: <Widget>[
        Text(t('a_kind'), style: OmText.caption.copyWith(color: c.inkMuted)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final String k in apptKinds)
              OmChip(label: t('a_kind_$k'), selected: _kind == k, onTap: () => setState(() => _kind = k)),
          ],
        ),
        TapField(
          label: t('a_date'),
          value: f.weekdayLong(_date),
          placeholder: t('choose_date'),
          icon: Icons.event_rounded,
          onTap: _chooseDate,
        ),
        TapField(
          label: t('a_time'),
          value: '${pad2(_time.hour)}:${pad2(_time.minute)}',
          placeholder: '',
          icon: Icons.schedule_rounded,
          onTap: _chooseTime,
        ),
        OmTextField(
          label: t('a_note'),
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 4,
        ),
        OmButton(label: t('save'), onPressed: _save, expand: true),
        if (widget.existing != null)
          OmButton(label: t('a_delete'), icon: Icons.delete_rounded, kind: BtnKind.outlined, onPressed: _delete, expand: true),
      ],
    );
  }
}

// ------------------------------------------------------------------ medicines

Future<void> showMedSheet(BuildContext context, {Medicine? existing}) {
  final S t = context.tRead;
  return showOmSheet<void>(
    context,
    title: existing == null ? t('md_add') : t('md_edit'),
    builder: (_) => _MedSheet(existing: existing),
  );
}

class _MedSheet extends StatefulWidget {
  const _MedSheet({this.existing});
  final Medicine? existing;

  @override
  State<_MedSheet> createState() => _MedSheetState();
}

class _MedSheetState extends State<_MedSheet> {
  late final TextEditingController _name;
  late TimeOfDay _time;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    final ({int hour, int minute})? clock = widget.existing == null ? null : parseClock(widget.existing!.time);
    _time = clock == null ? const TimeOfDay(hour: 20, minute: 0) : TimeOfDay(hour: clock.hour, minute: clock.minute);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _chooseTime() async {
    final TimeOfDay? tod = await pickTime(context, _time);
    if (tod != null && mounted) {
      setState(() => _time = tod);
    }
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _tried = true);
      return;
    }
    final AppStore store = context.storeRead;
    final S t = store.t;
    final bool isFirst = store.data.meds.isEmpty;
    store.saveMed(Medicine(id: widget.existing?.id ?? newId(), name: name, time: '${pad2(_time.hour)}:${pad2(_time.minute)}'));
    Navigator.of(context).pop();
    toastText(t('md_saved'));
    if (isFirst || widget.existing == null) {
      final bool allowed = await store.reminders.requestPermission();
      if (!allowed) {
        toastText(t('md_perm_off'));
      }
    }
  }

  void _remove() {
    final AppStore store = context.storeRead;
    final S t = store.t;
    final VoidCallback undo = store.deleteMed(widget.existing!.id);
    Navigator.of(context).pop();
    toastText(t('md_removed'), undoLabel: t('undo'), undo: undo);
  }

  @override
  Widget build(BuildContext context) {
    final S t = context.t;
    final OmColors c = context.om;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: <Widget>[
        OmTextField(
          label: t('md_name'),
          controller: _name,
          icon: Icons.medication_rounded,
          autofocus: widget.existing == null,
          textCapitalization: TextCapitalization.sentences,
          error: _tried && _name.text.trim().isEmpty ? t('md_name') : null,
          onChanged: (_) {
            if (_tried) {
              setState(() {});
            }
          },
        ),
        TapField(
          label: t('md_time'),
          value: '${pad2(_time.hour)}:${pad2(_time.minute)}',
          placeholder: '',
          icon: Icons.schedule_rounded,
          onTap: _chooseTime,
        ),
        Text(t('md_note'), style: OmText.caption.copyWith(color: c.inkMuted)),
        OmButton(label: t('save'), onPressed: _save, expand: true),
        if (widget.existing != null)
          OmButton(label: t('md_remove'), icon: Icons.delete_rounded, kind: BtnKind.outlined, onPressed: _remove, expand: true),
      ],
    );
  }
}

// ------------------------------------------------------------------ weight

Future<void> showWeightSheet(BuildContext context) {
  final S t = context.tRead;
  return showOmSheet<void>(context, title: t('wt_add'), builder: (_) => const _WeightSheet());
}

class _WeightSheet extends StatefulWidget {
  const _WeightSheet();

  @override
  State<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<_WeightSheet> {
  final TextEditingController _kg = TextEditingController();
  bool _tried = false;

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  bool get _bad => parseKg(_kg.text) == null;

  void _save() {
    final double? kg = parseKg(_kg.text);
    if (kg == null) {
      setState(() => _tried = true);
      return;
    }
    final AppStore store = context.storeRead;
    final S t = store.t;
    store.addWeight(kg);
    Navigator.of(context).pop();
    toastText(t('wt_saved'));
  }

  @override
  Widget build(BuildContext context) {
    final S t = context.t;
    final bool showError = (_tried || _kg.text.trim().isNotEmpty) && _bad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: <Widget>[
        OmTextField(
          label: t('wt_label'),
          controller: _kg,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            LengthLimitingTextInputFormatter(6),
          ],
          suffix: 'kg',
          error: showError && (_tried || _kg.text.length >= 2) ? t('wt_err') : null,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
          textInputAction: TextInputAction.done,
        ),
        OmButton(label: t('save'), kind: BtnKind.secondary, onPressed: _save, expand: true),
      ],
    );
  }
}

Future<void> showWeightEntrySheet(BuildContext context, WeightEntry entry) {
  final S t = context.tRead;
  final Fmt f = Fmt(t);
  return showOmSheet<void>(
    context,
    title: t('wt_entry'),
    builder: (BuildContext ctx) {
      final OmColors c = ctx.om;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: <Widget>[
          Text('${f.kg(entry.kg)} kg', style: OmText.numeralLg.copyWith(color: c.ink)),
          Text(f.weekdayLong(DateTime.fromMillisecondsSinceEpoch(entry.at)), style: OmText.body.copyWith(color: c.inkMuted)),
          OmButton(
            label: t('wt_delete'),
            icon: Icons.delete_rounded,
            kind: BtnKind.outlined,
            expand: true,
            onPressed: () {
              final VoidCallback undo = ctx.storeRead.deleteWeight(entry.id);
              Navigator.of(ctx).pop();
              toastText(t('wt_deleted'), undoLabel: t('undo'), undo: undo);
            },
          ),
        ],
      );
    },
  );
}

// ------------------------------------------------------------------ hospital bag

Future<void> showBagSheet(BuildContext context) {
  final S t = context.tRead;
  return showOmSheet<void>(context, title: t('b_add'), builder: (_) => const _BagSheet());
}

class _BagSheet extends StatefulWidget {
  const _BagSheet();

  @override
  State<_BagSheet> createState() => _BagSheetState();
}

class _BagSheetState extends State<_BagSheet> {
  final TextEditingController _item = TextEditingController();
  String _group = 'you';

  @override
  void dispose() {
    _item.dispose();
    super.dispose();
  }

  void _save() {
    final String text = _item.text.trim();
    if (text.isEmpty) {
      return;
    }
    context.storeRead.addBagItem(_group, text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final S t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: <Widget>[
        OmTextField(
          label: t('b_item'),
          controller: _item,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OmChip(label: t('b_you'), selected: _group == 'you', onTap: () => setState(() => _group = 'you')),
            OmChip(label: t('b_baby'), selected: _group == 'baby', onTap: () => setState(() => _group = 'baby')),
          ],
        ),
        OmButton(label: t('save'), onPressed: _save, expand: true),
      ],
    );
  }
}

// ------------------------------------------------------------------ contractions

Future<void> showContractionSheet(BuildContext context, Contraction contraction) {
  final S t = context.tRead;
  return showOmSheet<void>(context, title: t('c_edit'), builder: (_) => _ContractionSheet(contraction: contraction));
}

class _ContractionSheet extends StatefulWidget {
  const _ContractionSheet({required this.contraction});
  final Contraction contraction;

  @override
  State<_ContractionSheet> createState() => _ContractionSheetState();
}

class _ContractionSheetState extends State<_ContractionSheet> {
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = DateTime.fromMillisecondsSinceEpoch(widget.contraction.start);
    _end = DateTime.fromMillisecondsSinceEpoch(widget.contraction.end);
  }

  Future<void> _pick(bool isStart) async {
    final DateTime current = isStart ? _start : _end;
    final TimeOfDay? tod = await pickTime(context, TimeOfDay.fromDateTime(current));
    if (tod == null || !mounted) {
      return;
    }
    setState(() {
      if (isStart) {
        // The day nearest the old time, so 00:01 -> 23:59 stays the evening before.
        DateTime next = nearestClockTime(_start, tod.hour, tod.minute, second: _start.second);
        if (next.isAfter(DateTime.now())) {
          next = next.subtract(const Duration(days: 1));
        }
        final Duration length = _end.difference(_start);
        _start = next;
        _end = next.add(length);
      } else {
        DateTime next = nearestClockTime(_end, tod.hour, tod.minute, second: _end.second);
        while (!next.isAfter(_start)) {
          next = next.add(const Duration(days: 1));
        }
        if (next.difference(_start) > const Duration(hours: 1)) {
          // A contraction never lasts an hour; the time was meant for the same minute range.
          next = nearestClockTime(_start, tod.hour, tod.minute, second: _end.second);
          if (!next.isAfter(_start)) {
            next = _start.add(const Duration(seconds: 1));
          }
        }
        _end = next;
      }
    });
  }

  void _save() {
    context.storeRead.updateContraction(
      widget.contraction.id,
      start: _start.millisecondsSinceEpoch,
      end: _end.millisecondsSinceEpoch,
    );
    Navigator.of(context).pop();
  }

  void _delete() {
    final AppStore store = context.storeRead;
    final S t = store.t;
    final VoidCallback undo = store.deleteContraction(widget.contraction.id);
    Navigator.of(context).pop();
    toastText(t('c_deleted'), undoLabel: t('undo'), undo: undo);
  }

  @override
  Widget build(BuildContext context) {
    final S t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: <Widget>[
        TapField(label: t('c_started_l'), value: clockOf(_start), placeholder: '', icon: Icons.schedule_rounded, onTap: () => _pick(true)),
        TapField(label: t('c_ended_l'), value: clockOf(_end), placeholder: '', icon: Icons.schedule_rounded, onTap: () => _pick(false)),
        OmButton(label: t('save'), onPressed: _save, expand: true),
        OmButton(label: t('delete'), icon: Icons.delete_rounded, kind: BtnKind.outlined, onPressed: _delete, expand: true),
      ],
    );
  }
}

// ------------------------------------------------------------------ movement sessions

Future<void> showMoveSheet(BuildContext context, MoveSession session) {
  final S t = context.tRead;
  return showOmSheet<void>(context, title: t('m_edit'), builder: (_) => _MoveSheet(session: session));
}

class _MoveSheet extends StatefulWidget {
  const _MoveSheet({required this.session});
  final MoveSession session;

  @override
  State<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends State<_MoveSheet> {
  late DateTime _start;
  late DateTime _end;
  late int _count;

  @override
  void initState() {
    super.initState();
    _start = DateTime.fromMillisecondsSinceEpoch(widget.session.start);
    _end = DateTime.fromMillisecondsSinceEpoch(widget.session.end);
    _count = widget.session.count;
  }

  Future<void> _pick(bool isStart) async {
    final TimeOfDay? tod = await pickTime(context, TimeOfDay.fromDateTime(isStart ? _start : _end));
    if (tod == null || !mounted) {
      return;
    }
    setState(() {
      if (isStart) {
        DateTime next = nearestClockTime(_start, tod.hour, tod.minute);
        if (next.isAfter(DateTime.now())) {
          next = next.subtract(const Duration(days: 1));
        }
        final Duration length = _end.difference(_start);
        _start = next;
        _end = next.add(length);
      } else {
        DateTime next = nearestClockTime(_end, tod.hour, tod.minute);
        while (next.isBefore(_start)) {
          next = next.add(const Duration(days: 1));
        }
        _end = next;
      }
    });
  }

  void _save() {
    context.storeRead.updateMoveSession(
      widget.session.id,
      start: _start.millisecondsSinceEpoch,
      end: _end.millisecondsSinceEpoch,
      count: _count,
    );
    Navigator.of(context).pop();
  }

  void _delete() {
    final AppStore store = context.storeRead;
    final S t = store.t;
    final VoidCallback undo = store.deleteMoveSession(widget.session.id);
    Navigator.of(context).pop();
    toastText(t('m_deleted'), undoLabel: t('undo'), undo: undo);
  }

  @override
  Widget build(BuildContext context) {
    final S t = context.t;
    final OmColors c = context.om;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: <Widget>[
        Text(t('m_count_l'), style: OmText.label.copyWith(color: c.ink)),
        NumberStepper(
          value: _count,
          lessLabel: t('less'),
          moreLabel: t('more'),
          onChanged: (int v) => setState(() => _count = v),
        ),
        TapField(label: t('c_started_l'), value: clockOf(_start), placeholder: '', icon: Icons.schedule_rounded, onTap: () => _pick(true)),
        TapField(label: t('c_ended_l'), value: clockOf(_end), placeholder: '', icon: Icons.schedule_rounded, onTap: () => _pick(false)),
        OmButton(label: t('save'), onPressed: _save, expand: true),
        OmButton(label: t('delete'), icon: Icons.delete_rounded, kind: BtnKind.outlined, onPressed: _delete, expand: true),
      ],
    );
  }
}

// ------------------------------------------------------------------ delete and restore

Future<void> showDeleteAllSheet(BuildContext context) {
  final S t = context.tRead;
  return showOmSheet<void>(
    context,
    title: t('s_delete_t'),
    builder: (BuildContext ctx) {
      final OmColors c = ctx.om;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: <Widget>[
          Text(t('s_delete_b'), style: OmText.body.copyWith(color: c.ink)),
          OmButton(
            label: t('s_delete'),
            icon: Icons.delete_rounded,
            kind: BtnKind.outlined,
            expand: true,
            onPressed: () {
              final AppStore store = ctx.storeRead;
              messengerKey.currentState?.clearSnackBars();
              Navigator.of(ctx).popUntil((Route<dynamic> r) => r.isFirst);
              store.deleteEverything();
              unawaited(deleteSummaryFiles());
            },
          ),
          OmButton(label: t('cancel'), kind: BtnKind.quiet, onPressed: () => Navigator.of(ctx).pop()),
        ],
      );
    },
  );
}

Future<void> showRestoreSheet(BuildContext context, BackupFile backup) {
  final S t = context.tRead;
  final Fmt f = Fmt(t);
  final String when = backup.exportedAt == null ? '?' : f.dateLong(backup.exportedAt!);
  return showOmSheet<void>(
    context,
    title: t('s_restore_t'),
    builder: (BuildContext ctx) {
      final OmColors c = ctx.om;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: <Widget>[
          Text(t('s_restore_b', <String, Object?>{'date': when}), style: OmText.body.copyWith(color: c.ink)),
          OmButton(
            label: t('s_restore_go'),
            icon: Icons.settings_backup_restore_rounded,
            expand: true,
            onPressed: () async {
              final AppStore store = ctx.storeRead;
              messengerKey.currentState?.clearSnackBars();
              Navigator.of(ctx).pop();
              store.replaceAll(backup.data);
              final S restored = S(store.data.lang);
              toastText(restored('s_restore_done'));
              if (store.data.meds.isNotEmpty && !await store.reminders.requestPermission()) {
                toastText(restored('md_perm_off'));
              }
            },
          ),
          OmButton(label: t('cancel'), kind: BtnKind.quiet, onPressed: () => Navigator.of(ctx).pop()),
        ],
      );
    },
  );
}
