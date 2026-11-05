"""Sets up App Store signing for the release workflow.

  python3 tool/ios_signing.py --team TEAM_ID --profile app.mobileprovision
  python3 tool/ios_signing.py --dry-run

It checks the provisioning profile (app ID, team, type, expiry, certificate),
installs it where Xcode looks for it, switches the app target's Release and
Profile builds to manual signing, and writes ios/ExportOptions.plist for
`flutter build ipa`. --dry-run does the project changes with made-up values,
so the workflow can be tested without Apple keys.

The committed Xcode project keeps automatic signing; only CI runs this.
"""
import argparse
import datetime
import hashlib
import pathlib
import plistlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PBXPROJ = ROOT / 'ios' / 'Runner.xcodeproj' / 'project.pbxproj'
EXPORT_OPTIONS = ROOT / 'ios' / 'ExportOptions.plist'

# Xcode 16 and later read profiles from the first folder; older ones from the second.
PROFILE_DIRS = [
    pathlib.Path.home() / 'Library' / 'Developer' / 'Xcode' / 'UserData' / 'Provisioning Profiles',
    pathlib.Path.home() / 'Library' / 'MobileDevice' / 'Provisioning Profiles',
]


def fail(message):
    print(f'::error::{message}')
    sys.exit(1)


def app_id_from_project(pbx):
    ids = set(re.findall(r'PRODUCT_BUNDLE_IDENTIFIER = "?([^";]+)"?;', pbx))
    app_ids = sorted(i for i in ids if not i.endswith('.RunnerTests'))
    if len(app_ids) != 1:
        fail(f'Expected one app bundle ID in the Xcode project, found {app_ids or "none"}.')
    return app_ids[0]


def read_profile(path):
    raw = path.read_bytes()
    if raw.lstrip().startswith(b'<?xml') or raw.startswith(b'bplist'):
        return plistlib.loads(raw)
    if not shutil.which('security'):
        fail('The provisioning profile is signed; reading it needs macOS (security cms).')
    out = subprocess.run(['security', 'cms', '-D', '-i', str(path)], capture_output=True)
    if out.returncode != 0:
        fail('APPLE_PROVISIONING_PROFILE_BASE64 is not a provisioning profile '
             '(base64 of the downloaded .mobileprovision file).')
    return plistlib.loads(out.stdout)


def keychain_identities():
    """SHA-1 hashes of the code-signing identities in the keychains, or None off macOS."""
    if not shutil.which('security'):
        return None
    out = subprocess.run(['security', 'find-identity', '-v', '-p', 'codesigning'], capture_output=True, text=True)
    return set(re.findall(r'\b([0-9A-F]{40})\b', out.stdout))


def check_profile(profile, team, app_id):
    name = profile.get('Name', '')
    teams = profile.get('TeamIdentifier', [])
    if team not in teams:
        fail(f'The profile "{name}" belongs to team {", ".join(teams) or "?"}, but APPLE_TEAM_ID is {team}.')
    entitled = profile.get('Entitlements', {}).get('application-identifier', '')
    if entitled not in (f'{team}.{app_id}', f'{team}.*'):
        fail(f'The profile "{name}" is for {entitled}, but the app is {team}.{app_id}. '
             'Make an App Store profile for this app ID.')
    if profile.get('Entitlements', {}).get('get-task-allow'):
        fail(f'The profile "{name}" is a development profile. Make one of type "App Store Connect".')
    if profile.get('ProvisionedDevices') or profile.get('ProvisionsAllDevices'):
        fail(f'The profile "{name}" is an ad hoc or enterprise profile. Make one of type "App Store Connect".')
    expires = profile.get('ExpirationDate')
    if isinstance(expires, datetime.datetime):
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=datetime.timezone.utc)
        if expires < datetime.datetime.now(datetime.timezone.utc):
            fail(f'The profile "{name}" expired on {expires:%Y-%m-%d}. Make a new one.')
    certs = {hashlib.sha1(c).hexdigest().upper() for c in profile.get('DeveloperCertificates', [])}
    installed = keychain_identities()
    if installed is None:
        print('ios_signing: not on macOS, so the certificate match is not checked')
    elif not installed:
        fail('No signing identity was imported. APPLE_CERTIFICATE_P12_BASE64 must be a .p12 with the private key.')
    elif not certs & installed:
        fail(f'The profile "{name}" does not include the certificate from APPLE_CERTIFICATE_P12_BASE64. '
             'Edit the profile in the Apple Developer site, tick that certificate, and download it again.')
    return name


