// First run: language, welcome, due date, numbers. Language and due date are
// also reused from Settings.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/calc.dart';
import '../../data/store.dart';
import '../../l10n/strings.dart';
import '../../theme/tokens.dart';
import '../actions.dart';
import '../scope.dart';
import '../widgets.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;

  void _go(int step) => setState(() => _step = step);

  @override
  Widget build(BuildContext context) {
    final Widget page = switch (_step) {
      0 => LanguageScreen(onContinue: () => _go(1)),
      1 => WelcomeScreen(onBack: () => _go(0), onStart: () => _go(2)),
      2 => DueScreen(firstRun: true, onBack: () => _go(1), onDone: () => _go(3)),
      _ => SetupScreen(onBack: () => _go(2), onDone: () => context.storeRead.completeOnboarding()),
    };
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _step > 0) {
          _go(_step - 1);
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(key: ValueKey<int>(_step), child: page),
      ),
    );
  }
}

// ------------------------------------------------------------------ language

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key, required this.onContinue, this.onBack});

  final VoidCallback onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.store;
    final S t = context.t;
    final OmColors c = context.om;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (onBack != null) OmTopBar(onBack: onBack) else const SizedBox(height: 32),
            Expanded(
              child: PageBody(
                children: <Widget>[
                  Semantics(header: true, child: Text(t('lang_title'), style: OmText.headline.copyWith(color: c.ink))),
                  Text(t('lang_sub'), style: OmText.body.copyWith(color: c.inkMuted)),
                  OmGroup(
                    children: <Widget>[
                      for (final String lang in appLanguages)
                        _LanguageRow(
                          name: S(lang)('lang_self'),
                          caption: t('lang_$lang'),
                          locale: S.localeFor(lang),
                          selected: store.data.lang == lang,
                          onTap: () => store.setLang(lang),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomBar(
        children: <Widget>[OmButton(label: t('continue'), onPressed: onContinue, expand: true)],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.name, required this.caption, required this.locale, required this.selected, required this.onTap});

  final String name;
  final String caption;
  final Locale locale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: c.surfaceRaised,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(name, locale: locale, style: OmText.title.copyWith(color: c.ink)),
                        Text(caption, style: OmText.caption.copyWith(color: c.inkMuted)),
                      ],
                    ),
                  ),
                  if (selected) Icon(Icons.check_circle_rounded, color: c.clay),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ welcome

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onBack, required this.onStart});

  final VoidCallback onBack;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final S t = context.t;
    final OmColors c = context.om;
    Widget point(IconData icon, String title, String sub) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Lead(icon, tone: Tone.sage),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: OmText.title.copyWith(color: c.ink)),
                  Text(sub, style: OmText.caption.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
          ],
        );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            OmTopBar(onBack: onBack),
            Expanded(
              child: PageBody(
                spacing: 24,
                children: <Widget>[
                  const Align(alignment: AlignmentDirectional.centerStart, child: WelcomeArt()),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: <Widget>[
                      Semantics(header: true, child: Text(t('w_title'), style: OmText.display.copyWith(color: c.ink))),
                      Text(t('w_sub'), style: OmText.bodyLg.copyWith(color: c.inkMuted)),
                    ],
                  ),
                  Column(
                    spacing: 16,
                    children: <Widget>[
                      point(Icons.money_off_rounded, t('w_free'), t('w_free_sub')),
                      point(Icons.wifi_off_rounded, t('w_offline'), t('w_offline_sub')),
                      point(Icons.lock_rounded, t('w_private'), t('w_private_sub')),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.info_rounded, size: 20, color: c.inkMuted),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t('w_disclaimer'), style: OmText.caption.copyWith(color: c.inkMuted))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomBar(
        children: <Widget>[OmButton(label: t('w_start'), onPressed: onStart, expand: true)],
      ),
    );
  }
}

/// The soft shapes on the welcome screen (decorative).
class WelcomeArt extends StatelessWidget {
  const WelcomeArt({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(width: 208, height: 120, child: CustomPaint(painter: _WelcomePainter(context.om))),
    );
  }
}

class _WelcomePainter extends CustomPainter {
  _WelcomePainter(this.c);

  final OmColors c;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / 208, size.height / 120);
    canvas.translate(0, -16); // the drawing's view box starts at y = 16
    final Paint p = Paint()..isAntiAlias = true;
    p.color = c.clay;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 32, 96, 160), const Radius.circular(48)), p);
    p.color = c.sage;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(112, -40, 64, 120), const Radius.circular(32)), p);
    p.color = c.honey;
    canvas.drawCircle(const Offset(144, 112), 24, p);
    p.color = c.claySoft;
    canvas.drawCircle(const Offset(192, 40), 16, p);
    for (final double y in <double>[88, 104]) {
      for (final double x in <double>[32, 48, 64]) {
        canvas.drawCircle(Offset(x, y), 4, p);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WelcomePainter oldDelegate) => oldDelegate.c != c;
}

