// Building blocks that follow the Open Maternity design system.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'scope.dart';

// ------------------------------------------------------------------ buttons

enum BtnKind { primary, secondary, outlined, quiet, urgent }

class OmButton extends StatelessWidget {
  const OmButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = BtnKind.primary,
    this.expand = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BtnKind kind;
  final bool expand;

  /// Text colour for quiet buttons on tinted backgrounds.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    final Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[Icon(icon, size: 24), const SizedBox(width: 8)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    const EdgeInsets pad = EdgeInsets.symmetric(horizontal: 24, vertical: 8);
    final Widget button;
    switch (kind) {
      case BtnKind.quiet:
        return Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 1,
          heightFactor: 1,
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: color ?? c.clay,
              textStyle: OmText.label,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const StadiumBorder(),
            ),
            child: content,
          ),
        );
      case BtnKind.outlined:
        button = OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: c.ink,
            side: BorderSide(color: c.lineStrong),
            textStyle: OmText.label,
            minimumSize: const Size(64, OmSize.buttonHeight),
            padding: pad,
            shape: const StadiumBorder(),
          ),
          child: content,
        );
      case BtnKind.primary:
      case BtnKind.secondary:
      case BtnKind.urgent:
        final Color bg = kind == BtnKind.secondary ? c.sage : (kind == BtnKind.urgent ? c.urgent : c.clay);
        final Color fg = kind == BtnKind.secondary ? c.onSage : (kind == BtnKind.urgent ? c.onUrgent : c.onClay);
        button = FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            textStyle: OmText.label,
            minimumSize: const Size(64, OmSize.buttonHeight),
            padding: pad,
            shape: const StadiumBorder(),
          ),
          child: content,
        );
    }
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A round 48 px icon button with a label for screen readers.
class OmIconButton extends StatelessWidget {
  const OmIconButton({super.key, required this.icon, required this.label, required this.onPressed, this.color});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: color ?? context.om.ink,
      tooltip: label,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    );
  }
}

/// An outlined round 48 px button with an icon, e.g. call or add next to a number.
class RoundButton extends StatelessWidget {
  const RoundButton({super.key, required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: c.surfaceRaised,
        shape: CircleBorder(side: BorderSide(color: c.lineStrong)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: onPressed == null ? c.lineStrong : c.clay),
          ),
        ),
      ),
    );
  }
}

/// The round call button used next to saved numbers.
class CallButton extends StatelessWidget {
  const CallButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => RoundButton(icon: Icons.call_rounded, label: label, onPressed: onPressed);
}

/// − value + for whole numbers.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.lessLabel,
    required this.moreLabel,
    this.min = 0,
    this.max = 999,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String lessLabel;
  final String moreLabel;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    return Row(
      children: <Widget>[
        RoundButton(icon: Icons.remove_rounded, label: lessLabel, onPressed: value > min ? () => onChanged(value - 1) : null),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text('$value', textAlign: TextAlign.center, style: OmText.numeralLg.copyWith(color: c.ink)),
          ),
        ),
        RoundButton(icon: Icons.add_rounded, label: moreLabel, onPressed: value < max ? () => onChanged(value + 1) : null),
      ],
    );
  }
}

// ------------------------------------------------------------------ chips and choices

