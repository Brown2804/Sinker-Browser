#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=/home/khj12/.openclaw
SCHEME=iOS Browser
PROJECT_PATH=/DuckDuckGo-iOS.xcodeproj
ARCHIVE_PATH=/build/Sinker.xcarchive
EXPORT_PATH=/build/Sinker-ipa
EXPORT_OPTIONS_PLIST=/adhocExportOptions.plist

mkdir -p .
mkdir -p 

echo [Sinker] Archiving scheme: 
xcodebuild   -project    -scheme    -configuration Release   -destination 'generic/platform=iOS'   -archivePath    clean archive

echo [Sinker] Exporting IPA
xcodebuild   -exportArchive   -archivePath    -exportPath    -exportOptionsPlist 

echo [Sinker] Done. IPA output: 
ls -lah 
