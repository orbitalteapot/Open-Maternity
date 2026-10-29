"""Switches the app target's Release build to manual signing, for CI store builds.

Usage: python3 tool/ios_signing.py TEAM_ID "Provisioning profile name"
Also writes ios/ExportOptions.plist for `flutter build ipa`.
Only used inside the release workflow; the committed project keeps automatic signing.
"""
import pathlib
import plistlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP_ID = 'no.openmaternity.app'

team, profile = sys.argv[1], sys.argv[2]
pbx_path = ROOT / 'ios' / 'Runner.xcodeproj' / 'project.pbxproj'
pbx = pbx_path.read_text()

block = re.compile(r'(/\* (Release|Profile) \*/ = \{\s*isa = XCBuildConfiguration;.*?buildSettings = \{)(.*?)(\n\t\t\t\};)', re.S)
changed = 0


def patch(m):
    global changed
    settings = m.group(3)
    if f'PRODUCT_BUNDLE_IDENTIFIER = {APP_ID};' not in settings:
        return m.group(0)
    for key in ('CODE_SIGN_STYLE', 'DEVELOPMENT_TEAM', 'PROVISIONING_PROFILE_SPECIFIER', 'CODE_SIGN_IDENTITY', '"CODE_SIGN_IDENTITY[sdk=iphoneos*]"'):
        settings = re.sub(r'\n\t+' + re.escape(key) + r' = [^;]*;', '', settings)
    extra = (f'\n\t\t\t\tCODE_SIGN_IDENTITY = "Apple Distribution";'
             f'\n\t\t\t\tCODE_SIGN_STYLE = Manual;'
             f'\n\t\t\t\tDEVELOPMENT_TEAM = {team};'
             f'\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "{profile}";')
    changed += 1
    return m.group(1) + extra + settings + m.group(4)


pbx = block.sub(patch, pbx)
if changed == 0:
    sys.exit('ios_signing: no Release configuration for the app target found')
pbx_path.write_text(pbx)

with (ROOT / 'ios' / 'ExportOptions.plist').open('wb') as f:
    plistlib.dump({
        'method': 'app-store-connect',
        'teamID': team,
        'signingStyle': 'manual',
        'signingCertificate': 'Apple Distribution',
        'provisioningProfiles': {APP_ID: profile},
        'uploadSymbols': True,
        'destination': 'export',
    }, f)
print(f'ios_signing: manual signing set on {changed} configuration(s)')
