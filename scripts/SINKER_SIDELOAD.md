# Sinker iOS Sideload Build

## 1) (One-time) Prepare project signing for your own bundle/team

```bash
cd ~/Development/Sinker/DuckDuckGo-iOS
BASE_BUNDLE_ID=com.brown2804.sinker TEAM_ID=<YOUR_TEAM_ID> scripts/prepare_sinker_signing.sh
```

## 2) Archive + IPA Export

```bash
cd ~/Development/Sinker/DuckDuckGo-iOS
TEAM_ID=<YOUR_TEAM_ID> scripts/build_sinker_ipa.sh
```

Default values:
- Scheme: `iOS Browser`
- Archive path: `build/Sinker.xcarchive`
- IPA export path: `build/Sinker-ipa`
- Export options: `adhocExportOptions.plist`

## 3) Custom export/signing options

```bash
EXPORT_OPTIONS_PLIST=alphaAdhocExportOptions.plist scripts/build_sinker_ipa.sh
```

Use your own Apple Team for automatic signing attempt:

```bash
TEAM_ID=<YOUR_TEAM_ID> scripts/build_sinker_ipa.sh
```

If you already installed profiles manually and don't want Xcode auto-provision updates:

```bash
TEAM_ID=<YOUR_TEAM_ID> ALLOW_PROVISIONING_UPDATES=0 scripts/build_sinker_ipa.sh
```

If you intentionally want to skip keychain signing preflight checks:

```bash
SKIP_SIGNING_PREFLIGHT=1 scripts/build_sinker_ipa.sh
```

## 4) Install to iPad (AltStore/SideStore)

1. Open AltStore/SideStore.
2. Select the generated `.ipa` from `build/Sinker-ipa/`.
3. Trust developer profile on iPad if needed.

## Notes
- You need a valid signing profile/certificate for archive export.
- Current environment archive failure is due to missing provisioning profiles for team `HKE973VLUW` (original DuckDuckGo profile names). Update signing to your own team/bundle identifiers before export.
- For simulator testing, keep using:

```bash
xcodebuild -scheme 'iOS Browser' -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
