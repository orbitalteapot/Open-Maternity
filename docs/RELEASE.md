# Releasing Open Maternity

Everything builds in GitHub Actions, so you don't need a Mac. Store builds start when you push a tag such as `v1.0.0`, or when you run the **Release** workflow by hand. Each platform is skipped, with a note in the run, until its secrets are added.

## Before the first release

- [ ] **Choose the final app ID.** `no.openmaternity.app` is a placeholder. It is used in `android/app/build.gradle.kts` (`applicationId`), in `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`, 3 places), and in `.github/workflows/release.yml` and `tool/ios_signing.py`. It can never change after the first upload. Use a domain you control, reversed.
- [ ] **Check the name.** Search the stores and trademark registers for "Open Maternity".
- [ ] **Native-speaker review** of `lib/l10n/strings_nb.dart`, `strings_sv.dart`, `strings_da.dart` and the store texts in `docs/STORE_LISTING.md`.
- [ ] **Publish the privacy policy.** Make the repository public (or turn on GitHub Pages) so `docs/PRIVACY.md` has a public URL.
- [ ] **Test on real phones**: the test APK from the *test-build* release, and TestFlight on iPhone.
- [ ] **Screenshots**: phone screenshots in each language you list. Play needs at least 2; the App Store needs 6.9-inch iPhone screenshots.

## Version numbers

`version:` in `pubspec.yaml` (and `lib/version.dart`, which a test keeps in sync) is the version people see. The build number comes from the GitHub run number, so it always goes up.

## Android: Google Play

1. Create a Google Play developer account (one-time fee). **Personal accounts** must run a closed test with at least 12 testers for 14 days before they can publish to production. Organisation accounts skip this but need a D-U-N-S number.
2. Make an upload key, once, and keep a safe copy. With a JDK or Android Studio installed:
   ```sh
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
3. Turn it into text for GitHub. On Windows PowerShell:
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Content keystore.txt
   ```
   On macOS or Linux: `base64 -i upload-keystore.jks > keystore.txt`.
4. In the GitHub repository: **Settings → Secrets and variables → Actions → New repository secret**:

   | Secret | Value |
   | --- | --- |
   | `ANDROID_KEYSTORE_BASE64` | contents of `keystore.txt` |
   | `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
   | `ANDROID_KEY_ALIAS` | `upload` |
   | `ANDROID_KEY_PASSWORD` | the key password |

5. Push a tag (`git tag v1.0.0 && git push origin v1.0.0`) or run **Actions → Release → Run workflow**. Download `open-maternity.aab` from the run (or the GitHub release) and upload it in Play Console. Use **Play App Signing** when asked.
6. Optional, for automatic uploads to the internal testing track: create a Google Cloud service account with access to your Play Console app and add its JSON key as `PLAY_SERVICE_ACCOUNT_JSON`. The app must already exist in Play Console, with one AAB uploaded by hand.
7. Fill in **App content** using `docs/STORE_LISTING.md`: privacy policy, Data safety (no data collected), Health apps, ads (none), target audience (18+), content rating.

## iOS: App Store

You need the Apple Developer Program (yearly fee). Organisations need a D-U-N-S number. Apple may ask that health-related apps come from an organisation rather than a private person, so an organisation account is the safer choice for a non-profit.

1. **App ID:** in *Certificates, Identifiers & Profiles → Identifiers*, register an App ID with the bundle ID above. No capabilities are needed.
2. **Distribution certificate**, without a Mac, using OpenSSL (Git for Windows includes it):
   ```sh
   openssl req -new -newkey rsa:2048 -nodes -keyout dist.key -out dist.csr -subj "/emailAddress=YOU@EXAMPLE.COM/CN=YOUR NAME/C=NO"
   ```
   Upload `dist.csr` under *Certificates → + → Apple Distribution*, download `distribution.cer`, then:
   ```sh
   openssl x509 -in distribution.cer -inform DER -out dist.pem -outform PEM
   openssl pkcs12 -export -legacy -inkey dist.key -in dist.pem -out dist.p12
   ```
   Choose a password for `dist.p12`.
3. **Provisioning profile:** *Profiles → + → App Store Connect*, pick the App ID and certificate, name it (for example "Open Maternity App Store") and download it.
4. **App Store Connect API key:** *App Store Connect → Users and Access → Integrations → App Store Connect API*, create a key with the *App Manager* role, download the `.p8` file (only once), and note the Key ID and Issuer ID.
5. Create the app in App Store Connect with the same bundle ID.
6. Add the secrets (base64 the files as for Android):

   | Secret | Value |
   | --- | --- |
   | `APPLE_TEAM_ID` | your 10-character team ID |
   | `APPLE_CERTIFICATE_P12_BASE64` | `dist.p12`, base64 |
   | `APPLE_CERTIFICATE_PASSWORD` | the `.p12` password |
   | `APPLE_PROVISIONING_PROFILE_BASE64` | the `.mobileprovision` file, base64 |
   | `APP_STORE_CONNECT_API_KEY_ID` | Key ID |
   | `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |
   | `APP_STORE_CONNECT_API_KEY_P8_BASE64` | the `.p8` file, base64 |

7. Run the Release workflow. The build goes to **TestFlight**. Install TestFlight on your iPhone to test, then submit for review from App Store Connect. Use the review notes, privacy answers and age rating in `docs/STORE_LISTING.md`.

## What the app may never do

Keep these when changing the app; they are what the store forms and the privacy policy promise:

- No network access, no analytics or crash-reporting SDKs, no ads.
- No phone numbers or medical advice built in.
- No automatic "go to hospital now" alerts. Those would make the app a medical device under EU MDR.