class OmChip extends StatelessWidget {
  const OmChip({super.key, required this.label, required this.onTap, this.selected = false, this.icon, this.semanticsLabel});

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final IconData? icon;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    final Color bg = selected ? c.claySoft : c.surfaceRaised;
    final Color fg = selected ? c.onClaySoft : c.ink;
    final IconData? lead = selected ? Icons.check_rounded : icon;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: BorderSide(color: selected ? c.clay : c.lineStrong)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: lead != null ? 12 : 16, end: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (lead != null) ...<Widget>[Icon(lead, size: 20, color: fg), const SizedBox(width: 4)],
                  Flexible(child: Text(label, style: OmText.label.copyWith(color: fg))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChoiceItem<T> {
  const ChoiceItem(this.value, this.label);
  final T value;
  final String label;
}

/// Segmented control: one choice out of a few.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.items, required this.value, required this.onChanged});

  final List<ChoiceItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: BorderRadius.circular(OmSize.radiusMd),
        border: Border.all(color: c.line),
      ),
      child: Row(
        spacing: 4,
        children: <Widget>[
          for (final ChoiceItem<T> item in items)
            Expanded(
              child: Semantics(
                inMutuallyExclusiveGroup: true,
                selected: item.value == value,
                button: true,
                child: Material(
                  color: item.value == value ? c.surfaceRaised : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(OmSize.radiusSm),
                    side: item.value == value ? BorderSide(color: c.lineStrong) : BorderSide.none,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(OmSize.radiusSm),
                    onTap: () => onChanged(item.value),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            item.label,
                            textAlign: TextAlign.center,
                            style: OmText.label.copyWith(color: item.value == value ? c.ink : c.inkMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ surfaces

enum Tone { clay, sage, honey }

/// The round icon at the start of rows and tiles.
class Lead extends StatelessWidget {
  const Lead(this.icon, {super.key, this.tone = Tone.clay, this.size = 40, this.iconSize = 24});

  final IconData icon;
  final Tone tone;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    final (Color bg, Color fg) = switch (tone) {
      Tone.clay => (c.claySoft, c.onClaySoft),
      Tone.sage => (c.sageSoft, c.onSageSoft),
      Tone.honey => (c.honeySoft, c.onHoneySoft),
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: iconSize, color: fg),
    );
  }
}

/// Rows grouped in one rounded box, separated by hairlines.
class OmGroup extends StatelessWidget {
  const OmGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    final List<Widget> items = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(Divider(height: 1, thickness: 1, color: c.line));
      }
      items.add(children[i]);
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(OmSize.radiusMd),
        border: Border.all(color: c.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
    );
  }
}

class OmRow extends StatelessWidget {
  const OmRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.minHeight = 64,
    this.titleStyle,
    this.singleLineTitle = false,
  });

  /// Keeps the title on one line, shrinking it slightly if needed (names in lists).
  final bool singleLineTitle;
  final String title;
  final Widget? leading;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double minHeight;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    final Widget content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (singleLineTitle)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(title, maxLines: 1, style: titleStyle ?? OmText.title.copyWith(color: c.ink)),
                    )
                  else
                    Text(title, style: titleStyle ?? OmText.title.copyWith(color: c.ink)),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(subtitle!, style: OmText.caption.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
    return Material(
      color: c.surfaceRaised,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        header: true,
        child: Text(text, style: OmText.captionBold.copyWith(color: context.om.inkMuted)),
      ),
    );
  }
}

enum NoticeTone { neutral, caution, positive }

class Notice extends StatelessWidget {
  const Notice({super.key, required this.icon, this.title, this.body, this.tone = NoticeTone.neutral, this.action, this.filledIcon = false});

  final IconData icon;
  final String? title;
  final String? body;
  final NoticeTone tone;
  final Widget? action;
  final bool filledIcon;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    final (Color bg, Color fg) = switch (tone) {
      NoticeTone.neutral => (c.surfaceSunken, c.ink),
      NoticeTone.caution => (c.honeySoft, c.onHoneySoft),
      NoticeTone.positive => (c.sageSoft, c.onSageSoft),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(OmSize.radiusMd)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 32, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: <Widget>[
                if (title != null) Text(title!, style: OmText.title.copyWith(color: fg)),
                if (body != null) Text(body!, style: OmText.body.copyWith(color: fg)),
                ?action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OmCard extends StatelessWidget {
  const OmCard({super.key, required this.children, this.onTap});

  final List<Widget> children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    final Widget inner = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: children),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(OmSize.radiusLg),
        boxShadow: c.raisedShadow,
      ),
      child: Material(
        color: c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OmSize.radiusLg),
          side: BorderSide(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? inner : InkWell(onTap: onTap, child: inner),
      ),
    );
  }
}

/// Small line with an icon, above a card's title.
class Eyebrow extends StatelessWidget {
  const Eyebrow({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final Color color = context.om.inkMuted;
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 4),
        Expanded(child: Text(text, style: OmText.caption.copyWith(color: color))),
      ],
    );
  }
}

