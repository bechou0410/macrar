#!/bin/bash
# Deploys the freshly-signed build to /Applications/MacRAR.app, strips
# quarantine, and re-registers it as the canonical Services provider.
#
# Eliminates the "right-click menu disappears after rebuild" bug caused by
# two registered copies (build/Release + /Applications) competing in pbs.
set -euo pipefail

SRC="${1:-build/Release/MacRAR.app}"
DEST="/Applications/MacRAR.app"

if [[ ! -d "${SRC}" ]]; then
  echo "ERROR: source app not found at ${SRC}"
  exit 1
fi

# Kill any running instance so the copy doesn't hit a busy bundle.
killall MacRAR 2>/dev/null || true
sleep 0.5

echo "→ Copying ${SRC} → ${DEST}"
rm -rf "${DEST}"
cp -R "${SRC}" "${DEST}"
xattr -dr com.apple.quarantine "${DEST}" 2>/dev/null || true

# Unregister the source build copy so pbs only sees /Applications as the
# canonical MacRAR — eliminates "two MacRAR registrations" confusion.
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"${LSREG}" -u "${SRC}" 2>/dev/null || true

# Re-register /Applications so Services point to the new copy. Run last so it
# has the highest claim id and pbs prefers it.
bash "$(dirname "$0")/register-services.sh" "${DEST}"

# Force pbs to drop any cached NSBundlePath that points elsewhere.
killall pbs 2>/dev/null || true
sleep 0.5
/System/Library/CoreServices/pbs -update 2>/dev/null || true

echo "✓ Installed at ${DEST}"
