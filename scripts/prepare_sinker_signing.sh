#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PBXPROJ="${ROOT_DIR}/DuckDuckGo-iOS.xcodeproj/project.pbxproj"
DEV_CONFIG="${ROOT_DIR}/Configuration/DuckDuckGoDeveloper.xcconfig"
ALPHA_CONFIG="${ROOT_DIR}/Configuration/Configuration-Alpha.xcconfig"

BASE_BUNDLE_ID="${BASE_BUNDLE_ID:-com.brown2804.sinker}"
TEAM_ID="${TEAM_ID:-}"

if [[ ! -f "${PBXPROJ}" ]]; then
  echo "[Sinker] project.pbxproj not found: ${PBXPROJ}"
  exit 1
fi

echo "[Sinker] Preparing signing for base bundle id: ${BASE_BUNDLE_ID}"
cp "${PBXPROJ}" "${PBXPROJ}.bak.$(date +%Y%m%d-%H%M%S)"

# 1) Replace legacy DuckDuckGo bundle IDs with Sinker IDs.
perl -pi -e "s/com\\.duckduckgo\\.mobile\\.ios\\.alpha/${BASE_BUNDLE_ID}.alpha/g; s/com\\.duckduckgo\\.mobile\\.ios/${BASE_BUNDLE_ID}/g" "${PBXPROJ}"

# 2) Remove fixed provisioning profile specifiers to allow automatic signing.
perl -ni -e 'print unless /PROVISIONING_PROFILE_SPECIFIER\[sdk=iphoneos\*\]/' "${PBXPROJ}"

# 3) Optionally rewrite DEVELOPMENT_TEAM to user team.
if [[ -n "${TEAM_ID}" ]]; then
  perl -pi -e "s/DEVELOPMENT_TEAM = [A-Z0-9]+;/DEVELOPMENT_TEAM = ${TEAM_ID};/g" "${PBXPROJ}"
fi

# 4) Keep xcconfig app ids aligned.
if [[ -f "${DEV_CONFIG}" ]]; then
  perl -pi -e "s/^APP_ID\s*=\s*.*$/APP_ID = ${BASE_BUNDLE_ID}/" "${DEV_CONFIG}"
fi
if [[ -f "${ALPHA_CONFIG}" ]]; then
  perl -pi -e "s/^APP_ID\s*=\s*.*$/APP_ID = ${BASE_BUNDLE_ID}.alpha/" "${ALPHA_CONFIG}"
fi

echo "[Sinker] Signing prep complete."
echo "[Sinker] Next: TEAM_ID=<YOUR_TEAM_ID> scripts/build_sinker_ipa.sh"
