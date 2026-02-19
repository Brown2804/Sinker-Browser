#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="${SCHEME:-iOS Browser}"
PROJECT_PATH="${PROJECT_PATH:-${ROOT_DIR}/DuckDuckGo-iOS.xcodeproj}"
ARCHIVE_PATH="${ARCHIVE_PATH:-${ROOT_DIR}/build/Sinker.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-${ROOT_DIR}/build/Sinker-ipa}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-${ROOT_DIR}/adhocExportOptions.plist}"
TEAM_ID="${TEAM_ID:-${DEVELOPMENT_TEAM:-}}"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-1}"
SKIP_SIGNING_PREFLIGHT="${SKIP_SIGNING_PREFLIGHT:-0}"

if [[ -z "${TEAM_ID}" && -f "${HOME}/Library/Preferences/com.apple.dt.Xcode.plist" ]]; then
  TEAM_ID="$(python3 - <<'PY'
import plistlib, pathlib
p = pathlib.Path.home() / 'Library/Preferences/com.apple.dt.Xcode.plist'
try:
    data = plistlib.loads(p.read_bytes())
    teams = data.get('IDEProvisioningTeamByIdentifier', {})
    for _, arr in teams.items():
        if arr and isinstance(arr, list):
            team_id = arr[0].get('teamID')
            if team_id:
                print(team_id)
                break
except Exception:
    pass
PY
)"
  if [[ -n "${TEAM_ID}" ]]; then
    echo "[Sinker] Auto-discovered TEAM_ID from Xcode metadata: ${TEAM_ID}"
  fi
fi

if [[ "${SKIP_SIGNING_PREFLIGHT}" != "1" ]]; then
  if ! security find-identity -v -p codesigning 2>/dev/null | grep -qE '[0-9]+\) '; then
    if [[ -n "${TEAM_ID}" && "${ALLOW_PROVISIONING_UPDATES}" == "1" ]]; then
      echo "[Sinker] No local signing identity found; continuing with -allowProvisioningUpdates for TEAM_ID=${TEAM_ID}."
    else
      echo "[Sinker] No code signing identities found in keychain."
      echo "[Sinker] Install an Apple Development/Distribution certificate or run on a logged-in Xcode account machine."
      exit 2
    fi
  fi
fi

mkdir -p "$(dirname "${ARCHIVE_PATH}")"
mkdir -p "${EXPORT_PATH}"

ARCHIVE_ARGS=(
  -project "${PROJECT_PATH}"
  -scheme "${SCHEME}"
  -configuration Release
  -destination 'generic/platform=iOS'
  -archivePath "${ARCHIVE_PATH}"
  clean archive
)

if [[ -n "${TEAM_ID}" ]]; then
  echo "[Sinker] Applying automatic signing overrides for team: ${TEAM_ID}"
  ARCHIVE_ARGS+=(
    DEVELOPMENT_TEAM="${TEAM_ID}"
    CODE_SIGN_STYLE=Automatic
    CODE_SIGN_IDENTITY="Apple Development"
    PROVISIONING_PROFILE_SPECIFIER=
  )
  if [[ "${ALLOW_PROVISIONING_UPDATES}" == "1" ]]; then
    ARCHIVE_ARGS+=( -allowProvisioningUpdates )
  fi
fi

echo "[Sinker] Archiving scheme: ${SCHEME}"
xcodebuild "${ARCHIVE_ARGS[@]}"

RESOLVED_EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST}"
if [[ "${AUTO_FALLBACK_DEVELOPMENT_EXPORT:-1}" == "1" ]]; then
  export_method="$(python3 - <<PY
import plistlib
from pathlib import Path
p = Path('${EXPORT_OPTIONS_PLIST}')
try:
    data = plistlib.loads(p.read_bytes())
    print(data.get('method',''))
except Exception:
    print('')
PY
)"
  has_distribution_identity="$(security find-identity -v -p codesigning 2>/dev/null | grep -c 'iPhone Distribution' || true)"

  if [[ "${export_method}" == "ad-hoc" && "${has_distribution_identity}" == "0" ]]; then
    fallback_plist="$(mktemp /tmp/sinker-export-options.XXXXXX.plist)"
    python3 - <<PY
import plistlib
from pathlib import Path
src = Path('${EXPORT_OPTIONS_PLIST}')
dst = Path('${fallback_plist}')
data = plistlib.loads(src.read_bytes())
data['method'] = 'development'
data['signingStyle'] = 'automatic'
if '${TEAM_ID}':
    data['teamID'] = '${TEAM_ID}'
for key in ['provisioningProfiles', 'signingCertificate']:
    data.pop(key, None)
dst.write_bytes(plistlib.dumps(data))
PY
    RESOLVED_EXPORT_OPTIONS_PLIST="${fallback_plist}"
    echo "[Sinker] Distribution identity missing. Falling back export method to development: ${RESOLVED_EXPORT_OPTIONS_PLIST}"
  fi
fi

EXPORT_ARGS=(
  -exportArchive
  -archivePath "${ARCHIVE_PATH}"
  -exportPath "${EXPORT_PATH}"
  -exportOptionsPlist "${RESOLVED_EXPORT_OPTIONS_PLIST}"
)

if [[ -n "${TEAM_ID}" && "${ALLOW_PROVISIONING_UPDATES}" == "1" ]]; then
  EXPORT_ARGS+=( -allowProvisioningUpdates )
fi

echo "[Sinker] Exporting IPA"
xcodebuild "${EXPORT_ARGS[@]}"

echo "[Sinker] Done. IPA output: ${EXPORT_PATH}"
ls -lah "${EXPORT_PATH}"