class StatBox extends StatelessWidget {
  const StatBox({super.key, required this.value, required this.label, this.unit});

  final String value;
  final String label;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(OmSize.radiusMd),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text.rich(
              TextSpan(
                text: value,
                style: OmText.numeralLg.copyWith(color: c.ink),
                children: <InlineSpan>[
                  if (unit != null) TextSpan(text: ' $unit', style: OmText.body.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(label, maxLines: 1, style: OmText.caption.copyWith(color: c.inkMuted)),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.tone = Tone.clay});

  final IconData icon;
  final String title;
  final String body;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        spacing: 12,
        children: <Widget>[
          Lead(icon, tone: tone, size: 56, iconSize: 32),
          Text(title, textAlign: TextAlign.center, style: OmText.titleLg.copyWith(color: c.ink)),
          Text(body, textAlign: TextAlign.center, style: OmText.body.copyWith(color: c.inkMuted)),
        ],
      ),
    );
  }
}

class ProgressTrack extends StatelessWidget {
  const ProgressTrack({super.key, required this.value, this.color, this.background, this.label});

  final double value;
  final Color? color;
  final Color? background;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    return LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      minHeight: 8,
      color: color ?? c.clay,
      backgroundColor: background ?? c.surfaceRaised,
      borderRadius: BorderRadius.circular(999),
      semanticsLabel: label,
    );
  }
}

/// The big round button on the timers.
class TimerButton extends StatelessWidget {
  const TimerButton({super.key, required this.running, required this.onPressed, required this.semanticLabel, required this.child});

  final bool running;
  final VoidCallback onPressed;
  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    final Color bg = running ? c.clay : c.surfaceRaised;
    final Color fg = running ? c.onClay : c.clay;
    final Color ring = running ? c.claySoft : c.surfaceSunken;
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onPressed,
      child: Container(
        width: OmSize.timerButton + 24,
        height: OmSize.timerButton + 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
        child: Material(
          color: bg,
          shape: CircleBorder(side: running ? BorderSide.none : BorderSide(color: c.clay, width: 3)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.mediumImpact();
              onPressed();
            },
            child: SizedBox(
              width: OmSize.timerButton,
              height: OmSize.timerButton,
              child: IconTheme(
                data: IconThemeData(color: fg, size: 32),
                child: DefaultTextStyle(
                  style: OmText.label.copyWith(color: fg),
                  textAlign: TextAlign.center,
                  child: Padding(padding: const EdgeInsets.all(16), child: Center(child: child)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two equal columns that keep each row's items the same height.
class TwoColumns extends StatelessWidget {
  const TwoColumns({super.key, required this.children, this.gap = 12});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: children[i]),
              SizedBox(width: gap),
              Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: gap, children: rows);
  }
}

// ------------------------------------------------------------------ fields

OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(OmSize.radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );

class OmTextField extends StatelessWidget {
  const OmTextField({
    super.key,
    required this.label,
    required this.controller,
    this.icon,
    this.hint,
    this.help,
    this.error,
    this.keyboardType,
    this.suffix,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final String? hint;
  final String? help;
  final String? error;
  final TextInputType? keyboardType;
  final String? suffix;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    final bool hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: <Widget>[
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: <Widget>[
              Text(label, style: OmText.label.copyWith(color: c.ink)),
              TextField(
                controller: controller,
                autofocus: autofocus,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                textCapitalization: textCapitalization,
                inputFormatters: inputFormatters,
                onSubmitted: onSubmitted,
                onChanged: onChanged,
                minLines: 1,
                maxLines: maxLines,
                style: OmText.bodyLg.copyWith(color: c.ink),
                cursorColor: c.clay,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: OmText.bodyLg.copyWith(color: c.inkMuted),
                  prefixIcon: icon == null ? null : Icon(icon, color: c.inkMuted),
                  suffixText: suffix,
                  suffixStyle: OmText.body.copyWith(color: c.inkMuted),
                  filled: true,
                  fillColor: c.surfaceRaised,
                  isDense: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: _border(c.lineStrong, 1),
                  enabledBorder: _border(hasError ? c.honey : c.lineStrong, hasError ? 2 : 1),
                  focusedBorder: _border(hasError ? c.honey : c.clay, 2),
                ),
              ),
            ],
          ),
        ),
        if (help != null) Text(help!, style: OmText.caption.copyWith(color: c.inkMuted)),
        if (hasError)
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.error_rounded, size: 20, color: c.onHoneySoft),
                const SizedBox(width: 4),
                Expanded(child: Text(error!, style: OmText.caption.copyWith(color: c.onHoneySoft))),
              ],
            ),
          ),
      ],
    );
  }
}

