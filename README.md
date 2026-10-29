# Open Maternity

A free, calm toolkit for pregnancy: contraction timer, movement counter, hospital-bag checklist, appointments, medicine reminders and a weight log. In English, Norwegian (bokmål), Swedish and Danish.

- **Free and open source.** No ads, no in-app purchases, run as a non-profit (Apache-2.0).
- **Offline.** Every tool works without internet. Release builds for Android have no network permission at all.
- **Private.** No account, no analytics, no tracking. Everything stays on the phone. The user can export a backup file or a PDF summary and share it herself.
- **No built-in phone numbers.** The user adds the numbers she needs (maternity ward, midwife, …) and calls with one tap.
- **No medical advice.** The app shows what was logged. It does not tell anyone when to go to hospital; the "Call the maternity ward" button is always on the timer screens instead.

## Try it

Every push to `main` builds an Android test APK. Download `open-maternity-test.apk` from the **test-build** release on the Releases page and open it on an Android phone. Test builds have an extra *For testing* section in Settings with sample data.

## Build it yourself

You need Flutter 3.47.8 (stable).

```sh
flutter pub get
flutter test
flutter run                      # on a connected phone or emulator
flutter build apk --release      # Android
flutter build ios --release      # iOS (on a Mac)
```

## How it is organised

| Path | What |
| --- | --- |
| `lib/data/` | The data model, calculations (pregnancy week, contraction averages) and the store that saves to one JSON file |
| `lib/l10n/` | All text, one file per language. Keep every key and `{placeholder}` when translating |
| `lib/theme/` | Design tokens from the Open Maternity design system (colours checked for WCAG AA in light, dark and night) |
| `lib/ui/` | Screens, sheets and shared widgets |
| `lib/services/` | Reminders (local notifications), dialler, backup file, PDF summary |
| `tool/` | Platform setup, icons and CI helpers |
| `docs/` | Privacy policy, store texts and the release checklist |

## Contributing translations

Text lives in `lib/l10n/strings_<lang>.dart`. The tests check that every language has every key and the same placeholders. The Norwegian, Swedish and Danish texts need a review by native speakers before the first store release.

## Releasing

See [docs/RELEASE.md](docs/RELEASE.md).
