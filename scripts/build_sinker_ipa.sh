#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="${SCHEME:-iOS Browser}"
PROJECT_PATH="${PROJECT_PATH:-${ROOT_DIR}/DuckDuckGo-iOS.xcodeproj}"
ARCHIVE_PATH="${ARCHIVE_PATH:-${ROOT_DIR}/build/Sinker.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-${ROOT_DIR}/build/Sinker-ipa}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-${ROOT_DIR}/adhocExportOptions.plist}"

mkdir -p "$(dirname "${ARCHIVE_PATH}")"
mkdir -p "${EXPORT_PATH}"

echo "[Sinker] Archiving scheme: ${SCHEME}"
xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "${ARCHIVE_PATH}" \
  clean archive

echo "[Sinker] Exporting IPA"
xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}"

echo "[Sinker] Done. IPA output: ${EXPORT_PATH}"
ls -lah "${EXPORT_PATH}"
