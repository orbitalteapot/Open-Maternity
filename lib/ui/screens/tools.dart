// The tool screens: contractions, movements, bag, appointments, medicines,
// weight and the user's own phone numbers.
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../data/calc.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../l10n/format.dart';
import '../../l10n/strings.dart';
import '../../theme/tokens.dart';
import '../actions.dart';
import '../chart_cards.dart';
import '../scope.dart';
import '../sheets/sheets.dart';
import '../widgets.dart';
import 'home.dart';

/// Standard page: top bar, scrolling body, optional bottom action area.
class ToolPage extends StatelessWidget {
  const ToolPage({super.key, required this.title, required this.body, this.actions = const <Widget>[], this.bottom});

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            OmTopBar(title: title, onBack: () => Navigator.of(context).maybePop(), actions: actions),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: bottom,
    );
  }
}

/// The always-visible way to call the maternity ward on the timers.
class WardCallBar extends StatelessWidget {
  const WardCallBar({super.key});

  @override
  Widget build(BuildContext context) {
    final S t = context.t;
    final OmColors c = context.om;
    final String ward = context.store.data.number('ward');
    return BottomBar(
      children: <Widget>[
        if (ward.isNotEmpty)
          OmButton(
            label: t('u_call'),
            icon: Icons.call_rounded,
            kind: BtnKind.secondary,
            expand: true,
            onPressed: () => callNumber(context, ward),
          )
        else ...<Widget>[
          Text(t('u_no_number'), style: OmText.caption.copyWith(color: c.inkMuted)),
          OmButton(
            label: t('add_ward_number'),
            icon: Icons.add_rounded,
            kind: BtnKind.outlined,
            expand: true,
            onPressed: () => showNumberSheet(context, 'ward'),
          ),
        ],
      ],
    );
  }
}

/// The one-tap switch between the night theme and the normal one.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final S t = context.t;
    final bool night = context.om.id == OmThemeId.night;
    return OmIconButton(
      icon: night ? Icons.light_mode_rounded : Icons.nightlight_rounded,
      label: night ? t('use_light') : t('use_night'),
      onPressed: () => context.storeRead.setSessionTheme(night ? 'day' : 'night'),
    );
  }
}

// ------------------------------------------------------------------ contractions

class ContractionsScreen extends StatelessWidget {
  const ContractionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TrackerTheme(child: _ContractionsBody());
  }
}

class _ContractionsBody extends StatelessWidget {
  const _ContractionsBody();

  void _toggle(BuildContext context) {
    final AppStore store = context.storeRead;
    final S t = store.t;
    if (store.data.running == 0) {
      final VoidCallback? undoSeries = store.startContraction();
      if (undoSeries != null) {
        toastText(t('c_series_started'), undoLabel: t('undo'), undo: undoSeries);
      }
    } else {
      final VoidCallback? undo = store.stopContraction();
      if (undo != null) {
        toastText(t('c_saved'), undoLabel: t('undo'), undo: undo);
      }
    }
  }

