import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Builds the Material theme from the design tokens, so built-in widgets
/// (date and time pickers, snack bars, switches) match the custom ones.
ThemeData buildTheme(OmColors c) {
  final ColorScheme scheme = ColorScheme(
    brightness: c.brightness,
    primary: c.clay,
    onPrimary: c.onClay,
    primaryContainer: c.claySoft,
    onPrimaryContainer: c.onClaySoft,
    secondary: c.sage,
    onSecondary: c.onSage,
    secondaryContainer: c.sageSoft,
    onSecondaryContainer: c.onSageSoft,
    tertiary: c.honey,
    onTertiary: c.onHoney,
    tertiaryContainer: c.honeySoft,
    onTertiaryContainer: c.onHoneySoft,
    error: c.urgent,
    onError: c.onUrgent,
    errorContainer: c.urgentSoft,
    onErrorContainer: c.onUrgentSoft,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkMuted,
    surfaceContainerLowest: c.surfaceRaised,
    surfaceContainerLow: c.surfaceRaised,
    surfaceContainer: c.surfaceRaised,
    surfaceContainerHigh: c.surfaceRaised,
    surfaceContainerHighest: c.surfaceSunken,
    outline: c.lineStrong,
    outlineVariant: c.line,
    shadow: const Color(0xFF000000),
    scrim: c.scrim,
    inverseSurface: c.ink,
    onInverseSurface: c.surface,
    inversePrimary: c.claySoft,
    surfaceTint: Colors.transparent,
  );

  final TextTheme textTheme = const TextTheme(
    displayLarge: OmText.display,
    displayMedium: OmText.display,
    displaySmall: OmText.headline,
    headlineLarge: OmText.headline,
    headlineMedium: OmText.headline,
    headlineSmall: OmText.titleLg,
    titleLarge: OmText.titleLg,
    titleMedium: OmText.title,
    titleSmall: OmText.label,
    bodyLarge: OmText.bodyLg,
    bodyMedium: OmText.body,
    bodySmall: OmText.caption,
    labelLarge: OmText.label,
    labelMedium: OmText.captionBold,
    labelSmall: OmText.caption,
  ).apply(bodyColor: c.ink, displayColor: c.ink);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: OmText.textFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: c.surface,
    canvasColor: c.surface,
    extensions: <ThemeExtension<dynamic>>[c],
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    iconTheme: IconThemeData(color: c.ink, size: 24),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: OmText.body.copyWith(color: c.surface),
      actionTextColor: c.id == OmThemeId.light ? c.claySoft : c.onClay,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OmSize.radiusMd)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surfaceRaised,
      modalBackgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: c.scrim,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(OmSize.radiusXl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OmSize.radiusXl)),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: c.claySoft,
      headerForegroundColor: c.onClaySoft,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: c.surfaceRaised,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.clay,
      selectionColor: c.claySoft,
      selectionHandleColor: c.clay,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.claySoft,
      height: 80,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        final bool selected = states.contains(WidgetState.selected);
        return OmText.caption.copyWith(
          color: selected ? c.ink : c.inkMuted,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        final bool selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? c.onClaySoft : c.inkMuted, size: 24);
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        return states.contains(WidgetState.selected) ? c.onClay : c.lineStrong;
      }),
      trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        return states.contains(WidgetState.selected) ? c.clay : c.surfaceSunken;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        return states.contains(WidgetState.selected) ? Colors.transparent : c.lineStrong;
      }),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.clay),
  );
}

/// Status bar and navigation bar icon colours for a theme.
SystemUiOverlayStyle overlayStyleFor(OmColors c) {
  final bool dark = c.brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
  );
}
