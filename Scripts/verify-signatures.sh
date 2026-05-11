#!/bin/bash
# Sanity-check code signatures in the app bundle.
# spctl assessment is EXPECTED to fail without Developer ID — that's the point.
set -euo pipefail

APP="${1:-build/Release/MacRAR.app}"

echo "─── codesign --verify ───"
codesign --verify --strict --verbose=4 "${APP}"

echo
echo "─── codesign -dvvv ───"
codesign -dvvv "${APP}"

echo
echo "─── Nested binaries ───"
for bin in "${APP}/Contents/Helpers/MacOS"/* "${APP}/Contents/PlugIns"/*; do
  if [[ -e "${bin}" ]]; then
    echo ">>> ${bin}"
    codesign -dvv "${bin}" 2>&1 | head -5
    echo
  fi
done

echo "─── spctl assessment (expected: rejected — ad-hoc has no notarization) ───"
spctl -a -t exec -vv "${APP}" || echo "(↑ rejection is expected without Developer ID)"

echo
echo "✓ Internal consistency verified. Users will need Install.command or right-click → Open."