/// Looks like a field; opens a date or time picker when tapped.
class TapField extends StatelessWidget {
  const TapField({super.key, required this.label, required this.value, required this.placeholder, required this.onTap, this.icon});

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    final String shown = value ?? placeholder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: <Widget>[
        ExcludeSemantics(child: Text(label, style: OmText.label.copyWith(color: c.ink))),
        Semantics(
          container: true,
          button: true,
          label: label,
          value: shown,
          excludeSemantics: true,
          onTap: onTap,
          child: Material(
            color: c.surfaceRaised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(OmSize.radiusMd),
              side: BorderSide(color: c.lineStrong),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(OmSize.radiusMd),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: <Widget>[
                      if (icon != null) ...<Widget>[Icon(icon, color: c.inkMuted), const SizedBox(width: 12)],
                      Expanded(
                        child: Text(shown, style: OmText.bodyLg.copyWith(color: value == null ? c.inkMuted : c.ink)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ page parts

class OmTopBar extends StatelessWidget {
  const OmTopBar({super.key, this.title, this.onBack, this.actions = const <Widget>[]});

  final String? title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 0),
        child: Row(
          children: <Widget>[
            if (onBack != null)
              OmIconButton(icon: Icons.arrow_back_rounded, label: context.t('back'), onPressed: onBack),
            Expanded(
              child: title == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Semantics(
                        header: true,
                        child: Text(title!, style: OmText.title.copyWith(color: c.ink), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Bottom area for a screen's main action, kept above the system bars.
class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.om.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: children),
        ),
      ),
    );
  }
}

/// Scrolling page body with the standard padding and spacing.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.spacing = 16});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    // Leaves room for the phone's gesture bar on screens without a bottom bar.
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
      children: <Widget>[
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: spacing, children: children),
      ],
    );
  }
}

// ------------------------------------------------------------------ feedback

/// The app's one snack bar host, so messages survive closing a sheet.
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

/// A short message at the bottom of the screen, with optional Undo.
/// Needs no context, so it can be called after a sheet has closed.
void toastText(String text, {String? undoLabel, VoidCallback? undo}) {
  final ScaffoldMessengerState? messenger = messengerKey.currentState;
  if (messenger == null) {
    return;
  }
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      persist: false,
      duration: Duration(seconds: undo == null ? 4 : 6),
      action: undo == null || undoLabel == null ? null : SnackBarAction(label: undoLabel, onPressed: undo),
    ),
  );
}

/// Same as [toastText], reading the Undo label from [context] (which must still be mounted).
void showToast(BuildContext context, String text, {VoidCallback? undo}) {
  toastText(text, undoLabel: context.tRead('undo'), undo: undo);
}

/// Rebuilds every second while [active], for running timers.
class EverySecond extends StatefulWidget {
  const EverySecond({super.key, required this.active, required this.builder});

  final bool active;
  final WidgetBuilder builder;

  @override
  State<EverySecond> createState() => _EverySecondState();
}

class _EverySecondState extends State<EverySecond> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(EverySecond oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    } else if (!widget.active && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

// ------------------------------------------------------------------ sheets

/// Opens a bottom sheet with the standard handle, title and close button.
Future<T?> showOmSheet<T>(BuildContext context, {required String title, required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext ctx) => OmSheet(title: title, child: builder(ctx)),
  );
}

class OmSheet extends StatelessWidget {
  const OmSheet({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final OmColors c = context.om;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: c.lineStrong, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: OmText.titleLg.copyWith(color: c.ink)),
                  ),
                ),
                OmIconButton(
                  icon: Icons.close_rounded,
                  label: context.tRead('close'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
