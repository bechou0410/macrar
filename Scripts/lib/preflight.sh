#!/bin/bash
# Reports metadata about the bundled unrar binary. Run before signing.
set -euo pipefail

VENDOR="${SRCROOT:-$(pwd)}/Vendor/unrar"

for variant in arm64 x86_64 universal; do
  bin="${VENDOR}/${variant}/unrar"
  if [[ -f "${bin}" ]]; then
    echo "─── ${variant}/unrar ───"
    file "${bin}"
    lipo -info "${bin}" 2>/dev/null || true
    echo "Dependencies:"
    otool -L "${bin}" | sed 's/^/  /'
    echo "Existing signature:"
    codesign -dvv "${bin}" 2>&1 | head -5 || true
    echo
  fi
done
