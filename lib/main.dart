import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/storage.dart';
import 'data/store.dart';
import 'l10n/strings.dart';
import 'services/local_reminders.dart';
import 'services/reminders.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  _registerFontLicences();

  final Reminders reminders = LocalReminders();
  try {
    await reminders.init();
  } catch (_) {
    // The app works without reminders.
  }

  final AppStore store = await AppStore.open(
    storage: FileStateStorage(),
    reminders: reminders,
    initialLang: S.guessFromDevice(),
  );
  unawaited(store.syncReminders());

  runApp(OpenMaternityApp(store: store));
}

void _registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    const List<(String, String)> fonts = <(String, String)>[
      ('Fraunces', 'assets/fonts/OFL-Fraunces.txt'),
      ('Atkinson Hyperlegible Next', 'assets/fonts/OFL-AtkinsonHyperlegibleNext.txt'),
    ];
    for (final (String name, String path) in fonts) {
      final String text = await rootBundle.loadString(path);
      yield LicenseEntryWithLineBreaks(<String>[name], text);
    }
  });
}