  void _newSeries(BuildContext context) {
    final AppStore store = context.storeRead;
    final S t = store.t;
    final VoidCallback? undo = store.startNewSeries();
    if (undo != null) {
      toastText(t('c_series_started'), undoLabel: t('undo'), undo: undo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.store;
    final S t = context.t;
    final Fmt f = Fmt(t);
    final OmColors c = context.om;
    final AppData d = store.data;
    return ToolPage(
      title: t('t_contraction_timer'),
      actions: const <Widget>[ThemeToggleButton()],
      bottom: const WardCallBar(),
      body: EverySecond(
        active: d.running != 0,
        builder: (BuildContext context) {
          final int nowMs = DateTime.now().millisecondsSinceEpoch;
          final List<Contraction> cs = sortedContractions(d.contractions);
          final List<Contraction> series = currentSeries(cs, d.seriesStarts);
          final ContractionStats stats = contractionStats(cs, nowMs, seriesStarts: d.seriesStarts);
          final bool running = d.running != 0;
          final int runSecs = running ? ((nowMs - d.running) / 1000).floor() : 0;
          final String runTime = formatTimer(runSecs);
          final Contraction? newest = series.isEmpty ? null : series.last;
          final bool longBreak = !running && newest != null && nowMs - newest.end >= 30 * 60000;
          final String line = running
              ? t('c_started', <String, Object?>{'t': clockWithSeconds(DateTime.fromMillisecondsSinceEpoch(d.running))})
              : (series.isEmpty && cs.isNotEmpty)
                  ? t('c_series_empty')
                  : (newest != null && nowMs - newest.end < 15 * 60000)
                      ? t('c_saved_len', <String, Object?>{'d': formatDuration(newest.durationMs / 1000)})
                      : t('c_hint_idle');
          final List<Contraction> recent = series.reversed.take(5).toList();
          return PageBody(
            children: <Widget>[
              if (longBreak)
                Notice(
                  icon: Icons.more_time_rounded,
                  title: t('c_series_long', <String, Object?>{'t': sinceText(t, nowMs - newest.end)}),
                  body: t('c_series_sub'),
                  action: OmButton(
                    label: t('c_series_new'),
                    icon: Icons.playlist_add_rounded,
                    kind: BtnKind.quiet,
                    onPressed: () => _newSeries(context),
                  ),
                ),
              if (stats.sample >= 2)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: <Widget>[
                    TwoColumns(
                      gap: 8,
                      children: <Widget>[
                        StatBox(
                          value: stats.avgIntervalSec > 0 ? formatDuration(stats.avgIntervalSec) : '–',
                          label: t('c_apart'),
                        ),
                        StatBox(value: formatDuration(stats.avgDurationSec), label: t('c_lasting')),
                        StatBox(
                          value: stats.per10Min > 0 ? f.oneDecimal(stats.per10Min) : '–',
                          label: t('c_per10'),
                        ),
                        StatBox(value: '${stats.inLastHour}', label: t('c_hour')),
                      ],
                    ),
                    Text(t('c_avg', <String, Object?>{'n': stats.sample}), style: OmText.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 4),
                child: Column(
                  spacing: 24,
                  children: <Widget>[
                    TimerButton(
                      running: running,
                      semanticLabel: running ? '${t('c_stop')}, $runTime' : t('c_start'),
                      onPressed: () => _toggle(context),
                      child: running
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 4,
                              children: <Widget>[
                                FittedBox(fit: BoxFit.scaleDown, child: Text(runTime, style: OmText.numeralXl.copyWith(color: c.onClay))),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(Icons.stop_rounded, size: 24),
                                    const SizedBox(width: 4),
                                    Flexible(child: Text(t('c_stop'))),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 4,
                              children: <Widget>[
                                const Icon(Icons.play_arrow_rounded, size: 40),
                                Text(t('c_start')),
                              ],
                            ),
                    ),
                    Semantics(
                      liveRegion: true,
                      child: Text(line, textAlign: TextAlign.center, style: OmText.body.copyWith(color: c.inkMuted)),
                    ),
                  ],
                ),
              ),
              if (recent.isNotEmpty) ...<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: SectionLabel(t('c_recent'))),
                    if (!running && !longBreak)
                      OmButton(
                        label: t('c_series_short'),
                        icon: Icons.playlist_add_rounded,
                        kind: BtnKind.quiet,
                        onPressed: () => _newSeries(context),
                      ),
                  ],
                ),
                OmGroup(
                  children: <Widget>[
                    for (final Contraction x in recent) _ContractionRow(contraction: x, all: cs, seriesStarts: d.seriesStarts),
                  ],
                ),
              ],
              if (ContractionChartCard.hasData(d)) const ContractionChartCard(),
            ],
          );
        },
      ),
    );
  }
}

class _ContractionRow extends StatelessWidget {
  const _ContractionRow({required this.contraction, required this.all, required this.seriesStarts});

  final Contraction contraction;
  final List<Contraction> all;
  final List<int> seriesStarts;

