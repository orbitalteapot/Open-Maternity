import 'package:flutter/widgets.dart';

import '../data/store.dart';
import '../l10n/format.dart';
import '../l10n/strings.dart';

/// Makes the store available to every screen and rebuilds them when it changes.
class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  static AppStore watch(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  }

  static AppStore read(BuildContext context) {
    return context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
  }
}

extension AppContext on BuildContext {
  /// The store; the widget rebuilds when anything changes.
  AppStore get store => AppScope.watch(this);

  /// The store, without rebuilding. Use in callbacks.
  AppStore get storeRead => AppScope.read(this);

  /// Text in the user's language.
  S get t => S(AppScope.watch(this).data.lang);

  /// Text in the user's language, without rebuilding. Use in callbacks.
  S get tRead => S(AppScope.read(this).data.lang);

  Fmt get fmt => Fmt(t);
}
