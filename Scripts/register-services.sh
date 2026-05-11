#!/bin/bash
# Force-registers the .app with Launch Services + pre-enables our Services
# menu items in `pbs` so they appear in Finder right-click → Services
# without the user needing to toggle them in System Settings.
#
# Also unregisters any OTHER MacRAR copies (stale dev builds, DMG mounts,
# previous versions) so pbs has a single canonical bundle to dispatch to —
# fixes "right-click menu disappears after rebuild" bug.
set -euo pipefail

APP="${1:-/Applications/MacRAR.app}"

if [[ ! -d "${APP}" ]]; then
  echo "ERROR: app not found at ${APP}"
  exit 1
fi

LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
PBS="/System/Library/CoreServices/pbs"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${APP}/Contents/Info.plist")
CANONICAL="$(/usr/bin/python3 -c "import os; print(os.path.realpath('${APP}'))")"

echo "→ Unregistering stale MacRAR copies"
"${LSREG}" -dump 2>/dev/null \
  | awk '/^identifier:/{id=$2} /^path:/{print id"|"$2}' \
  | grep "^com.bechou.winrar|" \
  | cut -d'|' -f2 \
  | sort -u \
  | while read -r p; do
      [[ -z "$p" ]] && continue
      if [[ "$p" != "${CANONICAL}" ]]; then
        echo "    unregister $p"
        "${LSREG}" -u "$p" 2>/dev/null || true
      fi
    done

echo "→ Re-registering ${APP} with Launch Services"
"${LSREG}" -f -R -trusted "${APP}"

echo "→ Refreshing Services menu (pbs -update)"
"${PBS}" -update 2>/dev/null || true
sleep 1

# Enable our Services in pbs.plist so they appear without manual System Settings tweak.
echo "→ Enabling Services in pbs.plist"
defaults write pbs NSServicesStatus -dict-add \
  "${BUNDLE_ID} - Compress with MacRAR… - compressService" \
  '{"enabled_context_menu" = 1; "enabled_services_menu" = 1;}' 2>/dev/null || true
defaults write pbs NSServicesStatus -dict-add \
  "${BUNDLE_ID} - Extract with MacRAR - extractService" \
  '{"enabled_context_menu" = 1; "enabled_services_menu" = 1;}' 2>/dev/null || true

# Also surface them in Finder's "Quick Actions" so they appear at top-level on Tahoe.
defaults write pbs FinderActive -dict-add \
  "${BUNDLE_ID} - Compress with MacRAR… - compressService" -bool true 2>/dev/null || true
defaults write pbs FinderActive -dict-add \
  "${BUNDLE_ID} - Extract with MacRAR - extractService" -bool true 2>/dev/null || true

killall pbs 2>/dev/null || true
killall Finder 2>/dev/null || true

echo "✓ Services registered + enabled at ${APP}."
echo ""
echo "Right-click any file in Finder → Services:"
echo "    • Compress with MacRAR…"
echo "    • Extract with MacRAR"
