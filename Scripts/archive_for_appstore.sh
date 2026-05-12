#!/usr/bin/env bash
# Archive the app for App Store upload.
# Requires: Xcode + Apple Developer account configured in Xcode preferences.
# Usage: ./Scripts/archive_for_appstore.sh <TEAM_ID>
#
# After this completes, open the .xcarchive in Xcode > Organizer to upload to App Store Connect.

set -euo pipefail

TEAM_ID="${1:-}"
if [[ -z "$TEAM_ID" ]]; then
    echo "Usage: $0 <TEAM_ID>"
    echo "TEAM_ID is your Apple Developer Team ID (10-character string)"
    echo "Find it at https://developer.apple.com/account → Membership"
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE_PATH="$REPO_ROOT/build/PixelColoringGame-$(date +%Y%m%d-%H%M%S).xcarchive"

mkdir -p "$REPO_ROOT/build"

echo "==> Cleaning derived data..."
rm -rf /tmp/PixelColoringGameArchive

echo "==> Archiving..."
xcodebuild archive \
    -scheme PixelColoringGame \
    -project "$REPO_ROOT/PixelColoringGame.xcodeproj" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=iOS" \
    -derivedDataPath /tmp/PixelColoringGameArchive \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic \
    | xcbeautify --quiet 2>/dev/null || \
xcodebuild archive \
    -scheme PixelColoringGame \
    -project "$REPO_ROOT/PixelColoringGame.xcodeproj" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=iOS" \
    -derivedDataPath /tmp/PixelColoringGameArchive \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic

echo ""
echo "==> Archive complete: $ARCHIVE_PATH"
echo ""
echo "Next steps:"
echo "  1. Open Xcode → Window → Organizer"
echo "  2. Select the archive named PixelColoringGame-$(date +%Y%m%d-*).xcarchive"
echo "  3. Click 'Distribute App' → 'App Store Connect' → 'Upload'"
echo "  4. After upload, the build appears in App Store Connect within 15-30 minutes"
