import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/store.dart';
import 'l10n/strings.dart';
import 'theme/theme.dart';
import 'theme/tokens.dart';
import 'ui/scope.dart';
import 'ui/screens/home.dart';
import 'ui/screens/onboarding.dart';
import 'ui/widgets.dart';

final Map<OmThemeId, ThemeData> _themes = <OmThemeId, ThemeData>{
  for (final OmThemeId id in OmThemeId.values) id: buildTheme(OmColors.of(id)),
};

ThemeData themeFor(OmThemeId id) => _themes[id]!;

class OpenMaternityApp extends StatefulWidget {
  const OpenMaternityApp({super.key, required this.store});

  final AppStore store;

  @override
  State<OpenMaternityApp> createState() => _OpenMaternityAppState();
}

class _OpenMaternityAppState extends State<OpenMaternityApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      widget.store.flush();
    } else if (state == AppLifecycleState.resumed) {
      widget.store.touch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: widget.store,
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (BuildContext context, _) {
          final AppStore store = widget.store;
          final String pref = store.data.themePref;
          final S t = S(store.data.lang);
          return MaterialApp(
            title: 'Open Maternity',
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: messengerKey,
            locale: t.locale,
            supportedLocales: <Locale>[for (final String l in appLanguages) S.localeFor(l)],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: themeFor(pref == 'night' ? OmThemeId.night : OmThemeId.light),
            darkTheme: themeFor(OmThemeId.dark),
            themeMode: switch (pref) {
              'phone' => ThemeMode.system,
              'dark' => ThemeMode.dark,
              _ => ThemeMode.light,
            },
            builder: (BuildContext context, Widget? child) {
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlayStyleFor(context.om),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const RootGate(),
          );
        },
      ),
    );
  }
}

/// First run until the user has finished setup; then the main app.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return context.store.data.onboarded ? const HomeShell() : const OnboardingFlow();
  }
}

/// Theme for the timers: dim night colours from 22:00 to 06:00 (if turned on),
/// or whatever the user picked with the one-tap switch.
OmThemeId trackerThemeId(AppStore store, OmColors base, DateTime now) {
  if (store.sessionTheme == 'night') {
    return OmThemeId.night;
  }
  if (store.sessionTheme == 'day') {
    return base.id == OmThemeId.night ? OmThemeId.light : base.id;
  }
  if (store.data.nightAuto && (now.hour >= 22 || now.hour < 6)) {
    return OmThemeId.night;
  }
  return base.id;
}

class TrackerTheme extends StatelessWidget {
  const TrackerTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.store;
    final OmThemeId id = trackerThemeId(store, context.om, DateTime.now());
    final OmColors colors = OmColors.of(id);
    return Theme(
      data: themeFor(id),
      child: AnnotatedRegion<SystemUiOverlayStyle>(value: overlayStyleFor(colors), child: child),
    );
  }
}
