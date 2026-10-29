import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/calc.dart';
import '../../data/store.dart';
import '../../l10n/strings.dart';
import '../../theme/tokens.dart';
import '../../version.dart';
import '../actions.dart';
import '../scope.dart';
import '../sheets/sheets.dart';
import '../widgets.dart';
import 'home.dart';
import 'onboarding.dart';
import 'tools.dart';

/// Test builds (`--dart-define=OM_TESTING=true`) show sample data and restart tools.
const bool testingTools = bool.fromEnvironment('OM_TESTING');

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.store;
    final S t = context.t;
    final OmColors c = context.om;
    final DateTime? due = parseIsoDate(store.data.due);
    final TextStyle valueStyle = OmText.body.copyWith(color: c.inkMuted);
    final Widget chevron = Icon(Icons.chevron_right_rounded, color: c.inkMuted);

    Widget valueRow(IconData icon, String title, String value, VoidCallback onTap) => OmRow(
          leading: Icon(icon, color: c.inkMuted),
          title: title,
          minHeight: 56,
          onTap: onTap,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(value, style: valueStyle, textAlign: TextAlign.end),
              ),
              chevron,
            ],
          ),
        );

    Widget actionRow(IconData icon, String title, String sub, VoidCallback onTap) => OmRow(
          leading: Icon(icon, color: c.inkMuted),
          title: title,
          subtitle: sub,
          onTap: onTap,
        );

    return ToolPage(
      title: t('s_title'),
      body: PageBody(
        children: <Widget>[
          Notice(icon: Icons.lock_rounded, title: t('s_priv_t'), body: t('s_priv_b')),
          SectionLabel(t('s_phone')),
          OmGroup(
            children: <Widget>[
              valueRow(Icons.translate_rounded, t('s_lang'), t('lang_self'), () {
                pushScreen(
                  context,
                  Builder(
                    builder: (BuildContext ctx) => LanguageScreen(
                      onBack: () => Navigator.of(ctx).pop(),
                      onContinue: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                );
              }),
              valueRow(
                Icons.contact_phone_rounded,
                t('my_numbers'),
                t('n_saved', <String, Object?>{'n': store.savedNumberCount}),
                () => pushScreen(context, const NumbersScreen()),
              ),
              valueRow(
                Icons.event_rounded,
                t('s_due'),
                due == null ? t('not_added') : context.fmt.date(due),
                () => openDueScreen(context),
              ),
              Material(
                color: c.surfaceRaised,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.dark_mode_rounded, color: c.inkMuted),
                          const SizedBox(width: 12),
                          Text(t('s_theme'), style: OmText.title.copyWith(color: c.ink)),
                        ],
                      ),
                      Segmented<String>(
                        items: <ChoiceItem<String>>[
                          for (final String id in <String>['phone', 'light', 'dark', 'night']) ChoiceItem<String>(id, t('th_$id')),
                        ],
                        value: store.data.themePref,
                        onChanged: store.setThemePref,
                      ),
                    ],
                  ),
                ),
              ),
              MergeSemantics(
                child: OmRow(
                  leading: Icon(Icons.nightlight_rounded, color: c.inkMuted),
                  title: t('s_night'),
                  subtitle: t('s_night_sub'),
                  onTap: () => store.setNightAuto(!store.data.nightAuto),
                  trailing: Switch(value: store.data.nightAuto, onChanged: store.setNightAuto),
                ),
              ),
            ],
          ),
          SectionLabel(t('s_backup')),
          OmGroup(
            children: <Widget>[
              actionRow(Icons.download_rounded, t('s_export'), t('s_export_sub'), () => exportBackupFlow(context)),
              actionRow(Icons.upload_rounded, t('s_restore'), t('s_restore_sub'), () => restoreBackupFlow(context)),
              Builder(
                builder: (BuildContext ctx) =>
                    actionRow(Icons.share_rounded, t('s_summary'), t('s_summary_sub'), () => shareSummaryFlow(ctx)),
              ),
            ],
          ),
          OmGroup(
            children: <Widget>[
              actionRow(Icons.delete_rounded, t('s_delete'), t('s_delete_sub'), () => showDeleteAllSheet(context)),
            ],
          ),
          SectionLabel(t('s_about')),
          OmGroup(
            children: <Widget>[
              actionRow(Icons.description_rounded, t('s_licenses'), 'Open Maternity $appVersion', () {
                showLicensePage(context: context, applicationName: 'Open Maternity', applicationVersion: appVersion);
              }),
            ],
          ),
          if (kDebugMode || testingTools) ...<Widget>[
            SectionLabel(t('s_test')),
            OmGroup(
              children: <Widget>[
                actionRow(Icons.science_rounded, t('s_sample'), t('s_sample_sub'), () {
                  store.fillSample();
                  showToast(context, t('s_sample_done'));
                }),
                actionRow(Icons.restart_alt_rounded, t('s_restart'), t('s_restart_sub'), () {
                  Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
                  store.restartOnboarding();
                }),
              ],
            ),
          ],
          Text(
            '${t('s_footer')} ${t('s_version', <String, Object?>{'v': appVersion})}',
            style: OmText.caption.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}
