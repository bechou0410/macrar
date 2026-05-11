#!/bin/bash
# Ad-hoc code-signs the .app and nested helpers (no Apple Developer ID).
# Inside-out order: unrar → QL extension → main app.
set -euo pipefail

APP="${1:-build/Release/MacRAR.app}"

if [[ ! -d "${APP}" ]]; then
  echo "ERROR: app bundle not found: ${APP}"
  exit 1
fi

echo "→ Stripping quarantine + existing sigs from nested binaries"
xattr -cr "${APP}" 2>/dev/null || true

echo "→ Signing bundled unrar (ad-hoc)"
codesign --force --sign - --timestamp=none \
  "${APP}/Contents/Helpers/MacOS/unrar"

echo "→ Signing Quick Look extension"
QL="${APP}/Contents/PlugIns/QuickLookExtension.appex"
if [[ -d "${QL}" ]]; then
  codesign --force --sign - --timestamp=none --deep "${QL}"
fi

echo "→ Signing main app bundle"
codesign --force --sign - --timestamp=none --deep "${APP}"

echo "→ Verifying"
codesign --verify --verbose=4 "${APP}"
codesign -dvvv "${APP}" 2>&1 | head -10

echo "✓ Ad-hoc sign complete: ${APP}"

# Auto-deploy to /Applications and re-register so the Services menu always
# points to a single canonical copy. Solves the "right-click menu disappears
# after rebuild" problem where pbs had two competing MacRAR registrations.
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -x "${SCRIPTS_DIR}/install-to-applications.sh" ]]; then
  bash "${SCRIPTS_DIR}/install-to-applications.sh" "${APP}" 2>&1 \
    | grep -E "^(→|✓|ERROR)" || true
fi
