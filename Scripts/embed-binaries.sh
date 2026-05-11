#!/bin/bash
# Copies bundled unrar + RARLAB docs into the .app bundle.
# Called from Xcode pre-build script phase.
set -euo pipefail

APP="${TARGET_BUILD_DIR:-build/Release}/${WRAPPER_NAME:-MacRAR.app}"
SRC="${SRCROOT:-$(pwd)}"

HELPERS="${APP}/Contents/Helpers/MacOS"
RESOURCES="${APP}/Contents/Resources"

mkdir -p "${HELPERS}" "${RESOURCES}"

# unrar (bundled, required)
cp "${SRC}/Vendor/unrar/universal/unrar" "${HELPERS}/unrar"
chmod 755 "${HELPERS}/unrar"
# Ad-hoc sign so Xcode's outer codesign step doesn't reject nested binary.
# Final ad-hoc resign of the whole bundle happens in Scripts/sign-adhoc.sh for distribution.
codesign --force --sign - --timestamp=none "${HELPERS}/unrar"

# Docs for in-app help / credits
for doc in rar.txt rarlab-license.txt acknow.txt readme.txt; do
  if [[ -f "${SRC}/Vendor/docs/${doc}" ]]; then
    cp "${SRC}/Vendor/docs/${doc}" "${RESOURCES}/${doc}"
  fi
done

# Project LICENSE
[[ -f "${SRC}/LICENSE" ]] && cp "${SRC}/LICENSE" "${RESOURCES}/LICENSE.txt"

echo "[embed] unrar + docs → ${APP}"
