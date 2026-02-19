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
    PROVISIONING_PROFILE_SPECIFIER=
  )
  if [[ "${ALLOW_PROVISIONING_UPDATES}" == "1" ]]; then
    ARCHIVE_ARGS+=( -allowProvisioningUpdates )
  fi
fi

echo "[Sinker] Archiving scheme: ${SCHEME}"
xcodebuild "${ARCHIVE_ARGS[@]}"

EXPORT_ARGS=(
  -exportArchive
  -archivePath "${ARCHIVE_PATH}"
  -exportPath "${EXPORT_PATH}"
  -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}"
)

if [[ -n "${TEAM_ID}" && "${ALLOW_PROVISIONING_UPDATES}" == "1" ]]; then
  EXPORT_ARGS+=( -allowProvisioningUpdates )
fi

echo "[Sinker] Exporting IPA"
xcodebuild "${EXPORT_ARGS[@]}"

echo "[Sinker] Done. IPA output: ${EXPORT_PATH}"
ls -lah "${EXPORT_PATH}"
