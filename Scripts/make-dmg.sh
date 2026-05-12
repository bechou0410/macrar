#!/bin/bash
# Bundle the signed MacRAR.app into a polished DMG for GitHub Releases.
# Requires: brew install create-dmg
set -euo pipefail

APP_PATH="${1:-build/Release/MacRAR.app}"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "ERROR: app not found at ${APP_PATH}"
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist")
SRC="${SRCROOT:-$(pwd)}"
OUT_DIR="build/Release"
DMG_PATH="${OUT_DIR}/MacRAR-${VERSION}.dmg"
STAGE="${OUT_DIR}/dmg-stage"

rm -rf "${STAGE}" "${DMG_PATH}"
mkdir -p "${STAGE}"

cp -R "${APP_PATH}" "${STAGE}/"
cp "${SRC}/Resources/DMG/README-FIRST.txt" "${STAGE}/README-FIRST.txt"

if command -v create-dmg >/dev/null 2>&1; then
  create-dmg \
    --volname "MacRAR ${VERSION}" \
    --window-pos 200 120 \
    --window-size 720 420 \
    --icon-size 100 \
    --icon "MacRAR.app"       180 200 \
    --icon "README-FIRST.txt" 540 320 \
    --app-drop-link           540 200 \
    --hide-extension "MacRAR.app" \
    --hdiutil-quiet \
    "${DMG_PATH}" \
    "${STAGE}/" || {
      echo "create-dmg failed, falling back to hdiutil"
      hdiutil create -volname "MacRAR ${VERSION}" -srcfolder "${STAGE}" -ov -format UDZO "${DMG_PATH}"
    }
else
  hdiutil create -volname "MacRAR ${VERSION}" -srcfolder "${STAGE}" -ov -format UDZO "${DMG_PATH}"
fi

# Ad-hoc sign the DMG itself (internal consistency)
codesign --force --sign - "${DMG_PATH}" 2>/dev/null || true

# Publish SHA-256 for download-page verification
shasum -a 256 "${DMG_PATH}" > "${DMG_PATH}.sha256"

# create-dmg / hdiutil mount the staging volume during build, which leaves
# stale `/Volumes/dmg.*` and `dmg-stage` entries registered with Launch
# Services. Unregister them so they don't compete with /Applications copy.
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"${LSREG}" -dump 2>/dev/null \
  | awk '/^identifier:/{id=$2} /^path:/{print id"|"$2}' \
  | grep "^com.bechou.winrar|" \
  | cut -d'|' -f2 \
  | sort -u \
  | while read -r p; do
      if [[ "$p" == /Volumes/* || "$p" == */dmg-stage/* || "$p" == */build/Release/MacRAR.app* ]]; then
        "${LSREG}" -u "$p" 2>/dev/null || true
      fi
    done

# Make sure /Applications stays the canonical registration AFTER any DMG-mount
# artifacts. Delegate full re-register + Services-restore flow to the dedicated
# script — guarantees the Finder menu is intact when this returns.
if [[ -d /Applications/MacRAR.app ]]; then
  SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
  bash "${SCRIPTS_DIR}/register-services.sh" /Applications/MacRAR.app 2>&1 \
    | grep -E "^(→|✓|⚠)" || true
fi

echo ""
echo "✓ Created: ${DMG_PATH}"
echo "  SHA256: $(cat ${DMG_PATH}.sha256 | cut -d' ' -f1)"
