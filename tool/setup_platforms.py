"""Applies Open Maternity's settings to freshly generated android/ and ios/ folders.

Run once, right after:
    flutter create --org no.openmaternity --project-name open_maternity --platforms android,ios .

It fails loudly if the generated files don't look as expected, so a Flutter
template change is noticed instead of silently producing a wrong app.
"""
import pathlib
import plistlib
import re
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ICONS = ROOT / 'tool' / 'icons'

# PLACEHOLDER: the store ID. Change it before the first upload; it can never change afterwards.
APP_ID = 'no.openmaternity.app'
APP_NAME = 'Open Maternity'


def die(msg):
    print('setup_platforms: ' + msg, file=sys.stderr)
    sys.exit(1)


def replace_once(text, old, new, what):
    if old not in text:
        die(f'could not find {what}')
    return text.replace(old, new, 1)


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


# ----------------------------------------------------------------------------- Android

def android():
    app = ROOT / 'android' / 'app'
    gradle = app / 'build.gradle.kts'
    if not gradle.exists():
        die('android/app/build.gradle.kts missing - run flutter create first')
    g = gradle.read_text()

    g = 'import java.io.FileInputStream\nimport java.util.Properties\n\n' + g
    g = replace_once(
        g,
        'android {',
        '// Release signing: android/key.properties, written by the release workflow from\n'
        '// repository secrets (see docs/RELEASE.md). Without it, release builds use the debug key.\n'
        'val keystoreProperties = Properties()\n'
        'val keystorePropertiesFile = rootProject.file("key.properties")\n'
        'if (keystorePropertiesFile.exists()) {\n'
        '    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n'
        '}\n\n'
        'android {',
        'android block',
    )
    g, n = re.subn(r'applicationId = "[^"]*"',
                   '// PLACEHOLDER store ID: change before the first Google Play upload (it can never change later).\n'
                   f'        applicationId = "{APP_ID}"', g)
    if n != 1:
        die('applicationId not found exactly once')
    g = replace_once(g, 'compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', 'compileOptions')
    g = replace_once(
        g,
        '    buildTypes {',
        '    signingConfigs {\n'
        '        create("release") {\n'
        '            if (keystorePropertiesFile.exists()) {\n'
        '                keyAlias = keystoreProperties["keyAlias"] as String\n'
        '                keyPassword = keystoreProperties["keyPassword"] as String\n'
        '                storeFile = file(keystoreProperties["storeFile"] as String)\n'
        '                storePassword = keystoreProperties["storePassword"] as String\n'
        '            }\n'
        '        }\n'
        '    }\n\n'
        '    buildTypes {',
        'buildTypes',
    )
    g, n = re.subn(r'signingConfig = signingConfigs\.getByName\("debug"\)',
                   'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") '
                   'else signingConfigs.getByName("debug")', g)
    if n != 1:
        die('release signingConfig line not found')
    g = g.rstrip() + '\n\ndependencies {\n    // Needed by flutter_local_notifications for scheduled reminders on older Android versions.\n' \
        '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    gradle.write_text(g)

    main = app / 'src' / 'main'
    manifest = main / 'AndroidManifest.xml'
    m = manifest.read_text()
    m = replace_once(m, '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
                     '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
                     '    <!-- Medicine reminders: show notifications, and set them again after a restart. -->\n'
                     '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n'
                     '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />',
                     'manifest tag')
    m, n = re.subn(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', m)
    if n != 1:
        die('application label not found')
    m = replace_once(m, 'android:icon="@mipmap/ic_launcher"',
                     'android:icon="@mipmap/ic_launcher"\n'
                     '        android:allowBackup="false"\n'
                     '        android:fullBackupContent="false"', 'application icon')
    m = replace_once(
        m,
        '        <!-- Don\'t delete the meta-data below.',
        '        <!-- Scheduled medicine reminders (flutter_local_notifications). -->\n'
        '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\n'
        '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n'
        '            <intent-filter>\n'
        '                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
        '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
        '                <action android:name="android.intent.action.QUICKBOOT_POWERON" />\n'
        '                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\n'
        '            </intent-filter>\n'
        '        </receiver>\n'
        '        <!-- Don\'t delete the meta-data below.',
        'meta-data comment',
    )
    m = replace_once(
        m,
        '    <queries>',
        '    <queries>\n'
        '        <!-- Opening the phone\'s dialler with a saved number. -->\n'
        '        <intent>\n'
        '            <action android:name="android.intent.action.DIAL" />\n'
        '            <data android:scheme="tel" />\n'
        '        </intent>\n'
        '        <intent>\n'
        '            <action android:name="android.intent.action.VIEW" />\n'
        '            <data android:scheme="tel" />\n'
        '        </intent>',
        'queries',
    )
    manifest.write_text(m)

    # Release builds can never go online.
    write(app / 'src' / 'release' / 'AndroidManifest.xml',
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n'
          '    xmlns:tools="http://schemas.android.com/tools">\n'
          '    <!-- Open Maternity works fully offline. This removes network access from release builds,\n'
          '         even if a library ever asks for it. -->\n'
          '    <uses-permission android:name="android.permission.INTERNET" tools:node="remove" />\n'
          '    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" tools:node="remove" />\n'
          '</manifest>\n')

    res = main / 'res'
    write(res / 'values' / 'colors.xml',
          '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
          '    <color name="launch_background">#FBF6F0</color>\n'
          '    <color name="ic_launcher_background">#A8502F</color>\n</resources>\n')
    write(res / 'values-night' / 'colors.xml',
          '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
          '    <color name="launch_background">#1C1714</color>\n</resources>\n')
    launch = ('<?xml version="1.0" encoding="utf-8"?>\n'
              '<!-- Shown while the app starts on Android 11 and older (newer versions show the app icon). -->\n'
              '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
              '    <item android:drawable="@color/launch_background" />\n'
              '    <item android:drawable="@drawable/launch_mark" android:gravity="center" android:width="96dp" android:height="96dp" />\n'
              '</layer-list>\n')
    write(res / 'drawable' / 'launch_background.xml', launch)
    write(res / 'drawable-v21' / 'launch_background.xml', launch)
    launch_mark = ('<?xml version="1.0" encoding="utf-8"?>\n'
                   '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
                   '    android:width="96dp" android:height="96dp" android:viewportWidth="704" android:viewportHeight="704">\n'
                   '    <path android:fillColor="{circle}" android:pathData="M212,238 a140,140 0 1,0 280,0 a140,140 0 1,0 -280,0 Z" />\n'
                   '    <path android:strokeColor="{arc}" android:strokeWidth="96" android:strokeLineCap="round"\n'
                   '        android:pathData="M92,298 A260,260 0 0,0 612,298" />\n'
                   '</vector>\n')
    write(res / 'drawable' / 'launch_mark.xml', launch_mark.format(circle='#B97D22', arc='#A8502F'))
    write(res / 'drawable-night' / 'launch_mark.xml', launch_mark.format(circle='#E0B062', arc='#E89A78'))

    # Launcher icon: PNGs for old Android, an adaptive icon (with themed monochrome layer) for 8.0+.
    for density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']:
        src = ICONS / 'android' / f'mipmap-{density}.png'
        dst = res / f'mipmap-{density}' / 'ic_launcher.png'
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
    mark = ('    <path android:fillColor="{fill}" android:pathData="M40.7,43.17 a13.3,13.3 0 1,0 26.6,0 a13.3,13.3 0 1,0 -26.6,0 Z" />\n'
            '    <path android:strokeColor="{stroke}" android:strokeWidth="9.12" android:strokeLineCap="round"\n'
            '        android:pathData="M29.3,48.87 A24.7,24.7 0 0,0 78.7,48.87" />\n')
    vector = ('<?xml version="1.0" encoding="utf-8"?>\n'
              '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
              '    android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">\n'
              '{body}</vector>\n')
    write(res / 'drawable' / 'ic_launcher_foreground.xml', vector.format(body=mark.format(fill='#F5D9A6', stroke='#FBF6F0')))
    write(res / 'drawable' / 'ic_launcher_monochrome.xml', vector.format(body=mark.format(fill='#FFFFFF', stroke='#FFFFFF')))
    write(res / 'mipmap-anydpi-v26' / 'ic_launcher.xml',
          '<?xml version="1.0" encoding="utf-8"?>\n'
          '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '    <background android:drawable="@color/ic_launcher_background" />\n'
          '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
          '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n'
          '</adaptive-icon>\n')
    # Small white icon in the status bar for reminders.
    write(res / 'drawable' / 'ic_notification.xml',
          '<?xml version="1.0" encoding="utf-8"?>\n'
          '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
          '    android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">\n'
          '    <path android:fillColor="#FFFFFF" android:pathData="M7,7.93 a5,5 0 1,0 10,0 a5,5 0 1,0 -10,0 Z" />\n'
          '    <path android:strokeColor="#FFFFFF" android:strokeWidth="3.43" android:strokeLineCap="round"\n'
          '        android:pathData="M2.72,10.07 A9.28,9.28 0 0,0 21.28,10.07" />\n'
          '</vector>\n')
    # Keep the notification icon even when resources are shrunk.
    write(res / 'raw' / 'keep.xml',
          '<?xml version="1.0" encoding="utf-8"?>\n'
          '<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@drawable/ic_notification" />\n')
    print('android: done')


# ----------------------------------------------------------------------------- iOS

def ios():
    runner = ROOT / 'ios' / 'Runner'
    info_path = runner / 'Info.plist'
    if not info_path.exists():
        die('ios/Runner/Info.plist missing - run flutter create first')
    with info_path.open('rb') as f:
        info = plistlib.load(f)
    info['CFBundleDisplayName'] = APP_NAME
    info['CFBundleName'] = APP_NAME
    info['CFBundleDevelopmentRegion'] = 'en'
    info['CFBundleLocalizations'] = ['en', 'nb', 'sv', 'da']
    info['ITSAppUsesNonExemptEncryption'] = False
    info['UISupportedInterfaceOrientations'] = ['UIInterfaceOrientationPortrait']
    info.pop('UISupportedInterfaceOrientations~ipad', None)
    info['UIRequiresFullScreen'] = True
    with info_path.open('wb') as f:
        plistlib.dump(info, f)

    pbx_path = ROOT / 'ios' / 'Runner.xcodeproj' / 'project.pbxproj'
    pbx = pbx_path.read_text()
    pbx, n = re.subn(r'PRODUCT_BUNDLE_IDENTIFIER = no\.openmaternity\.openMaternity(\.RunnerTests)?;',
                     lambda mm: f'PRODUCT_BUNDLE_IDENTIFIER = {APP_ID}{mm.group(1) or ""};', pbx)
    if n < 3:
        die(f'expected the bundle identifier at least 3 times, found {n}')
    pbx = pbx.replace('TARGETED_DEVICE_FAMILY = "1,2";', 'TARGETED_DEVICE_FAMILY = 1;')
    pbx_path.write_text(pbx)

    delegate = runner / 'AppDelegate.swift'
    d = delegate.read_text()
    d = replace_once(d, 'import UIKit', 'import UIKit\nimport UserNotifications', 'UIKit import')
    d = replace_once(
        d,
        '  ) -> Bool {',
        '  ) -> Bool {\n'
        '    // Lets medicine reminders show while the app is open.\n'
        '    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate',
        'didFinishLaunching',
    )
    delegate.write_text(d)

    launch = runner / 'Base.lproj' / 'LaunchScreen.storyboard'
    s = launch.read_text()
    s = replace_once(s, '<color key="backgroundColor" red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>',
                     '<color key="backgroundColor" red="0.984" green="0.965" blue="0.941" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>',
                     'launch screen background')
    launch.write_text(s)

    icons = runner / 'Assets.xcassets' / 'AppIcon.appiconset'
    for png in (ICONS / 'ios').glob('*.png'):
        shutil.copyfile(png, icons / png.name)
    launch_images = runner / 'Assets.xcassets' / 'LaunchImage.imageset'
    for png in (ICONS / 'ios-launch').glob('*.png'):
        shutil.copyfile(png, launch_images / png.name)
    print('ios: done')


if __name__ == '__main__':
    android()
    ios()