// ------------------------------------------------------------------ due date

class DueScreen extends StatefulWidget {
  const DueScreen({super.key, required this.firstRun, required this.onBack, required this.onDone});

  final bool firstRun;
  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  State<DueScreen> createState() => _DueScreenState();
}

class _DueScreenState extends State<DueScreen> {
  DateTime? _due;

  @override
  void initState() {
    super.initState();
    _due = parseIsoDate(context.storeRead.data.due);
  }

  Future<bool> _choose() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime? d = await pickDate(
      context,
      initial: _due ?? today.add(const Duration(days: 140)),
      first: today.subtract(const Duration(days: 60)),
      last: today.add(const Duration(days: 300)),
    );
    if (d != null && mounted) {
      setState(() => _due = d);
      return true;
    }
    return false;
  }

  Future<void> _continue() async {
    if (_due == null) {
      final bool chosen = await _choose();
      if (!chosen) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    context.storeRead.setDue(isoDate(_due!));
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final S t = context.t;
    final OmColors c = context.om;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            OmTopBar(
              onBack: widget.onBack,
              actions: <Widget>[
                if (widget.firstRun) OmButton(label: t('skip'), kind: BtnKind.quiet, onPressed: widget.onDone),
                const SizedBox(width: 8),
              ],
            ),
            Expanded(
              child: PageBody(
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: <Widget>[
                      Semantics(header: true, child: Text(t('due_title'), style: OmText.headline.copyWith(color: c.ink))),
                      Text(t('due_sub'), style: OmText.body.copyWith(color: c.inkMuted)),
                    ],
                  ),
                  TapField(
                    label: t('due_label'),
                    value: _due == null ? null : context.fmt.dateLong(_due!),
                    placeholder: t('choose_date'),
                    icon: Icons.event_rounded,
                    onTap: _choose,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomBar(
        children: <Widget>[
          OmButton(label: widget.firstRun ? t('continue') : t('save'), onPressed: _continue, expand: true),
        ],
      ),
    );
  }
}

/// Opens the due date screen from Today or Settings.
Future<void> openDueScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext ctx) => DueScreen(
        firstRun: false,
        onBack: () => Navigator.of(ctx).pop(),
        onDone: () => Navigator.of(ctx).pop(),
      ),
    ),
  );
}

// ------------------------------------------------------------------ numbers

final List<TextInputFormatter> _phoneFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9+*#()\- ]')),
  LengthLimitingTextInputFormatter(32),
];

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.onBack, required this.onDone});

  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final TextEditingController _ward;
  late final TextEditingController _midwife;

  @override
  void initState() {
    super.initState();
    final AppStore store = context.storeRead;
    _ward = TextEditingController(text: store.data.number('ward'));
    _midwife = TextEditingController(text: store.data.number('midwife'));
  }

  @override
  void dispose() {
    _ward.dispose();
    _midwife.dispose();
    super.dispose();
  }

  void _save() {
    final AppStore store = context.storeRead;
    store.setNumber('ward', _ward.text);
    store.setNumber('midwife', _midwife.text);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final S t = context.t;
    final OmColors c = context.om;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            OmTopBar(
              onBack: widget.onBack,
              actions: <Widget>[
                OmButton(label: t('skip'), kind: BtnKind.quiet, onPressed: widget.onDone),
                const SizedBox(width: 8),
              ],
            ),
            Expanded(
              child: PageBody(
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: <Widget>[
                      Semantics(header: true, child: Text(t('n_title'), style: OmText.headline.copyWith(color: c.ink))),
                      Text(t('n_sub'), style: OmText.body.copyWith(color: c.inkMuted)),
                    ],
                  ),
                  OmTextField(
                    label: t('role_ward'),
                    controller: _ward,
                    icon: Icons.local_hospital_rounded,
                    hint: t('phone_ph'),
                    help: t('n_ward_help'),
                    keyboardType: TextInputType.phone,
                    inputFormatters: _phoneFormatters,
                    textInputAction: TextInputAction.next,
                  ),
                  OmTextField(
                    label: t('role_midwife'),
                    controller: _midwife,
                    icon: Icons.person_rounded,
                    hint: t('phone_ph'),
                    keyboardType: TextInputType.phone,
                    inputFormatters: _phoneFormatters,
                    textInputAction: TextInputAction.done,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.contact_phone_rounded, size: 20, color: c.inkMuted),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t('n_more_later'), style: OmText.caption.copyWith(color: c.inkMuted))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomBar(
        children: <Widget>[OmButton(label: t('n_save'), onPressed: _save, expand: true)],
      ),
    );
  }
}