def install_profile(path, profile):
    uuid = profile.get('UUID')
    if not uuid:
        fail('The provisioning profile has no UUID.')
    for folder in PROFILE_DIRS:
        folder.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, folder / f'{uuid}.mobileprovision')


def set_manual_signing(pbx, app_id, team, profile_name):
    block = re.compile(
        r'(/\* (?:Release|Profile) \*/ = \{\n\t+isa = XCBuildConfiguration;\n(?:\t+baseConfigurationReference = [^\n]*\n)?'
        r'\t+buildSettings = \{)(.*?)(\n\t+\};\n\t+name = (?:Release|Profile);)',
        re.S,
    )
    keys = ('CODE_SIGN_STYLE', 'DEVELOPMENT_TEAM', 'PROVISIONING_PROFILE_SPECIFIER', 'CODE_SIGN_IDENTITY',
            '"CODE_SIGN_IDENTITY[sdk=iphoneos*]"')
    changed = 0

    def patch(m):
        nonlocal changed
        settings = m.group(2)
        if not re.search(r'PRODUCT_BUNDLE_IDENTIFIER = "?' + re.escape(app_id) + r'"?;', settings):
            return m.group(0)
        for key in keys:
            settings = re.sub(r'\n\t+' + re.escape(key) + r' = [^;]*;', '', settings)
        extra = ('\n\t\t\t\tCODE_SIGN_IDENTITY = "Apple Distribution";'
                 '\n\t\t\t\t"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";'
                 '\n\t\t\t\tCODE_SIGN_STYLE = Manual;'
                 f'\n\t\t\t\tDEVELOPMENT_TEAM = {team};'
                 f'\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "{profile_name}";')
        changed += 1
        return m.group(1) + extra + settings + m.group(3)

    pbx = block.sub(patch, pbx)
    if changed != 2:
        fail(f'Expected the app target to have a Release and a Profile configuration; changed {changed}.')
    return pbx


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--team')
    parser.add_argument('--profile', type=pathlib.Path)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()

    pbx = PBXPROJ.read_text()
    app_id = app_id_from_project(pbx)
    if args.dry_run:
        team, profile_name = 'ABCDE12345', 'Dry run'
    else:
        if not args.team or not args.profile:
            fail('Usage: ios_signing.py --team TEAM_ID --profile FILE (or --dry-run)')
        team = args.team.strip()
        if not re.fullmatch(r'[A-Z0-9]{10}', team):
            fail(f'APPLE_TEAM_ID should be 10 letters and digits, like ABCDE12345 (got "{team}").')
        profile = read_profile(args.profile)
        profile_name = check_profile(profile, team, app_id)
        install_profile(args.profile, profile)

    PBXPROJ.write_text(set_manual_signing(pbx, app_id, team, profile_name))
    with EXPORT_OPTIONS.open('wb') as f:
        plistlib.dump({
            'method': 'app-store-connect',
            'teamID': team,
            'signingStyle': 'manual',
            'signingCertificate': 'Apple Distribution',
            'provisioningProfiles': {app_id: profile_name},
            'uploadSymbols': True,
            'destination': 'export',
        }, f)
    print(f'ios_signing: {app_id}, team {team}, profile "{profile_name}"' + (' (dry run)' if args.dry_run else ''))


if __name__ == '__main__':
    main()
