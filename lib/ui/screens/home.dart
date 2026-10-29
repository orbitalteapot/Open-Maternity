// The three tabs: Today, Tools and History.
import 'package:flutter/material.dart';

import '../../data/calc.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../l10n/format.dart';
import '../../l10n/strings.dart';
import '../../services/summary_pdf.dart';
import '../../theme/tokens.dart';
import '../actions.dart';
import '../chart_cards.dart';
import '../scope.dart';
import '../sheets/sheets.dart';
import '../widgets.dart';
import 'onboarding.dart';
import 'settings.dart';
import 'tools.dart';

void pushScreen(BuildContext context, Widget screen) {
  Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => screen));
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final S t = context.t;
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          setState(() => _tab = 0);
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tab,
            children: const <Widget>[TodayTab(), ToolsTab(), HistoryTab()],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (int i) => setState(() => _tab = i),
          destinations: <Widget>[
            NavigationDestination(icon: const Icon(Icons.today_rounded), label: t('tab_today')),
            NavigationDestination(icon: const Icon(Icons.grid_view_rounded), label: t('tab_tools')),
            NavigationDestination(icon: const Icon(Icons.history_rounded), label: t('tab_history')),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ shared pieces

/// Status line for a tool tile (also used on Today).
String runningStatus(S t, AppStore store, int now) {
  if (store.data.running != 0) {
    return t('running_at', <String, Object?>{'t': formatTimer(((now - store.data.running) / 1000).floor())});
  }
  final RunningMoves? m = store.data.move;
  if (m != null) {
    return t('running_at', <String, Object?>{'t': '${m.count}'});
  }
  return '';
}

class _RunningTile extends StatelessWidget {
  const _RunningTile({required this.icon, required this.title, required this.status, required this.onTap});

  final IconData icon;
  final String title;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    return Material(
      color: c.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OmSize.radiusLg),
        side: BorderSide(color: c.clay, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Lead(icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: OmText.title.copyWith(color: c.ink)),
                      Text(status, style: OmText.captionBold.copyWith(color: c.clay)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(OmSize.radiusLg), boxShadow: c.raisedShadow),
      child: Material(
        color: c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OmSize.radiusLg),
          side: BorderSide(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Lead(icon),
                  const SizedBox(width: 10),
                  Expanded(
                    // One line; shrinks a little rather than splitting a long word.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(title, maxLines: 1, style: OmText.title.copyWith(color: c.ink)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Today

class TodayTab extends StatelessWidget {
  const TodayTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.store;
    final S t = context.t;
    final Fmt f = Fmt(t);
    final OmColors c = context.om;
    final AppData d = store.data;
    return EverySecond(
      active: d.running != 0 || d.move != null,
      builder: (BuildContext context) {
        final DateTime now = DateTime.now();
        final int nowMs = now.millisecondsSinceEpoch;
        final PregnancyWeek? week = pregnancyWeek(d.due, now);
        final List<Appointment> upcoming = upcomingAppointments(d, nowMs);
        final int packed = bagPackedCount(d);
        final int total = bagTotal(d);
        return PageBody(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(f.weekdayLong(now), style: OmText.label.copyWith(color: c.inkMuted))),
                OmIconButton(
                  icon: Icons.settings_rounded,
                  label: t('s_title'),
                  onPressed: () => pushScreen(context, const SettingsScreen()),
                ),
              ],
            ),
            if (week != null)
              _Hero(week: week, due: parseIsoDate(d.due)!)
            else
              Notice(
                icon: Icons.event_rounded,
                body: t('due_missing'),
                action: OmButton(
                  label: t('due_add'),
                  icon: Icons.add_rounded,
                  kind: BtnKind.quiet,
                  onPressed: () => openDueScreen(context),
                ),
              ),
            if (d.number('ward').isEmpty)
              _numberNotice(context, t('notice_ward_t'), t('notice_ward_b'), 'ward')
            else if (d.number('midwife').isEmpty)
              _numberNotice(context, t('notice_mw_t'), t('notice_mw_b'), 'midwife'),
            if (d.running != 0)
              _RunningTile(
                icon: Icons.timer_rounded,
                title: t('timer_running'),
                status: formatTimer(((nowMs - d.running) / 1000).floor()),
                onTap: () => pushScreen(context, const ContractionsScreen()),
              )
            else if (d.move != null)
              _RunningTile(
                icon: Icons.touch_app_rounded,
                title: t('t_movements'),
                status: runningStatus(t, store, nowMs),
                onTap: () => pushScreen(context, const MovementsScreen()),
              ),
            TwoColumns(
              children: <Widget>[
                _QuickTile(
                  icon: Icons.timer_rounded,
                  title: t('t_contractions'),
                  onTap: () => pushScreen(context, const ContractionsScreen()),
                ),
                _QuickTile(
                  icon: Icons.touch_app_rounded,
                  title: t('t_movements'),
                  onTap: () => pushScreen(context, const MovementsScreen()),
                ),
              ],
            ),
            if (upcoming.isNotEmpty)
              OmCard(
                onTap: () => pushScreen(context, const AppointmentsScreen()),
                children: <Widget>[
                  Eyebrow(icon: Icons.event_rounded, text: t('next_appt')),
                  Text(t('a_kind_${upcoming.first.kind}'), style: OmText.titleLg.copyWith(color: c.ink)),
                  Text(apptWhen(f, upcoming.first), style: OmText.body.copyWith(color: c.inkMuted)),
                ],
              ),
            if (packed < total)
              OmCard(
                onTap: () => pushScreen(context, const BagScreen()),
                children: <Widget>[
                  Eyebrow(icon: Icons.luggage_rounded, text: t('t_bag')),
                  Text(t('packed_of', <String, Object?>{'a': packed, 'b': total}), style: OmText.titleLg.copyWith(color: c.ink)),
                  ProgressTrack(value: total == 0 ? 0 : packed / total, color: c.sage, background: c.surfaceSunken),
                  OmButton(
                    label: t('open_list'),
                    kind: BtnKind.quiet,
                    onPressed: () => pushScreen(context, const BagScreen()),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _numberNotice(BuildContext context, String title, String body, String role) {
    return Notice(
      icon: Icons.lightbulb_rounded,
      tone: NoticeTone.caution,
      title: title,
      body: body,
      action: OmButton(
        label: context.t('add_number'),
        icon: Icons.add_rounded,
        kind: BtnKind.quiet,
        color: context.om.onHoneySoft,
        onPressed: () => showNumberSheet(context, role),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.week, required this.due});

  final PregnancyWeek week;
  final DateTime due;

  @override
  Widget build(BuildContext context) {
    final S t = context.t;
    final Fmt f = Fmt(t);
    final OmColors c = context.om;
    final String left = week.daysToDue > 1
        ? t('days_left', <String, Object?>{'n': week.daysToDue})
        : week.daysToDue == 1
            ? t('days_left_1')
            : week.daysToDue == 0
                ? t('due_today')
                : week.daysToDue == -1
                    ? t('days_over_1')
                    : t('days_over', <String, Object?>{'n': -week.daysToDue});
    final TextStyle caption = OmText.caption.copyWith(color: c.onClaySoft);
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        decoration: BoxDecoration(color: c.claySoft, borderRadius: BorderRadius.circular(OmSize.radiusLg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: <Widget>[
            Text(t('tri_${week.trimester}'), style: caption),
            Text(t('week_n', <String, Object?>{'n': week.week}), style: OmText.display.copyWith(color: c.onClaySoft)),
            Text(weeksAndDays(t, week), style: OmText.body.copyWith(color: c.onClaySoft)),
            ProgressTrack(value: week.progress, color: c.clay, background: c.surfaceRaised),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: Text(t('due_on', <String, Object?>{'date': f.dayMonth(due)}), style: caption)),
                const SizedBox(width: 8),
                Expanded(child: Text(left, style: caption, textAlign: TextAlign.end)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Tools

class ToolsTab extends StatelessWidget {
  const ToolsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.store;
    final S t = context.t;
    final Fmt f = Fmt(t);
    final OmColors c = context.om;
    final AppData d = store.data;
    return EverySecond(
      active: d.running != 0,
      builder: (BuildContext context) {
        final int nowMs = DateTime.now().millisecondsSinceEpoch;
        final List<Contraction> cs = sortedContractions(d.contractions);
        final List<MoveSession> moves = List<MoveSession>.of(d.moves)..sort((MoveSession a, MoveSession b) => b.start.compareTo(a.start));
        final List<Appointment> upcoming = upcomingAppointments(d, nowMs);
        final List<Medicine> meds = sortedMeds(d);
        final Medicine? nextMed = meds.where((Medicine m) => !store.takenToday(m.id)).firstOrNull;
        final List<WeightEntry> ws = sortedWeights(d);

        final String cStatus = d.running != 0
            ? runningStatus(t, store, nowMs)
            : cs.isNotEmpty
                ? t('last_at', <String, Object?>{'t': '${f.dayLabel(cs.last.start)} ${f.time(cs.last.start)}'})
                : t('not_started');
        final String mStatus = d.move != null
            ? t('running_at', <String, Object?>{'t': '${d.move!.count}'})
            : moves.isNotEmpty
                ? t('last_at', <String, Object?>{'t': '${f.dayLabel(moves.first.start)} ${f.time(moves.first.start)}'})
                : t('not_started');

        return PageBody(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Semantics(header: true, child: Text(t('tools'), style: OmText.headline.copyWith(color: c.ink)))),
                OmIconButton(
                  icon: Icons.contact_phone_rounded,
                  label: t('my_numbers'),
                  onPressed: () => pushScreen(context, const NumbersScreen()),
                ),
              ],
            ),
            TwoColumns(
              children: <Widget>[
                _ToolTile(
                  icon: Icons.timer_rounded,
                  title: t('t_contraction_timer'),
                  status: cStatus,
                  running: d.running != 0,
                  onTap: () => pushScreen(context, const ContractionsScreen()),
                ),
                _ToolTile(
                  icon: Icons.touch_app_rounded,
                  title: t('t_movements'),
                  status: mStatus,
                  running: d.move != null,
                  onTap: () => pushScreen(context, const MovementsScreen()),
                ),
                _ToolTile(
                  icon: Icons.luggage_rounded,
                  tone: Tone.sage,
                  title: t('t_bag'),
                  status: t('packed_of', <String, Object?>{'a': bagPackedCount(d), 'b': bagTotal(d)}),
                  onTap: () => pushScreen(context, const BagScreen()),
                ),
                _ToolTile(
                  icon: Icons.event_rounded,
                  tone: Tone.honey,
                  title: t('t_appts'),
                  status: upcoming.isEmpty
                      ? t('nothing_planned')
                      : t('next_at', <String, Object?>{'t': '${f.dayMonthShort(upcoming.first.when)} ${upcoming.first.time}'}),
                  onTap: () => pushScreen(context, const AppointmentsScreen()),
                ),
                _ToolTile(
                  icon: Icons.medication_rounded,
                  title: t('t_meds'),
                  status: meds.isEmpty
                      ? t('none_added')
                      : nextMed != null
                          ? t('next_at', <String, Object?>{'t': nextMed.time})
                          : t('all_taken'),
                  onTap: () => pushScreen(context, const MedicinesScreen()),
                ),
                _ToolTile(
                  icon: Icons.monitor_weight_rounded,
                  tone: Tone.sage,
                  title: t('t_weight'),
                  status: ws.isEmpty ? t('not_started') : t('last_at', <String, Object?>{'t': '${f.kg(ws.last.kg)} kg'}),
                  onTap: () => pushScreen(context, const WeightScreen()),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.status,
    required this.onTap,
    this.tone = Tone.clay,
    this.running = false,
  });

  final IconData icon;
  final String title;
  final String status;
  final VoidCallback onTap;
  final Tone tone;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(OmSize.radiusLg), boxShadow: c.raisedShadow),
      child: Material(
        color: c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OmSize.radiusLg),
          side: running ? BorderSide(color: c.clay, width: 2) : BorderSide(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 128),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Lead(icon, tone: tone),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: <Widget>[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(title, maxLines: 1, style: OmText.title.copyWith(color: c.ink)),
                      ),
                      Text(
                        status,
                        style: running ? OmText.captionBold.copyWith(color: c.clay) : OmText.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ History

class _Event {
  _Event({
    required this.at,
    required this.type,
    required this.icon,
    required this.tone,
    required this.title,
    required this.sub,
    this.contraction,
    this.move,
  });

  final int at;
  final String type;
  final IconData icon;
  final Tone tone;
  final String title;
  final String sub;
  final Contraction? contraction;
  final MoveSession? move;
}

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.store;
    final S t = context.t;
    final Fmt f = Fmt(t);
    final OmColors c = context.om;
    final AppData d = store.data;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    final List<Contraction> cs = sortedContractions(d.contractions);
    final List<_Event> events = <_Event>[];
    for (int i = 0; i < cs.length; i++) {
      final double? gap = intervalBefore(cs, i, seriesStarts: d.seriesStarts);
      final String sub = t('c_long', <String, Object?>{'d': formatDuration(cs[i].durationMs / 1000)}) +
          (gap == null ? '' : ' · ${t('c_after', <String, Object?>{'d': formatDuration(gap)})}');
      events.add(_Event(at: cs[i].start, type: 'contractions', icon: Icons.timer_rounded, tone: Tone.clay, title: t('h_contraction'), sub: sub, contraction: cs[i]));
    }
    for (final MoveSession m in d.moves) {
      events.add(_Event(at: m.start, type: 'movements', icon: Icons.touch_app_rounded, tone: Tone.clay, title: t('h_session'), sub: movesLine(t, m), move: m));
    }
    for (final WeightEntry w in d.weights) {
      events.add(_Event(at: w.at, type: 'weight', icon: Icons.monitor_weight_rounded, tone: Tone.sage, title: t('h_weight'), sub: '${f.kg(w.kg)} kg'));
    }
    for (final MedTaken l in d.medLog) {
      final Medicine? med = d.meds.where((Medicine m) => m.id == l.medId).firstOrNull;
      events.add(_Event(at: l.at, type: 'meds', icon: Icons.medication_rounded, tone: Tone.honey, title: t('h_med'), sub: med?.name ?? ''));
    }
    final List<_Event> shown = events.where((_Event e) => _filter == 'all' || e.type == _filter).toList()
      ..sort((_Event a, _Event b) => b.at.compareTo(a.at));

    final List<(String, List<_Event>)> days = <(String, List<_Event>)>[];
    for (final _Event e in shown) {
      final String label = f.dayLabel(e.at, now: nowMs);
      if (days.isEmpty || days.last.$1 != label) {
        days.add((label, <_Event>[]));
      }
      days.last.$2.add(e);
    }


    return PageBody(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Semantics(header: true, child: Text(t('h_title'), style: OmText.headline.copyWith(color: c.ink)))),
            Builder(
              builder: (BuildContext ctx) => OmIconButton(
                icon: Icons.share_rounded,
                label: t('h_export'),
                onPressed: () => shareSummaryFlow(ctx),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final (String id, String key) in <(String, String)>[
              ('all', 'h_all'),
              ('contractions', 't_contractions'),
              ('movements', 't_movements'),
              ('weight', 't_weight'),
            ])
              OmChip(label: t(key), selected: _filter == id, onTap: () => setState(() => _filter = id)),
          ],
        ),
        if ((_filter == 'all' || _filter == 'contractions') && ContractionChartCard.hasData(d)) const ContractionChartCard(),
        if ((_filter == 'all' || _filter == 'movements') && MovementChartCard.hasData(d)) const MovementChartCard(),
        if (shown.isEmpty) EmptyState(icon: Icons.history_rounded, title: t('h_empty'), body: t('h_empty_sub')),
        for (final (String label, List<_Event> list) in days) ...<Widget>[
          SectionLabel(label),
          OmGroup(children: <Widget>[for (final _Event e in list) _EventRow(event: e)]),
        ],
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final _Event event;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    final S t = context.t;
    final String time = clockOfMs(event.at);
    return Material(
      color: c.surfaceRaised,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          child: Row(
            children: <Widget>[
              SizedBox(width: 56, child: Text(time, style: OmText.time.copyWith(color: c.ink))),
              Lead(event.icon, tone: event.tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(event.title, style: OmText.body.copyWith(color: c.ink)),
                    if (event.sub.isNotEmpty) Text(event.sub, style: OmText.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
              if (event.contraction != null)
                OmIconButton(
                  icon: Icons.edit_rounded,
                  label: '${t('edit')}, $time',
                  color: c.inkMuted,
                  onPressed: () => showContractionSheet(context, event.contraction!),
                )
              else if (event.move != null)
                OmIconButton(
                  icon: Icons.edit_rounded,
                  label: '${t('edit')}, $time',
                  color: c.inkMuted,
                  onPressed: () => showMoveSheet(context, event.move!),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ helpers used by several screens

List<Appointment> upcomingAppointments(AppData d, int nowMs) {
  return d.appts.where((Appointment a) => a.when.millisecondsSinceEpoch >= nowMs - 3600000).toList()
    ..sort((Appointment a, Appointment b) => a.when.compareTo(b.when));
}

List<Appointment> pastAppointments(AppData d, int nowMs) {
  return d.appts.where((Appointment a) => a.when.millisecondsSinceEpoch < nowMs - 3600000).toList()
    ..sort((Appointment a, Appointment b) => b.when.compareTo(a.when));
}

String apptWhen(Fmt f, Appointment a) => '${f.weekdayLong(a.when)}, ${a.time}';

List<Medicine> sortedMeds(AppData d) => List<Medicine>.of(d.meds)..sort((Medicine a, Medicine b) => a.time.compareTo(b.time));

List<WeightEntry> sortedWeights(AppData d) => List<WeightEntry>.of(d.weights)..sort((WeightEntry a, WeightEntry b) => a.at.compareTo(b.at));

int bagTotal(AppData d) => defaultBag.length + d.bagCustom.length;

int bagPackedCount(AppData d) {
  int n = 0;
  for (final DefaultBagItem b in defaultBag) {
    if (d.bagDone.contains(b.id)) {
      n++;
    }
  }
  for (final BagItem b in d.bagCustom) {
    if (d.bagDone.contains(b.id)) {
      n++;
    }
  }
  return n;
}

String movesLine(S t, MoveSession m) {
  final int minutes = ((m.end - m.start) / 60000).round();
  return t('m_line', <String, Object?>{'n': m.count, 'm': minutes < 1 ? 1 : minutes});
}