  @override
  Widget build(BuildContext context) {
    final S t = context.t;
    final OmColors c = context.om;
    final double? gap = intervalBefore(all, all.indexOf(contraction), seriesStarts: seriesStarts);
    final String time = clockOfMs(contraction.start);
    return Material(
      color: c.surfaceRaised,
      child: InkWell(
        onTap: () => showContractionSheet(context, contraction),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
            child: Row(
              children: <Widget>[
                SizedBox(width: 56, child: Text(time, style: OmText.time.copyWith(color: c.ink))),
                const Lead(Icons.timer_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(t('c_long', <String, Object?>{'d': formatDuration(contraction.durationMs / 1000)}), style: OmText.body.copyWith(color: c.ink)),
                      if (gap != null)
                        Text(t('c_after', <String, Object?>{'d': formatDuration(gap)}), style: OmText.caption.copyWith(color: c.inkMuted)),
                    ],
                  ),
                ),
                OmIconButton(
                  icon: Icons.edit_rounded,
                  label: '${t('c_edit')}, $time',
                  color: c.inkMuted,
                  onPressed: () => showContractionSheet(context, contraction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ movements

class MovementsScreen extends StatelessWidget {
  const MovementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TrackerTheme(child: _MovementsBody());
  }
}

class _MovementsBody extends StatelessWidget {
  const _MovementsBody();

  void _end(BuildContext context) {
    final AppStore store = context.storeRead;
    final S t = store.t;
    final VoidCallback? undo = store.endMoves();
    if (undo != null) {
      toastText(t('m_saved'), undoLabel: t('undo'), undo: undo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.store;
    final S t = context.t;
    final Fmt f = Fmt(t);
    final OmColors c = context.om;
    final AppData d = store.data;
    final RunningMoves? move = d.move;
    final List<MoveSession> sessions = List<MoveSession>.of(d.moves)..sort((MoveSession a, MoveSession b) => b.start.compareTo(a.start));
    return ToolPage(
      title: t('t_movements'),
      actions: const <Widget>[ThemeToggleButton()],
      bottom: const WardCallBar(),
      body: EverySecond(
        active: move != null,
        builder: (BuildContext context) {
          final int nowMs = DateTime.now().millisecondsSinceEpoch;
          return PageBody(
            children: <Widget>[
              if (move != null) ...<Widget>[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: <Widget>[
                      Expanded(child: StatBox(value: '${move.count}', label: t('m_count'))),
                      Expanded(child: StatBox(value: '${((nowMs - move.start) / 60000).floor()}', label: t('m_since'))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    spacing: 24,
                    children: <Widget>[
                      TimerButton(
                        running: true,
                        semanticLabel: '${t('m_felt')} (${move.count})',
                        onPressed: () => context.storeRead.countMove(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 4,
                          children: <Widget>[
                            const Icon(Icons.touch_app_rounded, size: 40),
                            Text(t('m_felt')),
                          ],
                        ),
                      ),
                      OmButton(label: t('m_end'), kind: BtnKind.outlined, onPressed: () => _end(context)),
                    ],
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    spacing: 24,
                    children: <Widget>[
                      TimerButton(
                        running: false,
                        semanticLabel: t('m_start'),
                        onPressed: () => context.storeRead.startMoves(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 4,
                          children: <Widget>[
                            const Icon(Icons.play_arrow_rounded, size: 40),
                            Text(t('m_start')),
                          ],
                        ),
                      ),
                      Text(t('m_intro'), textAlign: TextAlign.center, style: OmText.body.copyWith(color: c.inkMuted)),
                    ],
                  ),
                ),
              if (MovementChartCard.hasData(d)) const MovementChartCard(),
              if (sessions.isNotEmpty) ...<Widget>[
                SectionLabel(t('m_earlier')),
                OmGroup(
                  children: <Widget>[
                    for (final MoveSession m in sessions.take(5))
                      OmRow(
                        leading: const Lead(Icons.touch_app_rounded),
                        title: movesLine(t, m),
                        titleStyle: OmText.body.copyWith(color: c.ink),
                        subtitle: '${f.dayLabel(m.start, now: nowMs)}, ${f.time(m.start)}',
                        onTap: () => showMoveSheet(context, m),
                        trailing: Icon(Icons.edit_rounded, color: c.inkMuted),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ hospital bag

class BagScreen extends StatelessWidget {
  const BagScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.store;
    final S t = context.t;
    final OmColors c = context.om;
    final AppData d = store.data;
    final int packed = bagPackedCount(d);
    final int total = bagTotal(d);
    final String title = t('packed_of', <String, Object?>{'a': packed, 'b': total});

    List<Widget> rows(String group) => <Widget>[
          for (final DefaultBagItem b in defaultBag.where((DefaultBagItem b) => b.group == group))
            _BagRow(label: t('b_i_${b.id}'), done: d.bagDone.contains(b.id), onToggle: () => store.toggleBag(b.id)),
          for (final BagItem b in d.bagCustom.where((BagItem b) => b.group == group))
            _BagRow(
              label: b.text,
              done: d.bagDone.contains(b.id),
              onToggle: () => store.toggleBag(b.id),
              onRemove: () {
                final VoidCallback undo = store.removeBagItem(b.id);
                showToast(context, t('b_removed'), undo: undo);
              },
            ),
        ];

    final List<Widget> you = rows('you');
    final List<Widget> baby = rows('baby');
    return ToolPage(
      title: t('t_bag'),
      actions: <Widget>[
        OmIconButton(icon: Icons.add_rounded, label: t('b_add'), onPressed: () => showBagSheet(context)),
      ],
      body: PageBody(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: <Widget>[
              Text(title, style: OmText.titleLg.copyWith(color: c.ink)),
              ProgressTrack(value: total == 0 ? 0 : packed / total, color: c.sage, background: c.surfaceSunken, label: title),
            ],
          ),
          if (total > 0 && packed == total)
            Notice(icon: Icons.check_circle_rounded, tone: NoticeTone.positive, title: t('b_all'), body: t('b_all_sub')),
          if (you.isNotEmpty) ...<Widget>[SectionLabel(t('b_you')), OmGroup(children: you)],
          if (baby.isNotEmpty) ...<Widget>[SectionLabel(t('b_baby')), OmGroup(children: baby)],
        ],
      ),
    );
  }
}

class _BagRow extends StatelessWidget {
  const _BagRow({required this.label, required this.done, required this.onToggle, this.onRemove});

  final String label;
  final bool done;
  final VoidCallback onToggle;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    return Material(
      color: c.surfaceRaised,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              checked: done,
              child: InkWell(
                onTap: onToggle,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: done ? c.sage : Colors.transparent,
                            shape: BoxShape.circle,
                            border: done ? null : Border.all(color: c.lineStrong, width: 2),
                          ),
                          child: done ? Icon(Icons.check_rounded, size: 20, color: c.onSage) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(label, style: OmText.title.copyWith(color: done ? c.inkMuted : c.ink)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (onRemove != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: OmIconButton(
                icon: Icons.close_rounded,
                label: context.t('b_remove', <String, Object?>{'item': label}),
                color: c.inkMuted,
                onPressed: onRemove,
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ appointments

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.store;
    final S t = context.t;
    final Fmt f = Fmt(t);
    final OmColors c = context.om;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final List<Appointment> upcoming = upcomingAppointments(store.data, nowMs);
    final List<Appointment> past = pastAppointments(store.data, nowMs);
    return ToolPage(
      title: t('t_appts'),
      bottom: BottomBar(
        children: <Widget>[
          OmButton(label: t('a_add'), icon: Icons.add_rounded, expand: true, onPressed: () => showApptSheet(context)),
        ],
      ),
      body: PageBody(
        children: <Widget>[
          if (store.data.appts.isEmpty)
            EmptyState(icon: Icons.event_rounded, tone: Tone.honey, title: t('a_empty'), body: t('a_empty_sub')),
          for (final Appointment a in upcoming) _ApptCard(appt: a),
          if (past.isNotEmpty) ...<Widget>[
            SectionLabel(t('a_earlier')),
            OmGroup(
              children: <Widget>[
                for (final Appointment a in past)
                  OmRow(
                    leading: const Lead(Icons.event_rounded, tone: Tone.honey),
                    title: t('a_kind_${a.kind}'),
                    titleStyle: OmText.body.copyWith(color: c.ink),
                    subtitle: apptWhen(f, a),
                    onTap: () => showApptSheet(context, existing: a),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ApptCard extends StatelessWidget {
  const _ApptCard({required this.appt});

  final Appointment appt;

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.store;
    final S t = context.t;
    final Fmt f = Fmt(t);
    final OmColors c = context.om;
    final String? role = appt.role;
    final String number = role == null ? '' : store.data.number(role);
    return OmCard(
      onTap: () => showApptSheet(context, existing: appt),
      children: <Widget>[
        Eyebrow(icon: Icons.event_rounded, text: t('a_kind_${appt.kind}')),
        Text(apptWhen(f, appt), style: OmText.titleLg.copyWith(color: c.ink)),
        if (appt.note.isNotEmpty) Text(appt.note, style: OmText.body.copyWith(color: c.inkMuted)),
        if (role != null)
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(t('role_$role'), style: OmText.title.copyWith(color: c.ink)),
                    Text(number.isEmpty ? t('not_added') : number, style: OmText.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
              if (number.isNotEmpty)
                CallButton(label: '${t('call')} ${t('role_$role')}', onPressed: () => callNumber(context, number))
              else
                OmChip(label: t('add_number'), icon: Icons.add_rounded, onTap: () => showNumberSheet(context, role)),
            ],
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ medicines

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> with WidgetsBindingObserver {
  /// True when there are medicines but the phone blocks notifications.
  bool _remindersOff = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check(ask: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the phone's settings: check again.
    if (state == AppLifecycleState.resumed) {
      _check(ask: false);
    }
  }

  Future<void> _check({required bool ask}) async {
    final AppStore store = context.storeRead;
    if (store.data.meds.isEmpty) {
      if (_remindersOff && mounted) {
        setState(() => _remindersOff = false);
      }
      return;
    }
    bool allowed = await store.reminders.isAllowed();
    if (!allowed && ask) {
      allowed = await store.reminders.requestPermission();
    }
    if (allowed) {
      await store.syncReminders();
    }
    if (mounted) {
      setState(() => _remindersOff = !allowed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.store;
    final S t = context.t;
    final OmColors c = context.om;
    final List<Medicine> meds = sortedMeds(store.data);
    return ToolPage(
      title: t('t_meds'),
      bottom: BottomBar(
        children: <Widget>[
          OmButton(
            label: t('md_add'),
            icon: Icons.add_rounded,
            expand: true,
            onPressed: () async {
              await showMedSheet(context);
              if (mounted) {
                await _check(ask: false);
              }
            },
          ),
        ],
      ),
      body: PageBody(
        children: <Widget>[
          if (meds.isNotEmpty && _remindersOff)
            Notice(
              icon: Icons.notifications_off_rounded,
              tone: NoticeTone.caution,
              body: t('md_perm_off'),
              action: OmButton(
                label: t('md_perm_on'),
                kind: BtnKind.quiet,
                color: c.onHoneySoft,
                onPressed: () => _check(ask: true),
              ),
            ),
          if (meds.isEmpty)
            EmptyState(icon: Icons.medication_rounded, title: t('md_empty'), body: t('md_empty_sub'))
          else ...<Widget>[
            OmGroup(
              children: <Widget>[
                for (final Medicine m in meds)
                  OmRow(
                    leading: const Lead(Icons.medication_rounded),
                    title: m.name,
                    subtitle: t('md_daily', <String, Object?>{'t': m.time}),
                    onTap: () => showMedSheet(context, existing: m),
                    trailing: store.takenToday(m.id)
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.check_circle_rounded, size: 20, color: c.sage),
                              const SizedBox(width: 4),
                              Text(t('md_taken'), style: OmText.caption.copyWith(color: c.ink)),
                            ],
                          )
                        : OmChip(
                            label: t('md_mark'),
                            icon: Icons.check_rounded,
                            semanticsLabel: '${t('md_mark')}: ${m.name}',
                            onTap: () {
                              final VoidCallback undo = store.markTaken(m.id);
                              showToast(context, t('md_taken_toast'), undo: undo);
                            },
                          ),
                  ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.schedule_rounded, size: 20, color: c.inkMuted),
                const SizedBox(width: 8),
                Expanded(child: Text(t('md_note'), style: OmText.caption.copyWith(color: c.inkMuted))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ weight

class WeightScreen extends StatelessWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.store;
    final S t = context.t;
    final Fmt f = Fmt(t);
    final OmColors c = context.om;
    final List<WeightEntry> ws = sortedWeights(store.data);
    final String since = ws.length >= 2
        ? t('wt_since', <String, Object?>{'d': f.kgSigned(ws.last.kg - ws.first.kg)})
        : t('wt_first');
    return ToolPage(
      title: t('t_weight'),
      bottom: BottomBar(
        children: <Widget>[
          OmButton(
            label: t('wt_add'),
            icon: Icons.add_rounded,
            kind: BtnKind.secondary,
            expand: true,
            onPressed: () => showWeightSheet(context),
          ),
        ],
      ),
      body: PageBody(
        children: <Widget>[
          if (ws.isEmpty)
            EmptyState(icon: Icons.monitor_weight_rounded, tone: Tone.sage, title: t('wt_empty'), body: t('wt_empty_sub'))
          else ...<Widget>[
            StatBox(value: f.kg(ws.last.kg), unit: 'kg', label: since),
            OmGroup(
              children: <Widget>[
                for (final WeightEntry w in ws.reversed)
                  OmRow(
                    leading: const Lead(Icons.monitor_weight_rounded, tone: Tone.sage),
                    title: '${f.kg(w.kg)} kg',
                    titleStyle: OmText.body.copyWith(color: c.ink),
                    subtitle: f.weekdayShort(DateTime.fromMillisecondsSinceEpoch(w.at)),
                    onTap: () => showWeightEntrySheet(context, w),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ my numbers

const Map<String, IconData> roleIcons = <String, IconData>{
  'ward': Icons.local_hospital_rounded,
  'midwife': Icons.person_rounded,
  'centre': Icons.medical_services_rounded,
  'doctor': Icons.medical_information_rounded,
  'emergency': Icons.call_rounded,
  'support': Icons.favorite_rounded,
};

const List<(String, List<String>)> roleGroups = <(String, List<String>)>[
  ('grp_birth', <String>['ward', 'midwife']),
  ('grp_care', <String>['centre', 'doctor']),
  ('grp_emergency', <String>['emergency', 'support']),
];

class NumbersScreen extends StatelessWidget {
  const NumbersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.store;
    final S t = context.t;
    final OmColors c = context.om;
    return ToolPage(
      title: t('my_numbers'),
      body: PageBody(
        children: <Widget>[
          Text(t('my_numbers_sub'), style: OmText.body.copyWith(color: c.inkMuted)),
          for (final (String group, List<String> roles) in roleGroups) ...<Widget>[
            SectionLabel(t(group)),
            OmGroup(
              children: <Widget>[
                for (final String role in roles) _numberRow(context, store, t, role),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _numberRow(BuildContext context, AppStore store, S t, String role) {
    final String number = store.data.number(role);
    final String title = t('role_$role');
    final String sub = number.isEmpty
        ? t('not_added')
        : (role == 'support' && store.data.supportName.isNotEmpty ? '${store.data.supportName} · $number' : number);
    return OmRow(
      leading: Lead(roleIcons[role]!, tone: number.isEmpty ? Tone.honey : Tone.clay),
      title: title,
      singleLineTitle: true,
      subtitle: sub,
      onTap: () => showNumberSheet(context, role),
      trailing: number.isNotEmpty
          ? CallButton(label: '${t('call')} $title', onPressed: () => callNumber(context, number))
          : RoundButton(
              icon: Icons.add_rounded,
              label: '${t('add_number')}: $title',
              onPressed: () => showNumberSheet(context, role),
            ),
    );
  }
}
