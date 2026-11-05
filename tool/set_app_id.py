"""Changes the store app ID (Android applicationId and iOS bundle ID) everywhere.

  python3 tool/set_app_id.py com.example.openmaternity

Do this once, before the first store upload: the ID can never change after that.
The release workflow and tool/ios_signing.py read the ID from these files.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
GRADLE = ROOT / 'android' / 'app' / 'build.gradle.kts'
PBXPROJ = ROOT / 'ios' / 'Runner.xcodeproj' / 'project.pbxproj'

if len(sys.argv) != 2 or not re.fullmatch(r'[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+', sys.argv[1]):
    sys.exit('Usage: python3 tool/set_app_id.py com.example.app  (lower case letters and digits, '
             'at least two parts separated by dots, each part starting with a letter)')
new = sys.argv[1]

gradle = GRADLE.read_text()
gradle, n = re.subn(r'applicationId = "[^"]+"', f'applicationId = "{new}"', gradle)
if n != 1:
    sys.exit('Could not find applicationId in android/app/build.gradle.kts')
GRADLE.write_text(gradle)

pbx = PBXPROJ.read_text()
pbx, n = re.subn(r'PRODUCT_BUNDLE_IDENTIFIER = "?[^";]+?(\.RunnerTests)?"?;',
                 lambda m: f'PRODUCT_BUNDLE_IDENTIFIER = {new}{m.group(1) or ""};', pbx)
if n == 0:
    sys.exit('Could not find PRODUCT_BUNDLE_IDENTIFIER in ios/Runner.xcodeproj/project.pbxproj')
PBXPROJ.write_text(pbx)
print(f'App ID is now {new} (Android and iOS, {n} places in the Xcode project).')
