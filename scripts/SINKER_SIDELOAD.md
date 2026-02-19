# Sinker iOS Sideload Build

## 1) Archive + IPA Export

```bash
cd ~/Development/Sinker/DuckDuckGo-iOS
scripts/build_sinker_ipa.sh
```

Default values:
- Scheme: `iOS Browser`
- Archive path: `build/Sinker.xcarchive`
- IPA export path: `build/Sinker-ipa`
- Export options: `adhocExportOptions.plist`

## 2) Custom export options

```bash
EXPORT_OPTIONS_PLIST=alphaAdhocExportOptions.plist scripts/build_sinker_ipa.sh
```

## 3) Install to iPad (AltStore/SideStore)

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
