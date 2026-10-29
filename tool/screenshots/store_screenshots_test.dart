// Store screenshots in all four languages, rendered with the real fonts.
// Not part of the normal test run (it lives outside test/). Make them with:
//   flutter test --update-goldens tool/screenshots
// The images land in tool/screenshots/out/<store>/<language>/.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:open_maternity/app.dart';
import 'package:open_maternity/data/calc.dart';
import 'package:open_maternity/data/models.dart';
import 'package:open_maternity/data/storage.dart';
import 'package:open_maternity/data/store.dart';
import 'package:open_maternity/l10n/strings.dart';
import 'package:open_maternity/ui/screens/tools.dart';

class _Device {
  const _Device(this.folder, this.logical, this.ratio);
  final String folder;
  final Size logical;
  final double ratio;
}

// App Store 6.9" (1290 x 2796) and Google Play phone (1080 x 2160).
const List<_Device> _devices = <_Device>[
  _Device('appstore', Size(430, 932), 3),
  _Device('play', Size(400, 800), 2.7),
];

Future<void> _loadFont(String family, List<String> files) async {
  final FontLoader loader = FontLoader(family);
  for (final String f in files) {
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

String? _materialIconsFont() {
  final List<String> roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null) Platform.environment['FLUTTER_ROOT']!,
  ];
  Directory d = File(Platform.resolvedExecutable).parent;
  for (int i = 0; i < 10; i++) {
    roots.add(d.path);
    d = d.parent;
  }
  for (final String root in roots) {
    final File f = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (f.existsSync()) {
      return f.path;
    }
  }
  return null;
}

Future<AppStore> _demoStore(String lang) async {
  final DateTime now = DateTime.now();
  final AppStore store = AppStore(
    storage: MemoryStateStorage(),
    saveDelay: Duration.zero,
    data: AppData(
      onboarded: true,
      lang: lang,
      due: isoDate(now.add(const Duration(days: 26))),
      numbers: <String, String>{
        'ward': '12 34 56 78',
        'midwife': '23 45 67 89',
        'centre': '',
        'doctor': '',
        'emergency': '',
        'support': '',
      },
    ),
  );
  store.data.nightAuto = false;
  store.fillSample();
  return store;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await _loadFont('Atkinson Hyperlegible Next', <String>[
      'assets/fonts/AtkinsonHyperlegibleNext-Regular.ttf',
      'assets/fonts/AtkinsonHyperlegibleNext-SemiBold.ttf',
      'assets/fonts/AtkinsonHyperlegibleNext-Bold.ttf',
    ]);
    await _loadFont('Fraunces', <String>['assets/fonts/Fraunces-SemiBold.ttf']);
    final String? icons = _materialIconsFont();
    if (icons != null) {
      await _loadFont('MaterialIcons', <String>[icons]);
    }
  });

  for (final _Device device in _devices) {
    for (final String lang in appLanguages) {
      testWidgets('${device.folder} $lang', (WidgetTester tester) async {
        tester.view.physicalSize = device.logical * device.ratio;
        tester.view.devicePixelRatio = device.ratio;
        addTearDown(tester.view.reset);

        final AppStore store = await _demoStore(lang);
        await tester.pumpWidget(OpenMaternityApp(store: store));
        await tester.pumpAndSettle();
        final String dir = 'out/${device.folder}/$lang';

        Future<void> shot(String name) async {
          await tester.pumpAndSettle();
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('$dir/$name.png'));
        }

        Future<void> open(Widget screen) async {
          tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(builder: (_) => screen));
          await tester.pumpAndSettle();
        }

        Future<void> back() async {
          tester.state<NavigatorState>(find.byType(Navigator).first).pop();
          await tester.pumpAndSettle();
        }

        await shot('1_today');

        await open(const ContractionsScreen());
        await shot('2_contractions');
        await back();

        store.startMoves();
        for (int i = 0; i < 7; i++) {
          store.countMove();
        }
        await open(const MovementsScreen());
        await tester.pump(const Duration(seconds: 1));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('$dir/3_movements.png'));
        store.endMoves();
        await tester.pump(const Duration(seconds: 7));
        await back();

        await tester.tap(find.byType(NavigationDestination).at(1));
        await shot('4_tools');

        await open(const BagScreen());
        await shot('5_bag');
        await back();

        await tester.tap(find.byType(NavigationDestination).at(2));
        await shot('6_history');

        await open(const NumbersScreen());
        await shot('7_numbers');
        await back();

        await tester.pump(const Duration(seconds: 7));
      });
    }
  }
}
