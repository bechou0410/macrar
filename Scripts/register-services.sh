#!/bin/bash
# Aggressively (re)registers MacRAR's Services menu items.
#
# Idempotent — safe to run after every build. Steps:
#   1. Unregister EVERY MacRAR copy lsregister knows about (Trash, /Volumes
#      DMG mounts, build dirs, old /Applications copies, etc.)
#   2. Re-register ONLY the canonical /Applications copy
#   3. Force pbs to refresh + enable our 2 entries in NSServicesStatus
#      and FinderActive so the Services submenu shows them by default
#   4. Restart pbs + Finder so changes are visible immediately
set -euo pipefail

APP="${1:-/Applications/MacRAR.app}"

if [[ ! -d "${APP}" ]]; then
  echo "ERROR: app not found at ${APP}"
  exit 1
fi

LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
PBS="/System/Library/CoreServices/pbs"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${APP}/Contents/Info.plist")
CANONICAL=$(/usr/bin/python3 -c "import os; print(os.path.realpath('${APP}'))")

echo "→ Unregistering EVERY MacRAR copy lsregister tracks (except ${CANONICAL})"
# Enumerate every path with our bundle ID. Use awk to pair identifier+path lines.
"${LSREG}" -dump 2>/dev/null \
  | awk '/^identifier:/{id=$2} /^path:/{print id"|"$2}' \
  | grep "^${BUNDLE_ID}|" \
  | cut -d'|' -f2 \
  | sort -u \
  | while read -r p; do
      [[ -z "$p" ]] && continue
      if [[ "$p" != "${CANONICAL}" ]]; then
        "${LSREG}" -u "$p" 2>/dev/null || true
      fi
    done

# Also nuke common stale path patterns that lsregister sometimes can't unregister
# directly (DMG mount points that no longer exist):
for stale in /Volumes/dmg.* /Volumes/MacRAR* /private/var/folders/*/MacRAR.app; do
  [[ -e "$stale" ]] || continue
  "${LSREG}" -u "$stale" 2>/dev/null || true
done

echo "→ Registering canonical ${APP} with Launch Services"
"${LSREG}" -f -R -trusted "${APP}"

echo "→ Refreshing Services (pbs -update)"
"${PBS}" -update 2>/dev/null || true
sleep 1

# Enable our Services in pbs.plist so they appear without manual System Settings tweak.
echo "→ Enabling Services in pbs.plist"
for slot in "Compress with MacRAR… - compressService" "Extract with MacRAR - extractService"; do
  key="${BUNDLE_ID} - ${slot}"
  defaults write pbs NSServicesStatus -dict-add \
    "${key}" \
    '{"enabled_context_menu" = 1; "enabled_services_menu" = 1;}' 2>/dev/null || true
  defaults write pbs FinderActive -dict-add \
    "${key}" -bool true 2>/dev/null || true
done

echo "→ Restarting pbs + Finder (wait for them to come back online)"
killall pbs 2>/dev/null || true
killall Finder 2>/dev/null || true

# Wait up to 5s for pbs + Finder to restart. Without this, the script can
# return while the Services menu is briefly empty — making users think the
# menu disappeared after rebuild.
for _ in $(seq 1 50); do
  if pgrep -x Finder >/dev/null && "${PBS}" -dump_pboard 2>/dev/null | grep -q "${BUNDLE_ID}"; then
    break
  fi
  sleep 0.1
done

# Final verification — does pbs see our services pointing to /Applications?
ACTUAL=$("${PBS}" -dump_pboard 2>/dev/null \
  | awk -v bid="${BUNDLE_ID}" '/NSBundleIdentifier/{id=$0} /NSBundlePath/{print id"|"$0}' \
  | grep "${BUNDLE_ID}" | head -1)

if [[ -n "${ACTUAL}" ]]; then
  echo "✓ Services registered + enabled."
  echo "  pbs sees: ${ACTUAL#*|}"
  echo "  Finder pid: $(pgrep -x Finder 2>/dev/null || echo "not running yet")"
else
  echo "⚠ pbs did not pick up the services yet — give it a few seconds, or log out / log in."
fi
