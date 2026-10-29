import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:open_maternity/app.dart';
import 'package:open_maternity/data/models.dart';
import 'package:open_maternity/data/storage.dart';
import 'package:open_maternity/data/store.dart';

Future<AppStore> _store({AppData? data}) async {
  final AppStore store = AppStore(storage: MemoryStateStorage(), data: data, saveDelay: Duration.zero);
  return store;
}

Future<void> _pump(WidgetTester tester, AppStore store) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(OpenMaternityApp(store: store));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  testWidgets('first run: language, welcome, due date skipped, numbers', (WidgetTester tester) async {
    final AppStore store = await _store();
    await _pump(tester, store);

    expect(find.text('Choose your language'), findsOneWidget);
    await tester.tap(find.text('Svenska'));
    await tester.pumpAndSettle();
    expect(find.text('Välj språk'), findsOneWidget);
    expect(store.data.lang, 'sv');

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Calm tools for your pregnancy'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('When is your due date?'), findsOneWidget);

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.text('Add the numbers you may need'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '22 33 44 55');
    await tester.tap(find.text('Save numbers'));
    await tester.pumpAndSettle();

    expect(store.data.onboarded, isTrue);
    expect(store.data.number('ward'), '22 33 44 55');
    expect(find.text('Add your due date to see which week you are in.'), findsOneWidget);
    expect(find.text("Add your midwife's number"), findsOneWidget);
  });

  testWidgets('contraction timer start, stop and undo', (WidgetTester tester) async {
    final AppStore store = await _store(data: AppData(onboarded: true, due: '2026-11-26'));
    await _pump(tester, store);

    await tester.tap(find.text('Contractions'));
    await tester.pumpAndSettle();
    expect(find.text('Tap Start when a contraction begins.'), findsOneWidget);
    expect(find.text("Add the ward's number"), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Start'));
    await tester.pump();
    expect(store.data.running, isNot(0));

    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Stop, ')));
    await tester.pump();
    expect(store.data.running, 0);
    expect(store.data.contractions.length, 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Contraction saved'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(store.data.contractions, isEmpty);
    expect(store.data.running, isNot(0));

    // Stop again so no timer is left running.
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Stop, ')));
    await tester.pumpAndSettle(const Duration(seconds: 7));
    expect(store.data.contractions.length, 1);
  });

  testWidgets('every tool opens', (WidgetTester tester) async {
    final AppStore store = await _store(data: AppData(onboarded: true, due: '2026-11-26'));
    store.fillSample();
    store.data.running = 0;
    await _pump(tester, store);

    await tester.tap(find.text('Tools').last);
    await tester.pumpAndSettle();
    for (final String tool in <String>['Hospital bag', 'Appointments', 'Medicines', 'Weight']) {
      await tester.tap(find.text(tool).first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back'), findsOneWidget, reason: tool);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    expect(find.text('Last hour'), findsOneWidget);
  });

  testWidgets('settings opens and changes theme', (WidgetTester tester) async {
    final AppStore store = await _store(data: AppData(onboarded: true));
    await _pump(tester, store);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Everything stays on this phone'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(store.data.themePref, 'dark');
  });
}
